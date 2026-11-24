package core

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func pooledFixture(t *testing.T, handler http.HandlerFunc) (*firstPartyHTTPService, *atomic.Int32) {
	t.Helper()
	var accepted atomic.Int32
	server := httptest.NewUnstartedServer(handler)
	server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateNew {
			accepted.Add(1)
		}
	}
	server.StartTLS()
	t.Cleanup(server.Close)
	service := newFirstPartyHTTPService(func() *http.Transport {
		transport := firstPartyHTTPTransport(func(ctx context.Context, network, _ string) (net.Conn, error) {
			return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
		})
		transport.TLSClientConfig = server.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
		transport.TLSClientConfig.ServerName = server.Certificate().DNSNames[0]
		return transport
	})
	t.Cleanup(service.resetIdle)
	return service, &accepted
}

func TestFirstPartyHTTPPoolReuses200FixturePostsAndPreservesCommittedResult(t *testing.T) {
	var service *firstPartyHTTPService
	var writes atomic.Int32
	service, accepted := pooledFixture(t, func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		if string(body) != "fixture" || r.Header.Get("Authorization") != "Bearer synthetic" {
			t.Error("credential/body changed")
		}
		if writes.Add(1) == 200 {
			service.resetIdle()
		}
		io.WriteString(w, "committed")
	})
	for i := 0; i < 200; i++ {
		p := firstPartyParams()
		p.RequestID = fmt.Sprint(i)
		if i%2 == 0 {
			p.URL = "https://link.zolmid.com/api/v1/passport/auth/login"
		} else {
			p.URL = "https://link.zolmid.com/api/v1/zolnit/client/bundle"
		}
		p.Method = "POST"
		p.Body = base64.StdEncoding.EncodeToString([]byte("fixture"))
		p.Headers = map[string]string{"Authorization": "Bearer synthetic"}
		result, err := service.send(p)
		if err != nil || result.Body != base64.StdEncoding.EncodeToString([]byte("committed")) {
			t.Fatalf("request %d: %v", i, err)
		}
	}
	if accepted.Load() != 1 || writes.Load() != 200 {
		t.Fatalf("accepted=%d writes=%d", accepted.Load(), writes.Load())
	}
	t.Logf("200 POSTs: %d accepted TCP connection, 200 committed results; reset during final handler preserved result", accepted.Load())
}

func TestFirstPartyHTTPPoolScopesAndExpires(t *testing.T) {
	s := newFirstPartyHTTPService(newFirstPartyHTTPTransport)
	defer s.resetIdle()
	p := firstPartyParams()
	a, _ := s.pooledTransport(p)
	b, _ := s.pooledTransport(p)
	if a != b {
		t.Fatal("same scope did not reuse")
	}
	p.Headers = map[string]string{"Authorization": "Bearer changed"}
	b, _ = s.pooledTransport(p)
	if a == b {
		t.Fatal("authorization crossed pool scope")
	}
	p.ClientID = "different-client"
	c, _ := s.pooledTransport(p)
	if b == c {
		t.Fatal("client scope reused")
	}
	s.mu.Lock()
	for _, pool := range s.pools {
		pool.until = time.Now().Add(-time.Second)
	}
	s.mu.Unlock()
	d, _ := s.pooledTransport(p)
	if c == d {
		t.Fatal("expired policy reused")
	}
	s.resetIdle()
	e, _ := s.pooledTransport(p)
	if d == e {
		t.Fatal("network generation reused")
	}
	p.Addresses = []string{"192.0.2.1"}
	f, _ := s.pooledTransport(p)
	p.Addresses = []string{"192.0.2.2"}
	g, _ := s.pooledTransport(p)
	if f == g {
		t.Fatal("address policy reused")
	}
}

func TestFirstPartyHTTPPoolDoesNotReplayCommittedPostOnReusedSocket(t *testing.T) {
	for _, body := range []string{"", "synthetic"} {
		t.Run(fmt.Sprint(len(body)), func(t *testing.T) {
			var calls atomic.Int32
			s, _ := pooledFixture(t, func(w http.ResponseWriter, r *http.Request) {
				io.Copy(io.Discard, r.Body)
				if calls.Add(1) == 1 {
					io.WriteString(w, "warm")
					return
				}
				conn, _, err := w.(http.Hijacker).Hijack()
				if err != nil {
					t.Error(err)
					return
				}
				conn.Close()
			})
			p := firstPartyParams()
			if _, err := s.send(p); err != nil {
				t.Fatal(err)
			}
			p.RequestID = "write"
			p.Method = "POST"
			p.Body = base64.StdEncoding.EncodeToString([]byte(body))
			p.Headers = map[string]string{"Idempotency-Key": "synthetic"}
			if _, err := s.send(p); err == nil {
				t.Fatal("lost committed result was accepted")
			}
			if calls.Load() != 2 {
				t.Fatalf("POST replayed: total requests %d", calls.Load())
			}
		})
	}
}

func TestFirstPartyHTTPPoolInvalidationCancelsOnlyNewDial(t *testing.T) {
	generation, cancel := context.WithCancel(context.Background())
	entered, release := make(chan struct{}), make(chan struct{})
	left, right := net.Pipe()
	defer right.Close()
	guarded := guardFirstPartyDial(generation, func(ctx context.Context, _, _ string) (net.Conn, error) {
		close(entered)
		<-ctx.Done()
		<-release
		return left, nil
	})
	result := make(chan error, 1)
	go func() { _, err := guarded(context.Background(), "tcp", "fixture"); result <- err }()
	<-entered
	cancel()
	close(release)
	if err := <-result; err != context.Canceled {
		t.Fatal(err)
	}
	right.SetReadDeadline(time.Now().Add(time.Second))
	var b [1]byte
	if _, err := right.Read(b[:]); err != io.EOF {
		t.Fatalf("late socket was not closed: %v", err)
	}
}

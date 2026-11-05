package core

import (
	"context"
	"encoding/base64"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func firstPartyParams() FirstPartyHTTPParams {
	return FirstPartyHTTPParams{ClientID: "client", RequestID: "request", Method: "GET", URL: "https://link.zolmid.com/api/v1/test", Timeout: 2000}
}

func firstPartyTestService(t *testing.T, handler http.HandlerFunc, trusted bool) *firstPartyHTTPService {
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	return newFirstPartyHTTPService(func() *http.Transport {
		transport := firstPartyHTTPTransport(func(ctx context.Context, network, address string) (net.Conn, error) {
			if address != "link.zolmid.com:443" {
				t.Errorf("unexpected destination %s", address)
			}
			return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
		})
		if trusted {
			transport.TLSClientConfig.RootCAs = server.Client().Transport.(*http.Transport).TLSClientConfig.RootCAs
			transport.TLSClientConfig.ServerName = server.Certificate().DNSNames[0]
		}
		return transport
	})
}

func TestFirstPartyHTTPRejectsRequestsOutsideContract(t *testing.T) {
	cases := map[string]func(*FirstPartyHTTPParams){
		"host":      func(p *FirstPartyHTTPParams) { p.URL = "https://example.com/api/v1/test" },
		"scheme":    func(p *FirstPartyHTTPParams) { p.URL = "http://link.zolmid.com/api/v1/test" },
		"path":      func(p *FirstPartyHTTPParams) { p.URL = "https://link.zolmid.com/private" },
		"user-info": func(p *FirstPartyHTTPParams) { p.URL = "https://secret@link.zolmid.com/api/v1/test" },
		"method":    func(p *FirstPartyHTTPParams) { p.Method = "PUT" },
		"header":    func(p *FirstPartyHTTPParams) { p.Headers = map[string]string{"Cookie": "secret"} },
		"body": func(p *FirstPartyHTTPParams) {
			p.Method = "POST"
			p.Body = strings.Repeat("A", firstPartyHTTPMaxRequest*2)
		},
		"deadline": func(p *FirstPartyHTTPParams) { p.Timeout = 26000 },
	}
	for name, change := range cases {
		t.Run(name, func(t *testing.T) {
			p := firstPartyParams()
			change(&p)
			_, err := handleFirstPartyHTTP(p)
			failure, ok := err.(*MethodError)
			if !ok || failure.Message != "first-party request failed" || failure.Details != nil {
				t.Fatalf("unsanitized error: %#v", err)
			}
		})
	}
}

func TestFirstPartyHTTPPostResponseAndNoRedirectReplay(t *testing.T) {
	var calls atomic.Int32
	service := firstPartyTestService(t, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		body, _ := io.ReadAll(r.Body)
		if r.Method != "POST" || string(body) != "fixture-body" || r.Header.Get("Authorization") != "Bearer fixture" {
			t.Error("request content mismatch")
		}
		w.Header().Set("Location", "https://example.invalid/leak")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(307)
		_, _ = io.WriteString(w, `{"data":"fixture"}`)
	}, true)
	p := firstPartyParams()
	p.Method = "POST"
	p.Body = base64.StdEncoding.EncodeToString([]byte("fixture-body"))
	p.Headers = map[string]string{"Authorization": "Bearer fixture"}
	result, err := service.send(p)
	if err != nil || result.Status != 307 || calls.Load() != 1 {
		t.Fatalf("result=%#v err=%v calls=%d", result, err, calls.Load())
	}
	body, _ := base64.StdEncoding.DecodeString(result.Body)
	if string(body) != `{"data":"fixture"}` {
		t.Fatal("response was changed")
	}
}

func TestFirstPartyHTTPStrictTLS(t *testing.T) {
	transport := newFirstPartyHTTPTransport()
	if transport.TLSClientConfig.InsecureSkipVerify || transport.Proxy != nil {
		t.Fatal("TLS or proxy policy weakened")
	}
	service := firstPartyTestService(t, func(w http.ResponseWriter, r *http.Request) { t.Error("untrusted peer received request") }, false)
	_, err := service.send(firstPartyParams())
	if failure, ok := err.(*MethodError); !ok || failure.Code != "network" {
		t.Fatalf("error=%v", err)
	}
}

func TestFirstPartyHTTPDeadlineClosesSlowBody(t *testing.T) {
	stopped := make(chan struct{})
	service := firstPartyTestService(t, func(w http.ResponseWriter, r *http.Request) {
		defer close(stopped)
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}, true)
	p := firstPartyParams()
	p.Timeout = 100
	_, err := service.send(p)
	if failure, ok := err.(*MethodError); !ok || failure.Code != "timeout" {
		t.Fatalf("error=%v", err)
	}
	select {
	case <-stopped:
	case <-time.After(time.Second):
		t.Fatal("socket survived deadline")
	}
}

func TestFirstPartyHTTPCancellationIsScopedAndCanPrecedeAdmission(t *testing.T) {
	started := make(chan struct{})
	service := firstPartyTestService(t, func(w http.ResponseWriter, r *http.Request) {
		close(started)
		<-r.Context().Done()
	}, true)
	p := firstPartyParams()
	done := make(chan error, 1)
	go func() { _, err := service.send(p); done <- err }()
	<-started
	service.cancel(FirstPartyHTTPCancelParams{ClientID: "other", RequestID: p.RequestID})
	select {
	case err := <-done:
		t.Fatalf("other client cancelled request: %v", err)
	case <-time.After(20 * time.Millisecond):
	}
	service.cancel(FirstPartyHTTPCancelParams{ClientID: p.ClientID, RequestID: p.RequestID})
	if err := <-done; err.(*MethodError).Code != "cancelled" {
		t.Fatalf("error=%v", err)
	}
	p.RequestID = "before"
	service.cancel(FirstPartyHTTPCancelParams{ClientID: p.ClientID, RequestID: p.RequestID})
	if _, err := service.send(p); err.(*MethodError).Code != "cancelled" {
		t.Fatalf("pre-cancel error=%v", err)
	}
}

func TestFirstPartyHTTPRejectsOversizedResponse(t *testing.T) {
	service := firstPartyTestService(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "8388609")
		w.WriteHeader(200)
	}, true)
	_, err := service.send(firstPartyParams())
	if failure, ok := err.(*MethodError); !ok || failure.Code != "response_too_large" {
		t.Fatalf("error=%v", err)
	}
}

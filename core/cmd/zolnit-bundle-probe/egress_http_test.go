package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

type observationTransport func(*http.Request) (*http.Response, error)

func (f observationTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

type observationBody struct {
	io.Reader
	closed bool
	read   int
}

func (b *observationBody) Read(p []byte) (int, error) {
	n, e := b.Reader.Read(p)
	b.read += n
	return n, e
}
func (b *observationBody) Close() error { b.closed = true; return nil }
func observationClient(t *testing.T, handle func(*http.Request) *http.Response) *http.Client {
	t.Helper()
	client := isolatedClient(nil)
	client.Transport = observationTransport(func(r *http.Request) (*http.Response, error) { return handle(r), nil })
	return client
}
func responseWith(body io.ReadCloser, status int) *http.Response {
	return &http.Response{StatusCode: status, Header: http.Header{"Content-Type": {"application/json"}}, Body: body, ContentLength: -1}
}
func TestEgressRequestUsesOnlyDocumentedFixedEndpoint(t *testing.T) {
	key := bytes.Repeat([]byte{1}, 32)
	body := &observationBody{Reader: strings.NewReader(`{"ip":"8.8.8.8","country":"US","secret":"MUST_NOT_LEAK"}`)}
	calls := 0
	client := observationClient(t, func(r *http.Request) *http.Response {
		calls++
		if r.URL.String() != egressObservationURL || r.Method != http.MethodGet || r.URL.RawQuery != "" || r.Body != nil {
			t.Fatal("request deviated from fixed endpoint")
		}
		if r.Header.Get("Authorization") != "" || r.Header.Get("Cookie") != "" || r.Header.Get("Accept-Encoding") != "identity" {
			t.Fatal("unexpected credential or compression header")
		}
		return responseWith(body, 200)
	})
	country, tag, code, status := requestEgress(context.Background(), client, key)
	if country != "US" || !strings.HasPrefix(tag, "eg1.") || len(tag) != 68 || code != "" || status != 200 || calls != 1 || !body.closed {
		t.Fatal("fixed observation failed")
	}
	if strings.Contains(tag, "8.8.8.8") || strings.Contains(tag, "MUST_NOT_LEAK") {
		t.Fatal("private data in output")
	}
}
func TestEgressRequestNeverFollowsRedirect(t *testing.T) {
	body := &observationBody{Reader: strings.NewReader("PRIVATE_REDIRECT_BODY")}
	calls := 0
	client := observationClient(t, func(r *http.Request) *http.Response {
		calls++
		response := responseWith(body, 302)
		response.Header.Set("Location", "https://must-never-visit.invalid/private")
		return response
	})
	country, tag, code, status := requestEgress(context.Background(), client, bytes.Repeat([]byte{1}, 32))
	if calls != 1 || country != "" || tag != "" || code != "egress_http_status" || status != 302 || !body.closed {
		t.Fatal("redirect was not refused")
	}
}
func TestEgressResponseIsBoundedAndInvalidContentReturnsNoObservation(t *testing.T) {
	for _, tc := range []struct {
		name, ctype, encoding, content, want string
		length                               int64
		maxRead                              int
	}{
		{"declared_large", "application/json", "", strings.Repeat("x", 4097), "egress_response_too_large", 4097, 0},
		{"streamed_large", "application/json", "", strings.Repeat("x", 9000), "egress_response_too_large", -1, 4097},
		{"html", "text/html", "", "PRIVATE_HTML", "egress_response_invalid", -1, 0},
		{"compressed", "application/json", "gzip", "PRIVATE_GZIP", "egress_response_invalid", -1, 0},
		{"invalid_json", "application/json", "", "PRIVATE_INVALID_IP_BODY", "invalid_egress_observation", -1, 4097},
		{"unknown_country", "application/json", "", `{"ip":"8.8.8.8","country":null}`, "invalid_egress_country", -1, 4097},
	} {
		t.Run(tc.name, func(t *testing.T) {
			body := &observationBody{Reader: strings.NewReader(tc.content)}
			client := observationClient(t, func(r *http.Request) *http.Response {
				response := responseWith(body, 200)
				response.Header.Set("Content-Type", tc.ctype)
				response.Header.Set("Content-Encoding", tc.encoding)
				response.ContentLength = tc.length
				return response
			})
			country, tag, code, _ := requestEgress(context.Background(), client, bytes.Repeat([]byte{1}, 32))
			if country != "" || tag != "" || code != tc.want || !body.closed || body.read > tc.maxRead {
				t.Fatal("response did not fail closed within limits")
			}
		})
	}
}
func TestEgressNetworkErrorsAreSanitized(t *testing.T) {
	client := isolatedClient(nil)
	client.Transport = observationTransport(func(*http.Request) (*http.Response, error) { return nil, errors.New("PRIVATE_CREDENTIAL 8.8.8.8") })
	country, tag, code, status := requestEgress(context.Background(), client, bytes.Repeat([]byte{1}, 32))
	if country != "" || tag != "" || code != "isolated_connection_failed" || status != 0 {
		t.Fatal("transport error was not sanitized")
	}
}

type contextObservationReader struct{ ctx context.Context }

func (r contextObservationReader) Read([]byte) (int, error) { <-r.ctx.Done(); return 0, r.ctx.Err() }
func TestEgressBodyHonorsRequestDeadline(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	body := &observationBody{Reader: contextObservationReader{ctx}}
	client := observationClient(t, func(*http.Request) *http.Response { return responseWith(body, 200) })
	country, tag, code, _ := requestEgress(ctx, client, bytes.Repeat([]byte{1}, 32))
	if country != "" || tag != "" || code != "isolated_connection_failed" || !body.closed {
		t.Fatal("deadline did not fail closed")
	}
}
func TestEgressModeNeedsPrivateWindowContextAndExclusiveFixedTarget(t *testing.T) {
	now := time.Unix(2000, 0)
	for _, opt := range []options{
		{account: "2", target: "gstatic", timeout: time.Second, observe: true},
		{account: "2", target: "gstatic", timeout: time.Second, observe: true, probe: true},
		{account: "2", target: "gstatic", timeout: time.Second, observe: true, targetExplicit: true},
	} {
		r := execute(encoded(t, fixture(t, now)), opt, func() time.Time { return now })
		if r.OK || r.Country != "" || r.EgressTag != "" {
			t.Fatal("unsafe observation context accepted")
		}
		if !opt.probe && !opt.targetExplicit && r.Code != "observation_context_required" {
			t.Fatal("missing key was not classified")
		}
	}
	f := fixture(t, now)
	f["observation"] = map[string]string{"key_b64u": base64.RawURLEncoding.EncodeToString(make([]byte, 32))}
	r := execute(encoded(t, f), options{account: "2", target: "gstatic", timeout: time.Second, observe: true}, func() time.Time { return now })
	if r.OK || r.Code != "observation_context_required" {
		t.Fatal("all-zero key accepted")
	}
}

package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/dialer"
)

func fixture(t *testing.T, at time.Time) map[string]any {
	t.Helper()
	document := "proxies:\n- {name: zn.node.socks5.1, type: socks5, server: 192.0.2.1, port: 1080}\nproxy-groups:\n- {name: zn.service.ai, type: select, proxies: [REJECT, DIRECT]}\nrule-providers:\n  forbidden: {type: http, url: 'https://must-never-fetch.invalid/private'}\ndns: {enable: true, listen: '0.0.0.0:53'}\ntun: {enable: true}\nmixed-port: 7890\n"
	hash := sha256.Sum256([]byte(document))
	return map[string]any{"http_status": 200, "source_path": bundlePath, "body": map[string]any{"data": map[string]any{
		"schema_version": 1, "account_id": "2", "bundle_id": "synthetic", "issued_at": at.Unix() - 1, "expires_at": at.Unix() + 299,
		"connection": map[string]any{"engine": "mihomo", "format": "yaml", "sha256": hex.EncodeToString(hash[:]), "document": document},
		"outbounds":  []any{map[string]any{"id": "socks5:1", "proxy_name": "zn.node.socks5.1", "display_name": "Synthetic"}},
		"routing":    map[string]any{"version": 1, "authority": "zolnit", "revision": "synthetic", "services": []any{map[string]any{"id": "ai", "group": "zn.service.ai", "automatic": "zn.service.ai.auto", "manual": "zn.service.ai.manual"}}, "nodes": []any{}},
	}}}
}
func body(f map[string]any) map[string]any {
	return f["body"].(map[string]any)["data"].(map[string]any)
}
func encoded(t *testing.T, f map[string]any) *bytes.Reader {
	t.Helper()
	data, err := json.Marshal(f)
	if err != nil {
		t.Fatal(err)
	}
	return bytes.NewReader(data)
}
func TestValidationRefusesInvalidOrStaleFrames(t *testing.T) {
	now := time.Unix(2000, 0)
	cases := []struct {
		name, code string
		mutate     func(map[string]any)
	}{
		{"403_stale_body", "entitlement_unavailable", func(f map[string]any) {
			f["http_status"] = 403
			f["body"].(map[string]any)["error"] = map[string]any{"code": "entitlement_unavailable"}
		}},
		{"503_stale_body", "bundle_unavailable", func(f map[string]any) {
			f["http_status"] = 503
			f["body"].(map[string]any)["error"] = map[string]any{"code": "bundle_unavailable"}
		}},
		{"wrong_path", "invalid_api_frame", func(f map[string]any) { f["source_path"] = "/api/v1/client/subscribe" }},
		{"wrong_account", "invalid_bundle_binding", func(f map[string]any) { body(f)["account_id"] = "other" }},
		{"expired", "invalid_bundle_ttl", func(f map[string]any) { body(f)["expires_at"] = now.Unix() }},
		{"overlong", "invalid_bundle_ttl", func(f map[string]any) { body(f)["expires_at"] = now.Unix() + 301 }},
		{"future", "invalid_bundle_ttl", func(f map[string]any) { body(f)["issued_at"] = now.Unix() + 1 }},
		{"hash", "invalid_connection_hash", func(f map[string]any) { body(f)["connection"].(map[string]any)["document"] = "secret" }},
		{"mapping", "invalid_outbound_mapping", func(f map[string]any) { body(f)["outbounds"].([]any)[0].(map[string]any)["proxy_name"] = "DIRECT" }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			f := fixture(t, now)
			c.mutate(f)
			v, code := validate(encoded(t, f), "2", func() time.Time { return now })
			if v != nil || code != c.code {
				t.Fatalf("got %s", code)
			}
		})
	}
	for _, value := range []string{`{"http_status":200,"http_status":403}`, `{"http_status":200} {}`, `<html>403 secret</html>`} {
		if _, code := validate(strings.NewReader(value), "2", func() time.Time { return now }); code != "invalid_input" {
			t.Fatal(code)
		}
	}
}
func TestValidationOnlyNeverAppliesListenersProvidersDNSOrTUN(t *testing.T) {
	now := time.Unix(2000, 0)
	r := execute(encoded(t, fixture(t, now)), options{account: "2", target: "gstatic", timeout: time.Second}, func() time.Time { return now })
	if !r.OK || r.Code != "validated" || r.Nodes != 0 || !r.Mapping || !r.Hash || r.Mode != "validate" {
		t.Fatalf("unexpected sanitized report: %+v", r)
	}
}
func TestCoreParserErrorsNeverExposeCredentials(t *testing.T) {
	now := time.Unix(2000, 0)
	f := fixture(t, now)
	b := body(f)
	doc := "proxies:\n- {name: zn.node.ss.1, type: ss, server: 192.0.2.1, port: 443, cipher: NEVER_LOG_PRIVATE_CREDENTIAL, password: NEVER_LOG_PRIVATE_CREDENTIAL}\nproxy-groups:\n- {name: zn.service.ai, type: select, proxies: [REJECT]}\n"
	hash := sha256.Sum256([]byte(doc))
	b["connection"] = map[string]any{"engine": "mihomo", "format": "yaml", "sha256": hex.EncodeToString(hash[:]), "document": doc}
	b["outbounds"] = []any{map[string]any{"id": "ss:1", "proxy_name": "zn.node.ss.1", "display_name": "Private display"}}
	r := execute(encoded(t, f), options{account: "2", outbound: "ss:1", probe: true, target: "gstatic", timeout: time.Second}, func() time.Time { return now })
	data, _ := json.Marshal(r)
	if r.OK || r.Code != "core_proxy_invalid" || strings.Contains(string(data), "NEVER_LOG") || strings.Contains(string(data), "Private display") {
		t.Fatalf("unexpected report code %s", r.Code)
	}
}
func TestIsolatedHTTPUsesRetainedCoreProxyAndIgnoresEnvironmentProxy(t *testing.T) {
	t.Setenv("HTTP_PROXY", "http://127.0.0.1:1")
	t.Setenv("HTTPS_PROXY", "http://127.0.0.1:1")
	var received atomic.Int32
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodHead {
			t.Error("not HEAD")
		}
		w.WriteHeader(204)
	}))
	defer target.Close()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	done := make(chan struct{})
	go func() {
		defer close(done)
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		_ = conn.SetDeadline(time.Now().Add(3 * time.Second))
		header := make([]byte, 2)
		if _, err = io.ReadFull(conn, header); err != nil {
			return
		}
		methods := make([]byte, int(header[1]))
		if _, err = io.ReadFull(conn, methods); err != nil {
			return
		}
		_, _ = conn.Write([]byte{5, 0})
		request := make([]byte, 4)
		if _, err = io.ReadFull(conn, request); err != nil {
			return
		}
		var host string
		switch request[3] {
		case 1:
			b := make([]byte, 4)
			_, _ = io.ReadFull(conn, b)
			host = net.IP(b).String()
		case 3:
			b := make([]byte, 1)
			_, _ = io.ReadFull(conn, b)
			s := make([]byte, int(b[0]))
			_, _ = io.ReadFull(conn, s)
			host = string(s)
		default:
			return
		}
		port := make([]byte, 2)
		if _, err = io.ReadFull(conn, port); err != nil {
			return
		}
		address := net.JoinHostPort(host, strconv.Itoa(int(port[0])<<8|int(port[1])))
		if address != strings.TrimPrefix(target.URL, "http://") {
			return
		}
		upstream, err := net.DialTimeout("tcp", address, time.Second)
		if err != nil {
			return
		}
		defer upstream.Close()
		received.Add(1)
		_, _ = conn.Write([]byte{5, 0, 0, 1, 127, 0, 0, 1, 0, 0})
		go func() { _, _ = io.Copy(upstream, conn) }()
		_, _ = io.Copy(conn, upstream)
	}()
	host, portText, _ := net.SplitHostPort(listener.Addr().String())
	port, err := strconv.Atoi(portText)
	if err != nil {
		t.Fatal(err)
	}
	proxy, err := adapter.ParseProxy(map[string]any{"name": "synthetic", "type": "socks5", "server": host, "port": port}, adapter.WithDialerForAPI(dialer.NewDialer()))
	if err != nil {
		t.Fatal("Core proxy parse failed")
	}
	defer proxy.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	status, err := isolatedHTTP(ctx, proxy, target.URL)
	if err != nil || status != 204 || received.Load() != 1 {
		t.Fatalf("isolated Core transport failed: status %d", status)
	}
	<-done
}

type receiptReader struct {
	source io.Reader
	after  func()
}

func (r receiptReader) Read(p []byte) (int, error) {
	n, err := r.source.Read(p)
	if err == io.EOF {
		r.after()
	}
	return n, err
}
func TestTTLUsesCompletedReceiptTime(t *testing.T) {
	now := time.Unix(2000, 0)
	f := fixture(t, now)
	input := receiptReader{encoded(t, f), func() { now = now.Add(5 * time.Minute) }}
	_, code := validate(input, "2", func() time.Time { return now })
	if code != "invalid_bundle_ttl" {
		t.Fatal(code)
	}
}

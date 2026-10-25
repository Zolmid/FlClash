package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/resolver"
	MT "github.com/metacubex/tls"
)

func TestRuntimeNetworkPermissionAndRestore(t *testing.T) {
	for _, initial := range []bool{true, false} {
		previous := resolver.DisableIPv6
		resolver.DisableIPv6 = initial
		for _, enabled := range []bool{false, true} {
			restore := applyRuntimeNetwork(enabled)
			if resolver.DisableIPv6 != !enabled {
				t.Fatal("permission ignored")
			}
			restore()
			if resolver.DisableIPv6 != initial {
				t.Fatal("process flag not restored")
			}
		}
		resolver.DisableIPv6 = previous
	}
}

func TestFailureStagesUseTypedEvidenceOnly(t *testing.T) {
	secret := "PRIVATE_credential_host_IP_key_response"
	for _, tc := range []struct {
		err            error
		location, want string
	}{
		{fmt.Errorf("%s: %w", secret, resolver.ErrIPNotFound), "proxy_tls", "hostname_lookup"},
		{resolver.ErrIPv6Disabled, "proxy_tls", "hostname_lookup"},
		{resolver.ErrIPVersion, "proxy_tls", "hostname_lookup"},
		{&net.DNSError{Err: secret, Name: secret}, "proxy_tls", "hostname_lookup"},
		{&net.DNSError{Err: secret, IsTimeout: true}, "proxy_tls", "timeout"},
		{context.DeadlineExceeded, "target_tls", "timeout"},
		{&net.OpError{Op: "dial", Err: syscall.ECONNREFUSED}, "proxy_tls", "dial"},
		{&net.OpError{Op: "read", Err: io.EOF}, "proxy_tls", "unknown"},
		{&tls.CertificateVerificationError{Err: errors.New(secret)}, "target_tls", "target_tls"},
		{&MT.CertificateVerificationError{Err: errors.New(secret)}, "proxy_tls", "proxy_tls"},
		{x509.UnknownAuthorityError{}, "target_tls", "target_tls"},
		{tls.RecordHeaderError{}, "target_tls", "target_tls"},
		{MT.RecordHeaderError{}, "proxy_tls", "proxy_tls"},
		{errors.New("dial lookup tls timeout " + secret), "proxy_tls", "unknown"},
		{&networkPhaseError{stage: "unknown", cause: io.EOF}, "target_tls", "unknown"},
	} {
		stage := classifyNetworkFailure(tc.err, tc.location)
		if stage != tc.want {
			t.Fatalf("stage %s, want %s", stage, tc.want)
		}
		data, _ := json.Marshal(report{Code: "isolated_connection_failed", FailureStage: stage})
		if strings.Contains(string(data), secret) {
			t.Fatal("error leaked")
		}
	}
	data, _ := json.Marshal(report{OK: true})
	if strings.Contains(string(data), "failure_stage") {
		t.Fatal("success has failure stage")
	}
}

type failingStageTransport struct{ err error }

func (f failingStageTransport) RoundTrip(*http.Request) (*http.Response, error) { return nil, f.err }

func TestEgressFailureStageCompatibility(t *testing.T) {
	stage := ""
	client := &http.Client{Transport: failingStageTransport{&net.DNSError{Err: "PRIVATE", Name: "PRIVATE"}}}
	country, marker, code, status := requestEgress(context.Background(), client, nil, &stage)
	if code != "isolated_connection_failed" || stage != "hostname_lookup" || country != "" || marker != "" || status != 0 {
		t.Fatal("egress failure contract changed")
	}
}

func TestProxyParseFailureAndRestrictions(t *testing.T) {
	now := time.Unix(2000, 0)
	for _, tc := range []struct {
		option string
		code   string
	}{
		{"certificate: PRIVATE", "unsupported_proxy_option"},
		{"private-key: PRIVATE", "unsupported_proxy_option"},
		{"interface-name: PRIVATE", "unsupported_proxy_option"},
		{"routing-mark: 1", "unsupported_proxy_option"},
		{"dialer-proxy: zn.node.socks5.1", "invalid_dialer_chain"},
		{"dialer-proxy: missing", "invalid_dialer_chain"},
		{"port: invalid", "core_proxy_invalid"},
	} {
		t.Run(tc.option, func(t *testing.T) {
			f := fixture(t, now)
			doc := "proxies:\n- name: zn.node.socks5.1\n  type: socks5\n  server: 127.0.0.1\n  " + tc.option + "\nproxy-groups:\n- {name: zn.service.ai, type: select, proxies: [REJECT]}\n"
			setNetworkDocument(f, doc)
			r := execute(encoded(t, f), options{account: "2", outbound: "socks5:1", target: "gstatic", probe: true, timeout: time.Second}, func() time.Time { return now })
			if r.Code != tc.code || r.FailureStage != "parse_proxy" {
				t.Fatalf("got %s/%s", r.Code, r.FailureStage)
			}
			data, _ := json.Marshal(r)
			if strings.Contains(string(data), "PRIVATE") {
				t.Fatal("parser leaked option")
			}
		})
	}
}

func TestRealCoreCertificateFailuresKeepTLSBoundary(t *testing.T) {
	tlsTarget := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	tlsTarget.Config.ErrorLog = log.New(io.Discard, "", 0)
	tlsTarget.StartTLS()
	defer tlsTarget.Close()
	listener, _ := localSocks(t, "tcp4", "127.0.0.1:0", strings.TrimPrefix(tlsTarget.URL, "https://"))
	_, socksPortText, _ := net.SplitHostPort(listener.Addr().String())
	socksPort, _ := strconv.Atoi(socksPortText)
	_, tlsPortText, _ := net.SplitHostPort(tlsTarget.Listener.Addr().String())
	tlsPort, _ := strconv.Atoi(tlsPortText)
	previous := targets["gstatic"]
	defer func() { targets["gstatic"] = previous }()
	for _, stage := range []string{"proxy_tls", "target_tls"} {
		t.Run(stage, func(t *testing.T) {
			port, extra := socksPort, ""
			targets["gstatic"] = tlsTarget.URL
			if stage == "proxy_tls" {
				port, extra = tlsPort, ", tls: true"
				targets["gstatic"] = "https://127.0.0.1:1"
			}
			f := proxyFrame(t, false, "127.0.0.1", port, extra)
			result := execute(encoded(t, f), options{account: "2", outbound: "socks5:1", target: "gstatic", probe: true, timeout: 2 * time.Second}, time.Now)
			if result.OK || result.Code != "isolated_connection_failed" || result.FailureStage != stage {
				t.Fatalf("TLS boundary: %s/%s", result.Code, result.FailureStage)
			}
			data, _ := json.Marshal(result)
			for _, secret := range []string{"127.0.0.1", "certificate", "https://", "PRIVATE"} {
				if strings.Contains(string(data), secret) {
					t.Fatal("TLS diagnostic leaked")
				}
			}
		})
	}
}

package core

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

func TestExtractFirstPartyECH(t *testing.T) {
	config := []byte{0, 4, 0xfe, 0x0d, 0, 0}
	record := func(host string, priority uint16, target string) *D.HTTPS {
		return &D.HTTPS{SVCB: D.SVCB{Hdr: D.RR_Header{Name: host, Rrtype: D.TypeHTTPS, Class: D.ClassINET, Ttl: 123}, Priority: priority, Target: target, Value: []D.SVCBKeyValue{&D.SVCBECHConfig{ECH: config}}}}
	}
	for _, tc := range []struct {
		name string
		rr   *D.HTTPS
		want bool
	}{
		{"owned", record("link.zolmid.com.", 1, "."), true},
		{"other host", record("other.zolmid.com.", 1, "."), false},
		{"alias mode", record("link.zolmid.com.", 0, "."), false},
		{"redirected target", record("link.zolmid.com.", 1, "other.zolmid.com."), false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, ttl := extractFirstPartyECH(&D.Msg{Answer: []D.RR{tc.rr}})
			if tc.want && (!bytes.Equal(got, config) || ttl != 123) {
				t.Fatalf("got %x TTL %d", got, ttl)
			}
			if !tc.want && len(got) != 0 {
				t.Fatalf("unexpected config %x", got)
			}
		})
	}
}

func TestFirstPartyECHFallbackVerifiesIdentity(t *testing.T) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{SerialNumber: big.NewInt(1), DNSNames: []string{firstPartyECHHost}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	server.TLS = &tls.Config{Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: key}}}
	server.StartTLS()
	defer server.Close()
	roots := x509.NewCertPool()
	roots.AddCert(cert)
	for _, tc := range []struct {
		name    string
		config  []byte
		trusted bool
		ok      bool
	}{
		{"ordinary TLS", nil, true, true},
		{"unsupported ECH", []byte{0, 4, 0xfe, 0x0d, 0, 0}, true, true},
		{"untrusted certificate", nil, false, false},
		{"unsupported ECH with untrusted certificate", []byte{0, 4, 0xfe, 0x0d, 0, 0}, false, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			firstPartyECHCache.Lock()
			firstPartyECHCache.config = tc.config
			firstPartyECHCache.until = time.Now().Add(time.Minute)
			firstPartyECHCache.Unlock()
			transport := firstPartyHTTPTransport(func(ctx context.Context, network, address string) (net.Conn, error) {
				return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
			})
			if tc.trusted {
				transport.TLSClientConfig.RootCAs = roots
			} else {
				transport.TLSClientConfig.RootCAs = x509.NewCertPool()
			}
			enableFirstPartyECH(transport)
			response, err := (&http.Client{Transport: transport, Timeout: 4 * time.Second}).Get("https://link.zolmid.com/api/v1/test")
			if response != nil {
				response.Body.Close()
			}
			if (err == nil) != tc.ok {
				t.Fatalf("request error = %v, want success %v", err, tc.ok)
			}
		})
	}
	firstPartyECHCache.Lock()
	firstPartyECHCache.config = nil
	firstPartyECHCache.until = time.Time{}
	firstPartyECHCache.Unlock()
}

func TestFirstPartyECHRejectsWrongHostname(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	defer server.Close()
	firstPartyECHCache.Lock()
	firstPartyECHCache.config = nil
	firstPartyECHCache.until = time.Now().Add(time.Minute)
	firstPartyECHCache.Unlock()
	defer func() { firstPartyECHCache.Lock(); firstPartyECHCache.until = time.Time{}; firstPartyECHCache.Unlock() }()
	transport := firstPartyHTTPTransport(func(ctx context.Context, network, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
	})
	transport.TLSClientConfig.RootCAs = server.Client().Transport.(*http.Transport).TLSClientConfig.RootCAs
	enableFirstPartyECH(transport)
	resp, err := (&http.Client{Transport: transport, Timeout: 4 * time.Second}).Get("https://link.zolmid.com/api/v1/test")
	if resp != nil {
		resp.Body.Close()
	}
	if err == nil {
		t.Fatal("accepted certificate for a different hostname")
	}
}

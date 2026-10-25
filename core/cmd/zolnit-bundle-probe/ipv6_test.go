package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/transport/socks5"
)

func setNetworkDocument(f map[string]any, document string) {
	hash := sha256.Sum256([]byte(document))
	body(f)["connection"] = map[string]any{"engine": "mihomo", "format": "yaml", "sha256": hex.EncodeToString(hash[:]), "document": document}
}

func TestDocumentIPv6StrictBoolean(t *testing.T) {
	now := time.Unix(2000, 0)
	for _, tc := range []struct {
		text           string
		valid, enabled bool
	}{
		{"", true, false}, {"ipv6: false\n", true, false}, {"ipv6: true\n", true, true},
		{"ipv6: 'true'\n", false, false}, {"ipv6: 1\n", false, false},
		{"ipv6: null\n", false, false}, {"ipv6: []\n", false, false}, {"ipv6: {}\n", false, false},
	} {
		f := fixture(t, now)
		doc := body(f)["connection"].(map[string]any)["document"].(string)
		setNetworkDocument(f, tc.text+doc)
		v, code := validate(encoded(t, f), "2", func() time.Time { return now })
		if tc.valid {
			if code != "" || v.ipv6 != tc.enabled {
				t.Fatal("permission not retained")
			}
		} else if v != nil || code != "invalid_connection_ipv6" {
			t.Fatal("non-boolean permission accepted")
		}
	}
}

type loopbackResolver struct {
	resolver.Resolver
	addr         netip.Addr
	v4, v6, both atomic.Int32
}

func (*loopbackResolver) Invalid() bool { return true }
func (r *loopbackResolver) LookupIP(context.Context, string) ([]netip.Addr, error) {
	r.both.Add(1)
	return []netip.Addr{r.addr}, nil
}
func (r *loopbackResolver) LookupIPv4(context.Context, string) ([]netip.Addr, error) {
	r.v4.Add(1)
	if !r.addr.Is4() {
		return nil, resolver.ErrIPNotFound
	}
	return []netip.Addr{r.addr}, nil
}
func (r *loopbackResolver) LookupIPv6(context.Context, string) ([]netip.Addr, error) {
	r.v6.Add(1)
	if !r.addr.Is6() {
		return nil, resolver.ErrIPNotFound
	}
	return []netip.Addr{r.addr}, nil
}

func installLoopbackResolver(t *testing.T, addr string) *loopbackResolver {
	t.Helper()
	previous := resolver.ProxyServerHostResolver
	r := &loopbackResolver{addr: netip.MustParseAddr(addr)}
	resolver.ProxyServerHostResolver = r
	t.Cleanup(func() { resolver.ProxyServerHostResolver = previous })
	return r
}

func localSocks(t *testing.T, network, bind, allowed string) (net.Listener, *atomic.Int32) {
	t.Helper()
	l, err := net.Listen(network, bind)
	if err != nil {
		t.Fatal("loopback SOCKS listener unavailable")
	}
	var count atomic.Int32
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			wg.Add(1)
			go func() {
				defer wg.Done()
				defer c.Close()
				_ = c.SetDeadline(time.Now().Add(3 * time.Second))
				addr, cmd, _, err := socks5.ServerHandshake(c, nil)
				if err != nil || cmd != socks5.CmdConnect || addr.String() != allowed {
					return
				}
				upstream, err := net.DialTimeout("tcp", allowed, time.Second)
				if err != nil {
					return
				}
				defer upstream.Close()
				count.Add(1)
				copied := make(chan struct{})
				go func() { _, _ = io.Copy(upstream, c); close(copied) }()
				_, _ = io.Copy(c, upstream)
				_ = c.Close()
				_ = upstream.Close()
				<-copied
			}()
		}
	}()
	t.Cleanup(func() { _ = l.Close(); wg.Wait() })
	return l, &count
}

func proxyFrame(t *testing.T, ipv6 bool, server string, port int, extra string) map[string]any {
	t.Helper()
	f := fixture(t, time.Now())
	doc := fmt.Sprintf("ipv6: %t\nproxies:\n- {name: zn.node.socks5.1, type: socks5, server: '%s', port: %d%s}\nproxy-groups:\n- {name: zn.service.ai, type: select, proxies: [REJECT]}\ndns: {enable: true, listen: '0.0.0.0:53'}\ntun: {enable: true}\n", ipv6, server, port, extra)
	setNetworkDocument(f, doc)
	return f
}

func TestAAAAOnlyRealCoreSocksHTTPPermission(t *testing.T) {
	r := installLoopbackResolver(t, "::1")
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodHead {
			t.Error("not HEAD")
		}
		w.WriteHeader(204)
	}))
	defer target.Close()
	socks, count := localSocks(t, "tcp6", "[::1]:0", strings.TrimPrefix(target.URL, "http://"))
	_, portText, _ := net.SplitHostPort(socks.Addr().String())
	port, _ := strconv.Atoi(portText)
	oldTarget := targets["gstatic"]
	targets["gstatic"] = target.URL
	defer func() { targets["gstatic"] = oldTarget }()
	initial := resolver.DisableIPv6
	for _, enabled := range []bool{false, true, false} {
		before := count.Load()
		result := execute(encoded(t, proxyFrame(t, enabled, "aaaa-only.invalid", port, "")), options{account: "2", outbound: "socks5:1", target: "gstatic", probe: true, timeout: 2 * time.Second}, time.Now)
		if enabled {
			if !result.OK || result.Status != 204 || result.FailureStage != "" || count.Load() != before+1 {
				t.Fatalf("IPv6 probe failed: %s/%s", result.Code, result.FailureStage)
			}
		} else if result.OK || result.Code != "isolated_connection_failed" || result.FailureStage != "hostname_lookup" || count.Load() != before {
			t.Fatalf("IPv6 deny failed: %s/%s", result.Code, result.FailureStage)
		}
		if resolver.DisableIPv6 != initial {
			t.Fatal("process setting leaked")
		}
	}
	if r.v4.Load() != 2 || r.both.Load() != 1 || r.v6.Load() != 0 {
		t.Fatal("AAAA-only lookup path not exercised")
	}
}

func TestIPv4AndRealCoreDialerChain(t *testing.T) {
	installLoopbackResolver(t, "127.0.0.1")
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) { w.WriteHeader(204) }))
	defer target.Close()
	exit, exitCount := localSocks(t, "tcp4", "127.0.0.1:0", strings.TrimPrefix(target.URL, "http://"))
	entry, entryCount := localSocks(t, "tcp4", "127.0.0.1:0", exit.Addr().String())
	_, exitPortText, _ := net.SplitHostPort(exit.Addr().String())
	exitPort, _ := strconv.Atoi(exitPortText)
	_, entryPortText, _ := net.SplitHostPort(entry.Addr().String())
	entryPort, _ := strconv.Atoi(entryPortText)
	for _, enabled := range []bool{false, true} {
		f := proxyFrame(t, enabled, "ipv4-only.invalid", exitPort, ", ip-version: ipv4")
		v, code := validate(encoded(t, f), "2", time.Now)
		if code != "" {
			t.Fatal(code)
		}
		restore := applyRuntimeNetwork(v.ipv6)
		for _, chain := range []bool{false, true} {
			mapping := v.proxies["zn.node.socks5.1"]
			if chain {
				mapping["dialer-proxy"] = "synthetic-entry"
				v.proxies["synthetic-entry"] = map[string]any{"name": "synthetic-entry", "type": "socks5", "server": "127.0.0.1", "port": entryPort, "ip-version": "ipv4"}
			}
			var owned []C.Proxy
			proxy, code := buildProxy(v, "zn.node.socks5.1", map[string]bool{}, &owned)
			if code != "" {
				restore()
				t.Fatal(code)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			status, err := isolatedHTTP(ctx, proxy, target.URL)
			cancel()
			for i := len(owned) - 1; i >= 0; i-- {
				_ = owned[i].Close()
			}
			if err != nil || status != 204 {
				restore()
				t.Fatal("IPv4 or proxy chain regression")
			}
		}
		restore()
	}
	if entryCount.Load() != 2 || exitCount.Load() != 4 {
		t.Fatal("chain bypassed configured entry")
	}
}

func TestAAAAOnlyExplicitIPVersion(t *testing.T) {
	installLoopbackResolver(t, "::1")
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	defer target.Close()
	listener, _ := localSocks(t, "tcp6", "[::1]:0", strings.TrimPrefix(target.URL, "http://"))
	_, portText, _ := net.SplitHostPort(listener.Addr().String())
	port, _ := strconv.Atoi(portText)
	oldTarget := targets["gstatic"]
	targets["gstatic"] = target.URL
	defer func() { targets["gstatic"] = oldTarget }()
	for _, version := range []string{"ipv4", "ipv6", "ipv4-prefer", "ipv6-prefer"} {
		t.Run(version, func(t *testing.T) {
			f := proxyFrame(t, true, "aaaa-only.invalid", port, ", ip-version: "+version)
			r := execute(encoded(t, f), options{account: "2", outbound: "socks5:1", target: "gstatic", probe: true, timeout: 2 * time.Second}, time.Now)
			if version == "ipv4" {
				if r.OK || r.FailureStage != "hostname_lookup" {
					t.Fatal("IPv4-only preference ignored")
				}
			} else if !r.OK || r.Status != 204 {
				t.Fatalf("preference regression: %s/%s", r.Code, r.FailureStage)
			}
		})
	}
}

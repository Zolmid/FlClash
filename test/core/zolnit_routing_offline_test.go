package routing_test

import (
	"io"
	"net/netip"
	"os"
	"slices"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	R "github.com/metacubex/mihomo/rules"
	RC "github.com/metacubex/mihomo/rules/common"
	"go.yaml.in/yaml/v3"
)

func TestNativeRoutingOffline(t *testing.T) {
	expectedVersion := os.Getenv("ZOLNIT_CORE_VERSION")
	if expectedVersion == "" {
		expectedVersion = "v1.19.32"
	}
	if C.Version != expectedVersion {
		t.Fatalf("unexpected linked Core version %s", C.Version)
	}
	t.Logf("retained Core version %s", C.Version)
	path := os.Getenv("ZOLNIT_ROUTING_CONFIG")
	if path == "" {
		t.Fatal("ZOLNIT_ROUTING_CONFIG must name the generated synthetic fixture")
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var document map[string]any
	if err = yaml.Unmarshal(content, &document); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"mixed-port", "port", "socks-port", "redir-port", "tproxy-port"} {
		if value, ok := document[key]; ok && value != 0 {
			t.Fatalf("fixture enables %s", key)
		}
	}
	if document["mode"] != "rule" || document["external-controller"] != "" {
		t.Fatal("fixture mode or controller is not isolated")
	}
	for _, key := range []string{"dns", "tun"} {
		if document[key].(map[string]any)["enable"] != false {
			t.Fatalf("fixture enables %s", key)
		}
	}
	for _, key := range []string{"proxy-providers", "rule-providers", "listeners", "tunnels"} {
		if _, exists := document[key]; exists {
			t.Fatalf("fixture contains forbidden section %s", key)
		}
	}

	proxies := map[string]C.Proxy{
		"DIRECT":     adapter.NewProxy(outbound.NewDirect()),
		"REJECT":     adapter.NewProxy(outbound.NewReject()),
		"COMPATIBLE": adapter.NewProxy(outbound.NewCompatible()),
	}
	alias, aliasErr := adapter.ParseProxy(map[string]any{"name": "named-network-looking-alias", "type": "direct"})
	if aliasErr != nil || alias.Type() != C.Direct || alias.Name() == "DIRECT" {
		t.Fatal("Core did not expose the real type of a direct alias")
	}
	t.Logf("custom alias real Core type: %s", alias.Type().String())
	allProxies := []string{}
	reserved := []netip.Prefix{
		netip.MustParsePrefix("192.0.2.0/24"),
		netip.MustParsePrefix("198.51.100.0/24"),
		netip.MustParsePrefix("203.0.113.0/24"),
	}
	for _, item := range document["proxies"].([]any) {
		mapping := item.(map[string]any)
		if mapping["type"] != "socks5" {
			t.Fatal("offline fixture must use unauthenticated SOCKS5 only")
		}
		for key := range mapping {
			if !slices.Contains([]string{"name", "type", "server", "port"}, key) {
				t.Fatalf("unexpected proxy option %s", key)
			}
		}
		address, parseErr := netip.ParseAddr(mapping["server"].(string))
		if parseErr != nil || !slices.ContainsFunc(reserved, func(prefix netip.Prefix) bool {
			return prefix.Contains(address)
		}) {
			t.Fatal("fixture contains a non-reserved address")
		}
		proxy, parseErr := adapter.ParseProxy(mapping)
		if parseErr != nil {
			t.Fatal(parseErr)
		}
		if proxy.Type() != C.Socks5 {
			t.Fatal("fixture did not produce a network proxy")
		}
		if _, exists := proxies[proxy.Name()]; exists {
			t.Fatal("duplicate proxy name")
		}
		proxies[proxy.Name()] = proxy
		allProxies = append(allProxies, proxy.Name())
	}

	providers := map[string]P.ProxyProvider{}
	t.Cleanup(func() {
		for _, provider := range providers {
			if closer, ok := provider.(io.Closer); ok {
				closer.Close()
			}
		}
	})
	selectors := map[string]*outboundgroup.Selector{}
	pending := append([]any(nil), document["proxy-groups"].([]any)...)
	for len(pending) != 0 {
		next := []any{}
		for _, item := range pending {
			mapping := item.(map[string]any)
			if mapping["type"] != "select" || mapping["use"] != nil ||
				mapping["include-all"] != nil || mapping["include-all-proxies"] != nil ||
				mapping["include-all-providers"] != nil {
				t.Fatal("offline fixture contains an active or dynamic provider")
			}
			mapping["interval"] = 0
			ready := true
			for _, member := range mapping["proxies"].([]any) {
				if _, exists := proxies[member.(string)]; !exists {
					ready = false
				}
			}
			if !ready {
				next = append(next, item)
				continue
			}
			group, parseErr := outboundgroup.ParseProxyGroup(mapping, proxies, providers, allProxies, nil)
			if parseErr != nil {
				t.Fatal(parseErr)
			}
			selector, ok := group.(*outboundgroup.Selector)
			if !ok {
				t.Fatal("fixture did not produce a Selector")
			}
			selectors[group.Name()] = selector
			proxies[group.Name()] = adapter.NewProxy(group)
		}
		if len(next) == len(pending) {
			t.Fatal("cyclic or unresolved group references")
		}
		pending = next
	}

	rules := []C.Rule{}
	for _, item := range document["rules"].([]any) {
		tp, payload, target, params := RC.ParseRulePayload(item.(string), true)
		if !slices.Contains([]string{"DOMAIN", "DOMAIN-SUFFIX", "MATCH"}, tp) {
			t.Fatal("offline fixture contains a rule requiring external data")
		}
		if _, exists := proxies[target]; !exists {
			t.Fatal("rule target does not exist")
		}
		rule, parseErr := R.ParseRule(tp, payload, target, params, nil)
		if parseErr != nil || rule.Adapter() != target {
			t.Fatalf("rule target parse failed: %v", parseErr)
		}
		rules = append(rules, rule)
	}

	selectProxy := func(group, proxy string) {
		t.Helper()
		selector := selectors[group]
		if selector == nil {
			t.Fatalf("missing selector %s", group)
		}
		if err := selector.Set(proxy); err != nil || selector.Now() != proxy {
			t.Fatalf("selector %s did not apply %s: %v", group, proxy, err)
		}
	}
	resolve := func(host string) string {
		t.Helper()
		target := ""
		for _, rule := range rules {
			if matched, _ := rule.Match(&C.Metadata{Host: host}, C.RuleMatchHelper{}); matched {
				target = rule.Adapter()
				break
			}
		}
		seen := map[string]bool{}
		for selectors[target] != nil {
			if seen[target] {
				t.Fatal("selection loop")
			}
			seen[target] = true
			target = selectors[target].Now()
		}
		if proxies[target] == nil {
			t.Fatal("route does not resolve to an outbound")
		}
		return target
	}
	assertRoute := func(host, want string) {
		t.Helper()
		if got := resolve(host); got != want {
			t.Fatalf("%s resolved to %s, want %s", host, got, want)
		}
	}

	assertRoute("api.openai.com", "REJECT")
	assertRoute("www.netflix.com", "REJECT")
	assertRoute("ordinary.example", "zn.node.socks5.1")
	selectProxy("zn.service.ai.auto", "zn.node.socks5.2")
	selectProxy("zn.service.media.auto", "zn.node.socks5.1")
	assertRoute("api.openai.com", "zn.node.socks5.2")
	assertRoute("www.netflix.com", "zn.node.socks5.1")
	if err := selectors["zn.service.ai.auto"].Set("zn.node.socks5.1"); err == nil ||
		selectors["zn.service.ai.auto"].Now() != "zn.node.socks5.2" {
		t.Fatal("Core admitted an excluded AI candidate or changed selection on rejection")
	}
	selectProxy("zn.service.ai", "DIRECT")
	assertRoute("api.openai.com", "DIRECT")
	assertRoute("www.netflix.com", "zn.node.socks5.1")
	selectProxy("zn.service.ai", "zn.service.ai.manual")
	assertRoute("api.openai.com", "zn.node.socks5.1")
	selectProxy("zn.service.ai.manual", "zn.node.socks5.3")
	assertRoute("api.openai.com", "zn.node.socks5.3")
	assertRoute("ordinary.example", "zn.node.socks5.1")
	t.Log("retained Core selectors and domain rules accepted independent AI/media choices and explicit manual/DIRECT")
}

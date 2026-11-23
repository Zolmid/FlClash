package clientbundle

import "testing"

func TestManagedDNSInheritance(t *testing.T) {
	cases := []struct {
		name    string
		dns     map[string]any
		overlay map[string]any
		code    string
		added   bool
	}{
		{"private enterprise", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.corp.example": []any{"10.1.2.3", "fd00::1"}}}, "", true},
		{"local system", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.lan": []any{"system"}}}, "", true},
		{"public resolver rejected", map[string]any{"enable": true, "nameserver": []any{"https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.corp.example": []any{"8.8.8.8"}}}, "", false},
		{"system public rejected", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.corp.example": []any{"system://"}}}, "", false},
		{"signed overlap", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}, "nameserver-policy": map[string]any{"+.example": "https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.corp.example": []any{"10.0.0.1"}}}, "managed_dns_policy_conflict", false},
		{"opaque signed policy", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}, "nameserver-policy": map[string]any{"rule-set:public": "https://dns.example/dns-query"}}, map[string]any{"nameserver-policy": map[string]any{"+.corp.example": []any{"10.0.0.1"}}}, "managed_dns_policy_conflict", false},
		{"disabled", map[string]any{"enable": false, "nameserver": []any{"https://dns.example/dns-query"}}, nil, "invalid_managed_dns", false},
		{"missing resolvers", map[string]any{}, nil, "invalid_managed_dns", false},
		{"system fallback", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}, "fallback": []any{"system"}}, nil, "invalid_managed_dns", false},
		{"system public policy", map[string]any{"nameserver": []any{"https://dns.example/dns-query"}, "nameserver-policy": map[string]any{"+.public.example": "system://"}}, nil, "invalid_managed_dns", false},
		{"global system", map[string]any{"nameserver": []any{"system://"}}, nil, "invalid_managed_dns", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			config := map[string]any{"dns": tc.dns}
			if got := mergeManagedDNS(config, tc.overlay); got != tc.code {
				t.Fatalf("code %q, want %q", got, tc.code)
			}
			if tc.code != "" {
				return
			}
			if tc.dns["enable"] != true {
				t.Fatal("DNS not enabled")
			}
			policy, _ := tc.dns["nameserver-policy"].(map[string]any)
			count := len(policy)
			if tc.added && count != 1 || !tc.added && count != 0 {
				t.Fatalf("unexpected policy: %v", policy)
			}
		})
	}
	if code := mergeManagedDNS(map[string]any{}, nil); code != "invalid_managed_dns" {
		t.Fatal(code)
	}
}

func TestManagedDNSRequiresEncryptedPublicResolvers(t *testing.T) {
	for _, key := range []string{"nameserver", "fallback", "default-nameserver", "direct-nameserver", "proxy-server-nameserver"} {
		for _, value := range []string{"223.5.5.5", "udp://223.5.5.5", "tcp://8.8.8.8:53"} {
			t.Run(key+"/"+value, func(t *testing.T) {
				dns := map[string]any{"nameserver": []any{"https://dns.example/dns-query"}, key: []any{value}}
				if got := mergeManagedDNS(map[string]any{"dns": dns}, nil); got != "invalid_managed_dns" {
					t.Fatalf("got %q", got)
				}
			})
		}
	}
	for _, key := range []string{"nameserver-policy", "proxy-server-nameserver-policy"} {
		for _, domain := range []string{"rule-set:public", "geosite:cn", "+.public.example"} {
			dns := map[string]any{"nameserver": []any{"tls://dns.example"}, key: map[string]any{domain: []any{"udp://223.5.5.5"}}}
			if got := mergeManagedDNS(map[string]any{"dns": dns}, nil); got != "invalid_managed_dns" {
				t.Fatalf("%s %s: %q", key, domain, got)
			}
		}
		dns := map[string]any{"nameserver": []any{"tls://dns.example"}, key: map[string]any{"+.corp.example": []any{"10.0.0.53:53"}, "rule-set:public": []any{"https://dns.example/dns-query"}}}
		if got := mergeManagedDNS(map[string]any{"dns": dns}, nil); got != "" {
			t.Fatalf("private policy %s: %q", key, got)
		}
	}
}

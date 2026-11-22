package core

import (
	"context"
	"errors"
	"net/netip"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/trie"
	"github.com/metacubex/mihomo/config"
)

func ownedDNSFixture(t *testing.T) *ownedDNSResolver {
	t.Helper()
	r, err := newOwnedDNSResolver(&OwnedDNSConfig{Hosts: []string{"link.zolmid.com", "node.nodes.zolmid.com"},
		Relay: "https://link.zolmid.com/api/v1/zolnit/client/httpdns", Strict: true}, nil)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func TestOwnedDNSStrictNeverFallsBackOnMissingAuthOrExpiredCache(t *testing.T) {
	r := ownedDNSFixture(t)
	r.cache["node.nodes.zolmid.com"] = ownedDNSCache{ips: []netip.Addr{netip.MustParseAddr("192.0.2.1")}, until: time.Now().Add(-time.Second)}
	if ips, err := r.lookup(context.Background(), "node.nodes.zolmid.com"); err == nil || len(ips) != 0 {
		t.Fatal("expired answer or fallback accepted")
	}
}

func TestOwnedDNSCacheFamiliesAndRevocation(t *testing.T) {
	r := ownedDNSFixture(t)
	r.cache["node.nodes.zolmid.com"] = ownedDNSCache{ips: []netip.Addr{netip.MustParseAddr("192.0.2.1"), netip.MustParseAddr("2001:db8::1")}, until: time.Now().Add(time.Minute)}
	ips, err := r.LookupIPv4(context.Background(), "node.nodes.zolmid.com")
	if err != nil || len(ips) != 1 || !ips[0].Is4() {
		t.Fatal(ips, err)
	}
	ips, err = r.LookupIPv6(context.Background(), "node.nodes.zolmid.com")
	if err != nil || len(ips) != 1 || !ips[0].Is6() {
		t.Fatal(ips, err)
	}
	r.revoked.Store(true)
	if _, err = r.LookupIP(context.Background(), "node.nodes.zolmid.com"); err == nil {
		t.Fatal("revoked session resolved")
	}
}

func TestOwnedDNSRejectsInvalidAddressesAndBindings(t *testing.T) {
	for _, value := range []string{"example.com", "127.0.0.1", "::", "ff02::1", "fe80::1%en0"} {
		if _, err := validateOwnedAddresses([]string{value}); err == nil {
			t.Fatal(value)
		}
	}
	r := ownedDNSFixture(t)
	binding := r.config
	binding.Hosts = append(binding.Hosts, "*.nodes.zolmid.com")
	if _, err := newOwnedDNSResolver(&binding, nil); err == nil {
		t.Fatal("wildcard accepted")
	}
}

func TestOwnedDNSRejectsHostsOverrideWithoutMutatingConfig(t *testing.T) {
	r := ownedDNSFixture(t)
	hosts := trie.New[resolver.HostValue]()
	if err := hosts.Insert("node.nodes.zolmid.com", resolver.HostValue{IPs: []netip.Addr{netip.MustParseAddr("192.0.2.1")}}); err != nil {
		t.Fatal(err)
	}
	cfg := &config.Config{Hosts: hosts}
	if _, err := ownedDNSForConfig(cfg, &r.config); err == nil {
		t.Fatal("hosts override accepted")
	}
	if cfg.Hosts.Search("node.nodes.zolmid.com") == nil {
		t.Fatal("signed projection changed")
	}
}

func TestOwnedDNSNativeDisabledIsDistinctFromStrictFailure(t *testing.T) {
	previous := activeOwnedDNS.Load()
	defer activeOwnedDNS.Store(previous)
	activeOwnedDNS.Store(nil)
	p := firstPartyParams()
	p.OwnedDNSOnly = true
	_, err := handleFirstPartyHTTP(p)
	if err == nil || err.(*MethodError).Code != "owned_dns_disabled" {
		t.Fatal(err)
	}
	r := ownedDNSFixture(t)
	r.revoked.Store(true)
	activeOwnedDNS.Store(r)
	_, err = handleFirstPartyHTTP(p)
	if err == nil || err.(*MethodError).Code == "owned_dns_disabled" {
		t.Fatal("strict error permitted legacy fallback", err)
	}
}

type ownedFallbackFixture struct {
	resolver.Resolver
	calls int
}

func (r *ownedFallbackFixture) Invalid() bool { return true }
func (r *ownedFallbackFixture) LookupIP(context.Context, string) ([]netip.Addr, error) {
	r.calls++
	return []netip.Addr{netip.MustParseAddr("198.51.100.7")}, nil
}
func TestOwnedDNSKeepsExistingResolverAuthoritativeForOrdinaryTraffic(t *testing.T) {
	r := ownedDNSFixture(t)
	fallback := &ownedFallbackFixture{}
	r.Resolver = fallback
	ips, err := r.LookupIP(context.Background(), "ordinary.example")
	if err != nil || len(ips) != 1 || ips[0].String() != "198.51.100.7" || fallback.calls != 1 {
		t.Fatal(ips, err, fallback.calls)
	}
	_, err = r.LookupIP(context.Background(), "node.nodes.zolmid.com")
	if err == nil || fallback.calls != 1 {
		t.Fatal("strict resolver escaped to ordinary policy")
	}
}

func TestOwnedDNSBootstrapSurvivesOneFamilyFailure(t *testing.T) {
	for _, failed := range []uint16{1, 28} {
		answer, err := collectOwnedDNSBootstrap(context.Background(), func(_ context.Context, family uint16) (ownedDNSAnswer, error) {
			if family == failed {
				return ownedDNSAnswer{}, errors.New("synthetic family outage")
			}
			if family == 1 {
				return ownedDNSAnswer{Addresses: []string{"192.0.2.1"}, TTL: 30}, nil
			}
			return ownedDNSAnswer{Addresses: []string{"2001:db8::1"}, TTL: 20}, nil
		})
		if err != nil || len(answer.Addresses) != 1 {
			t.Fatal(answer, err)
		}
	}
	_, err := collectOwnedDNSBootstrap(context.Background(), func(context.Context, uint16) (ownedDNSAnswer, error) {
		return ownedDNSAnswer{}, errors.New("synthetic outage")
	})
	if err == nil {
		t.Fatal("all bootstrap failures accepted")
	}
}

func TestOwnedDNSBootstrapCombinesTtlAndHonorsCancellation(t *testing.T) {
	answer, err := collectOwnedDNSBootstrap(context.Background(), func(_ context.Context, family uint16) (ownedDNSAnswer, error) {
		if family == 1 {
			return ownedDNSAnswer{Addresses: []string{"192.0.2.1"}, TTL: 60}, nil
		}
		return ownedDNSAnswer{Addresses: []string{"2001:db8::1"}, TTL: 10}, nil
	})
	if err != nil || len(answer.Addresses) != 2 || answer.TTL != 10 {
		t.Fatal(answer, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err = collectOwnedDNSBootstrap(ctx, func(ctx context.Context, _ uint16) (ownedDNSAnswer, error) {
		<-ctx.Done()
		return ownedDNSAnswer{}, ctx.Err()
	})
	if err == nil {
		t.Fatal("cancelled bootstrap accepted")
	}
}

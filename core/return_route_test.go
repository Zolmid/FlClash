package core

import (
	"core/clientbundle"
	"encoding/json"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"maps"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type returnFixture struct {
	lease   *routingLeaseFixture
	proxies map[string]constant.Proxy
	spec    *RoutingLeaseSpec
}

func newReturnFixture(t *testing.T, all bool) *returnFixture {
	t.Helper()
	f := newRoutingLeaseFixture(t)
	p := maps.Clone(tunnel.AllProxies())
	p["role-direct"] = selectorOver(t, "role-direct", f.reject)
	p["role-lite"] = selectorOver(t, "role-lite", f.usExit)
	p["role-optimized"] = selectorOver(t, "role-optimized", f.reject)
	if all {
		p["role-direct"] = selectorOver(t, "role-direct", f.sgExit)
		p["role-optimized"] = selectorOver(t, "role-optimized", f.usExit)
	}
	p["return"] = selectorOver(t, "return", p["role-direct"], p["role-lite"], p["role-optimized"], f.direct, f.sgExit, f.reject)
	tunnel.UpdateProxies(p, nil)
	spec := f.spec(120 * time.Second)
	spec.ReturnRoute = &clientbundle.ReturnRouteSpec{GroupName: "return", Options: []clientbundle.ReturnRouteOption{
		{ID: "direct", Target: "role-direct"}, {ID: "hk_lite", Target: "role-lite"}, {ID: "hk_optimized", Target: "role-optimized"},
	}, Outbounds: []string{"us-exit", "sg-exit"}}
	return &returnFixture{lease: f, proxies: p, spec: spec}
}

func returnPick(t *testing.T) string {
	t.Helper()
	selector, err := selectableGroup("return")
	if err != nil {
		t.Fatal(err)
	}
	return selector.Now()
}

func TestReturnRouteInstallNormalizesBeforePublicationAndPreservesAI(t *testing.T) {
	f := newReturnFixture(t, false)
	routes := recordRoutes(t)
	currentRoute.mu.Lock()
	currentRoute.watched = true
	currentRoute.mu.Unlock()
	selectMu.Lock()
	patchSelectGroupLocked(map[string]string{"return": "role-direct", "AI 服务": "AI 服务 · 手动", "AI 服务 · 手动": "DIRECT"})
	installRoutingLeaseLocked(f.spec)
	refreshRouteLocked(true)
	selectMu.Unlock()
	if returnPick(t) != "role-lite" {
		t.Fatal("first installation kept unavailable default")
	}
	published := routes.published()
	if len(published) != 1 || published[0].Picks["return"] != "role-lite" {
		t.Fatal("published unavailable return selection")
	}
	if f.lease.policy.Adapter().(pickableGroup).Now() != "AI 服务 · 手动" || f.lease.manual.Adapter().(pickableGroup).Now() != "DIRECT" {
		t.Fatal("return normalization changed independent manual AI policy")
	}
}

func TestReturnRouteAllChoicesAndManualDirectSurviveDowngrade(t *testing.T) {
	f := newReturnFixture(t, true)
	f.lease.install(f.spec)
	for _, target := range []string{"role-direct", "role-lite", "role-optimized", "sg-exit", "DIRECT"} {
		result := handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: target, RoutingLease: handleGetRoutingLease()})
		if result.Message != "" || returnPick(t) != target {
			t.Fatal("valid manual choice rejected")
		}
		selectMu.Lock()
		normalizeReturnRouteLocked(tunnel.AllProxies())
		selectMu.Unlock()
		if returnPick(t) != target {
			t.Fatal("available manual choice reset")
		}
	}
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.lease.reject)
	f.proxies["role-optimized"] = selectorOver(t, "role-optimized", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	refreshRoute()
	if returnPick(t) != "DIRECT" {
		t.Fatal("downgrade reinterpreted explicit manual DIRECT as role")
	}
	f.proxies["return"].Adapter().(pickableGroup).ForceSet("role-optimized")
	refreshRoute()
	if returnPick(t) != "role-lite" {
		t.Fatal("downgrade did not select remaining delivered role")
	}
}

func TestReturnRouteTraversalRequiresDeliveredNetworkLeafAndStopsParentCycles(t *testing.T) {
	f := newReturnFixture(t, false)
	f.lease.install(f.spec)
	cases := []struct {
		name  string
		build func() constant.Proxy
		want  bool
	}{
		{"delivered", func() constant.Proxy { return f.lease.usExit }, true},
		{"unlisted", func() constant.Proxy { return networkNode(t, "unlisted") }, false},
		{"pseudo-direct", func() constant.Proxy { return directNode("us-exit") }, false},
		{"reject", func() constant.Proxy { return f.lease.reject }, false},
		{"pseudo-reject", func() constant.Proxy {
			return adapter.NewProxy(outbound.NewRejectWithOption(outbound.RejectOption{Name: "us-exit"}))
		}, false},
		{"deep", func() constant.Proxy {
			leaf := f.lease.usExit
			for _, name := range []string{"deep-c", "deep-b", "deep-a"} {
				leaf = selectorOver(t, name, leaf)
				f.proxies[name] = leaf
			}
			return leaf
		}, true},
		{"pure-cycle", func() constant.Proxy {
			a := selectorOver(t, "cycle-a", directNode("cycle-b"))
			b := selectorOver(t, "cycle-b", a)
			f.proxies["cycle-a"], f.proxies["cycle-b"] = a, b
			return a
		}, false},
		{"cycle-with-exit", func() constant.Proxy {
			a := selectorOver(t, "cycle-a", directNode("cycle-b"))
			b := selectorOver(t, "cycle-b", a, f.lease.usExit)
			f.proxies["cycle-a"], f.proxies["cycle-b"] = a, b
			return a
		}, true},
		{"parent-cycle-cannot-borrow-lite", func() constant.Proxy { return selectorOver(t, "parent-cycle", f.proxies["return"]) }, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			candidate := tc.build()
			p := maps.Clone(f.proxies)
			p[candidate.Name()] = candidate
			if got := returnRouteUsable(f.spec.ReturnRoute, candidate.Name(), p); got != tc.want {
				t.Fatalf("reachability=%v want %v", got, tc.want)
			}
		})
	}
}

func TestReturnRouteRejectsStaleGuardAndFreshGuardWithEmptyAlias(t *testing.T) {
	f := newReturnFixture(t, true)
	old := f.lease.install(f.spec)
	for _, mutate := range []func(*RoutingLeaseGuard){
		func(g *RoutingLeaseGuard) { g.Token = "old" }, func(g *RoutingLeaseGuard) { g.InstanceID = "old" },
		func(g *RoutingLeaseGuard) { g.AccountID = "old" }, func(g *RoutingLeaseGuard) { g.AccountGeneration++ },
		func(g *RoutingLeaseGuard) { g.BundleID = "old" }, func(g *RoutingLeaseGuard) { g.ConfigurationDigest = "old" },
		func(g *RoutingLeaseGuard) { g.ConfigurationGeneration++ }, func(g *RoutingLeaseGuard) { g.ExpiresAt++ },
	} {
		guard := *old
		mutate(&guard)
		if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: &guard}).Message == "" {
			t.Fatal("stale identity accepted")
		}
	}
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	for _, guard := range []*RoutingLeaseGuard{nil, old, handleGetRoutingLease()} {
		if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-direct", RoutingLease: guard}).Message == "" {
			t.Fatal("empty same-name alias accepted")
		}
	}
	next := *f.spec
	next.BundleID = "next"
	f.lease.install(&next)
	if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: old}).Message == "" {
		t.Fatal("old config guard accepted")
	}
	clearRoutingLeaseForConfigChange()
	if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: handleGetRoutingLease()}).Message == "" {
		t.Fatal("configuration revocation kept return authority")
	}
}

func TestReturnRouteFailClosedWithoutUsableRole(t *testing.T) {
	f := newReturnFixture(t, false)
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	f.lease.install(f.spec)
	if returnPick(t) == "DIRECT" {
		t.Fatal("invented DIRECT fallback")
	}
	for _, option := range f.spec.ReturnRoute.Options {
		if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: option.Target}).Message == "" {
			t.Fatal("unusable role accepted")
		}
	}
}

func TestReturnRouteMalformedOptionalPolicyDoesNotRevokeAI(t *testing.T) {
	for _, raw := range []string{`null`, `42`, `{"options":"bad"}`, `{"groupName":"return","options":[]}`} {
		t.Run(raw, func(t *testing.T) {
			f := newReturnFixture(t, true)
			data, _ := json.Marshal(f.spec)
			var object map[string]json.RawMessage
			_ = json.Unmarshal(data, &object)
			object["returnRoute"] = json.RawMessage(raw)
			data, _ = json.Marshal(object)
			var spec RoutingLeaseSpec
			if json.Unmarshal(data, &spec) != nil || f.lease.install(&spec) == nil {
				t.Fatal("malformed optional policy broke AI lease")
			}
			if activeRoutingLease.returnRoute != nil {
				t.Fatal("malformed optional policy installed")
			}
		})
	}
	mutations := []func(*clientbundle.ReturnRouteSpec){
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].ID = "direct" },
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].Target = s.Options[0].Target },
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].Target = "DIRECT" },
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].Target = "REJECT" },
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].Target = "clientzn.service.ai" },
		func(s *clientbundle.ReturnRouteSpec) { s.Options[1].Target = "sg-exit-not-member" },
		func(s *clientbundle.ReturnRouteSpec) { s.GroupName = "role-lite" },
		func(s *clientbundle.ReturnRouteSpec) { s.GroupName = "us-exit" },
		func(s *clientbundle.ReturnRouteSpec) { s.Outbounds = append(s.Outbounds, s.Outbounds[0]) },
	}
	for _, mutate := range mutations {
		f := newReturnFixture(t, true)
		mutate(f.spec.ReturnRoute)
		if f.lease.install(f.spec) == nil || activeRoutingLease.returnRoute != nil {
			t.Fatal("illegal mapping affected independent AI or was partially accepted")
		}
	}
}

func TestReturnRouteManualAuthoritySurvivesAutoExpiryAndOwnerStopButNotLogout(t *testing.T) {
	f := newReturnFixture(t, true)
	begin, _ := bundleOwnerFixture(t)
	f.lease.now = time.Unix(1001, 0)
	routingLeaseNow = func() time.Time { return f.lease.now }
	spec := f.lease.spec(120 * time.Second)
	spec.ReturnRoute = f.spec.ReturnRoute
	spec.AccountID = "account-1"
	spec.AccountGeneration = 7
	spec.RenewalOverlay = "{}"
	clientBundleSetup = &SetupParams{RoutingLease: spec}
	f.lease.install(spec)
	begin.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	// Swift omits response metadata; Android copies it through JSON with new pointers.
	for _, include := range []bool{false, true} {
		request := *begin
		if !include {
			request.ReturnRouteGuard = nil
		}
		data, _ := json.Marshal(request)
		var decoded BeginClientBundleOwnerParams
		_ = json.Unmarshal(data, &decoded)
		if _, err := handleBeginClientBundleOwner(&decoded); err != nil {
			t.Fatal("response metadata changed owner binding")
		}
		begin.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	}
	for _, mutate := range []func(*ClientBundleOwnerContext){
		func(c *ClientBundleOwnerContext) { c.OwnerSerial++ }, func(c *ClientBundleOwnerContext) { c.InstanceID = "other" },
		func(c *ClientBundleOwnerContext) { c.AccountID = "other" }, func(c *ClientBundleOwnerContext) { c.AccountGeneration++ },
		func(c *ClientBundleOwnerContext) { c.ConfigurationGeneration++ },
	} {
		request := *begin
		mutate(&request.ClientBundleOwnerContext)
		if _, err := handleBeginClientBundleOwner(&request); err == nil {
			t.Fatal("original owner binding no longer enforced")
		}
	}
	before := handleGetClientBundleOwner().ReturnRouteGuard
	f.lease.now = f.lease.now.Add(121 * time.Second)
	after := handleGetClientBundleOwner().ReturnRouteGuard
	if after == nil || handleGetRoutingLease() != nil {
		t.Fatal("manual authority followed AI expiry")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: before}).Message == "" {
		t.Fatal("expired token accepted")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: after}).Message != "" {
		t.Fatal("fresh manual guard rejected after expiry")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "us-exit", RoutingLease: after}).Message == "" {
		t.Fatal("manual guard revived automatic authority")
	}
	owner := *clientBundleOwner
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: &owner})
	stopped := handleGetClientBundleOwner().ReturnRouteGuard
	if stopped == nil || handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-optimized", RoutingLease: stopped}).Message != "" {
		t.Fatal("ordinary owner stop retired manual route")
	}
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: &owner, InvalidateSession: true})
	if handleGetClientBundleOwner().ReturnRouteGuard != nil {
		t.Fatal("logout kept manual guard")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: stopped}).Message == "" {
		t.Fatal("logout kept cached manual authority")
	}
}

func TestReturnRouteFallbackUsesInputOrderAndPreservesQualifiedAI(t *testing.T) {
	f := newReturnFixture(t, true)
	guard := f.lease.install(f.spec)
	if handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "us-exit", RoutingLease: guard}).Message != "" {
		t.Fatal("AI setup failed")
	}
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	f.spec.ReturnRoute.Options[1], f.spec.ReturnRoute.Options[2] = f.spec.ReturnRoute.Options[2], f.spec.ReturnRoute.Options[1]
	selectMu.Lock()
	installReturnRouteLocked(activeRoutingLease, f.spec.ReturnRoute, tunnel.AllProxies(), false, "")
	selectMu.Unlock()
	if returnPick(t) != "role-optimized" {
		t.Fatal("fallback reordered mapped options")
	}
	if f.lease.auto.Adapter().(pickableGroup).Now() != "us-exit" {
		t.Fatal("normalization reset qualified AI choice")
	}
	if !handleInvalidateRoutingLease(handleGetRoutingLease()) {
		t.Fatal("AI revocation failed")
	}
	selectMu.Lock()
	manual := returnRouteGuardLocked()
	selectMu.Unlock()
	if manual == nil || handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-lite", RoutingLease: manual}).Message != "" {
		t.Fatal("AI revocation removed manual return authority")
	}
}

func TestReturnRouteNoUsableRoleBlocksPseudoDirectInsteadOfSelectingFirstMember(t *testing.T) {
	f := newReturnFixture(t, false)
	f.proxies["pseudo-direct"] = directNode("pseudo-direct")
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.proxies["pseudo-direct"])
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.reject)
	f.proxies["return"] = selectorOver(t, "return", f.proxies["role-direct"], f.proxies["role-lite"], f.proxies["role-optimized"], f.lease.direct, f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	f.lease.install(f.spec)
	if returnPick(t) != "REJECT" {
		t.Fatal("missing REJECT member silently selected pseudo DIRECT")
	}
	// A later graph update must remain visible through the blocking selector.
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.usExit)
	tunnel.UpdateProxies(f.proxies, nil)
	refreshRoute()
	if returnPick(t) != "role-lite" {
		t.Fatal("blocking member hid recovered delivered role")
	}
}

func TestReturnRouteTraversalCannotBorrowManagedOrReservedDescendants(t *testing.T) {
	f := newReturnFixture(t, false)
	for _, name := range []string{"zn.service.ai", "zn.service.ai.manual", "clientzn.service.ai", "clientzn.service.ai.manual", "DIRECT", "direct", "ReJeCt"} {
		t.Run(name, func(t *testing.T) {
			managed := selectorOver(t, name, f.lease.usExit)
			candidate := selectorOver(t, "candidate", managed)
			p := maps.Clone(f.proxies)
			p[name] = managed
			p["candidate"] = candidate
			if returnRouteUsable(f.spec.ReturnRoute, "candidate", p) {
				t.Fatal("role borrowed excluded descendant's exit")
			}
			candidate = selectorOver(t, "candidate", managed, f.lease.usExit)
			p["candidate"] = candidate
			if !returnRouteUsable(f.spec.ReturnRoute, "candidate", p) {
				t.Fatal("excluded descendant hid independent delivered leaf")
			}
		})
	}
}

func TestReturnRouteConcurrentGroupReadersDuringFailClosedNormalization(t *testing.T) {
	f := newReturnFixture(t, false)
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.lease.dirAlias)
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	selector := f.proxies["return"].Adapter().(*outboundgroup.Selector)
	base := selector.GroupBase
	var readers sync.WaitGroup
	start := make(chan struct{})
	for range 4 {
		readers.Add(1)
		go func() {
			defer readers.Done()
			<-start
			for range 1000 {
				_ = selector.Proxies()
				_ = selector.GroupBase.Name()
			}
		}()
	}
	close(start)
	f.lease.install(f.spec)
	for range 100 {
		selectMu.Lock()
		normalizeReturnRouteLocked(tunnel.AllProxies())
		selectMu.Unlock()
	}
	readers.Wait()
	if selector.GroupBase != base || selector.Now() != "REJECT" {
		t.Fatal("normalization replaced published group or failed to block")
	}
}

func TestReturnRouteReuseRequiresPreviouslyPreparedBlockingMember(t *testing.T) {
	f := newReturnFixture(t, true)
	f.proxies["return"] = selectorOver(t, "return", f.proxies["role-direct"], f.proxies["role-lite"], f.proxies["role-optimized"])
	tunnel.UpdateProxies(f.proxies, nil)
	old := *f.spec
	old.ReturnRoute = nil
	old.ConnectionDigest = "same-connection"
	old.MetadataDigest = "same-metadata"
	f.lease.install(&old)
	previous := clientBundleSetup
	t.Cleanup(func() { clientBundleSetup = previous })
	clientBundleSetup = &SetupParams{RoutingLease: &old}
	withCurrentConfig(t, &config.Config{})
	next := old
	next.ReturnRoute = f.spec.ReturnRoute
	configMu.Lock()
	reused := reuseClientBundleConfigurationLocked(&SetupParams{RoutingLease: &next})
	configMu.Unlock()
	if reused {
		t.Fatal("same-config renewal reused a published selector without real REJECT")
	}
	if returnRouteMember(next.ReturnRoute, "REJECT", tunnel.AllProxies()) {
		t.Fatal("reuse mutated published selector")
	}
}

package core

import (
	"core/clientbundle"
	"maps"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func boolPtr(v bool) *bool { return &v }

func testInstallReturnRoute(state *routingLeaseState, spec *clientbundle.ReturnRouteSpec, proxies map[string]constant.Proxy) {
	prevEnabled := false
	prevSelected := ""
	if state.returnRoute != nil {
		prevEnabled = state.returnRoute.enabled
		prevSelected = state.returnRoute.selectedID
	}
	installReturnRouteLocked(state, spec, proxies, prevEnabled, prevSelected)
}

type dispatchFixture struct {
	lease       *routingLeaseFixture
	proxies     map[string]constant.Proxy
	spec        *RoutingLeaseSpec
	cnLocal     constant.Proxy
	mediaLocal  constant.Proxy
	cnParent    constant.Proxy
	mediaParent constant.Proxy
}

func newDispatchFixture(t *testing.T, allUsable bool) *dispatchFixture {
	t.Helper()
	f := newRoutingLeaseFixture(t)
	p := maps.Clone(tunnel.AllProxies())
	if allUsable {
		p["role-direct"] = selectorOver(t, "role-direct", f.sgExit)
		p["role-lite"] = selectorOver(t, "role-lite", f.usExit)
		p["role-optimized"] = selectorOver(t, "role-optimized", f.usExit)
	} else {
		p["role-direct"] = selectorOver(t, "role-direct", f.reject)
		p["role-lite"] = selectorOver(t, "role-lite", f.usExit)
		p["role-optimized"] = selectorOver(t, "role-optimized", f.reject)
	}
	p["return"] = selectorOver(t, "return", p["role-direct"], p["role-lite"], p["role-optimized"], f.direct, f.sgExit, f.reject)

	cnLocal := selectorOver(t, "cn-local", f.direct)
	mediaLocal := selectorOver(t, "media-local", f.direct)
	p["cn-local"] = cnLocal
	p["media-local"] = mediaLocal

	cnParent := selectorOver(t, "cn-dispatch", cnLocal, p["return"])
	mediaParent := selectorOver(t, "media-dispatch", mediaLocal, p["return"])
	p["cn-dispatch"] = cnParent
	p["media-dispatch"] = mediaParent

	tunnel.UpdateProxies(p, nil)

	spec := f.spec(120 * time.Second)
	spec.ReturnRoute = &clientbundle.ReturnRouteSpec{
		GroupName: "return",
		Options: []clientbundle.ReturnRouteOption{
			{ID: "direct", Target: "role-direct"},
			{ID: "hk_lite", Target: "role-lite"},
			{ID: "hk_optimized", Target: "role-optimized"},
		},
		Outbounds: []string{"us-exit", "sg-exit"},
		Dispatches: []clientbundle.ReturnDispatchSpec{
			{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "cn-local", ReturnTarget: "return"},
			{ID: "return_media_dispatch", GroupName: "media-dispatch", LocalTarget: "media-local", ReturnTarget: "return"},
		},
	}

	return &dispatchFixture{
		lease:       f,
		proxies:     p,
		spec:        spec,
		cnLocal:     cnLocal,
		mediaLocal:  mediaLocal,
		cnParent:    cnParent,
		mediaParent: mediaParent,
	}
}

func dispatchParentNow(t *testing.T, name string) string {
	t.Helper()
	selector, err := selectableGroup(name)
	if err != nil {
		t.Fatal(err)
	}
	return selector.Now()
}

func TestDispatchInitialDefaultIsLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	f.lease.install(f.spec)
	state := activeRoutingLease
	if state.returnRoute == nil || len(state.returnRoute.dispatches) != 2 {
		t.Fatal("dispatch selectors not installed")
	}
	if state.returnRoute.enabled {
		t.Fatal("dispatch should default to disabled")
	}
	if state.returnRoute.selectedID != "" {
		t.Fatal("selectedID should be empty when disabled")
	}
}

func TestDispatchEnableAllThreeRoutesAndDisable(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)

	for _, optionID := range []string{"direct", "hk_lite", "hk_optimized"} {
		result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
			RoutingLease: guard,
			Enabled:      boolPtr(true),
			OptionID:     optionID,
		})
		if err != nil {
			t.Fatalf("enable %s: %v", optionID, err)
		}
		if !result.Enabled {
			t.Fatalf("enable %s: not enabled", optionID)
		}
		if result.SelectedID == nil || *result.SelectedID != optionID {
			t.Fatalf("enable %s: selectedID mismatch", optionID)
		}
		if len(result.Selections) != 3 {
			t.Fatalf("enable %s: expected 3 selections, got %d", optionID, len(result.Selections))
		}
		if result.Selections["cn-dispatch"] != "return" {
			t.Fatalf("enable %s: cn-dispatch not pointed to return", optionID)
		}
		if result.Selections["media-dispatch"] != "return" {
			t.Fatalf("enable %s: media-dispatch not pointed to return", optionID)
		}
		var target string
		for _, opt := range f.spec.ReturnRoute.Options {
			if opt.ID == optionID {
				target = opt.Target
			}
		}
		if result.Selections["return"] != target {
			t.Fatalf("enable %s: return group selection %s, want %s", optionID, result.Selections["return"], target)
		}
		guard = handleGetRoutingLease()
		if guard == nil {
			selectMu.Lock()
			guard = returnRouteGuardLocked()
			selectMu.Unlock()
		}
		if guard == nil {
			t.Fatalf("no guard after enable %s", optionID)
		}
	}

	result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(false),
	})
	if err != nil {
		t.Fatalf("disable: %v", err)
	}
	if result.Enabled {
		t.Fatal("disable: still enabled")
	}
	if result.SelectedID != nil {
		t.Fatal("disable: selectedID should be nil")
	}
	if len(result.Selections) != 2 {
		t.Fatalf("disable: expected 2 selections, got %d", len(result.Selections))
	}
	if result.Selections["cn-dispatch"] != "cn-local" {
		t.Fatal("disable: cn-dispatch not restored to local")
	}
	if result.Selections["media-dispatch"] != "media-local" {
		t.Fatal("disable: media-dispatch not restored to local")
	}
}

func TestDispatchRejectsStaleGuard(t *testing.T) {
	f := newDispatchFixture(t, true)
	old := f.lease.install(f.spec)
	next := *f.spec
	next.BundleID = "next"
	f.lease.install(&next)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: old,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err == nil {
		t.Fatal("stale guard accepted")
	}
}

func TestDispatchRejectsEnableWithoutOptionID(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
	})
	if err == nil {
		t.Fatal("enable without optionId accepted")
	}
}

func TestDispatchRejectsUnknownOptionID(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "invented",
	})
	if err == nil {
		t.Fatal("unknown optionId accepted")
	}
}

func TestDispatchRejectsUnusableOption(t *testing.T) {
	f := newDispatchFixture(t, false)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "direct",
	})
	if err == nil {
		t.Fatal("unusable option accepted")
	}
	result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err != nil {
		t.Fatalf("usable option rejected: %v", err)
	}
	if !result.Enabled {
		t.Fatal("not enabled")
	}
}

func TestDispatchChangeProxyCannotBypassGuard(t *testing.T) {
	f := newDispatchFixture(t, true)
	f.lease.install(f.spec)
	result := handleChangeProxy(&ChangeProxyParams{GroupName: "cn-dispatch", ProxyName: "return"})
	if result.Message == "" {
		t.Fatal("changeProxy bypassed dispatch guard for parent selector")
	}
	result = handleChangeProxy(&ChangeProxyParams{GroupName: "media-dispatch", ProxyName: "return"})
	if result.Message == "" {
		t.Fatal("changeProxy bypassed dispatch guard for media parent selector")
	}
}

func TestDispatchRenewalPreservesEnabledState(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	renewed := *f.spec
	renewed.BundleID = "renewal-1"
	selectMu.Lock()
	testInstallReturnRoute(activeRoutingLease, renewed.ReturnRoute, tunnel.AllProxies())
	selectMu.Unlock()
	state := activeRoutingLease
	if !state.returnRoute.enabled || state.returnRoute.selectedID != "hk_lite" {
		t.Fatal("compatible renewal did not preserve enabled state")
	}
	if dispatchParentNow(t, "cn-dispatch") != "return" {
		t.Fatal("renewal reset cn-dispatch parent to local")
	}
	if dispatchParentNow(t, "media-dispatch") != "return" {
		t.Fatal("renewal reset media-dispatch parent to local")
	}
}

func TestDispatchRenewalFailsClosedOnMissingBindings(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	noDispatch := *f.spec.ReturnRoute
	noDispatch.Dispatches = nil
	selectMu.Lock()
	testInstallReturnRoute(activeRoutingLease, &noDispatch, tunnel.AllProxies())
	selectMu.Unlock()
	state := activeRoutingLease
	if state.returnRoute.enabled {
		t.Fatal("renewal without dispatches kept enabled state")
	}
}

func TestDispatchRenewalFailsClosedOnUnusableOption(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_optimized",
	})
	if err != nil {
		t.Fatal(err)
	}
	f.proxies["role-optimized"] = selectorOver(t, "role-optimized", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	selectMu.Lock()
	testInstallReturnRoute(activeRoutingLease, f.spec.ReturnRoute, tunnel.AllProxies())
	selectMu.Unlock()
	state := activeRoutingLease
	if !state.returnRoute.enabled {
		t.Fatal("renewal cleared activation intent despite fail-closed contract")
	}
	if state.returnRoute.selectedID != "" {
		t.Fatal("renewal kept stale selected option")
	}
	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("renewal leaked cn-dispatch to local instead of blocking")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("renewal leaked media-dispatch to local instead of blocking")
	}
}

func TestDispatchNormalizationDisablesOnUnusableOption(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	selectMu.Lock()
	normalizeReturnRouteLocked(tunnel.AllProxies())
	selectMu.Unlock()
	state := activeRoutingLease
	if !state.returnRoute.enabled {
		t.Fatal("normalization cleared activation intent despite fail-closed contract")
	}
	if state.returnRoute.selectedID != "" {
		t.Fatal("normalization kept stale selected option ID")
	}
	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("normalization leaked cn-dispatch to local")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("normalization leaked media-dispatch to local")
	}
}

func TestDispatchMalformedSpecsDoNotBreakReturnRoute(t *testing.T) {
	f := newDispatchFixture(t, true)
	bad := *f.spec.ReturnRoute
	bad.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "return", ReturnTarget: "return"},
		{ID: "return_media_dispatch", GroupName: "media-dispatch", LocalTarget: "media-local", ReturnTarget: "return"},
	}
	f.lease.install(&RoutingLeaseSpec{
		AccountID: f.spec.AccountID, AccountGeneration: f.spec.AccountGeneration,
		BundleID: f.spec.BundleID, ConfigurationDigest: f.spec.ConfigurationDigest,
		ExpiresAt: f.spec.ExpiresAt, Services: f.spec.Services, ReturnRoute: &bad,
	})
	state := activeRoutingLease
	if state.returnRoute == nil {
		t.Fatal("malformed dispatches broke the return route itself")
	}
	if len(state.returnRoute.dispatches) != 0 {
		t.Fatal("malformed dispatches were partially installed")
	}
}

func TestDispatchNoDispatchesReturnsUnavailable(t *testing.T) {
	f := newDispatchFixture(t, true)
	noDispatch := *f.spec.ReturnRoute
	noDispatch.Dispatches = nil
	spec := *f.spec
	spec.ReturnRoute = &noDispatch
	guard := f.lease.install(&spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      boolPtr(true),
		OptionID:     "hk_lite",
	})
	if err != errDispatchUnavailable {
		t.Fatalf("expected errDispatchUnavailable, got %v", err)
	}
}

func TestDispatchValidateDispatchesRejectsOneEntry(t *testing.T) {
	spec := &clientbundle.ReturnRouteSpec{
		GroupName: "return",
		Options: []clientbundle.ReturnRouteOption{
			{ID: "direct", Target: "a"}, {ID: "hk_lite", Target: "b"}, {ID: "hk_optimized", Target: "c"},
		},
		Outbounds: []string{"leaf"},
		Dispatches: []clientbundle.ReturnDispatchSpec{
			{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "cn-local", ReturnTarget: "return"},
		},
	}
	if spec.ValidateDispatches() {
		t.Fatal("accepted single dispatch entry")
	}
}

func TestDispatchValidateDispatchesRejectsDuplicateGroups(t *testing.T) {
	spec := &clientbundle.ReturnRouteSpec{
		GroupName: "return",
		Options: []clientbundle.ReturnRouteOption{
			{ID: "direct", Target: "a"}, {ID: "hk_lite", Target: "b"}, {ID: "hk_optimized", Target: "c"},
		},
		Outbounds: []string{"leaf"},
		Dispatches: []clientbundle.ReturnDispatchSpec{
			{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "cn-local", ReturnTarget: "return"},
			{ID: "return_media_dispatch", GroupName: "cn-dispatch", LocalTarget: "media-local", ReturnTarget: "return"},
		},
	}
	if spec.ValidateDispatches() {
		t.Fatal("accepted duplicate dispatch group names")
	}
}

func TestDispatchValidateDispatchesRejectsWrongReturnTarget(t *testing.T) {
	spec := &clientbundle.ReturnRouteSpec{
		GroupName: "return",
		Options: []clientbundle.ReturnRouteOption{
			{ID: "direct", Target: "a"}, {ID: "hk_lite", Target: "b"}, {ID: "hk_optimized", Target: "c"},
		},
		Outbounds: []string{"leaf"},
		Dispatches: []clientbundle.ReturnDispatchSpec{
			{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "cn-local", ReturnTarget: "return"},
			{ID: "return_media_dispatch", GroupName: "media-dispatch", LocalTarget: "media-local", ReturnTarget: "other"},
		},
	}
	if spec.ValidateDispatches() {
		t.Fatal("accepted dispatch with wrong returnTarget")
	}
}

func TestDispatchGuardStaleExpiredBlocked(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	f.lease.now = f.lease.now.Add(121 * time.Second)
	selectMu.Lock()
	newGuard := returnRouteGuardLocked()
	selectMu.Unlock()
	if newGuard == nil {
		t.Fatal("return route guard disappeared after expiry")
	}
	_, err = handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(false),
	})
	if err == nil {
		t.Fatal("expired guard accepted for dispatch")
	}
	result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: newGuard, Enabled: boolPtr(false),
	})
	if err != nil {
		t.Fatalf("fresh guard rejected: %v", err)
	}
	if result.Enabled {
		t.Fatal("dispatch still enabled after disable with fresh guard")
	}
}

func TestDispatchActiveOptionLossCannotLeakLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	if dispatchParentNow(t, "cn-dispatch") != "return" {
		t.Fatal("enable did not set cn-dispatch to return group")
	}
	f.proxies["role-direct"] = selectorOver(t, "role-direct", f.lease.reject)
	f.proxies["role-lite"] = selectorOver(t, "role-lite", f.lease.reject)
	f.proxies["role-optimized"] = selectorOver(t, "role-optimized", f.lease.reject)
	tunnel.UpdateProxies(f.proxies, nil)
	selectMu.Lock()
	normalizeReturnRouteLocked(tunnel.AllProxies())
	selectMu.Unlock()

	childSelector, _ := selectableGroup("return")
	if childSelector.Now() != "REJECT" {
		t.Fatal("child return route did not normalize to REJECT")
	}
	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("active option loss leaked cn-dispatch parent to local")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("active option loss leaked media-dispatch parent to local")
	}
	if dispatchParentNow(t, "cn-dispatch") != "return" {
		t.Fatalf("cn-dispatch at %s, want return (blocking via REJECT)", dispatchParentNow(t, "cn-dispatch"))
	}
	state := activeRoutingLease
	if !state.returnRoute.enabled {
		t.Fatal("option loss cleared activation intent")
	}
	if state.returnRoute.selectedID != "" {
		t.Fatal("option loss did not clear stale selectedID")
	}
}

func TestDispatchMetadataLossCannotLeakLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_optimized",
	})
	if err != nil {
		t.Fatal(err)
	}
	if dispatchParentNow(t, "cn-dispatch") != "return" {
		t.Fatal("pre-condition: cn-dispatch not at return")
	}
	noDispatch := *f.spec.ReturnRoute
	noDispatch.Dispatches = nil
	selectMu.Lock()
	testInstallReturnRoute(activeRoutingLease, &noDispatch, tunnel.AllProxies())
	selectMu.Unlock()

	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("metadata loss leaked cn-dispatch parent to local")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("metadata loss leaked media-dispatch parent to local")
	}
}

func TestDispatchRenewalIncompatibleDispatchesCannotLeakLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	bad := *f.spec.ReturnRoute
	bad.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn-dispatch", LocalTarget: "cn-local", ReturnTarget: "cn-local"},
		{ID: "return_media_dispatch", GroupName: "media-dispatch", LocalTarget: "media-local", ReturnTarget: "cn-local"},
	}
	selectMu.Lock()
	testInstallReturnRoute(activeRoutingLease, &bad, tunnel.AllProxies())
	selectMu.Unlock()

	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("incompatible dispatch renewal leaked cn-dispatch to local")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("incompatible dispatch renewal leaked media-dispatch to local")
	}
}

func TestDispatchExplicitDisableIsOnlyPathToLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	guard = handleGetRoutingLease()
	if guard == nil {
		selectMu.Lock()
		guard = returnRouteGuardLocked()
		selectMu.Unlock()
	}
	result, err = handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(false),
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Enabled {
		t.Fatal("explicit disable did not clear enabled")
	}
	if dispatchParentNow(t, "cn-dispatch") != "cn-local" {
		t.Fatal("explicit disable did not restore cn-dispatch to local")
	}
	if dispatchParentNow(t, "media-dispatch") != "media-local" {
		t.Fatal("explicit disable did not restore media-dispatch to local")
	}
	if _, hasReturn := result.Selections["return"]; hasReturn {
		t.Fatal("disable selections included the return group")
	}
	if len(result.Selections) != 2 {
		t.Fatalf("disable selections count %d, want 2 (parents only)", len(result.Selections))
	}
}

func TestDispatchRejectsNilParams(t *testing.T) {
	_, err := handleSetClientReturnRoute(nil)
	if err != errDispatchEnabledMissing {
		t.Fatalf("nil params: got %v, want errDispatchEnabledMissing", err)
	}
}

func TestDispatchRejectsOmittedEnabled(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard,
		Enabled:      nil,
		OptionID:     "hk_lite",
	})
	if err != errDispatchEnabledMissing {
		t.Fatalf("nil Enabled: got %v, want errDispatchEnabledMissing", err)
	}
}

func TestDispatchValidateDispatchesRequiresExactIDs(t *testing.T) {
	base := func() *clientbundle.ReturnRouteSpec {
		return &clientbundle.ReturnRouteSpec{
			GroupName: "return",
			Options: []clientbundle.ReturnRouteOption{
				{ID: "direct", Target: "a"}, {ID: "hk_lite", Target: "b"}, {ID: "hk_optimized", Target: "c"},
			},
			Outbounds: []string{"leaf"},
		}
	}
	s := base()
	s.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn", LocalTarget: "cn-l", ReturnTarget: "return"},
		{ID: "return_media_dispatch", GroupName: "media", LocalTarget: "media-l", ReturnTarget: "return"},
	}
	if !s.ValidateDispatches() {
		t.Fatal("valid dispatch pair rejected")
	}
	s2 := base()
	s2.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn", LocalTarget: "cn-l", ReturnTarget: "return"},
		{ID: "return_other", GroupName: "media", LocalTarget: "media-l", ReturnTarget: "return"},
	}
	if s2.ValidateDispatches() {
		t.Fatal("unknown dispatch ID accepted")
	}
	s3 := base()
	s3.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn", LocalTarget: "cn-l", ReturnTarget: "return"},
		{ID: "return_dispatch", GroupName: "media", LocalTarget: "media-l", ReturnTarget: "return"},
	}
	if s3.ValidateDispatches() {
		t.Fatal("duplicate dispatch ID accepted")
	}
	s4 := base()
	s4.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn", LocalTarget: "a", ReturnTarget: "return"},
		{ID: "return_media_dispatch", GroupName: "media", LocalTarget: "media-l", ReturnTarget: "return"},
	}
	if s4.ValidateDispatches() {
		t.Fatal("localTarget overlapping option target accepted")
	}
	s5 := base()
	s5.Dispatches = []clientbundle.ReturnDispatchSpec{
		{ID: "return_dispatch", GroupName: "cn", LocalTarget: "shared", ReturnTarget: "return"},
		{ID: "return_media_dispatch", GroupName: "media", LocalTarget: "shared", ReturnTarget: "return"},
	}
	if !s5.ValidateDispatches() {
		t.Fatal("shared pure local wrapper rejected")
	}
}

func TestDispatchLocalWrapperMustBePureDirect(t *testing.T) {
	f := newDispatchFixture(t, true)
	f.proxies["cn-local"] = selectorOver(t, "cn-local", f.lease.usExit)
	tunnel.UpdateProxies(f.proxies, nil)
	f.lease.install(f.spec)
	state := activeRoutingLease
	if len(state.returnRoute.dispatches) != 0 {
		t.Fatal("dispatch installed with non-DIRECT local wrapper")
	}
}

func TestDispatchLocalWrapperRejectsCycles(t *testing.T) {
	f := newDispatchFixture(t, true)
	inner := selectorOver(t, "inner-wrap", f.lease.direct)
	f.proxies["inner-wrap"] = inner
	outer := selectorOver(t, "cn-local", inner, f.proxies["cn-local"])
	f.proxies["cn-local"] = outer
	tunnel.UpdateProxies(f.proxies, nil)
	if localWrapperPureDirectProxy("cn-local", tunnel.AllProxies()) {
		t.Fatal("local wrapper with potential cycle accepted")
	}
}

func TestDispatchLeaseReinstallPreservesIntent(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	if guard == nil {
		t.Fatal("no guard after full install")
	}
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	renewed := *f.spec
	renewed.BundleID = "renewed"
	f.lease.install(&renewed)
	state := activeRoutingLease
	if state == nil || state.returnRoute == nil {
		t.Fatal("reinstall failed")
	}
	if !state.returnRoute.enabled {
		t.Fatal("full config replacement did not preserve enabled state")
	}
}

func TestDispatchSavedSelectionsRestoreAcknowledgedActivation(t *testing.T) {
	f := newDispatchFixture(t, true)
	picks := map[string]string{"return": "role-lite", "cn-dispatch": "return", "media-dispatch": "return"}
	if enabled, _ := persistedReturnDispatchChoice(f.spec.ReturnRoute, map[string]string{"cn-dispatch": "return"}); enabled {
		t.Fatal("partial preferences granted activation")
	}
	selectMu.Lock()
	patchSelectGroupLocked(picks)
	installRoutingLeaseLocked(f.spec, picks)
	state := activeRoutingLease.returnRoute
	selectMu.Unlock()
	if !state.enabled || state.selectedID != "hk_lite" {
		t.Fatal("saved current-profile activation not restored")
	}
	guard := handleGetRoutingLease()
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "DIRECT", RoutingLease: guard}); result.Message == "" {
		t.Fatal("restored activation bypassed through DIRECT")
	}
	if _, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{RoutingLease: guard, Enabled: boolPtr(false)}); err != nil {
		t.Fatal(err)
	}
	selectMu.Lock()
	installRoutingLeaseLocked(f.spec, picks)
	enabled := activeRoutingLease.returnRoute.enabled
	selectMu.Unlock()
	if enabled {
		t.Fatal("stale saved preferences overrode the live disable")
	}
}

func TestDispatchFullConfigReplacementBlocksRatherThanLocal(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	noDispatch := *f.spec
	rr := *f.spec.ReturnRoute
	rr.Dispatches = nil
	noDispatch.ReturnRoute = &rr
	noDispatch.BundleID = "no-dispatch"
	f.lease.install(&noDispatch)
	if dispatchParentNow(t, "cn-dispatch") == "cn-local" {
		t.Fatal("full config replacement without dispatches leaked cn-dispatch to local")
	}
	if dispatchParentNow(t, "media-dispatch") == "media-local" {
		t.Fatal("full config replacement without dispatches leaked media-dispatch to local")
	}
}

func TestDispatchActiveGenericDIRECTCannotBypass(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	guard = handleGetRoutingLease()
	if guard == nil {
		selectMu.Lock()
		guard = returnRouteGuardLocked()
		selectMu.Unlock()
	}
	result := handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "DIRECT", RoutingLease: guard})
	if result.Message == "" {
		t.Fatal("literal DIRECT accepted on child while dispatch ON")
	}
	result = handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "REJECT", RoutingLease: guard})
	if result.Message == "" {
		t.Fatal("literal REJECT accepted on child while dispatch ON")
	}
	result = handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "sg-exit", RoutingLease: guard})
	if result.Message == "" {
		t.Fatal("unmapped member accepted on child while dispatch ON")
	}
}

func TestDispatchSelectReturnMappedChildThenRenewPreservesActual(t *testing.T) {
	f := newDispatchFixture(t, true)
	guard := f.lease.install(f.spec)
	_, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite",
	})
	if err != nil {
		t.Fatal(err)
	}
	guard = handleGetRoutingLease()
	if guard == nil {
		selectMu.Lock()
		guard = returnRouteGuardLocked()
		selectMu.Unlock()
	}
	result := handleChangeProxy(&ChangeProxyParams{GroupName: "return", ProxyName: "role-optimized", RoutingLease: guard})
	if result.Message != "" {
		t.Fatalf("mapped child change rejected: %s", result.Message)
	}
	state := activeRoutingLease
	if state.returnRoute.selectedID != "hk_optimized" {
		t.Fatalf("selectedID not synced: got %s, want hk_optimized", state.returnRoute.selectedID)
	}
	renewed := *f.spec
	renewed.BundleID = "renewed-sync"
	f.lease.install(&renewed)
	state = activeRoutingLease
	if !state.returnRoute.enabled || state.returnRoute.selectedID != "hk_optimized" {
		t.Fatalf("renewal did not preserve actual chosen role: enabled=%v selectedID=%s",
			state.returnRoute.enabled, state.returnRoute.selectedID)
	}
	selector, _ := selectableGroup("return")
	if selector.Now() != "role-optimized" {
		t.Fatal("renewal restored old selection instead of actual")
	}
}

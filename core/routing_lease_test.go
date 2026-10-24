package core

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func networkNode(t *testing.T, name string) constant.Proxy {
	t.Helper()
	p, err := adapter.ParseProxy(map[string]any{
		"name":   name,
		"type":   "socks5",
		"server": "127.0.0.1",
		"port":   1080,
	})
	if err != nil {
		t.Fatalf("ParseProxy(%s): %v", name, err)
	}
	t.Cleanup(func() { _ = p.Close() })
	return p
}

func rejectNode() constant.Proxy {
	return adapter.NewProxy(outbound.NewReject())
}

func directNode(name string) constant.Proxy {
	return adapter.NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: name}))
}

type routingLeaseFixture struct {
	now      time.Time
	policy   constant.Proxy
	auto     constant.Proxy
	manual   constant.Proxy
	usExit   constant.Proxy
	sgExit   constant.Proxy
	direct   constant.Proxy
	reject   constant.Proxy
	dirAlias constant.Proxy
	subGroup constant.Proxy
}

func newRoutingLeaseFixture(t *testing.T) *routingLeaseFixture {
	t.Helper()
	clearRoutingLeaseForConfigChange()
	t.Cleanup(resetRoutingLeaseInstance)

	prevNow := routingLeaseNow
	fix := &routingLeaseFixture{
		now:      time.UnixMilli(1_700_000_000_000),
		usExit:   networkNode(t, "us-exit"),
		sgExit:   networkNode(t, "sg-exit"),
		direct:   directNode("DIRECT"),
		reject:   rejectNode(),
		dirAlias: directNode("direct-alias"),
	}
	routingLeaseNow = func() time.Time { return fix.now }
	t.Cleanup(func() { routingLeaseNow = prevNow })

	fix.subGroup = selectorOver(t, "nested-group", fix.usExit)
	fix.auto = selectorOver(t, "AI 自动", fix.reject, fix.usExit, fix.sgExit, fix.dirAlias, fix.subGroup)
	fix.manual = selectorOver(t, "AI 服务 · 手动", fix.usExit, fix.sgExit, fix.direct)
	fix.policy = selectorOver(t, "AI 服务", fix.auto, fix.manual, fix.direct)

	tunnel.UpdateProxies(map[string]constant.Proxy{
		"AI 服务":        fix.policy,
		"AI 自动":        fix.auto,
		"AI 服务 · 手动":   fix.manual,
		"us-exit":      fix.usExit,
		"sg-exit":      fix.sgExit,
		"DIRECT":       fix.direct,
		"REJECT":       fix.reject,
		"direct-alias": fix.dirAlias,
		"nested-group": fix.subGroup,
	}, nil)
	t.Cleanup(func() { tunnel.UpdateProxies(nil, nil) })
	return fix
}

func (f *routingLeaseFixture) spec(ttl time.Duration, allowed ...string) *RoutingLeaseSpec {
	if len(allowed) == 0 {
		allowed = []string{"us-exit", "sg-exit"}
	}
	return &RoutingLeaseSpec{
		AccountID:           "acct-1",
		AccountGeneration:   3,
		BundleID:            "bundle-1",
		ConfigurationDigest: "digest-1",
		ExpiresAt:           f.now.Add(ttl).UnixMilli(),
		Services: []RoutingLeaseServiceSpec{
			{
				GroupName:      "AI 服务",
				AutomaticGroup: "AI 自动",
				ManualGroup:    "AI 服务 · 手动",
				AllowedProxies: allowed,
			},
		},
	}
}

func (f *routingLeaseFixture) install(spec *RoutingLeaseSpec) *RoutingLeaseGuard {
	selectMu.Lock()
	installRoutingLeaseLocked(spec)
	selectMu.Unlock()
	return handleGetRoutingLease()
}

func TestRoutingLeaseWatchdogForcesRejectOnTTLWithoutFlutterAndPreservesManualAndDirect(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	guard := fix.install(fix.spec(40 * time.Millisecond))
	if guard == nil {
		t.Fatal("expected active routing lease guard")
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: guard,
	}); res.Message != "" || !res.Changed {
		t.Fatalf("guarded automatic switch failed: %+v", res)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务 · 手动",
		ProxyName: "sg-exit",
	}); res.Message != "" {
		t.Fatalf("manual group selection failed: %+v", res)
	}
	guard = handleGetRoutingLease()
	if guard == nil {
		t.Fatal("expected lease guard to remain active before TTL")
	}

	fix.now = fix.now.Add(50 * time.Millisecond)
	deadline := time.Now().Add(time.Second)
	for groupNow(t, fix.auto) != "REJECT" && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("automatic group = %q after TTL expiry without Flutter, want REJECT", got)
	}
	if got := groupNow(t, fix.manual); got != "sg-exit" {
		t.Fatalf("manual group = %q after TTL expiry, want sg-exit preserved", got)
	}
	if handleGetRoutingLease() != nil {
		t.Fatal("getRoutingLease returned non-nil after TTL expiry")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: guard,
	}); res.Message == "" {
		t.Fatal("expired guard was accepted after TTL")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务",
		ProxyName: "DIRECT",
	}); res.Message != "" {
		t.Fatalf("switching policy group to DIRECT failed: %+v", res)
	}
	if got := groupNow(t, fix.policy); got != "DIRECT" {
		t.Fatalf("policy group = %q, want DIRECT", got)
	}
}

func TestRoutingLeaseManualIntentRotatesTokenAgainstABA(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	staleGuard := fix.install(fix.spec(120 * time.Second))
	if staleGuard == nil {
		t.Fatal("expected active lease guard")
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务",
		ProxyName: "AI 服务 · 手动",
	}); res.Message != "" {
		t.Fatalf("switch to manual failed: %+v", res)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务",
		ProxyName: "AI 自动",
	}); res.Message != "" {
		t.Fatalf("switch back to automatic failed: %+v", res)
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: staleGuard,
	}); res.Message == "" {
		t.Fatal("stale guard succeeded after manual ABA transition")
	}
	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("automatic group = %q, want REJECT", got)
	}

	freshGuard := handleGetRoutingLease()
	if freshGuard == nil || freshGuard.Token == staleGuard.Token {
		t.Fatalf("freshGuard = %+v, want a rotated token", freshGuard)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: freshGuard,
	}); res.Message != "" {
		t.Fatalf("fresh guard after ABA failed: %+v", res)
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务 · 手动",
		ProxyName: "sg-exit",
	}); res.Message != "" {
		t.Fatalf("manual node switch failed: %+v", res)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "sg-exit",
		RoutingLease: freshGuard,
	}); res.Message == "" {
		t.Fatal("guard from before manual group change was accepted")
	}
	if !handleInvalidateRoutingLease(staleGuard) {
		t.Fatal("expected invalidateRoutingLease with same configurationGeneration to succeed after manual token rotation")
	}
	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("automatic group = %q after invalidation, want REJECT", got)
	}
}

func TestRoutingLeaseRejectsDirectAliasGroupAndUnguardedWrites(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	patchSelectGroup(map[string]string{"AI 自动": "direct-alias"})
	guard := fix.install(fix.spec(120*time.Second, "us-exit", "direct-alias", "nested-group", "DIRECT", "REJECT"))
	if guard == nil {
		t.Fatal("expected active lease guard")
	}
	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("initial selection on direct-alias = %q, want forced to REJECT", got)
	}

	for _, forbidden := range []string{"direct-alias", "nested-group", "DIRECT", "sg-exit"} {
		if res := handleChangeProxy(&ChangeProxyParams{
			GroupName:    "AI 自动",
			ProxyName:    forbidden,
			RoutingLease: guard,
		}); res.Message == "" {
			t.Fatalf("guarded selection of forbidden target %q succeeded", forbidden)
		}
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 自动",
		ProxyName: "us-exit",
	}); res.Message == "" {
		t.Fatal("unguarded non-REJECT selection into automatic group succeeded")
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: guard,
	}); res.Message != "" {
		t.Fatalf("valid guarded selection failed: %+v", res)
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 自动",
		ProxyName: "REJECT",
	}); res.Message != "" {
		t.Fatalf("unguarded REJECT failed: %+v", res)
	}
	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("automatic group = %q, want REJECT", got)
	}
}

func TestRoutingLeaseStaleConfigInstanceAndExternalSelectorSwapSafety(t *testing.T) {
	fix := newRoutingLeaseFixture(t)

	var scheduled []func()
	prevAfter := routingLeaseAfterFunc
	routingLeaseAfterFunc = func(_ time.Duration, fn func()) *time.Timer {
		scheduled = append(scheduled, fn)
		return time.NewTimer(time.Hour)
	}
	t.Cleanup(func() { routingLeaseAfterFunc = prevAfter })

	firstGuard := fix.install(fix.spec(120 * time.Second))
	if firstGuard == nil {
		t.Fatal("expected first lease guard")
	}
	secondGuard := fix.install(fix.spec(120 * time.Second))
	if secondGuard == nil || secondGuard.ConfigurationGeneration <= firstGuard.ConfigurationGeneration {
		t.Fatalf("secondGuard = %+v, want newer configurationGeneration than %+v", secondGuard, firstGuard)
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: firstGuard,
	}); res.Message == "" {
		t.Fatal("first guard wrote to second configuration generation")
	}
	if handleInvalidateRoutingLease(firstGuard) {
		t.Fatal("first guard invalidated second configuration generation")
	}

	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: secondGuard,
	}); res.Message != "" {
		t.Fatalf("second guard selection failed: %+v", res)
	}
	scheduled[0]()
	if got := groupNow(t, fix.auto); got != "us-exit" {
		t.Fatalf("stale timer callback mutated current selector to %q", got)
	}

	replacementAuto := selectorOver(t, "AI 自动", fix.reject, fix.usExit, fix.sgExit)
	_ = replacementAuto.Adapter().(*outboundgroup.Selector).Set("sg-exit")
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"AI 服务":      fix.policy,
		"AI 自动":      replacementAuto,
		"AI 服务 · 手动": fix.manual,
		"us-exit":    fix.usExit,
		"sg-exit":    fix.sgExit,
		"DIRECT":     fix.direct,
		"REJECT":     fix.reject,
	}, nil)
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: secondGuard,
	}); res.Message == "" {
		t.Fatal("guard succeeded after external selector replacement")
	}
	if got := groupNow(t, replacementAuto); got != "sg-exit" {
		t.Fatalf("replacement selector = %q, want untouched sg-exit", got)
	}

	_ = fix.install(fix.spec(120 * time.Second))
	resetRoutingLeaseInstance()
	if handleGetRoutingLease() != nil {
		t.Fatal("expected nil lease after instance reset")
	}
}

func TestApplyConfigInvalidatesPreviousLeaseBeforeLoadAndInstallsNewLeaseAtomically(t *testing.T) {
	if os.Getenv("ZOLNIT_LEASE_APPLY_TEST_CHILD") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestApplyConfigInvalidatesPreviousLeaseBeforeLoadAndInstallsNewLeaseAtomically$", "-test.timeout=15s")
		cmd.Env = append(os.Environ(), "ZOLNIT_LEASE_APPLY_TEST_CHILD=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("isolated Core apply failed: %v\n%s", err, output)
		}
		return
	}
	fix := newRoutingLeaseFixture(t)
	oldGuard := fix.install(fix.spec(120 * time.Second))
	if oldGuard == nil {
		t.Fatal("expected initial guard")
	}

	home := t.TempDir()
	constant.SetHomeDir(home)
	profile := "mixed-port: 0\nexternal-controller: ''\ndns: {enable: false}\ntun: {enable: false}\nntp: {enable: false}\nproxies:\n  - name: us-exit\n    type: socks5\n    server: 127.0.0.1\n    port: 1080\nproxy-groups:\n  - name: AI 自动\n    type: select\n    proxies:\n      - REJECT\n      - us-exit\n  - name: AI 服务 · 手动\n    type: select\n    proxies:\n      - us-exit\n      - DIRECT\n  - name: AI 服务\n    type: select\n    proxies:\n      - AI 自动\n      - AI 服务 · 手动\n      - DIRECT\n"
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte(profile), 0o600); err != nil {
		t.Fatalf("write config.yaml: %v", err)
	}

	spec := fix.spec(180*time.Second, "us-exit")
	spec.BundleID = "bundle-2"
	spec.ConfigurationDigest = "digest-2"
	rawParams, err := json.Marshal(map[string]any{
		"selected-map": map[string]string{
			"AI 服务": "AI 自动",
			"AI 自动": "us-exit",
		},
		"test-url":      defaultTestURL,
		"routing-lease": spec,
	})
	if err != nil {
		t.Fatalf("marshal setup params: %v", err)
	}
	var params SetupParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		t.Fatalf("unmarshal setup params: %v", err)
	}
	if err := applyConfig(&params); err != nil {
		t.Fatalf("applyConfig: %v", err)
	}

	if selector, err := selectableGroup("AI 自动"); err != nil || selector.Now() != "REJECT" {
		t.Fatal("a newly installed lease reused an unmeasured cached automatic selection")
	}
	newGuard := handleGetRoutingLease()
	if newGuard == nil || newGuard.BundleID != "bundle-2" || newGuard.ConfigurationGeneration <= oldGuard.ConfigurationGeneration {
		t.Fatalf("newGuard = %+v, want active bundle-2 guard", newGuard)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: oldGuard,
	}); res.Message == "" {
		t.Fatal("old guard succeeded after applyConfig")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: newGuard,
	}); res.Message != "" {
		t.Fatalf("new guard failed after applyConfig: %+v", res)
	}
}

func TestRoutingLeaseOverlongOrExpiredSpecFailsClosed(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	for _, ttl := range []time.Duration{0, -time.Second, 301 * time.Second} {
		patchSelectGroup(map[string]string{"AI 自动": "us-exit"})
		if guard := fix.install(fix.spec(ttl)); guard != nil {
			t.Fatalf("ttl %v installed guard %+v, want nil", ttl, guard)
		}
		if got := groupNow(t, fix.auto); got != "REJECT" {
			t.Fatalf("ttl %v left automatic group at %q, want REJECT", ttl, got)
		}
		if res := handleChangeProxy(&ChangeProxyParams{
			GroupName: "AI 自动",
			ProxyName: "us-exit",
		}); res.Message == "" {
			t.Fatalf("ttl %v left automatic group writable without a valid lease", ttl)
		}
	}
}

func TestClearRoutingLeaseForConfigChangeRejectsOldAutomaticGroupAndPreservesManualBeforeLoad(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	guard := fix.install(fix.spec(120 * time.Second))
	if guard == nil {
		t.Fatal("expected initial guard")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: guard,
	}); res.Message != "" {
		t.Fatalf("initial automatic selection failed: %+v", res)
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 服务 · 手动",
		ProxyName: "sg-exit",
	}); res.Message != "" {
		t.Fatalf("initial manual selection failed: %+v", res)
	}

	clearRoutingLeaseForConfigChange()

	if got := groupNow(t, fix.auto); got != "REJECT" {
		t.Fatalf("automatic group = %q during config load window, want REJECT", got)
	}
	if got := groupNow(t, fix.manual); got != "sg-exit" {
		t.Fatalf("manual group = %q during config load window, want preserved sg-exit", got)
	}
	if handleGetRoutingLease() != nil {
		t.Fatal("expected nil guard after clearRoutingLeaseForConfigChange")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName:    "AI 自动",
		ProxyName:    "us-exit",
		RoutingLease: guard,
	}); res.Message == "" {
		t.Fatal("old guard succeeded during config load window")
	}
	if res := handleChangeProxy(&ChangeProxyParams{
		GroupName: "AI 自动",
		ProxyName: "us-exit",
	}); res.Message == "" {
		t.Fatal("unguarded automatic selection succeeded during config load window")
	}
}

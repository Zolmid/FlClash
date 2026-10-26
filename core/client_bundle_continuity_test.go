package core

import (
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
)

func TestClientBundleLeaseRenewalPreservesQualifiedCurrentButNotRevocation(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	spec := fix.spec(200 * time.Second)
	spec.ConnectionDigest = "synthetic-connection"
	spec.MetadataDigest = "synthetic-qualified-policy"
	spec.RenewalOverlay = "{}"
	guard := fix.install(spec)
	result := handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "us-exit", RoutingLease: guard})
	if result.Message != "" {
		t.Fatal(result.Message)
	}
	withCurrentConfig(t, &config.Config{})
	oldSetup := clientBundleSetup
	t.Cleanup(func() { clientBundleSetup = oldSetup })
	params := &SetupParams{RoutingLease: spec}
	rememberClientBundleSetupLocked(params)
	fix.now = fix.now.Add(91 * time.Second)
	next := *spec
	next.BundleID = "renewed-synthetic"
	next.ConfigurationDigest = "renewed-application"
	next.ExpiresAt = fix.now.Add(200 * time.Second).UnixMilli()
	configMu.Lock()
	reused := reuseClientBundleConfigurationLocked(&SetupParams{RoutingLease: &next})
	configMu.Unlock()
	if !reused || fix.auto.Adapter().(pickableGroup).Now() != "us-exit" {
		t.Fatal("renewal reset a still-qualified selection")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "sg-exit", RoutingLease: guard}).Message == "" {
		t.Fatal("renewal accepted an old lease guard")
	}
	current := handleGetRoutingLease()
	if !handleInvalidateRoutingLease(current) {
		t.Fatal("explicit revocation failed")
	}
	selectMu.Lock()
	reused = renewRoutingLeaseLocked(&next)
	selectMu.Unlock()
	if reused || fix.auto.Adapter().(pickableGroup).Now() != "REJECT" {
		t.Fatal("revocation was treated as unknown health")
	}
}

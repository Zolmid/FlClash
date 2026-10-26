package core

import (
	"bytes"
	"core/clientbundle"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"go.yaml.in/yaml/v3"
)

func returnInstallBody(t *testing.T, downgrade bool) []byte {
	t.Helper()
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/ui-groups-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var data map[string]any
	if json.Unmarshal(body, &data) != nil {
		t.Fatal("invalid public fixture")
	}
	connection := data["connection"].(map[string]any)
	var original map[string]any
	if yaml.Unmarshal([]byte(connection["document"].(string)), &original) != nil {
		t.Fatal("invalid fixture document")
	}
	routing := data["routing"].(map[string]any)
	routing["nodes"] = []any{}
	role := routing["ui_groups"].([]any)[0].(map[string]any)
	options := role["options"].([]any)
	direct := options[0].(map[string]any)
	alias := map[string]any{"name": "synthetic-direct-role", "type": "select", "proxies": []any{direct["target"]}}
	direct["target"] = alias["name"]
	groups := append(original["proxy-groups"].([]any), alias)
	targets := map[string]bool{}
	for _, raw := range options {
		targets[raw.(map[string]any)["target"].(string)] = true
	}
	lite := options[1].(map[string]any)["target"].(string)
	for _, raw := range groups {
		group := raw.(map[string]any)
		group["type"] = "select"
		delete(group, "url")
		delete(group, "interval")
		if group["name"] == role["group"] {
			members := group["proxies"].([]any)
			members[0] = alias["name"]
		}
		if downgrade && targets[group["name"].(string)] && group["name"] != lite {
			group["proxies"] = []any{"REJECT"}
		}
	}
	document := map[string]any{"proxies": original["proxies"], "proxy-groups": groups,
		"rules": []any{"MATCH,DIRECT"}, "mixed-port": 0, "port": 0, "socks-port": 0,
		"external-controller": "", "dns": map[string]any{"enable": false},
		"tun": map[string]any{"enable": false}, "ntp": map[string]any{"enable": false}, "geo-auto-update": false}
	encoded, err := yaml.Marshal(document)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(encoded)
	connection["document"], connection["sha256"] = string(encoded), hex.EncodeToString(hash[:])
	if downgrade {
		data["bundle_id"] = "synthetic-downgrade"
	}
	encoded, err = json.Marshal(map[string]any{"data": data})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}

func TestReturnRouteInitialAndNativeRenewalInstall(t *testing.T) {
	if os.Getenv("ZOLNIT_RETURN_INSTALL_CHILD") != "1" {
		command := exec.Command(os.Args[0], "-test.run=^TestReturnRouteInitialAndNativeRenewalInstall$", "-test.timeout=20s")
		command.Env = append(os.Environ(), "ZOLNIT_RETURN_INSTALL_CHILD=1")
		if output, err := command.CombinedOutput(); err != nil {
			t.Fatalf("isolated installation failed: %v (output bytes=%d)", err, len(output))
		}
		return
	}
	begin, _ := bundleOwnerFixture(t)
	constant.SetHomeDir(t.TempDir())
	isRunning.Store(false)
	body := returnInstallBody(t, false)
	prepared, code := clientbundle.Prepare(body, "account-1", "{}", time.Unix(1001, 0))
	if code != "" || prepared.ReturnRoute == nil {
		t.Fatal("synthetic producer preparation failed")
	}
	initialLease := &RoutingLeaseSpec{AccountID: "account-1", AccountGeneration: 7, RenewalOverlay: "{}",
		BundleID: prepared.Bundle.ID, ConfigurationDigest: prepared.Digest, ExpiresAt: 1100_000,
		ConnectionDigest: prepared.Bundle.Connection.SHA, MetadataDigest: prepared.MetadataDigest, ReturnRoute: prepared.ReturnRoute}
	for _, service := range prepared.Services {
		initialLease.Services = append(initialLease.Services, RoutingLeaseServiceSpec{
			GroupName: service.GroupName, AutomaticGroup: service.AutomaticGroup, ManualGroup: service.ManualGroup, AllowedProxies: service.AllowedProxies})
	}
	var sourceConfig map[string]any
	if yaml.Unmarshal(prepared.Document, &sourceConfig) != nil {
		t.Fatal("invalid app config")
	}
	for _, raw := range sourceConfig["proxy-groups"].([]any) {
		entry := raw.(map[string]any)
		if entry["name"] != prepared.ReturnRoute.GroupName {
			continue
		}
		members := []any{}
		for _, name := range entry["proxies"].([]any) {
			if name != "REJECT" {
				members = append(members, name)
			}
		}
		entry["proxies"] = members
	}
	source, err := yaml.Marshal(sourceConfig)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(constant.Path.HomeDir(), "config.yaml")
	if os.WriteFile(path, source, 0600) != nil {
		t.Fatal("source write failed")
	}
	immutableSource := filepath.Join(t.TempDir(), "v1-source.yaml")
	if os.WriteFile(immutableSource, source, 0600) != nil {
		t.Fatal("profile source write failed")
	}
	baseConfig, err := loadSetupConfig(&SetupParams{Base: &SetupBase{Path: immutableSource, Overlay: "{}"}, RoutingLease: initialLease})
	if err != nil || !returnRouteMember(prepared.ReturnRoute, "REJECT", baseConfig.Proxies) {
		t.Fatal("base setup omitted prepared blocking member")
	}
	unchanged, err := os.ReadFile(immutableSource)
	if err != nil || !bytes.Equal(unchanged, source) {
		t.Fatal("base setup changed immutable source bytes")
	}
	if os.WriteFile(path, source, 0600) != nil {
		t.Fatal("source restore failed")
	}
	if err := applyConfig(&SetupParams{RoutingLease: initialLease}); err != nil {
		t.Fatal("initial Core setup failed")
	}
	after, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(after, source) {
		t.Fatal("initial setup changed source bytes")
	}
	group := prepared.ReturnRoute.GroupName
	selector, err := selectableGroup(group)
	if err != nil {
		t.Fatal(err)
	}
	if !returnRouteMember(prepared.ReturnRoute, "REJECT", currentConfig.Proxies) {
		t.Fatal("initial setup published selector without blocking member")
	}
	first := prepared.ReturnRoute.Options[0].Target
	optimized := prepared.ReturnRoute.Options[2].Target
	lite := prepared.ReturnRoute.Options[1].Target
	if selector.Now() != first {
		t.Fatal("initial Core default changed despite available role")
	}
	initial := handleGetClientBundleOwner().ReturnRouteGuard
	if handleChangeProxy(&ChangeProxyParams{GroupName: group, ProxyName: optimized, RoutingLease: initial}).Message != "" {
		t.Fatal("manual role unavailable before downgrade")
	}
	begin.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	owner, err := handleBeginClientBundleOwner(begin)
	if err != nil {
		t.Fatal(err)
	}
	applied, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: string(returnInstallBody(t, true))})
	if err != nil || !applied {
		t.Fatal("native owner renewal failed")
	}
	selector, err = selectableGroup(group)
	if err != nil || selector.Now() != lite {
		t.Fatal("native downgrade kept unusable cached role")
	}
	if !returnRouteMember(prepared.ReturnRoute, "REJECT", currentConfig.Proxies) {
		t.Fatal("native renewal published selector without blocking member")
	}
	if clientBundleSetup.RoutingLease.ReturnRoute == nil || handleGetClientBundleOwner().ReturnRouteGuard == nil {
		t.Fatal("native renewal dropped optional return authority")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: group, ProxyName: optimized, RoutingLease: initial}).Message == "" {
		t.Fatal("old renewal guard survived new graph")
	}
	current := handleGetClientBundleOwner().ReturnRouteGuard
	if handleChangeProxy(&ChangeProxyParams{GroupName: group, ProxyName: optimized, RoutingLease: current}).Message == "" {
		t.Fatal("new guard authorized empty downgraded role")
	}
	if handleChangeProxy(&ChangeProxyParams{GroupName: group, ProxyName: lite, RoutingLease: current}).Message != "" {
		t.Fatal("remaining role rejected after native renewal")
	}
	// The unchanged-config renewal path must keep the same usable selection, too.
	next, code := clientbundle.Prepare(returnInstallBody(t, true), "account-1", "{}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	configMu.Lock()
	reused, err := applyPreparedClientBundleLocked(next, clientBundleSetup)
	configMu.Unlock()
	if err != nil || !reused || selector.Now() != lite {
		t.Fatal("same-config renewal reset manual selection")
	}
	if currentConfig == nil || currentConfig.General.MixedPort != 0 || currentConfig.DNS.Enable || currentConfig.General.Tun.Enable {
		t.Fatal("synthetic installation enabled host networking")
	}
}

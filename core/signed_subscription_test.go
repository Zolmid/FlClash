package core

import (
	"bytes"
	"core/clientbundle"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const signedTestDevice = "0123456789abcdef0123456789abcdef"

func signedTestKey() ed25519.PrivateKey {
	seed, _ := hex.DecodeString("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
	return ed25519.NewKeyFromSeed(seed)
}

func signedFixtures(t *testing.T) map[string]string {
	t.Helper()
	content, err := os.ReadFile("clientbundle/testdata/signed-v2-php.json")
	if err != nil {
		t.Fatal(err)
	}
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(content, &raw); err != nil {
		t.Fatal(err)
	}
	fixtures := map[string]string{}
	for key, value := range raw {
		fixtures[key] = string(value)
	}
	return fixtures
}

// signedHome enables a test-only RFC 8032 trust root on a temporary Core home.
func signedHome(t *testing.T) (*BeginClientBundleOwnerParams, map[string]string) {
	t.Helper()
	params, _ := bundleOwnerFixture(t)
	public := base64.RawURLEncoding.EncodeToString(signedTestKey().Public().(ed25519.PublicKey))
	oldTrust, oldHome := signedSubscriptionTrust, C.Path.HomeDir()
	signedSubscriptionTrust = func() (*clientbundle.Trust, error) {
		return clientbundle.ParseTrust([]byte(`{"public_key_map":{"rfc8032-test":"` + public + `"}}`))
	}
	C.SetHomeDir(t.TempDir())
	routingLeaseNow = func() time.Time { return time.Unix(1200, 0) }
	t.Cleanup(func() { signedSubscriptionTrust = oldTrust; C.SetHomeDir(oldHome) })
	fixtures := signedFixtures(t)
	for name, serial := range map[string]int{"bundle1": 1, "bundle2": 2} {
		fixtures[name] = resign(t, fixtures[name], serial, runtimeValid)
	}
	return params, fixtures
}

// runtimeValid completes the shared mapping fixture into a document mihomo
// loads, so the Core's runtime validation runs unmodified in these tests.
func runtimeValid(document string) string {
	document = strings.Replace(document, "type: http\n", "type: http\n        behavior: domain\n", 1)
	return strings.Replace(document, "uuid: CONNECTION_CREDENTIAL", "uuid: 9d5e3f86-0f0a-4b8e-9d2a-2f6c8a0e4b11", 1)
}

func applySigned(t *testing.T, envelope string) (*SignedSubscriptionState, error) {
	t.Helper()
	probe, err := handleGetSignedSubscription(nil)
	if err != nil {
		return nil, err
	}
	intent := probe.Intent
	return handleApplySignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Envelope: envelope, Intent: intent})
}

func methodCode(err error) string {
	var methodErr *MethodError
	if errors.As(err, &methodErr) {
		return methodErr.Code
	}
	return ""
}

func signedIntentForTest(t *testing.T) *uint64 {
	t.Helper()
	probe, err := handleGetSignedSubscription(nil)
	if err != nil || probe.Intent == nil {
		t.Fatal("missing signed intent", err)
	}
	return probe.Intent
}

func TestSignedSubscriptionStaysInactiveWithEmptyTrust(t *testing.T) {
	params, body := bundleOwnerFixture(t)
	state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if err != nil || state.Available {
		t.Fatal("empty test trust enabled signed subscriptions", err)
	}
	if probe, _ := handleGetSignedSubscription(&SignedSubscriptionParams{}); probe.Available {
		t.Fatal("capability probe reported signed subscriptions with an empty pin")
	}
	if _, err := applySigned(t, signedFixtures(t)["bundle1"]); methodCode(err) != "signed_subscription_unavailable" {
		t.Fatal("test-signed package accepted with empty trust", err)
	}
	applies := 0
	clientBundleApply = func(*clientbundle.Prepared, *SetupParams) (bool, error) { applies++; return true, nil }
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	routingLeaseNow = func() time.Time { return time.Unix(1001, 0) }
	if ok, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: body}); !ok || err != nil || applies != 1 {
		t.Fatal("legacy v1 installation changed without signed negotiation", err)
	}
}

func TestSignedOwnerInstallsFromDurableStoreAcrossOwnerRecreation(t *testing.T) {
	params, fixtures := signedHome(t)
	var installed []*clientbundle.Prepared
	clientBundleApply = func(prepared *clientbundle.Prepared, _ *SetupParams) (bool, error) {
		installed = append(installed, prepared)
		return true, nil
	}
	if probe, _ := handleGetSignedSubscription(nil); !probe.Available {
		t.Fatal("capability probe missed a pinned trust root")
	}
	if state, err := applySigned(t, fixtures["state2"]); err != nil || state.Installed || !state.NeedsRefresh {
		t.Fatal("signed state installed credentials or hid the missing bundle", state, err)
	}
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	if result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 1, DeviceID: signedTestDevice}); err != nil || result.Installed || result.Code != "signed_subscription_required" {
		t.Fatal("state package became installable", result, err)
	}
	if state, err := applySigned(t, fixtures["bundle1"]); err != nil || !state.Installed || state.Serial != 1 {
		t.Fatal(state, err)
	}
	result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 2, DeviceID: signedTestDevice})
	if err != nil || !result.Installed || result.ExpiresAt != 1500_000 || *result.SubscriptionExpiresAt != 100000 {
		t.Fatal("signed install", result, err)
	}
	if installed[0].Bundle.Expires-installed[0].Bundle.Issued > 300 {
		t.Fatal("qualification lease outlived 300 seconds")
	}
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: owner})
	params.Generation++
	params.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	recreated, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	if result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: recreated, Sequence: 1, DeviceID: signedTestDevice}); err != nil || !result.Installed || result.Serial != 1 {
		t.Fatal("recreated owner lost the durable signed package", result, err)
	}
	if _, err := handleApplySignedSubscription(&SignedSubscriptionParams{
		AccountID: "account-1", DeviceID: signedTestDevice, Owner: owner, Envelope: fixtures["bundle2"],
	}); methodCode(err) != "signed_subscription_stale_owner" {
		t.Fatal("superseded owner could write durable subscription state", err)
	}
	if state, err := handleGetSignedSubscription(&SignedSubscriptionParams{
		AccountID: "account-1", DeviceID: signedTestDevice,
	}); err != nil || state.Serial != 1 {
		t.Fatal("stale owner changed the stored serial", state, err)
	}
	if len(installed) != 2 {
		t.Fatal("runtime did not receive both installations", len(installed))
	}
	for _, prepared := range installed {
		if !strings.Contains(string(prepared.Document), "9d5e3f86-0f0a-4b8e-9d2a-2f6c8a0e4b11") ||
			!strings.Contains(string(prepared.Document), "AUTHORIZED_PASSWORD") {
			t.Fatal("runtime projection lost signed node credentials")
		}
	}
	summary, err := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Summary: true})
	if err != nil || summary.Body != "" || summary.ExpiresAt != 1500 || summary.IssuedAt != 1200 || !summary.State.Installed {
		t.Fatal("summary projection carried credentials or lost the lease", summary, err)
	}
	full, _ := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if !strings.Contains(full.Body, "\"connection\"") {
		t.Fatal("full projection lost the bundle body")
	}
}

func TestSignedSetupAndOfflineExpiryLeaveUnrelatedYAMLIntact(t *testing.T) {
	_, fixtures := signedHome(t)
	path := filepath.Join(C.Path.HomeDir(), "config.yaml")
	const unrelated = "third-party fixture"
	if err := os.WriteFile(path, []byte(unrelated), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := applySigned(t, fixtures["bundle1"]); err != nil {
		t.Fatal(err)
	}
	body := &SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice}
	projected, err := handleProjectSignedSubscription(body)
	if err != nil {
		t.Fatal(err)
	}
	prepared, code := clientbundle.Prepare([]byte(projected.Body), body.AccountID, "", routingLeaseNow())
	if code != "" {
		t.Fatal(code)
	}
	setup := &SetupParams{RoutingLease: &RoutingLeaseSpec{
		AccountID: body.AccountID, SignedDeviceID: body.DeviceID, SignedSerial: 1,
		SignedIntent:     signedIntentForTest(t),
		ConnectionDigest: prepared.Bundle.Connection.SHA,
	}}
	if err := withSignedSetupLocked(setup, func(fromStore *clientbundle.Prepared) error {
		if fromStore == nil || !bytes.Equal(fromStore.Document, prepared.Document) {
			t.Fatal("signed setup attempted to load the shared YAML")
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	clientBundleSetup = setup
	reject := adapter.NewProxy(outbound.NewReject())
	node := adapter.NewProxy(outbound.NewRejectWithOption(outbound.RejectOption{Name: "fixture-node"}))
	oldConfig, oldProxies, oldProviders := currentConfig, tunnel.Proxies(), tunnel.Providers()
	proxies := map[string]C.Proxy{rejectProxyName: reject, "fixture-node": node}
	currentConfig = &config.Config{Proxies: proxies}
	tunnel.UpdateProxies(proxies, nil)
	t.Cleanup(func() {
		currentConfig = oldConfig
		tunnel.UpdateProxies(oldProxies, oldProviders)
	})
	retireSignedAccountLocked(body.AccountID, strings.Repeat("f", 32))
	if tunnel.Proxies()["fixture-node"] != node {
		t.Fatal("different installation fenced the live runtime")
	}
	routingLeaseNow = func() time.Time { return time.Unix(100001, 0) }
	checkSignedRuntimeLocked(setup)
	if tunnel.Proxies()["fixture-node"] != reject {
		t.Fatal("offline expiry left the node routable")
	}
	if _, err := handleProjectSignedSubscription(body); methodCode(err) != "subscription_expired" {
		t.Fatal("expired credentials remained projectable", err)
	}
	if contents, err := os.ReadFile(path); err != nil || string(contents) != unrelated {
		t.Fatal("signed setup or expiry changed third-party YAML", err)
	}
}

func TestSignedColdSetupUsesLatestDurableMaterialInsteadOfOldConfiguration(t *testing.T) {
	_, fixtures := signedHome(t)
	oldConfig := currentConfig
	currentConfig = nil
	t.Cleanup(func() { currentConfig = oldConfig })
	if _, err := applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	applied := false
	clientBundleApply = func(prepared *clientbundle.Prepared, params *SetupParams) (bool, error) {
		if params.RoutingLease.SignedSerial != 2 || params.RoutingLease.SignedDeviceID != signedTestDevice ||
			!strings.Contains(string(prepared.Document), "9d5e3f86-0f0a-4b8e-9d2a-2f6c8a0e4b11") {
			t.Fatal("cold setup did not use the latest signed credentials")
		}
		applied = true
		return true, nil
	}
	params := &SetupParams{RoutingLease: &RoutingLeaseSpec{
		AccountID: "account-1", SignedDeviceID: signedTestDevice, SignedSerial: 1,
		SignedIntent: signedIntentForTest(t),
	}}
	if err := withSignedSetupLocked(params, func(*clientbundle.Prepared) error {
		t.Fatal("cold setup tried to load stale compiled YAML")
		return nil
	}); err != nil || !applied {
		t.Fatal("cold setup could not recover the signed store", err)
	}
}

func TestSignedFloorRefusesUnsignedLegacyInstallation(t *testing.T) {
	params, fixtures := signedHome(t)
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/client-bundle-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	clientBundleApply = func(*clientbundle.Prepared, *SetupParams) (bool, error) { return true, nil }
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := applySigned(t, fixtures["bundle1"]); err != nil {
		t.Fatal(err)
	}
	routingLeaseNow = func() time.Time { return time.Unix(1001, 0) }
	if ok, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: string(body)}); ok || methodCode(err) != "signed_subscription_required" {
		t.Fatal("unsigned body downgraded a signed installation", ok, err)
	}
}

func TestSignedReplacementRevocationAndNoResurrection(t *testing.T) {
	params, fixtures := signedHome(t)
	clientBundleApply = func(*clientbundle.Prepared, *SetupParams) (bool, error) { return true, nil }
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"bundle1", "bundle2"} {
		if _, err := applySigned(t, fixtures[name]); err != nil {
			t.Fatal(name, err)
		}
	}
	if _, err := applySigned(t, fixtures["bundle1"]); methodCode(err) != "subscription_replay" {
		t.Fatal("lower serial replaced a newer package", err)
	}
	result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 1, DeviceID: signedTestDevice})
	if err != nil || result.Serial != 2 {
		t.Fatal("higher serial not installed", result, err)
	}
	clientBundleSetup.RoutingLease.SignedDeviceID = signedTestDevice
	oldConfig, oldProxies, oldProviders := currentConfig, tunnel.Proxies(), tunnel.Providers()
	t.Cleanup(func() {
		currentConfig = oldConfig
		tunnel.UpdateProxies(oldProxies, oldProviders)
	})
	reject := adapter.NewProxy(outbound.NewReject())
	node := adapter.NewProxy(outbound.NewRejectWithOption(outbound.RejectOption{Name: "fixture-node"}))
	proxies := map[string]C.Proxy{rejectProxyName: reject, "fixture-node": node}
	currentConfig = &config.Config{Proxies: proxies}
	tunnel.UpdateProxies(proxies, nil)
	state, err := applySigned(t, fixtures["revoked3"])
	if err != nil || !state.Revoked || state.Installed {
		t.Fatal("signed revocation not applied", state, err)
	}
	cachedSetup := &SetupParams{RoutingLease: &RoutingLeaseSpec{
		AccountID: "account-1", SignedDeviceID: signedTestDevice, SignedSerial: 2,
		SignedIntent: signedIntentForTest(t),
	}}
	if err := withSignedSetupLocked(cachedSetup, func(*clientbundle.Prepared) error {
		t.Fatal("revoked compiled configuration entered the setup path")
		return nil
	}); methodCode(err) != "subscription_tombstone" {
		t.Fatal("revoked compiled configuration was not fenced", err)
	}
	if tunnel.Proxies()["fixture-node"] != reject {
		t.Fatal("revocation left a manually addressable node in the runtime")
	}
	if matchesClientBundleOwnerLocked(owner) {
		t.Fatal("revocation left the runtime owner active")
	}
	for _, name := range []string{"bundle1", "bundle2"} {
		if _, err := applySigned(t, fixtures[name]); err == nil {
			t.Fatal("revoked package resurrected:", name)
		}
	}
	params.Generation++
	params.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	next, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	if result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: next, Sequence: 1, DeviceID: signedTestDevice}); err != nil || result.Code != "subscription_tombstone" {
		t.Fatal("revoked package installed after owner restart", result, err)
	}
	if _, err := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Summary: true}); methodCode(err) != "subscription_tombstone" {
		t.Fatal("revoked package projected", err)
	}
}

// resign rewrites a fixture payload and signs it with the public RFC 8032 seed.
func resign(t *testing.T, envelope string, serial int, edit func(string) string) string {
	t.Helper()
	var outer map[string]any
	if err := json.Unmarshal([]byte(envelope), &outer); err != nil {
		t.Fatal(err)
	}
	signed := outer["signed"].(map[string]any)
	payload, _ := base64.RawURLEncoding.DecodeString(signed["payload"].(string))
	var fields struct {
		Connection struct {
			Document string `json:"document"`
			SHA      string `json:"sha256"`
		} `json:"connection"`
		BundleID string `json:"bundle_id"`
		Serial   int    `json:"serial"`
	}
	if err := json.Unmarshal(payload, &fields); err != nil {
		t.Fatal(err)
	}
	document := edit(fields.Connection.Document)
	documentHash := sha256.Sum256([]byte(document))
	encodedDocument, _ := json.Marshal(document)
	encodedOld, _ := json.Marshal(fields.Connection.Document)
	text := strings.Replace(string(payload), string(encodedOld), string(encodedDocument), 1)
	text = strings.Replace(text, fields.Connection.SHA, hex.EncodeToString(documentHash[:]), 1)
	text = strings.Replace(text, ",\"serial\":"+strconv.Itoa(fields.Serial)+",", ",\"serial\":"+strconv.Itoa(serial)+",", 1)
	suffix := ",\"bundle_id\":\"" + fields.BundleID + "\"}"
	preimage := strings.TrimSuffix(text, suffix) + "}"
	sum := sha256.Sum256([]byte(preimage))
	id := hex.EncodeToString(sum[:])
	next := []byte(strings.TrimSuffix(preimage, "}") + ",\"bundle_id\":\"" + id + "\"}")
	signature := ed25519.Sign(signedTestKey(), append([]byte(clientbundle.SignedPrefix), next...))
	outer["serial"], outer["bundle_id"] = serial, id
	outer["signed"] = map[string]string{"kid": "rfc8032-test", "payload": base64.RawURLEncoding.EncodeToString(next),
		"signature": base64.RawURLEncoding.EncodeToString(signature)}
	encoded, _ := json.Marshal(outer)
	if !bytes.Contains(next, []byte(id)) {
		t.Fatal("resign failed")
	}
	return string(encoded)
}

func TestSignedRuntimeValidationRetainsWorkingPackage(t *testing.T) {
	_, fixtures := signedHome(t)
	if _, err := applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	broken := resign(t, fixtures["bundle2"], 5, func(document string) string {
		return strings.Replace(document, "port: 443", "port: not-a-port", 1)
	})
	if _, err := applySigned(t, broken); methodCode(err) != "invalid_renewed_configuration" {
		t.Fatal("runtime-invalid configuration committed", err)
	}
	state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if err != nil || state.Serial != 2 {
		t.Fatal("failed apply lost the working package", state, err)
	}
	valid := resign(t, fixtures["bundle2"], 5, func(document string) string { return document })
	if state, err := applySigned(t, valid); err != nil || state.Serial != 5 {
		t.Fatal("resigned valid package rejected; validation is not specific", state, err)
	}
}

func TestSignedSignOutKeepsFloor(t *testing.T) {
	_, fixtures := signedHome(t)
	if _, err := applySigned(t, fixtures["bundle1"]); err != nil {
		t.Fatal(err)
	}
	probe, err := handleGetSignedSubscription(nil)
	if err != nil {
		t.Fatal(err)
	}
	if ok, err := handleSignOutSignedSubscription(&SignedSignOutParams{Intent: probe.Intent}); !ok || err != nil {
		t.Fatal(err)
	}
	state, _ := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if state.Installed || !state.HasFloor {
		t.Fatal("sign-out kept credentials or dropped the floor", state)
	}
	if signedFloorRefusesUnsigned("account-1") != true {
		t.Fatal("sign-out reopened the unsigned downgrade path")
	}
}

func TestSignedAccountFloorWithoutEnrollmentAfterClockRollback(t *testing.T) {
	_, fixtures := signedHome(t)
	if _, err := applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	probe, err := handleGetSignedSubscription(nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = handleSignOutSignedSubscription(&SignedSignOutParams{Intent: probe.Intent}); err != nil {
		t.Fatal(err)
	}
	routingLeaseNow = func() time.Time { return time.Unix(900, 0) }
	state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1"})
	if err != nil || !state.Available || !state.HasFloor {
		t.Fatal("account floor unavailable without enrollment", state, err)
	}
	if _, err := applySigned(t, fixtures["bundle1"]); methodCode(err) != "subscription_replay" {
		t.Fatal("clock rollback allowed replay", err)
	}
}

func TestSignedFloorSurvivesVaultLossAndCoreRecovery(t *testing.T) {
	params, fixtures := signedHome(t)
	if _, err := applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(filepath.Join(signedSubscriptionDir(), "subscription-v2-floor.json"))
	if err != nil {
		t.Fatal(err)
	}
	packageBefore, err := os.ReadFile(filepath.Join(signedSubscriptionDir(), "subscription-v2-package.json"))
	if err != nil {
		t.Fatal(err)
	}
	legacy := &SetupParams{RoutingLease: &RoutingLeaseSpec{AccountID: "account-1"}}
	trust := signedSubscriptionTrust
	signedSubscriptionTrust = func() (*clientbundle.Trust, error) { return nil, errors.New("temporary unavailable") }
	called := false
	err = withSignedSetupLocked(legacy, func(*clientbundle.Prepared) error { called = true; return nil })
	if err == nil || called {
		t.Fatal("unavailable signed store allowed unsigned setup", err)
	}
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/client-bundle-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	routingLeaseNow = func() time.Time { return time.Unix(1001, 0) }
	if ok, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: string(body)}); ok || methodCode(err) != "signed_subscription_required" {
		t.Fatal("unavailable signed store allowed legacy install", ok, err)
	}
	signedSubscriptionTrust = trust
	if err := withSignedSetupLocked(legacy, func(*clientbundle.Prepared) error { t.Fatal("old account bypassed floor"); return nil }); methodCode(err) != "signed_subscription_required" {
		t.Fatal("restored Core allowed unsigned old account", err)
	}
	if ok, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: string(body)}); ok || methodCode(err) != "signed_subscription_required" {
		t.Fatal("legacy install bypassed floor", ok, err)
	}
	other := &SetupParams{RoutingLease: &RoutingLeaseSpec{AccountID: "account-2"}}
	if err := withSignedSetupLocked(other, func(*clientbundle.Prepared) error { return nil }); err != nil {
		t.Fatal("new account legacy path blocked", err)
	}
	after, err := os.ReadFile(filepath.Join(signedSubscriptionDir(), "subscription-v2-floor.json"))
	if err != nil || !bytes.Equal(before, after) {
		t.Fatal("legacy path changed prior floor", err)
	}
	packageAfter, err := os.ReadFile(filepath.Join(signedSubscriptionDir(), "subscription-v2-package.json"))
	if err != nil || !bytes.Equal(packageBefore, packageAfter) {
		t.Fatal("legacy path changed signed package", err)
	}
	if state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice}); err != nil || !state.Installed || state.Serial != 2 {
		t.Fatal("legacy path removed signed package", state, err)
	}
}

func TestLegacyFallbackKeepsStoreLockThroughCommit(t *testing.T) {
	_, _ = signedHome(t)
	entered, release := make(chan struct{}), make(chan struct{})
	fallbackDone := make(chan error, 1)
	go func() {
		fallbackDone <- clientbundle.WithNoSignedState(signedSubscriptionDir(), func() error {
			close(entered)
			<-release
			return nil
		})
	}()
	<-entered
	trust, err := signedSubscriptionTrust()
	if err != nil {
		close(release)
		t.Fatal(err)
	}
	storeDone := make(chan error, 1)
	go func() {
		store, err := clientbundle.OpenSubscriptionStore(signedSubscriptionDir(), trust, clientbundle.StoreOptions{})
		if store != nil {
			store.Close()
		}
		storeDone <- err
	}()
	select {
	case err := <-storeDone:
		close(release)
		t.Fatal("signed store opened during legacy commit", err)
	case <-time.After(50 * time.Millisecond):
	}
	close(release)
	if err := <-fallbackDone; err != nil {
		t.Fatal(err)
	}
	if err := <-storeDone; err != nil {
		t.Fatal("signed store did not reopen", err)
	}
}

func TestDelayedForegroundApplyAfterSignOut(t *testing.T) {
	_, fixtures := signedHome(t)
	probe, err := handleGetSignedSubscription(nil)
	if err != nil {
		t.Fatal(err)
	}
	configMu.Lock()
	started := make(chan struct{})
	done := make(chan error, 1)
	go func() {
		close(started)
		_, err := handleApplySignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Envelope: fixtures["bundle1"], Intent: probe.Intent})
		done <- err
	}()
	<-started
	if _, err := handleSignOutSignedSubscription(&SignedSignOutParams{Intent: probe.Intent}); err != nil {
		configMu.Unlock()
		t.Fatal(err)
	}
	configMu.Unlock()
	if err := <-done; methodCode(err) != "signed_subscription_stale_owner" {
		t.Fatal("late apply was not rejected", err)
	}
	state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if err != nil || state.Installed {
		t.Fatal("late apply restored signed credentials after logout", state, err)
	}
}

func TestSignedSessionSwitchFencesForegroundAndNativeAndAllowsNewLogin(t *testing.T) {
	params, fixtures := signedHome(t)
	probe, err := handleGetSignedSubscription(nil)
	if err != nil {
		t.Fatal(err)
	}
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	configMu.Lock()
	started := make(chan struct{}, 2)
	results := make(chan error, 2)
	go func() {
		started <- struct{}{}
		_, err := handleApplySignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Envelope: fixtures["bundle1"], Intent: probe.Intent})
		results <- err
	}()
	go func() {
		started <- struct{}{}
		_, err := handleApplySignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice, Envelope: fixtures["bundle1"], Owner: owner})
		results <- err
	}()
	<-started
	<-started
	if _, err := handleInvalidateSignedSubscription(&SignedSignOutParams{Intent: probe.Intent}); err != nil {
		configMu.Unlock()
		t.Fatal(err)
	}
	configMu.Unlock()
	for range 2 {
		if err := <-results; methodCode(err) != "signed_subscription_stale_owner" {
			t.Fatal("old session committed", err)
		}
	}
	staleSetup := &SetupParams{RoutingLease: &RoutingLeaseSpec{AccountID: "account-1", SignedDeviceID: signedTestDevice, SignedSerial: 1, SignedIntent: probe.Intent}}
	if err := withSignedSetupLocked(staleSetup, func(*clientbundle.Prepared) error { t.Fatal("stale setup reached runtime"); return nil }); methodCode(err) != "signed_subscription_stale_owner" {
		t.Fatal("old signed setup was not fenced", err)
	}
	state, err := handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if err != nil || state.Installed {
		t.Fatal("old session restored credentials", state, err)
	}
	next, err := handleGetSignedSubscription(nil)
	if err != nil {
		t.Fatal(err)
	}
	newAccount := resignAccount(t, fixtures["bundle1"], "account-2")
	if state, err := handleApplySignedSubscription(&SignedSubscriptionParams{AccountID: "account-2", DeviceID: signedTestDevice, Envelope: newAccount, Intent: next.Intent}); err != nil || !state.Installed {
		t.Fatal("new session could not enroll", state, err)
	}
	if _, err := handleSignOutSignedSubscription(&SignedSignOutParams{Intent: probe.Intent}); methodCode(err) != "signed_subscription_stale_owner" {
		t.Fatal("old logout removed new session", err)
	}
	state, err = handleGetSignedSubscription(&SignedSubscriptionParams{AccountID: "account-2", DeviceID: signedTestDevice})
	if err != nil || !state.Installed || !state.HasFloor {
		t.Fatal("new login was not retained", state, err)
	}
}

func resignAccount(t *testing.T, envelope, account string) string {
	t.Helper()
	var outer map[string]any
	if err := json.Unmarshal([]byte(envelope), &outer); err != nil {
		t.Fatal(err)
	}
	signed := outer["signed"].(map[string]any)
	payload, err := base64.RawURLEncoding.DecodeString(signed["payload"].(string))
	if err != nil {
		t.Fatal(err)
	}
	oldID := outer["bundle_id"].(string)
	text := strings.Replace(string(payload), `"account_id":"account-1"`, `"account_id":"`+account+`"`, 1)
	if text == string(payload) {
		t.Fatal("account was not replaced")
	}
	preimage := strings.TrimSuffix(text, `,"bundle_id":"`+oldID+`"}`) + "}"
	sum := sha256.Sum256([]byte(preimage))
	id := hex.EncodeToString(sum[:])
	next := []byte(strings.TrimSuffix(preimage, "}") + `,"bundle_id":"` + id + `"}`)
	signature := ed25519.Sign(signedTestKey(), append([]byte(clientbundle.SignedPrefix), next...))
	outer["account_id"], outer["bundle_id"] = account, id
	outer["signed"] = map[string]string{"kid": "rfc8032-test", "payload": base64.RawURLEncoding.EncodeToString(next), "signature": base64.RawURLEncoding.EncodeToString(signature)}
	encoded, err := json.Marshal(outer)
	if err != nil {
		t.Fatal(err)
	}
	return string(encoded)
}

package core

import (
	"core/clientbundle"
	"encoding/json"
	"errors"
	C "github.com/metacubex/mihomo/constant"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestIOSSerializedHandoffQuickSetup(t *testing.T) {
	_, fixtures := signedHome(t)
	if _, err := applySigned(t, fixtures["bundle1"]); err != nil {
		t.Fatal(err)
	}
	projection, err := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
	if err != nil {
		t.Fatal(err)
	}
	prepared, code := clientbundle.Prepare([]byte(projection.Body), "account-1", "{}", routingLeaseNow())
	if code != "" {
		t.Fatal(code)
	}
	wire, err := os.ReadFile(os.Getenv("ZN_HANDOFF_WIRE"))
	if err != nil {
		t.Fatal(err)
	}
	var shared map[string]any
	if err = json.Unmarshal(wire, &shared); err != nil {
		t.Fatal(err)
	}
	setup := shared["setupParams"].(map[string]any)
	setup["routing-lease"] = routingLeaseForPrepared(prepared, &RoutingLeaseSpec{
		AccountID: "account-1", AccountGeneration: 1, SignedDeviceID: signedTestDevice, SignedSerial: 1,
		SignedIntent: signedIntentForTest(t), ConfigurationDigest: "compiled-wire", RenewalOverlay: "{}",
	})
	directory := t.TempDir()
	input, output := filepath.Join(directory, "shared.json"), filepath.Join(directory, "runtime.json")
	wire, _ = json.Marshal(shared)
	if err = os.WriteFile(input, wire, 0600); err != nil {
		t.Fatal(err)
	}
	command := exec.Command(os.Getenv("ZN_HANDOFF_NATIVE_BINARY"), input, output)
	if result, err := command.CombinedOutput(); err != nil {
		t.Fatalf("native handoff: %v\n%s", err, result)
	} else {
		t.Log(string(result))
	}
	runtimeWire, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	oldSetup, oldApply := setupConfig, clientBundleApply
	defer func() { setupConfig, clientBundleApply = oldSetup, oldApply }()
	validated := 0
	validate := func(fromStore *clientbundle.Prepared, params *SetupParams) error {
		if fromStore == nil {
			return errors.New("signed handoff reached legacy YAML")
		}
		raw, err := unmarshalRawConfig(fromStore.Document)
		if err != nil {
			return err
		}
		cfg, err := parsePlatformConfig(raw)
		if err != nil {
			return err
		}
		owned, err := ownedDNSForConfig(cfg, params.OwnedDNS)
		if err != nil {
			return err
		}
		if owned == nil || !owned.config.Strict || owned.config.Authorization != "Bearer synthetic-fixture" {
			return errors.New("strict authorized runtime lost")
		}
		if params.RoutingLease.SignedDeviceID != signedTestDevice {
			return errors.New("device changed")
		}
		if params.RoutingLease.SignedSerial != int64(validated+1) {
			return errors.New("effective signed serial was not renewed")
		}
		validated++
		return nil
	}
	// Replace only listener/provider activation; keep QuickSetup decoding, durable
	// signed projection, platform parsing and strict DNS validation on production code.
	setupConfig = func(params *SetupParams) error {
		return withSignedSetupLocked(params, func(p *clientbundle.Prepared) error { return validate(p, params) })
	}
	clientBundleApply = func(p *clientbundle.Prepared, params *SetupParams) (bool, error) {
		err := validate(p, params)
		return err == nil, err
	}
	initWire, _ := json.Marshal(InitParams{HomeDir: C.Path.HomeDir()})
	run := func(wire []byte) string {
		done := make(chan string, 1)
		QuickSetup(string(initWire), string(wire), func(result string) { done <- result })
		select {
		case result := <-done:
			return result
		case <-time.After(10 * time.Second):
			t.Fatal("QuickSetup timed out")
			return "timeout"
		}
	}
	if result := run(runtimeWire); result != "" || validated != 1 {
		t.Fatalf("positive QuickSetup: %q validations=%d", result, validated)
	}
	if _, err = os.Stat(filepath.Join(C.Path.HomeDir(), "config.yaml")); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("legacy YAML unexpectedly created")
	}
	if _, err = applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	if result := run(runtimeWire); result != "" || validated != 2 {
		t.Fatalf("same-device serial renewal: %q validations=%d", result, validated)
	}
	t.Log("PASS production QuickSetup consumes fresh strict authorized signed runtime without config.yaml; newer durable serial accepted")
}

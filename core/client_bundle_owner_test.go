package core

import (
	"core/clientbundle"
	"os"
	"testing"
	"time"
)

func bundleOwnerFixture(t *testing.T) (*BeginClientBundleOwnerParams, string) {
	t.Helper()
	oldSetup, oldOwner, oldApply := clientBundleSetup, clientBundleOwner, clientBundleApply
	oldSerial, oldEpoch, oldFloor, oldGeneration, oldAttempt :=
		clientBundleSerial, clientBundleEpochFloor, clientBundleOwnerFloor, clientBundleGenFloor, clientBundleAttempt
	oldInit, oldNow := isInit.Load(), routingLeaseNow
	oldRetired := clientBundleRetiredEpoch
	clientBundleRetiredEpoch = 0
	isInit.Store(true)
	routingLeaseNow = func() time.Time { return time.Unix(1001, 0) }
	clientBundleSetup = &SetupParams{RoutingLease: &RoutingLeaseSpec{
		AccountID: "account-1", AccountGeneration: 7, RenewalOverlay: "{\"rules\":[]}"}}
	clientBundleOwner = nil
	clientBundleSerial, clientBundleEpochFloor, clientBundleOwnerFloor, clientBundleGenFloor, clientBundleAttempt = 0, 0, 0, 0, 0
	t.Cleanup(func() {
		configMu.Lock()
		defer configMu.Unlock()
		stopClientBundleRoutingLocked()
		clientBundleSetup, clientBundleOwner, clientBundleApply = oldSetup, oldOwner, oldApply
		clientBundleSerial, clientBundleEpochFloor, clientBundleOwnerFloor, clientBundleGenFloor, clientBundleAttempt =
			oldSerial, oldEpoch, oldFloor, oldGeneration, oldAttempt
		isInit.Store(oldInit)
		routingLeaseNow = oldNow
		clientBundleRetiredEpoch = oldRetired
	})
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/client-bundle-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	context := handleGetClientBundleOwner()
	if context == nil {
		t.Fatal("missing configured owner context")
	}
	return &BeginClientBundleOwnerParams{ClientBundleOwnerContext: *context,
		SessionEpoch: 10, OwnerID: 20, Generation: 1}, string(body)
}

func TestClientBundleOwnerConsumesProducerFixtureAndRejectsOldEpoch(t *testing.T) {
	params, _ := bundleOwnerFixture(t)
	clientBundleSetup.RoutingLease.AccountID = "4242"
	params.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/qualified-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	applied := false
	clientBundleApply = func(prepared *clientbundle.Prepared, _ *SetupParams) (bool, error) {
		if prepared.Bundle.Expires-prepared.Bundle.Issued != 150 || len(prepared.Bundle.Outbounds) != 20 {
			t.Fatal("producer identity, mapping or shortened TTL changed")
		}
		for _, service := range prepared.Services {
			if service.GroupName == "zn.service.ai" && len(service.AllowedProxies) != 6 {
				t.Fatal("qualified producer AI candidates were lost")
			}
		}
		applied = true
		return true, nil
	}
	old, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	params.SessionEpoch++
	params.ClientBundleOwnerContext = *handleGetClientBundleOwner()
	current, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = handleInstallClientBundle(&InstallClientBundleParams{Owner: old, Sequence: 1, Body: string(body)}); err == nil {
		t.Fatal("producer data bypassed an old account epoch")
	}
	if ok, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: current, Sequence: 1, Body: string(body)}); !ok || err != nil || !applied {
		t.Fatalf("producer installation=%v err=%v", ok, err)
	}
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: old, InvalidateSession: true})
	if !matchesClientBundleOwnerLocked(current) {
		t.Fatal("old logout revoked the new epoch")
	}
}

func TestClientBundleOwnerReplayAndRetirement(t *testing.T) {
	params, body := bundleOwnerFixture(t)
	applies := 0
	clientBundleApply = func(*clientbundle.Prepared, *SetupParams) (bool, error) { applies++; return true, nil }
	first, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	request := &InstallClientBundleParams{Owner: first, Sequence: 1, Body: body}
	if ok, err := handleInstallClientBundle(request); !ok || err != nil || applies != 1 {
		t.Fatalf("installation=%t err=%v applies=%d", ok, err, applies)
	}
	if _, err := handleInstallClientBundle(request); err == nil {
		t.Fatal("replayed installation accepted")
	}
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: first})
	params.Generation++
	second, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: first})
	if !matchesClientBundleOwnerLocked(second) {
		t.Fatal("old logout revoked the new owner")
	}
	if _, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: first, Sequence: 2, Body: body}); err == nil {
		t.Fatal("retired owner reinstalled a bundle")
	}
	old := *params
	old.Generation--
	if _, err := handleBeginClientBundleOwner(&old); err == nil {
		t.Fatal("retired generation reclaimed ownership")
	}
	old = *params
	old.OwnerID--
	if _, err := handleBeginClientBundleOwner(&old); err == nil {
		t.Fatal("old owner reclaimed ownership")
	}
	old = *params
	old.SessionEpoch--
	if _, err := handleBeginClientBundleOwner(&old); err == nil {
		t.Fatal("old account epoch reclaimed ownership")
	}
}

func TestClientBundleOwnerFenceWaitsForNativeInstallation(t *testing.T) {
	params, body := bundleOwnerFixture(t)
	entered, release, completed := make(chan struct{}), make(chan struct{}), make(chan struct{})
	clientBundleApply = func(*clientbundle.Prepared, *SetupParams) (bool, error) {
		close(entered)
		<-release
		close(completed)
		return true, nil
	}
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	installed := make(chan error, 1)
	go func() {
		_, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 1, Body: body})
		installed <- err
	}()
	<-entered
	fenced := make(chan bool, 1)
	go func() { fenced <- handleEndClientBundleOwner(&EndClientBundleOwnerParams{Owner: owner}) }()
	select {
	case <-fenced:
		close(release)
		t.Fatal("fence acknowledged before the running installation drained")
	case <-time.After(20 * time.Millisecond):
	}
	close(release)
	if err := <-installed; err != nil {
		t.Fatal(err)
	}
	if !<-fenced {
		t.Fatal("fence failed")
	}
	select {
	case <-completed:
	default:
		t.Fatal("fence did not drain installation")
	}
	if _, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: owner, Sequence: 2, Body: body}); err == nil {
		t.Fatal("late result resurrected the retired owner")
	}
}

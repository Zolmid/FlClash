package core

import (
	"core/clientbundle"
	"encoding/json"
	"testing"
	"time"
)

func signedProjectionFixture(t *testing.T) (*BeginClientBundleOwnerParams, map[string]string, func(*RoutingLeaseSpec)) {
	t.Helper()
	owner, fixtures := signedHome(t)
	oldCandidates, oldProjection := signedProjectionCandidates, installedSignedProjection
	oldLease, oldGeneration := activeRoutingLease, routingConfigurationGeneration
	signedProjectionCandidates, installedSignedProjection = map[string]*signedProjectionSnapshot{}, nil
	install := func(spec *RoutingLeaseSpec) {
		rememberClientBundleSetupLocked(&SetupParams{RoutingLease: spec})
		selectMu.Lock()
		defer selectMu.Unlock()
		routingConfigurationGeneration++
		activeRoutingLease = &routingLeaseState{instanceID: routingLeaseInstanceID, token: "projection-fixture",
			configurationGeneration: routingConfigurationGeneration, accountID: spec.AccountID,
			accountGeneration: spec.AccountGeneration, bundleID: spec.BundleID, configurationDigest: spec.ConfigurationDigest,
			expiresAt: spec.ExpiresAt, deadline: time.UnixMilli(spec.ExpiresAt), services: map[string]*routingLeaseService{},
			policyGroups: map[string]*routingLeaseService{}, manualGroups: map[string]*routingLeaseService{}}
	}
	clientBundleApply = func(prepared *clientbundle.Prepared, previous *SetupParams) (bool, error) {
		install(routingLeaseForPrepared(prepared, previous.RoutingLease))
		return true, nil
	}
	t.Cleanup(func() {
		selectMu.Lock()
		activeRoutingLease, routingConfigurationGeneration = oldLease, oldGeneration
		selectMu.Unlock()
		signedProjectionCandidates, installedSignedProjection = oldCandidates, oldProjection
	})
	if _, err := applySigned(t, fixtures["bundle1"]); err != nil {
		t.Fatal(err)
	}
	return owner, fixtures, install
}

func TestSignedCurrentProjectionUsesAppliedLeaseWithoutRenewing(t *testing.T) {
	params, fixtures, _ := signedProjectionFixture(t)
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	installed, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 1, DeviceID: signedTestDevice})
	if err != nil || !installed.Installed {
		t.Fatal(installed, err)
	}
	guard := handleGetRoutingLease()
	request := &SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice,
		Current: true, Intent: signedIntentForTest(t), Lease: guard}
	var before string
	for _, wall := range []int64{1201, 1210, 1240} {
		routingLeaseNow = func() time.Time { return time.Unix(wall, 0) }
		projection, err := handleProjectSignedSubscription(request)
		if err != nil || projection.Lease == nil || *projection.Lease != *guard || projection.ExpiresAt*1000 != installed.ExpiresAt {
			t.Fatal("read did not return the applied lease", err)
		}
		if before != "" && before != projection.Body {
			t.Fatal("read renewed the projection")
		}
		before = projection.Body
	}
	stale := *guard
	stale.Token = "stale-token"
	request.Lease = &stale
	if _, err := handleProjectSignedSubscription(request); methodCode(err) != "signed_projection_unavailable" {
		t.Fatal("stale lease read", err)
	}
	request.Lease = guard
	oldIntent := *request.Intent + 1
	request.Intent = &oldIntent
	if _, err := handleProjectSignedSubscription(request); methodCode(err) != "signed_projection_unavailable" {
		t.Fatal("stale session read", err)
	}
	request.Intent = signedIntentForTest(t)
	request.DeviceID = "fedcba9876543210fedcba9876543210"
	if _, err := handleProjectSignedSubscription(request); err == nil {
		t.Fatal("another installation read credentials")
	}
	request.DeviceID = signedTestDevice
	if _, err := applySigned(t, fixtures["bundle2"]); err != nil {
		t.Fatal(err)
	}
	if _, err := handleProjectSignedSubscription(request); methodCode(err) != "signed_projection_unavailable" {
		t.Fatal("unapplied signed generation was reported applied", err)
	}
	renewed, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 2, DeviceID: signedTestDevice})
	if err != nil || !renewed.Installed {
		t.Fatal(renewed, err)
	}
	request.Lease = handleGetRoutingLease()
	projection, err := handleProjectSignedSubscription(request)
	if err != nil || projection.State.Serial != 2 || projection.Lease.BundleID != renewed.BundleID {
		t.Fatal("renewed projection was not synchronized", err)
	}
	routingLeaseNow = func() time.Time { return time.Unix(100001, 0) }
	if _, err := handleProjectSignedSubscription(request); err == nil {
		t.Fatal("expired signed package remained readable")
	}
}

func TestSignedSetupProjectionSurvivesCoreProcessHandoff(t *testing.T) {
	for _, handoff := range []bool{false, true} {
		t.Run(map[bool]string{false: "same-core", true: "new-core"}[handoff], func(t *testing.T) {
			_, _, install := signedProjectionFixture(t)
			projection, err := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice})
			if err != nil {
				t.Fatal(err)
			}
			var envelope struct {
				Data struct {
					ID string `json:"bundle_id"`
				} `json:"data"`
			}
			if json.Unmarshal([]byte(projection.Body), &envelope) != nil {
				t.Fatal("projection shape")
			}
			prepared, code := clientbundle.Prepare([]byte(projection.Body), "account-1", "{}", routingLeaseNow())
			if code != "" {
				t.Fatal(code)
			}
			setup := &SetupParams{RoutingLease: &RoutingLeaseSpec{AccountID: "account-1", AccountGeneration: 7,
				SignedDeviceID: signedTestDevice, SignedSerial: 1, SignedIntent: signedIntentForTest(t),
				BundleID: envelope.Data.ID, ExpiresAt: projection.ExpiresAt * 1000,
				ConnectionDigest: prepared.Bundle.Connection.SHA, RenewalOverlay: "{}", ConfigurationDigest: "ui-configuration"}}
			if handoff {
				signedProjectionCandidates, installedSignedProjection = map[string]*signedProjectionSnapshot{}, nil
			}
			routingLeaseNow = func() time.Time { return time.Unix(1201, 0) }
			if err := withSignedSetupLocked(setup, func(p *clientbundle.Prepared) error { install(setup.RoutingLease); return nil }); err != nil {
				t.Fatal(err)
			}
			guard := handleGetRoutingLease()
			current, err := handleProjectSignedSubscription(&SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice,
				Current: true, Intent: setup.RoutingLease.SignedIntent, Lease: guard})
			if err != nil || current.Lease.BundleID != setup.RoutingLease.BundleID || current.Lease.ExpiresAt != current.ExpiresAt*1000 {
				t.Fatal("handoff returned another lease", err)
			}
			if handoff && current.Lease.BundleID == envelope.Data.ID {
				t.Fatal("fixture did not cross projection time")
			}
			if !handoff && current.Body != projection.Body {
				t.Fatal("same Core regenerated the Dart projection")
			}
		})
	}
}

func TestSignedCurrentProjectionIsErasedByVerifiedRevocation(t *testing.T) {
	params, fixtures, _ := signedProjectionFixture(t)
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 1, DeviceID: signedTestDevice})
	if err != nil || !result.Installed {
		t.Fatal(result, err)
	}
	request := &SignedSubscriptionParams{AccountID: "account-1", DeviceID: signedTestDevice,
		Current: true, Intent: signedIntentForTest(t), Lease: handleGetRoutingLease()}
	if _, err := handleProjectSignedSubscription(request); err != nil {
		t.Fatal(err)
	}
	if _, err := applySigned(t, fixtures["revoked3"]); err != nil {
		t.Fatal(err)
	}
	if _, err := handleProjectSignedSubscription(request); methodCode(err) != "subscription_tombstone" {
		t.Fatal("revoked read was accepted", err)
	}
	if installedSignedProjection != nil || len(signedProjectionCandidates) != 0 {
		t.Fatal("revoked projection retained credentials")
	}
}

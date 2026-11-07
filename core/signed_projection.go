package core

import (
	"bytes"
	"core/clientbundle"
	"encoding/json"
)

type signedProjectionSnapshot struct {
	body                        []byte
	account, device, digest, id string
	serial, issued, expires     int64
	intent                      uint64
}

var signedProjectionCandidates = map[string]*signedProjectionSnapshot{}
var installedSignedProjection *signedProjectionSnapshot

func rememberSignedProjectionLocked(body []byte, pkg *clientbundle.SignedPackage, intent uint64, installed bool) {
	var value struct {
		Data struct {
			ID      string `json:"bundle_id"`
			Issued  int64  `json:"issued_at"`
			Expires int64  `json:"expires_at"`
		} `json:"data"`
	}
	if pkg == nil || json.Unmarshal(body, &value) != nil || value.Data.ID == "" {
		return
	}
	for id, candidate := range signedProjectionCandidates {
		if candidate.expires <= routingLeaseNow().Unix() || candidate.intent != intent {
			delete(signedProjectionCandidates, id)
		}
	}
	if len(signedProjectionCandidates) >= 8 {
		var oldest *signedProjectionSnapshot
		for _, candidate := range signedProjectionCandidates {
			if oldest == nil || candidate.issued < oldest.issued {
				oldest = candidate
			}
		}
		delete(signedProjectionCandidates, oldest.id)
	}
	snapshot := &signedProjectionSnapshot{body: append([]byte(nil), body...), account: pkg.AccountID, device: pkg.DeviceID,
		digest: pkg.Digest, serial: pkg.Serial, intent: intent, id: value.Data.ID, issued: value.Data.Issued, expires: value.Data.Expires}
	signedProjectionCandidates[snapshot.id] = snapshot
	if installed {
		installedSignedProjection = snapshot
	}
}

func (s *signedProjectionSnapshot) matches(pkg *clientbundle.SignedPackage, intent uint64) bool {
	return s != nil && pkg != nil && s.intent == intent && s.account == pkg.AccountID && s.device == pkg.DeviceID &&
		s.serial == pkg.Serial && s.digest == pkg.Digest && s.expires > routingLeaseNow().Unix()
}

func signedProjectionForSetupLocked(lease *RoutingLeaseSpec, pkg *clientbundle.SignedPackage, intent uint64, fresh []byte) *signedProjectionSnapshot {
	for _, candidate := range []*signedProjectionSnapshot{signedProjectionCandidates[lease.BundleID], installedSignedProjection} {
		if candidate.matches(pkg, intent) && candidate.id == lease.BundleID && candidate.expires*1000 == lease.ExpiresAt && sameSignedRouting(candidate.body, fresh) {
			return candidate
		}
	}
	return nil
}

func sameSignedRouting(a, b []byte) bool {
	var left, right struct {
		Data map[string]json.RawMessage `json:"data"`
	}
	return json.Unmarshal(a, &left) == nil && json.Unmarshal(b, &right) == nil &&
		bytes.Equal(left.Data["routing"], right.Data["routing"])
}

func forgetSignedProjectionsLocked(account, device string, intent *uint64) {
	matches := func(s *signedProjectionSnapshot) bool {
		return s != nil && (account == "" || s.account == account) && (device == "" || s.device == device) && (intent == nil || s.intent == *intent)
	}
	for id, snapshot := range signedProjectionCandidates {
		if matches(snapshot) {
			clear(snapshot.body)
			delete(signedProjectionCandidates, id)
		}
	}
	if matches(installedSignedProjection) {
		clear(installedSignedProjection.body)
		installedSignedProjection = nil
	}
}

func currentSignedProjectionLocked(store *clientbundle.SubscriptionStore, params *SignedSubscriptionParams, intent uint64) (SignedSubscriptionProjection, error) {
	var zero SignedSubscriptionProjection
	status, err := store.Status(params.AccountID, params.DeviceID)
	if err != nil {
		return zero, err
	}
	if status.Revoked {
		return zero, clientbundle.ErrTombstone
	}
	if status.Expired {
		return zero, clientbundle.ErrExpired
	}
	snapshot := installedSignedProjection
	lease := handleGetRoutingLease()
	if params.Intent == nil || *params.Intent != intent || !snapshot.matches(status.Package, intent) || params.Lease == nil || lease == nil ||
		*params.Lease != *lease || lease.AccountID != params.AccountID || lease.BundleID != snapshot.id || lease.ExpiresAt != snapshot.expires*1000 ||
		clientBundleSetup == nil || clientBundleSetup.RoutingLease == nil || clientBundleSetup.RoutingLease.SignedDeviceID != params.DeviceID ||
		clientBundleSetup.RoutingLease.SignedSerial != snapshot.serial {
		return zero, clientbundle.SubscriptionError("signed_projection_unavailable")
	}
	fresh, _, err := store.Project(params.AccountID, params.DeviceID)
	if err != nil {
		return zero, err
	}
	if !sameSignedRouting(snapshot.body, fresh) {
		return zero, clientbundle.SubscriptionError("signed_projection_unavailable")
	}
	state := signedState(status)
	state.Intent = &intent
	result := SignedSubscriptionProjection{IssuedAt: snapshot.issued, ExpiresAt: snapshot.expires, State: state, Lease: lease}
	if !params.Summary {
		result.Body = string(snapshot.body)
	}
	return result, nil
}

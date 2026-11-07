package core

import (
	"core/clientbundle"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type SignedSubscriptionParams struct {
	AccountID string                  `json:"accountId"`
	DeviceID  string                  `json:"deviceId"`
	Envelope  string                  `json:"envelope,omitempty"`
	Summary   bool                    `json:"summary,omitempty"`
	Owner     *ClientBundleOwnerGuard `json:"owner,omitempty"`
	Intent    *uint64                 `json:"intent,omitempty"`
	Current   bool                    `json:"current,omitempty"`
	Lease     *RoutingLeaseGuard      `json:"lease,omitempty"`
}

type SignedSubscriptionState struct {
	Available             bool    `json:"available"`
	HasFloor              bool    `json:"hasFloor"`
	Installed             bool    `json:"installed"`
	Revoked               bool    `json:"revoked"`
	Expired               bool    `json:"expired"`
	NeedsRefresh          bool    `json:"needsRefresh"`
	Changed               bool    `json:"changed"`
	Serial                int64   `json:"serial,omitempty"`
	BundleID              string  `json:"bundleId,omitempty"`
	SubscriptionExpiresAt *int64  `json:"subscriptionExpiresAt"`
	RecheckAfterMs        int64   `json:"recheckAfterMs,omitempty"`
	Intent                *uint64 `json:"intent,omitempty"`
}

// A summary projection omits the credential-bearing body for callers that
// only schedule the lease, keeping the response below spill size.
type SignedSubscriptionProjection struct {
	Body      string                  `json:"body,omitempty"`
	IssuedAt  int64                   `json:"issuedAt"`
	ExpiresAt int64                   `json:"expiresAt"`
	State     SignedSubscriptionState `json:"state"`
	Lease     *RoutingLeaseGuard      `json:"lease,omitempty"`
}

type InstallSignedClientBundleParams struct {
	Owner    *ClientBundleOwnerGuard `json:"owner"`
	Sequence uint64                  `json:"sequence"`
	DeviceID string                  `json:"deviceId"`
}

// InstallSignedClientBundleResult reports a refusal from the signed store as
// Code, so a renewer can tell revocation or expiry from a superseded owner.
type InstallSignedClientBundleResult struct {
	Installed             bool   `json:"installed"`
	Code                  string `json:"code,omitempty"`
	BundleID              string `json:"bundleId,omitempty"`
	ExpiresAt             int64  `json:"expiresAt,omitempty"`
	SubscriptionExpiresAt *int64 `json:"subscriptionExpiresAt"`
	Serial                int64  `json:"serial,omitempty"`
}

const errSignedUnavailable clientbundle.SubscriptionError = "signed_subscription_unavailable"

var (
	signedSubscriptionTrust = clientbundle.ProductionTrust
	signedSubscriptionMu    sync.Mutex
	signedClock             struct {
		sync.Once
		wall int64
		mono time.Time
	}
)

func signedSubscriptionDir() string {
	return filepath.Join(constant.Path.HomeDir(), "zolnit", "subscription-v2")
}

// The store is reopened, under its cross-process lock, for every operation:
// the iOS app and its tunnel extension each run a Core on the same home.
func withSignedStore[T any](run func(*clientbundle.SubscriptionStore) (T, error)) (T, error) {
	var zero T
	trust, err := signedSubscriptionTrust()
	if !isInit.Load() || err != nil || trust.Empty() {
		return zero, errSignedUnavailable
	}
	signedSubscriptionMu.Lock()
	defer signedSubscriptionMu.Unlock()
	signedClock.Do(func() { signedClock.wall, signedClock.mono = routingLeaseNow().Unix(), time.Now() })
	store, err := clientbundle.OpenSubscriptionStore(signedSubscriptionDir(), trust, clientbundle.StoreOptions{
		Now:     routingLeaseNow,
		Elapsed: func() time.Duration { return 0 },
		Floor:   func() int64 { return signedClock.wall + int64(time.Since(signedClock.mono)/time.Second) },
	})
	if store != nil {
		defer store.Close()
	}
	if err != nil {
		return zero, err
	}
	defer scheduleReclaimOwnership()
	return run(store)
}

func signedMethodError(err error) *MethodError {
	var code clientbundle.SubscriptionError
	if !errors.As(err, &code) {
		code = "signed_subscription_storage_failed"
	}
	return &MethodError{Code: string(code), Message: string(code)}
}

func signedState(status clientbundle.SubscriptionStatus) SignedSubscriptionState {
	state := SignedSubscriptionState{Available: true, HasFloor: status.HasFloor, Revoked: status.Revoked,
		Expired: status.Expired, RecheckAfterMs: status.RecheckAfter.Milliseconds()}
	if pkg := status.Package; pkg != nil {
		state.Installed, state.Serial, state.BundleID, state.SubscriptionExpiresAt = true, pkg.Serial, pkg.BundleID, pkg.ExpiresAt
	}
	state.NeedsRefresh = !state.Installed && !state.Revoked
	return state
}

func validSignedBinding(params *SignedSubscriptionParams) bool {
	return params != nil && clientbundle.SafeText(params.AccountID) && len(params.DeviceID) == 32
}

// Without a binding it only reports whether signed subscriptions are enabled.
func handleGetSignedSubscription(params *SignedSubscriptionParams) (*SignedSubscriptionState, error) {
	if params == nil || params.AccountID == "" && params.DeviceID == "" {
		trust, err := signedSubscriptionTrust()
		if !isInit.Load() || err != nil || trust.Empty() {
			return &SignedSubscriptionState{}, nil
		}
		intent, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (uint64, error) { return store.SessionIntent() })
		if err != nil {
			return nil, signedMethodError(err)
		}
		return &SignedSubscriptionState{Available: true, Intent: &intent}, nil
	}
	if params.AccountID != "" && params.DeviceID == "" && clientbundle.SafeText(params.AccountID) {
		allowed, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (bool, error) {
			return store.AllowsUnsigned(params.AccountID), nil
		})
		if err != nil {
			return nil, signedMethodError(err)
		}
		return &SignedSubscriptionState{Available: true, HasFloor: !allowed}, nil
	}
	if !validSignedBinding(params) {
		return nil, signedMethodError(clientbundle.ErrInvalidSigned)
	}
	state, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (SignedSubscriptionState, error) {
		status, err := store.Status(params.AccountID, params.DeviceID)
		return signedState(status), err
	})
	if errors.Is(err, errSignedUnavailable) {
		return &SignedSubscriptionState{}, nil
	}
	if err != nil {
		return nil, signedMethodError(err)
	}
	return &state, nil
}

func validateSignedRuntime(prepared *clientbundle.Prepared) error {
	raw, err := unmarshalRawConfig(prepared.Document)
	if err == nil {
		_, err = parsePlatformConfig(raw)
	}
	if err != nil {
		return clientbundle.SubscriptionError("invalid_renewed_configuration")
	}
	return nil
}

func handleApplySignedSubscription(params *SignedSubscriptionParams) (*SignedSubscriptionState, error) {
	if !validSignedBinding(params) || params.Envelope == "" || len(params.Envelope) > 8<<20 {
		return nil, signedMethodError(clientbundle.ErrInvalidSigned)
	}
	configMu.Lock()
	defer configMu.Unlock()
	if params.Owner != nil && (params.Owner.AccountID != params.AccountID || !matchesClientBundleOwnerLocked(params.Owner) || !matchesSignedDeviceLocked(params.DeviceID)) {
		return nil, signedMethodError(clientbundle.SubscriptionError("signed_subscription_stale_owner"))
	}
	state, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (SignedSubscriptionState, error) {
		intent, err := store.SessionIntent()
		if err != nil {
			return SignedSubscriptionState{}, err
		}
		if params.Owner == nil && (params.Intent == nil || *params.Intent != intent) || params.Owner != nil && clientBundleSignedIntent != intent {
			return SignedSubscriptionState{}, clientbundle.SubscriptionError("signed_subscription_stale_owner")
		}
		applied, err := store.Apply(params.AccountID, params.DeviceID, []byte(params.Envelope), validateSignedRuntime)
		if err != nil {
			return SignedSubscriptionState{}, err
		}
		status, err := store.Status(params.AccountID, params.DeviceID)
		state := signedState(status)
		state.Changed = applied.Changed
		state.NeedsRefresh = state.NeedsRefresh || applied.NeedsRefresh
		return state, err
	})
	if state.Revoked || state.Expired {
		retireSignedAccountLocked(params.AccountID, params.DeviceID)
	}
	if err != nil {
		return nil, signedMethodError(err)
	}
	return &state, nil
}

func retireSignedAccountLocked(account, device string) {
	forgetSignedProjectionsLocked(account, device, nil)
	if clientBundleSetup == nil || clientBundleSetup.RoutingLease == nil || clientBundleSetup.RoutingLease.AccountID != account ||
		clientBundleSetup.RoutingLease.SignedDeviceID != device {
		return
	}
	clientBundleOwner = nil
	stopClientBundleRoutingLocked()
	selectMu.Lock()
	revokeActiveRoutingLeaseLocked(activeRoutingLease, true)
	if currentConfig != nil {
		proxies := tunnel.Proxies()
		if reject := proxies[rejectProxyName]; reject != nil {
			blocked := make(map[string]constant.Proxy, len(proxies))
			for name, proxy := range proxies {
				switch name {
				case directProxyName, rejectProxyName, "REJECT-DROP", "PASS", "COMPATIBLE":
					blocked[name] = proxy
				default:
					blocked[name] = reject
				}
			}
			currentConfig.Proxies, currentConfig.Providers = blocked, nil
			tunnel.UpdateProxies(blocked, nil)
			handleCloseConnections()
			refreshRouteLocked(true)
		}
	}
	clientBundleSetup.RoutingLease.ConnectionDigest = ""
	selectMu.Unlock()
}

func handleProjectSignedSubscription(params *SignedSubscriptionParams) (*SignedSubscriptionProjection, error) {
	if !validSignedBinding(params) {
		return nil, signedMethodError(clientbundle.ErrInvalidSigned)
	}
	configMu.Lock()
	defer configMu.Unlock()
	projection, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (SignedSubscriptionProjection, error) {
		intent, err := store.SessionIntent()
		if err != nil {
			return SignedSubscriptionProjection{}, err
		}
		if params.Current {
			return currentSignedProjectionLocked(store, params, intent)
		}
		body, pkg, err := store.Project(params.AccountID, params.DeviceID)
		if err != nil {
			return SignedSubscriptionProjection{}, err
		}
		var lease struct {
			Data struct {
				Issued  int64 `json:"issued_at"`
				Expires int64 `json:"expires_at"`
			} `json:"data"`
		}
		if err := json.Unmarshal(body, &lease); err != nil {
			return SignedSubscriptionProjection{}, err
		}
		status, err := store.Status(params.AccountID, params.DeviceID)
		projection := SignedSubscriptionProjection{IssuedAt: lease.Data.Issued, ExpiresAt: lease.Data.Expires, State: signedState(status)}
		if !params.Summary {
			projection.Body = string(body)
			rememberSignedProjectionLocked(body, pkg, intent, false)
		}
		return projection, err
	})
	if err != nil {
		if errors.Is(err, clientbundle.ErrTombstone) || errors.Is(err, clientbundle.ErrExpired) {
			retireSignedAccountLocked(params.AccountID, params.DeviceID)
		}
		return nil, signedMethodError(err)
	}
	return &projection, nil
}

func handleInstallSignedClientBundle(params *InstallSignedClientBundleParams) (*InstallSignedClientBundleResult, error) {
	if params == nil || params.Owner == nil || params.Sequence == 0 || len(params.DeviceID) != 32 {
		return nil, errors.New("invalid client bundle installation")
	}
	configMu.Lock()
	defer configMu.Unlock()
	if !matchesClientBundleOwnerLocked(params.Owner) || params.Sequence <= clientBundleAttempt || !matchesSignedDeviceLocked(params.DeviceID) {
		return nil, errors.New("superseded client bundle installation")
	}
	account := params.Owner.AccountID
	return withSignedStore(func(store *clientbundle.SubscriptionStore) (*InstallSignedClientBundleResult, error) {
		intent, err := store.SessionIntent()
		if err != nil {
			return nil, err
		}
		if clientBundleSignedIntent != intent {
			return nil, errors.New("superseded client bundle installation")
		}
		body, pkg, err := store.Project(account, params.DeviceID)
		if err != nil {
			if errors.Is(err, clientbundle.ErrTombstone) || errors.Is(err, clientbundle.ErrExpired) {
				retireSignedAccountLocked(account, params.DeviceID)
			}
			return &InstallSignedClientBundleResult{Code: signedMethodError(err).Code}, nil
		}
		prepared, code := clientbundle.Prepare(body, account, clientBundleSetup.RoutingLease.RenewalOverlay, routingLeaseNow())
		if code != "" {
			return &InstallSignedClientBundleResult{Code: code}, nil
		}
		clientBundleAttempt = params.Sequence
		applied, err := clientBundleApply(prepared, signedSetupParams(clientBundleSetup, pkg))
		if err != nil {
			return nil, err
		}
		if applied {
			replaceClientBundleRoutingLocked(body, params.Owner)
			rememberSignedProjectionLocked(body, pkg, intent, true)
			armSignedRuntimeCheckLocked(store)
		}
		return &InstallSignedClientBundleResult{Installed: applied, BundleID: prepared.Bundle.ID,
			ExpiresAt: prepared.Bundle.Expires * 1000, SubscriptionExpiresAt: pkg.ExpiresAt,
			Serial: pkg.Serial}, nil
	})
}

func signedSetupParams(previous *SetupParams, pkg *clientbundle.SignedPackage) *SetupParams {
	params := *previous
	lease := *previous.RoutingLease
	lease.SignedDeviceID, lease.SignedSerial = pkg.DeviceID, pkg.Serial
	params.RoutingLease = &lease
	return &params
}

func matchesSignedDeviceLocked(device string) bool {
	bound := clientBundleSetup.RoutingLease.SignedDeviceID
	return bound == "" || bound == device
}

func withSignedSetupLocked(params *SetupParams, apply func(*clientbundle.Prepared) error) error {
	lease := params.RoutingLease
	if lease == nil {
		return apply(nil)
	}
	if lease.SignedDeviceID == "" && lease.SignedSerial == 0 {
		return withUnsignedSignedGuard(lease.AccountID, func() error { return apply(nil) })
	}
	_, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (bool, error) {
		intent, err := store.SessionIntent()
		if err != nil {
			return false, err
		}
		if lease.SignedIntent == nil || *lease.SignedIntent != intent {
			return false, signedMethodError(clientbundle.SubscriptionError("signed_subscription_stale_owner"))
		}
		body, pkg, err := store.Project(lease.AccountID, lease.SignedDeviceID)
		if err != nil {
			return false, signedMethodError(err)
		}
		if saved := signedProjectionForSetupLocked(lease, pkg, intent, body); saved != nil {
			body = saved.body
		}
		prepared, code := clientbundle.Prepare(body, lease.AccountID, lease.RenewalOverlay, routingLeaseNow())
		if code != "" {
			return false, signedMethodError(clientbundle.SubscriptionError(code))
		}
		if currentConfig == nil && lease.SignedSerial > 0 && pkg.Serial > lease.SignedSerial {
			applied, err := clientBundleApply(prepared, signedSetupParams(params, pkg))
			if err == nil && !applied {
				err = signedMethodError(clientbundle.ErrSignedRequired)
			}
			if err == nil {
				rememberSignedProjectionLocked(body, pkg, intent, true)
				armSignedRuntimeCheckLocked(store)
			}
			return applied, err
		}
		if pkg.Serial != lease.SignedSerial || prepared.Bundle.Connection.SHA != lease.ConnectionDigest {
			return false, signedMethodError(clientbundle.ErrReplay)
		}
		params.RoutingLease = routingLeaseForPrepared(prepared, lease)
		params.RoutingLease.ConfigurationDigest = lease.ConfigurationDigest
		if err := apply(prepared); err != nil {
			return false, err
		}
		rememberSignedProjectionLocked(body, pkg, intent, true)
		armSignedRuntimeCheckLocked(store)
		return true, nil
	})
	return err
}

func withUnsignedSignedGuard(account string, run func() error) error {
	_, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (bool, error) {
		if !store.AllowsUnsigned(account) {
			return false, signedMethodError(clientbundle.ErrSignedRequired)
		}
		return true, run()
	})
	if !errors.Is(err, errSignedUnavailable) {
		return err
	}
	signedSubscriptionMu.Lock()
	defer signedSubscriptionMu.Unlock()
	err = clientbundle.WithNoSignedState(signedSubscriptionDir(), run)
	if errors.Is(err, clientbundle.ErrSignedRequired) {
		return signedMethodError(err)
	}
	return err
}

const signedRuntimePoll = 30 * time.Second

var signedRuntimeTimer *time.Timer

func scheduleSignedRuntimeCheckLocked(setup *SetupParams, delay time.Duration) {
	if signedRuntimeTimer != nil {
		signedRuntimeTimer.Stop()
	}
	if delay <= 0 || delay > signedRuntimePoll {
		delay = signedRuntimePoll
	}
	signedRuntimeTimer = time.AfterFunc(delay, func() {
		configMu.Lock()
		defer configMu.Unlock()
		checkSignedRuntimeLocked(setup)
	})
}

func armSignedRuntimeCheckLocked(store *clientbundle.SubscriptionStore) {
	setup := clientBundleSetup
	if setup == nil || setup.RoutingLease == nil || setup.RoutingLease.SignedDeviceID == "" {
		return
	}
	lease := setup.RoutingLease
	status, err := store.Status(lease.AccountID, lease.SignedDeviceID)
	if status.Expired || status.Revoked {
		retireSignedAccountLocked(lease.AccountID, lease.SignedDeviceID)
		if err == nil {
			return
		}
	}
	scheduleSignedRuntimeCheckLocked(setup, status.RecheckAfter)
}

func checkSignedRuntimeLocked(setup *SetupParams) {
	if setup == nil || clientBundleSetup != setup || !isInit.Load() {
		return
	}
	status, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (clientbundle.SubscriptionStatus, error) {
		lease := setup.RoutingLease
		return store.Status(lease.AccountID, lease.SignedDeviceID)
	})
	lease := setup.RoutingLease
	if status.Revoked || status.Expired {
		if lease.ConnectionDigest != "" {
			retireSignedAccountLocked(lease.AccountID, lease.SignedDeviceID)
		}
		if err == nil {
			return
		}
	}
	scheduleSignedRuntimeCheckLocked(setup, status.RecheckAfter)
}

// signedFloorRefusesUnsigned is true once this installation holds a signed
// floor for the account, or its signed state cannot be read.
func signedFloorRefusesUnsigned(account string) bool {
	return withUnsignedSignedGuard(account, func() error { return nil }) != nil
}

type SignedSignOutParams struct {
	Intent *uint64 `json:"intent"`
}

func handleSignOutSignedSubscription(params *SignedSignOutParams) (bool, error) {
	if params == nil || params.Intent == nil {
		return false, signedMethodError(clientbundle.SubscriptionError("signed_subscription_stale_owner"))
	}
	_, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (bool, error) {
		intent, err := store.SessionIntent()
		if err != nil {
			return false, err
		}
		if intent != *params.Intent {
			return false, clientbundle.SubscriptionError("signed_subscription_stale_owner")
		}
		if _, err := store.AdvanceSessionIntent(); err != nil {
			return false, err
		}
		return true, store.SignOut()
	})
	if err != nil && !errors.Is(err, errSignedUnavailable) {
		return false, signedMethodError(err)
	}
	return true, nil
}

func handleInvalidateSignedSubscription(params *SignedSignOutParams) (uint64, error) {
	if params == nil || params.Intent == nil {
		return 0, signedMethodError(clientbundle.SubscriptionError("signed_subscription_stale_owner"))
	}
	intent, err := withSignedStore(func(store *clientbundle.SubscriptionStore) (uint64, error) {
		current, err := store.SessionIntent()
		if err != nil {
			return 0, err
		}
		if current != *params.Intent {
			return 0, clientbundle.SubscriptionError("signed_subscription_stale_owner")
		}
		return store.AdvanceSessionIntent()
	})
	if err != nil {
		return 0, signedMethodError(err)
	}
	return intent, nil
}

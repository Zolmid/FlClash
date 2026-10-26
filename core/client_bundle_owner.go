package core

import (
	"core/clientbundle"
	"encoding/json"
	"errors"
	"time"

	"github.com/metacubex/mihomo/tunnel"
)

type ClientBundleOwnerContext struct {
	ReturnRouteGuard        *RoutingLeaseGuard `json:"returnRouteGuard,omitempty"`
	OwnerSerial             uint64             `json:"ownerSerial"`
	InstanceID              string             `json:"instanceId"`
	AccountID               string             `json:"accountId"`
	AccountGeneration       int                `json:"accountGeneration"`
	ConfigurationGeneration int                `json:"configurationGeneration"`
}

type BeginClientBundleOwnerParams struct {
	ClientBundleOwnerContext
	SessionEpoch uint64 `json:"sessionEpoch"`
	OwnerID      uint64 `json:"ownerId"`
	Generation   uint64 `json:"generation"`
}

type ClientBundleOwnerGuard struct {
	InstanceID        string `json:"instanceId"`
	AccountID         string `json:"accountId"`
	AccountGeneration int    `json:"accountGeneration"`
	SessionEpoch      uint64 `json:"sessionEpoch"`
	OwnerID           uint64 `json:"ownerId"`
	Generation        uint64 `json:"generation"`
	Serial            uint64 `json:"serial"`
}

type InstallClientBundleParams struct {
	Owner    *ClientBundleOwnerGuard `json:"owner"`
	Sequence uint64                  `json:"sequence"`
	Body     string                  `json:"body"`
}

type EndClientBundleOwnerParams struct {
	Owner             *ClientBundleOwnerGuard       `json:"owner,omitempty"`
	Context           *BeginClientBundleOwnerParams `json:"context,omitempty"`
	InvalidateSession bool                          `json:"invalidateSession,omitempty"`
}

var (
	clientBundleSetup        *SetupParams
	clientBundleOwner        *ClientBundleOwnerGuard
	clientBundleSerial       uint64
	clientBundleEpochFloor   uint64
	clientBundleOwnerFloor   uint64
	clientBundleGenFloor     uint64
	clientBundleAttempt      uint64
	clientBundleRetiredEpoch uint64
	clientBundleApply        = applyPreparedClientBundleLocked
)

func rememberClientBundleSetupLocked(params *SetupParams) {
	if params == nil || params.RoutingLease == nil {
		clientBundleSetup = nil
		return
	}
	data, err := json.Marshal(params)
	if err != nil {
		return
	}
	var copied SetupParams
	if json.Unmarshal(data, &copied) == nil {
		clientBundleSetup = &copied
	}
}

func patchClientBundlePreferencesLocked(params *UpdateParams) {
	if clientBundleSetup == nil || clientBundleSetup.RoutingLease == nil {
		return
	}
	var overlay, patch map[string]any
	encoded, err := json.Marshal(params)
	if err != nil || json.Unmarshal(encoded, &patch) != nil ||
		json.Unmarshal([]byte(clientBundleSetup.RoutingLease.RenewalOverlay), &overlay) != nil {
		clientBundleOwner, clientBundleSetup = nil, nil
		return
	}
	for key, value := range patch {
		if value == nil {
			continue
		}
		current, currentMap := overlay[key].(map[string]any)
		change, patchMap := value.(map[string]any)
		if currentMap && patchMap {
			for field, item := range change {
				current[field] = item
			}
		} else {
			overlay[key] = value
		}
	}
	encoded, err = json.Marshal(overlay)
	if err == nil {
		clientBundleSetup.RoutingLease.RenewalOverlay = string(encoded)
	}
}

func reuseClientBundleConfigurationLocked(params *SetupParams) bool {
	if currentConfig == nil || clientBundleSetup == nil || params == nil ||
		params.RoutingLease == nil || clientBundleSetup.RoutingLease == nil {
		return false
	}
	before, after := clientBundleSetup.RoutingLease, params.RoutingLease
	if after.ConnectionDigest == "" || after.MetadataDigest == "" ||
		before.ConnectionDigest != after.ConnectionDigest || before.MetadataDigest != after.MetadataDigest ||
		before.AccountID != after.AccountID || before.RenewalOverlay != after.RenewalOverlay ||
		clientBundleSetup.TestURL != params.TestURL || clientBundleSetup.SkipCertVerify != params.SkipCertVerify {
		return false
	}
	selectMu.Lock()
	defer selectMu.Unlock()
	proxies := tunnel.AllProxies()
	if _, valid := returnRouteSelector(after.ReturnRoute, proxies); valid && !returnRouteMember(after.ReturnRoute, rejectProxyName, proxies) {
		return false
	}
	return renewRoutingLeaseLocked(after)
}

func clientBundleContextLocked() *ClientBundleOwnerContext {
	if !isInit.Load() || clientBundleSetup == nil || clientBundleSetup.RoutingLease == nil ||
		clientBundleSetup.RoutingLease.RenewalOverlay == "" {
		return nil
	}
	spec := clientBundleSetup.RoutingLease
	selectMu.Lock()
	defer selectMu.Unlock()
	serial := uint64(0)
	if clientBundleOwner != nil {
		serial = clientBundleOwner.Serial
	}
	return &ClientBundleOwnerContext{InstanceID: routingLeaseInstanceID, AccountID: spec.AccountID,
		AccountGeneration: spec.AccountGeneration, ConfigurationGeneration: routingConfigurationGeneration, OwnerSerial: serial, ReturnRouteGuard: returnRouteGuardLocked()}
}

func handleGetClientBundleOwner() *ClientBundleOwnerContext {
	configMu.Lock()
	defer configMu.Unlock()
	return clientBundleContextLocked()
}

func sameClientBundleOwnerBinding(a, b ClientBundleOwnerContext) bool {
	return a.OwnerSerial == b.OwnerSerial && a.InstanceID == b.InstanceID && a.AccountID == b.AccountID &&
		a.AccountGeneration == b.AccountGeneration && a.ConfigurationGeneration == b.ConfigurationGeneration
}

func handleBeginClientBundleOwner(params *BeginClientBundleOwnerParams) (*ClientBundleOwnerGuard, error) {
	configMu.Lock()
	defer configMu.Unlock()
	context := clientBundleContextLocked()
	if params == nil || context == nil || !sameClientBundleOwnerBinding(params.ClientBundleOwnerContext, *context) ||
		params.SessionEpoch == 0 || params.OwnerID == 0 || params.Generation == 0 ||
		params.SessionEpoch < clientBundleEpochFloor || params.SessionEpoch <= clientBundleRetiredEpoch {
		return nil, errors.New("invalid client bundle owner")
	}
	if params.SessionEpoch > clientBundleEpochFloor {
		clientBundleEpochFloor, clientBundleOwnerFloor, clientBundleGenFloor = params.SessionEpoch, 0, 0
	}
	if params.OwnerID < clientBundleOwnerFloor {
		return nil, errors.New("superseded client bundle owner")
	}
	if params.OwnerID > clientBundleOwnerFloor {
		clientBundleOwnerFloor, clientBundleGenFloor = params.OwnerID, 0
	}
	if params.Generation <= clientBundleGenFloor {
		if clientBundleOwner != nil && clientBundleOwner.Generation == params.Generation {
			result := *clientBundleOwner
			return &result, nil
		}
		return nil, errors.New("retired client bundle owner")
	}
	if clientBundleSerial == ^uint64(0) {
		clientBundleOwner = nil
		return nil, errors.New("client bundle owner exhausted")
	}
	clientBundleGenFloor = params.Generation
	stopClientBundleRoutingLocked()
	clientBundleSerial++
	clientBundleAttempt = 0
	clientBundleOwner = &ClientBundleOwnerGuard{InstanceID: context.InstanceID, AccountID: context.AccountID,
		AccountGeneration: context.AccountGeneration, SessionEpoch: params.SessionEpoch,
		OwnerID: params.OwnerID, Generation: params.Generation, Serial: clientBundleSerial}
	result := *clientBundleOwner
	return &result, nil
}

func matchesClientBundleOwnerLocked(guard *ClientBundleOwnerGuard) bool {
	context := clientBundleContextLocked()
	return guard != nil && clientBundleOwner != nil && context != nil &&
		*guard == *clientBundleOwner && guard.InstanceID == context.InstanceID &&
		guard.AccountID == context.AccountID && guard.AccountGeneration == context.AccountGeneration
}

func handleInstallClientBundle(params *InstallClientBundleParams) (bool, error) {
	if params == nil || params.Owner == nil || params.Sequence == 0 || len(params.Body) > 8<<20 {
		return false, errors.New("invalid client bundle installation")
	}
	configMu.Lock()
	if !matchesClientBundleOwnerLocked(params.Owner) || params.Sequence <= clientBundleAttempt {
		configMu.Unlock()
		return false, errors.New("superseded client bundle installation")
	}
	overlay := clientBundleSetup.RoutingLease.RenewalOverlay
	configMu.Unlock()
	prepared, code := clientbundle.Prepare([]byte(params.Body), params.Owner.AccountID, overlay, routingLeaseNow())
	if code != "" {
		return false, errors.New(code)
	}
	configMu.Lock()
	defer configMu.Unlock()
	if !matchesClientBundleOwnerLocked(params.Owner) || params.Sequence <= clientBundleAttempt ||
		prepared.Bundle.Expires <= routingLeaseNow().Unix() {
		return false, errors.New("superseded client bundle installation")
	}
	clientBundleAttempt = params.Sequence
	applied, err := clientBundleApply(prepared, clientBundleSetup)
	if applied && err == nil {
		replaceClientBundleRoutingLocked([]byte(params.Body), params.Owner)
	}
	return applied, err
}

func handleEndClientBundleOwner(params *EndClientBundleOwnerParams) bool {
	configMu.Lock()
	defer configMu.Unlock()
	if params == nil {
		return true
	}
	if params.InvalidateSession {
		var identity *ClientBundleOwnerGuard
		if params.Owner != nil {
			identity = params.Owner
		} else if params.Context != nil {
			value := params.Context
			identity = &ClientBundleOwnerGuard{InstanceID: value.InstanceID,
				AccountID: value.AccountID, AccountGeneration: value.AccountGeneration,
				SessionEpoch: value.SessionEpoch, OwnerID: value.OwnerID, Generation: value.Generation}
		}
		context := clientBundleContextLocked()
		if identity == nil || context == nil || identity.InstanceID != context.InstanceID ||
			identity.AccountID != context.AccountID || identity.AccountGeneration != context.AccountGeneration ||
			identity.SessionEpoch == 0 {
			return true
		}
		clientBundleRetiredEpoch = max(clientBundleRetiredEpoch, identity.SessionEpoch)
		if clientBundleOwner != nil && clientBundleOwner.SessionEpoch > identity.SessionEpoch {
			return true
		}
	} else if !matchesClientBundleOwnerLocked(params.Owner) {
		return true
	}
	clientBundleOwner = nil
	stopClientBundleRoutingLocked()
	selectMu.Lock()
	if params.InvalidateSession {
		retireReturnRouteLocked()
	}
	revokeActiveRoutingLeaseLocked(activeRoutingLease, true)
	selectMu.Unlock()
	return true
}

func applyPreparedClientBundleLocked(prepared *clientbundle.Prepared, previous *SetupParams) (bool, error) {
	lease := &RoutingLeaseSpec{AccountID: prepared.Bundle.Account, AccountGeneration: previous.RoutingLease.AccountGeneration,
		BundleID: prepared.Bundle.ID, ConfigurationDigest: prepared.Digest,
		ExpiresAt:        time.Unix(prepared.Bundle.Expires, 0).UnixMilli(),
		ConnectionDigest: prepared.Bundle.Connection.SHA, MetadataDigest: prepared.MetadataDigest,
		RenewalOverlay: previous.RoutingLease.RenewalOverlay, ReturnRoute: prepared.ReturnRoute}
	for _, service := range prepared.Services {
		lease.Services = append(lease.Services, RoutingLeaseServiceSpec{GroupName: service.GroupName,
			AutomaticGroup: service.AutomaticGroup, ManualGroup: service.ManualGroup, AllowedProxies: service.AllowedProxies})
	}
	renewed := *previous
	renewed.RoutingLease = lease
	if reuseClientBundleConfigurationLocked(&renewed) {
		rememberClientBundleSetupLocked(&renewed)
		return true, nil
	}
	clearRoutingLeaseForConfigChange()
	raw, err := unmarshalRawConfig(prepared.Document)
	if err != nil {
		return false, errors.New("invalid renewed client configuration")
	}
	cfg, err := parsePlatformConfig(withReturnRouteReject(raw, lease))
	if err != nil || prepared.Bundle.Expires <= routingLeaseNow().Unix() {
		return false, errors.New("invalid renewed client configuration")
	}
	params := *previous
	params.SelectedMap = map[string]string{}
	selectMu.Lock()
	for name, proxy := range tunnel.AllProxies() {
		if proxy == nil {
			continue
		}
		if selector, ok := proxy.Adapter().(pickableGroup); ok {
			params.SelectedMap[name] = selector.Now()
		}
	}
	selectMu.Unlock()
	for _, service := range prepared.Services {
		current := params.SelectedMap[service.ManualGroup]
		valid := current == directProxyName
		for _, outbound := range prepared.Bundle.Outbounds {
			valid = valid || current == outbound.Name
		}
		if !valid {
			params.SelectedMap[service.ManualGroup] = directProxyName
		}
	}
	params.RoutingLease = lease
	applyParsedConfigLocked(cfg, &params, nil)
	rememberClientBundleSetupLocked(&params)
	return true, nil
}

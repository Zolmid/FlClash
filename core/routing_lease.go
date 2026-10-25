package core

import (
	"crypto/rand"
	"errors"
	"time"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const (
	maxRoutingLeaseTTL = 300 * time.Second
	rejectProxyName    = "REJECT"
	directProxyName    = "DIRECT"
)

var (
	errRoutingLeaseRequired        = errors.New("routing lease guard is required")
	errRoutingLeaseInvalid         = errors.New("routing lease guard is invalid")
	errRoutingLeaseNotAutomatic    = errors.New("routing lease policy group is not in automatic mode")
	errRoutingLeaseInvalidTarget   = errors.New("routing lease automatic group is not a selector")
	errRoutingLeaseProxyNotAllowed = errors.New("routing lease proxy is not allowed")
	errRoutingLeaseProxyType       = errors.New("routing lease proxy is not a network outbound")

	routingLeaseNow       = time.Now
	routingLeaseAfterFunc = time.AfterFunc

	routingLeaseInstanceID         = rand.Text()
	routingConfigurationGeneration int
	activeRoutingLease             *routingLeaseState
)

type routingLeaseService struct {
	groupName         string
	automaticGroup    string
	manualGroup       string
	policyProxy       constant.Proxy
	policySelector    pickableGroup
	automaticProxy    constant.Proxy
	automaticSelector pickableGroup
	manualProxy       constant.Proxy
	allowedProxies    map[string]constant.Proxy
}

type routingLeaseState struct {
	instanceID              string
	token                   string
	configurationGeneration int
	accountID               string
	accountGeneration       int
	bundleID                string
	configurationDigest     string
	expiresAt               int64
	deadline                time.Time
	revoked                 bool
	services                map[string]*routingLeaseService
	policyGroups            map[string]*routingLeaseService
	manualGroups            map[string]*routingLeaseService
	serviceOrder            []*routingLeaseService
	timer                   *time.Timer
}

func (s *routingLeaseState) matchesIdentity(guard *RoutingLeaseGuard) bool {
	return s != nil &&
		guard != nil &&
		guard.InstanceID != "" &&
		guard.InstanceID == s.instanceID &&
		guard.Token != "" &&
		guard.ConfigurationGeneration > 0 &&
		guard.ConfigurationGeneration == s.configurationGeneration &&
		guard.AccountID != "" &&
		guard.AccountID == s.accountID &&
		guard.AccountGeneration == s.accountGeneration &&
		guard.BundleID != "" &&
		guard.BundleID == s.bundleID &&
		guard.ConfigurationDigest != "" &&
		guard.ConfigurationDigest == s.configurationDigest &&
		guard.ExpiresAt == s.expiresAt
}

func (s *routingLeaseState) matchesGuard(guard *RoutingLeaseGuard) bool {
	return s.matchesIdentity(guard) && !s.revoked && guard.Token == s.token
}

func (s *routingLeaseState) guard() *RoutingLeaseGuard {
	if s == nil || s.revoked {
		return nil
	}
	return &RoutingLeaseGuard{
		InstanceID:              s.instanceID,
		Token:                   s.token,
		ConfigurationGeneration: s.configurationGeneration,
		AccountID:               s.accountID,
		AccountGeneration:       s.accountGeneration,
		BundleID:                s.bundleID,
		ConfigurationDigest:     s.configurationDigest,
		ExpiresAt:               s.expiresAt,
	}
}

func (s *routingLeaseState) rotateToken() {
	if s != nil {
		s.token = rand.Text()
	}
}

func isLeaseNetworkProxyType(adapterType constant.AdapterType) bool {
	switch adapterType {
	case constant.Shadowsocks,
		constant.ShadowsocksR,
		constant.Snell,
		constant.Socks5,
		constant.Http,
		constant.Vmess,
		constant.Vless,
		constant.Trojan,
		constant.Hysteria,
		constant.Hysteria2,
		constant.WireGuard,
		constant.Tuic,
		constant.Ssh,
		constant.Mieru,
		constant.AnyTLS,
		constant.Sudoku,
		constant.Masque,
		constant.TrustTunnel,
		constant.ShadowQuic,
		constant.OpenVPN,
		constant.Tailscale,
		constant.ZeroTier,
		constant.EasyTier,
		constant.GostRelay:
		return true
	default:
		return false
	}
}

func isLeaseNetworkProxy(proxy constant.Proxy) bool {
	return proxy != nil && isLeaseNetworkProxyType(proxy.Type())
}

func stopRoutingLeaseTimerLocked(state *routingLeaseState) {
	if state != nil && state.timer != nil {
		state.timer.Stop()
		state.timer = nil
	}
}

func resetRoutingLeaseInstance() {
	selectMu.Lock()
	defer selectMu.Unlock()
	revokeRoutingLeaseObservedLocked(activeRoutingLease, true, "instance_reset")
	activeRoutingLease = nil
	routingLeaseInstanceID = rand.Text()
	routingConfigurationGeneration++
	recordLeaseObservationLocked("instance_reset", "reset")
}

func clearRoutingLeaseForConfigChange() {
	selectMu.Lock()
	defer selectMu.Unlock()
	revokeRoutingLeaseObservedLocked(activeRoutingLease, true, "config_replaced")
	routingConfigurationGeneration++
	recordLeaseObservationLocked("config_replaced", "configuration")
}

func parseRoutingLeaseServices(specs []RoutingLeaseServiceSpec, proxies map[string]constant.Proxy) (
	services map[string]*routingLeaseService,
	policyGroups map[string]*routingLeaseService,
	manualGroups map[string]*routingLeaseService,
	order []*routingLeaseService,
	valid bool,
) {
	services = make(map[string]*routingLeaseService, len(specs))
	policyGroups = make(map[string]*routingLeaseService, len(specs))
	manualGroups = make(map[string]*routingLeaseService, len(specs))
	order = make([]*routingLeaseService, 0, len(specs))
	seenNames := make(map[string]struct{}, len(specs)*3)
	valid = len(specs) > 0

	for _, item := range specs {
		var svc *routingLeaseService
		if item.AutomaticGroup != "" {
			if _, exists := services[item.AutomaticGroup]; !exists {
				autoProxy := proxies[item.AutomaticGroup]
				autoSelector, autoOK := adapterAs[pickableGroup](autoProxy)
				if autoProxy == nil || autoProxy.Type() != constant.Selector || !autoOK {
					valid = false
				}
				policyProxy := proxies[item.GroupName]
				policySelector, policyOK := adapterAs[pickableGroup](policyProxy)
				if policyProxy == nil || policyProxy.Type() != constant.Selector || !policyOK {
					valid = false
				}
				manualProxy := proxies[item.ManualGroup]
				if manualProxy == nil || manualProxy.Type() != constant.Selector {
					valid = false
				}
				svc = &routingLeaseService{
					groupName:         item.GroupName,
					automaticGroup:    item.AutomaticGroup,
					manualGroup:       item.ManualGroup,
					policyProxy:       policyProxy,
					policySelector:    policySelector,
					automaticProxy:    autoProxy,
					automaticSelector: autoSelector,
					manualProxy:       manualProxy,
					allowedProxies:    make(map[string]constant.Proxy, len(item.AllowedProxies)),
				}
				for _, proxyName := range item.AllowedProxies {
					if proxyName == "" || proxyName == directProxyName || proxyName == rejectProxyName {
						continue
					}
					if candidate := proxies[proxyName]; isLeaseNetworkProxy(candidate) {
						svc.allowedProxies[proxyName] = candidate
					}
				}
				services[item.AutomaticGroup] = svc
				order = append(order, svc)
			} else {
				valid = false
			}
		} else {
			valid = false
		}
		if item.GroupName == "" || item.AutomaticGroup == "" || item.ManualGroup == "" {
			valid = false
			continue
		}
		if item.GroupName == item.AutomaticGroup ||
			item.GroupName == item.ManualGroup ||
			item.AutomaticGroup == item.ManualGroup {
			valid = false
			continue
		}
		for _, groupName := range []string{item.GroupName, item.AutomaticGroup, item.ManualGroup} {
			if _, exists := seenNames[groupName]; exists {
				valid = false
			}
			seenNames[groupName] = struct{}{}
		}
		if svc != nil {
			policyGroups[item.GroupName] = svc
			manualGroups[item.ManualGroup] = svc
		}
	}
	return services, policyGroups, manualGroups, order, valid
}

func installRoutingLeaseLocked(spec *RoutingLeaseSpec) {
	stopRoutingLeaseTimerLocked(activeRoutingLease)
	activeRoutingLease = nil
	routingConfigurationGeneration++
	if routingLeaseInstanceID == "" {
		routingLeaseInstanceID = rand.Text()
	}
	if spec == nil {
		recordLeaseObservationLocked("config_replaced", "no_lease")
		return
	}

	now := routingLeaseNow()
	expiresAt := time.UnixMilli(spec.ExpiresAt)
	remaining := expiresAt.Sub(now)
	proxies := tunnel.AllProxies()
	services, policyGroups, manualGroups, order, servicesValid := parseRoutingLeaseServices(spec.Services, proxies)

	valid := servicesValid &&
		spec.AccountID != "" &&
		spec.AccountGeneration >= 0 &&
		spec.BundleID != "" &&
		spec.ConfigurationDigest != "" &&
		spec.ExpiresAt > 0 &&
		remaining > 0 &&
		remaining <= maxRoutingLeaseTTL

	state := &routingLeaseState{
		instanceID:              routingLeaseInstanceID,
		token:                   rand.Text(),
		configurationGeneration: routingConfigurationGeneration,
		accountID:               spec.AccountID,
		accountGeneration:       spec.AccountGeneration,
		bundleID:                spec.BundleID,
		configurationDigest:     spec.ConfigurationDigest,
		expiresAt:               spec.ExpiresAt,
		deadline:                now.Add(remaining),
		revoked:                 !valid,
		services:                services,
		policyGroups:            policyGroups,
		manualGroups:            manualGroups,
		serviceOrder:            order,
	}
	activeRoutingLease = state

	if !valid {
		revokeRoutingLeaseObservedLocked(state, false, "installed")
		return
	}

	enforceInitialRoutingLeaseSelectionsLocked(state, proxies)
	recordLeaseObservationLocked("installed", "valid")
	instanceID := state.instanceID
	generation := state.configurationGeneration
	state.timer = routingLeaseAfterFunc(remaining, func() {
		expireRoutingLease(instanceID, generation)
	})
}

func enforceInitialRoutingLeaseSelectionsLocked(state *routingLeaseState, proxies map[string]constant.Proxy) {
	for _, svc := range state.serviceOrder {
		if svc.automaticSelector == nil || proxies[svc.automaticGroup] != svc.automaticProxy {
			continue
		}
		current := svc.automaticSelector.Now()
		if current == rejectProxyName {
			continue
		}
		setSelectorRejectLocked(svc.automaticGroup, svc.automaticSelector)
	}
}

func setSelectorRejectLocked(groupName string, selector outboundgroup.SelectAble) bool {
	if selector == nil {
		return false
	}
	var current string
	if group, ok := selector.(outboundgroup.ProxyGroup); ok {
		current = group.Now()
	}
	if err := selector.Set(rejectProxyName); err != nil {
		selector.ForceSet(rejectProxyName)
	}
	if group, ok := selector.(outboundgroup.ProxyGroup); ok {
		after := group.Now()
		if after != current {
			closeConnectionsForSelection(groupName, after)
			return true
		}
		return false
	}
	closeConnectionsForSelection(groupName, rejectProxyName)
	return true
}

func revokeActiveRoutingLeaseLocked(state *routingLeaseState, refresh bool) {
	revokeRoutingLeaseObservedLocked(state, refresh, "rpc_invalidated")
}

func revokeRoutingLeaseObservedLocked(state *routingLeaseState, refresh bool, kind string) {
	if state == nil {
		return
	}
	stopRoutingLeaseTimerLocked(state)
	state.revoked = true
	state.rotateToken()
	proxies := tunnel.AllProxies()
	changed := false
	for _, svc := range state.serviceOrder {
		clear(svc.allowedProxies)
		if svc.automaticSelector != nil && proxies[svc.automaticGroup] == svc.automaticProxy {
			if setSelectorRejectLocked(svc.automaticGroup, svc.automaticSelector) {
				changed = true
			}
		}
	}
	// Queue the actual REJECT state before route publication can wait on the frontend.
	recordLeaseObservationLocked(kind, "revoked")
	if refresh && changed {
		refreshRouteLocked(false)
	}
}

func expireRoutingLease(instanceID string, configurationGeneration int) {
	selectMu.Lock()
	defer selectMu.Unlock()
	if activeRoutingLease == nil ||
		activeRoutingLease.instanceID != instanceID ||
		activeRoutingLease.configurationGeneration != configurationGeneration {
		return
	}
	revokeRoutingLeaseObservedLocked(activeRoutingLease, true, "watchdog")
}

func serviceTopologyIntact(svc *routingLeaseService, proxies map[string]constant.Proxy) bool {
	return svc != nil &&
		svc.policyProxy != nil &&
		svc.policySelector != nil &&
		svc.automaticProxy != nil &&
		svc.automaticSelector != nil &&
		svc.manualProxy != nil &&
		proxies[svc.groupName] == svc.policyProxy &&
		proxies[svc.automaticGroup] == svc.automaticProxy &&
		proxies[svc.manualGroup] == svc.manualProxy &&
		svc.policyProxy.Type() == constant.Selector &&
		svc.automaticProxy.Type() == constant.Selector &&
		svc.manualProxy.Type() == constant.Selector
}

func ensureRoutingLeaseFreshLocked() {
	if activeRoutingLease == nil || activeRoutingLease.revoked {
		return
	}
	now := routingLeaseNow()
	if !now.Before(activeRoutingLease.deadline) || now.UnixMilli() >= activeRoutingLease.expiresAt {
		revokeRoutingLeaseObservedLocked(activeRoutingLease, true, "query_expired")
		return
	}
	proxies := tunnel.AllProxies()
	for _, svc := range activeRoutingLease.serviceOrder {
		if !serviceTopologyIntact(svc, proxies) {
			revokeRoutingLeaseObservedLocked(activeRoutingLease, true, "config_replaced")
			return
		}
	}
}

func handleGetRoutingLease() *RoutingLeaseGuard {
	selectMu.Lock()
	defer selectMu.Unlock()
	ensureRoutingLeaseFreshLocked()
	if activeRoutingLease == nil || activeRoutingLease.revoked {
		return nil
	}
	return activeRoutingLease.guard()
}

func handleInvalidateRoutingLease(guard *RoutingLeaseGuard) bool {
	selectMu.Lock()
	defer selectMu.Unlock()
	ensureRoutingLeaseFreshLocked()
	if activeRoutingLease == nil || !activeRoutingLease.matchesIdentity(guard) {
		return false
	}
	revokeActiveRoutingLeaseLocked(activeRoutingLease, true)
	return true
}

func authorizeAndResolveSelectorLocked(params *ChangeProxyParams) (selector pickableGroup, err error) {
	defer func() {
		if err != nil {
			recordLeaseObservationLocked("write_rejected", "authorization")
			return
		}
		if selector == nil || activeRoutingLease == nil {
			return
		}
		kind := "manual"
		if _, ok := activeRoutingLease.services[params.GroupName]; ok {
			kind = "automatic"
		} else if svc, ok := activeRoutingLease.policyGroups[params.GroupName]; ok && params.ProxyName == svc.automaticGroup {
			kind = "automatic"
		} else if _, ok := activeRoutingLease.manualGroups[params.GroupName]; !ok {
			if _, policy := activeRoutingLease.policyGroups[params.GroupName]; !policy {
				return
			}
		}
		selector = observedLeaseSelector{pickableGroup: selector, kind: kind}
	}()

	ensureRoutingLeaseFreshLocked()
	state := activeRoutingLease
	if state == nil {
		if params.RoutingLease != nil {
			return nil, errRoutingLeaseInvalid
		}
		return selectableGroup(params.GroupName)
	}

	proxies := tunnel.AllProxies()
	if svc, isAuto := state.services[params.GroupName]; isAuto {
		if !serviceTopologyIntact(svc, proxies) {
			revokeActiveRoutingLeaseLocked(state, false)
			return nil, errRoutingLeaseInvalidTarget
		}
		if params.RoutingLease == nil {
			if params.ProxyName != rejectProxyName {
				return nil, errRoutingLeaseRequired
			}
			state.rotateToken()
			return svc.automaticSelector, nil
		}
		if !state.matchesGuard(params.RoutingLease) {
			return nil, errRoutingLeaseInvalid
		}
		if svc.policySelector.Now() != svc.automaticGroup {
			return nil, errRoutingLeaseNotAutomatic
		}
		if params.ProxyName == rejectProxyName {
			return svc.automaticSelector, nil
		}
		candidate, allowed := svc.allowedProxies[params.ProxyName]
		if !allowed || candidate == nil || proxies[params.ProxyName] != candidate {
			return nil, errRoutingLeaseProxyNotAllowed
		}
		if !isLeaseNetworkProxy(candidate) {
			return nil, errRoutingLeaseProxyType
		}
		return svc.automaticSelector, nil
	}

	if params.RoutingLease != nil {
		return nil, errRoutingLeaseInvalid
	}
	if _, isPolicy := state.policyGroups[params.GroupName]; isPolicy {
		state.rotateToken()
	} else if _, isManual := state.manualGroups[params.GroupName]; isManual {
		state.rotateToken()
	}
	return selectableGroup(params.GroupName)
}

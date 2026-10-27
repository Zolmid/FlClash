package core

import (
	"core/clientbundle"
	"errors"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

var (
	errDispatchUnavailable    = errors.New("no dispatch bindings available")
	errDispatchOptionRequired = errors.New("optionId is required when enabling dispatch")
	errDispatchOptionUnknown  = errors.New("unknown dispatch optionId")
	errDispatchEnabledMissing = errors.New("enabled field is required")
)

type returnRouteDispatch struct {
	spec     clientbundle.ReturnDispatchSpec
	proxy    constant.Proxy
	selector pickableGroup
}

type returnRoutePolicy struct {
	spec       clientbundle.ReturnRouteSpec
	proxy      constant.Proxy
	retired    bool
	blocked    bool
	dispatches []returnRouteDispatch
	enabled    bool
	selectedID string
}

func returnRouteSelector(spec *clientbundle.ReturnRouteSpec, proxies map[string]constant.Proxy) (pickableGroup, bool) {
	if !spec.Valid() {
		return nil, false
	}
	proxy := proxies[spec.GroupName]
	if proxy == nil || proxy.Type() != constant.Selector {
		return nil, false
	}
	selector, ok := adapterAs[pickableGroup](proxy)
	group, groupOK := adapterAs[outboundgroup.ProxyGroup](proxy)
	if !ok || !groupOK {
		return nil, false
	}
	members := map[string]bool{}
	for _, member := range group.Proxies() {
		if member != nil {
			members[member.Name()] = true
		}
	}
	for _, option := range spec.Options {
		if !members[option.Target] || proxies[option.Target] == nil {
			return nil, false
		}
	}
	return selector, true
}

func installReturnRouteLocked(state *routingLeaseState, spec *clientbundle.ReturnRouteSpec, proxies map[string]constant.Proxy, prevEnabled bool, prevSelectedID string) {
	state.returnRoute = nil
	if _, ok := returnRouteSelector(spec, proxies); !ok {
		return
	}
	names := []string{spec.GroupName}
	for _, option := range spec.Options {
		names = append(names, option.Target)
	}
	for _, service := range state.serviceOrder {
		for _, name := range names {
			if name == service.groupName || name == service.automaticGroup || name == service.manualGroup {
				return
			}
		}
	}
	for _, d := range spec.Dispatches {
		for _, service := range state.serviceOrder {
			if d.GroupName == service.groupName || d.GroupName == service.automaticGroup || d.GroupName == service.manualGroup ||
				d.LocalTarget == service.groupName || d.LocalTarget == service.automaticGroup || d.LocalTarget == service.manualGroup {
				spec.Dispatches = nil
				break
			}
		}
	}
	copied := *spec
	copied.Options = append([]clientbundle.ReturnRouteOption(nil), spec.Options...)
	copied.Outbounds = append([]string(nil), spec.Outbounds...)
	copied.Dispatches = append([]clientbundle.ReturnDispatchSpec(nil), spec.Dispatches...)
	policy := &returnRoutePolicy{spec: copied, proxy: proxies[spec.GroupName]}
	if copied.ValidateDispatches() {
		policy.dispatches = installDispatchSelectorsLocked(copied.Dispatches, proxies)
	}
	if len(policy.dispatches) == 0 {
		policy.spec.Dispatches = nil
	}
	if prevEnabled && len(policy.dispatches) > 0 {
		restoreDispatchActivationLocked(policy, prevSelectedID, proxies)
	}
	state.returnRoute = policy
	normalizeReturnRouteLocked(proxies)
}

func returnRouteUsable(spec *clientbundle.ReturnRouteSpec, target string, proxies map[string]constant.Proxy) bool {
	whitelist := map[string]bool{}
	for _, name := range spec.Outbounds {
		whitelist[name] = true
	}
	visited := map[string]bool{spec.GroupName: true}
	pending := []string{target}
	for len(pending) > 0 {
		name := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		if visited[name] || !clientbundle.ReturnRouteName(name) {
			continue
		}
		visited[name] = true
		proxy := proxies[name]
		if proxy == nil {
			continue
		}
		if isLeaseNetworkProxy(proxy) && whitelist[name] {
			return true
		}
		group, ok := adapterAs[outboundgroup.ProxyGroup](proxy)
		if !ok {
			continue
		}
		for _, member := range group.Proxies() {
			if member != nil {
				pending = append(pending, member.Name())
			}
		}
	}
	return false
}

func currentReturnRouteSelector(state *routingLeaseState, proxies map[string]constant.Proxy) (pickableGroup, bool) {
	if state == nil || state.returnRoute == nil || state.returnRoute.retired || state.returnRoute.blocked ||
		proxies[state.returnRoute.spec.GroupName] != state.returnRoute.proxy {
		return nil, false
	}
	return returnRouteSelector(&state.returnRoute.spec, proxies)
}

func guardReturnDispatchReplacement(prepared *clientbundle.Prepared, previous *SetupParams) error {
	if previous == nil || previous.RoutingLease == nil {
		return nil
	}
	return guardReturnDispatchSpecReplacement(&RoutingLeaseSpec{
		AccountID: prepared.Bundle.Account, AccountGeneration: previous.RoutingLease.AccountGeneration,
		ReturnRoute: prepared.ReturnRoute,
	})
}

func guardReturnDispatchSpecReplacement(next *RoutingLeaseSpec) error {
	selectMu.Lock()
	defer selectMu.Unlock()
	state := activeRoutingLease
	if state == nil || state.returnRoute == nil || !state.returnRoute.enabled || state.returnRoute.retired ||
		next == nil || state.accountID != next.AccountID || state.accountGeneration != next.AccountGeneration {
		return nil
	}
	before, after := &state.returnRoute.spec, next.ReturnRoute
	compatible := after != nil && after.Valid() && after.ValidateDispatches() && len(after.Dispatches) == 2 && before.GroupName == after.GroupName
	if compatible {
		for _, old := range before.Dispatches {
			found := false
			for _, next := range after.Dispatches {
				found = found || old == next
			}
			compatible = compatible && found
		}
	}
	if compatible {
		return nil
	}
	if selector, ok := returnRouteSelector(before, tunnel.AllProxies()); ok {
		setSelectorRejectLocked(before.GroupName, selector)
	}
	state.returnRoute.blocked = true
	return errDispatchUnavailable
}

func returnRouteMember(spec *clientbundle.ReturnRouteSpec, target string, proxies map[string]constant.Proxy) bool {
	group, ok := adapterAs[outboundgroup.ProxyGroup](proxies[spec.GroupName])
	if !ok {
		return false
	}
	for _, member := range group.Proxies() {
		if member != nil && member.Name() == target && proxies[target] != nil {
			return true
		}
	}
	return false
}

func normalizeReturnRouteLocked(proxies map[string]constant.Proxy) {
	state := activeRoutingLease
	selector, ok := currentReturnRouteSelector(state, proxies)
	if !ok {
		return
	}
	spec := &state.returnRoute.spec
	if state.returnRoute.enabled && state.returnRoute.selectedID == "" {
		setSelectorRejectLocked(spec.GroupName, selector)
		return
	}
	current := selector.Now()
	if returnRouteMember(spec, current, proxies) &&
		(current == directProxyName || returnRouteUsable(spec, current, proxies)) {
		normalizeDispatchLocked(proxies)
		return
	}
	target := rejectProxyName
	for _, option := range spec.Options {
		if returnRouteUsable(spec, option.Target, proxies) {
			target = option.Target
			break
		}
	}
	if target == current {
		normalizeDispatchLocked(proxies)
		return
	}
	if selector.Set(target) != nil {
		normalizeDispatchLocked(proxies)
		return
	}
	closeConnectionsForSelection(spec.GroupName, selector.Now())
	normalizeDispatchLocked(proxies)
}

func returnRouteGuardLocked() *RoutingLeaseGuard {
	ensureRoutingLeaseFreshLocked()
	state := activeRoutingLease
	if _, ok := currentReturnRouteSelector(state, tunnel.AllProxies()); !ok {
		return nil
	}
	return state.identityGuard()
}

func retireReturnRouteLocked() {
	if activeRoutingLease != nil && activeRoutingLease.returnRoute != nil {
		activeRoutingLease.returnRoute.retired = true
	}
}

func authorizeReturnRouteLocked(state *routingLeaseState, params *ChangeProxyParams, proxies map[string]constant.Proxy) (pickableGroup, error) {
	selector, ok := currentReturnRouteSelector(state, proxies)
	if !ok {
		return nil, errRoutingLeaseInvalid
	}
	if params.RoutingLease != nil && (!state.matchesIdentity(params.RoutingLease) || params.RoutingLease.Token != state.token) {
		return nil, errRoutingLeaseInvalid
	}
	spec := &state.returnRoute.spec
	rr := state.returnRoute
	if rr.enabled {
		if params.ProxyName == directProxyName || params.ProxyName == rejectProxyName {
			return nil, errRoutingLeaseProxyNotAllowed
		}
		optionID := ""
		for _, opt := range spec.Options {
			if opt.Target == params.ProxyName {
				optionID = opt.ID
				break
			}
		}
		if optionID == "" {
			return nil, errRoutingLeaseProxyNotAllowed
		}
		if !returnRouteMember(spec, params.ProxyName, proxies) || !returnRouteUsable(spec, params.ProxyName, proxies) {
			return nil, errRoutingLeaseProxyNotAllowed
		}
		return dispatchSyncSelector{pickableGroup: selector, rr: rr, optionID: optionID}, nil
	}
	if !returnRouteMember(spec, params.ProxyName, proxies) {
		return nil, errRoutingLeaseProxyNotAllowed
	}
	if params.ProxyName != directProxyName && !returnRouteUsable(spec, params.ProxyName, proxies) {
		return nil, errRoutingLeaseProxyNotAllowed
	}
	return selector, nil
}

type dispatchSyncSelector struct {
	pickableGroup
	rr       *returnRoutePolicy
	optionID string
}

func (s dispatchSyncSelector) Set(name string) error {
	if err := s.pickableGroup.Set(name); err != nil {
		return err
	}
	s.rr.selectedID = s.optionID
	return nil
}

func (s dispatchSyncSelector) ForceSet(name string) {
	s.pickableGroup.ForceSet(name)
	s.rr.selectedID = s.optionID
}

func installDispatchSelectorsLocked(specs []clientbundle.ReturnDispatchSpec, proxies map[string]constant.Proxy) []returnRouteDispatch {
	if len(specs) == 0 {
		return nil
	}
	dispatches := make([]returnRouteDispatch, 0, len(specs))
	for _, d := range specs {
		proxy := proxies[d.GroupName]
		if proxy == nil || proxy.Type() != constant.Selector {
			return nil
		}
		selector, ok := adapterAs[pickableGroup](proxy)
		group, groupOK := adapterAs[outboundgroup.ProxyGroup](proxy)
		if !ok || !groupOK {
			return nil
		}
		members := map[string]bool{}
		for _, member := range group.Proxies() {
			if member != nil {
				members[member.Name()] = true
			}
		}
		if !members[d.LocalTarget] || !members[d.ReturnTarget] {
			return nil
		}
		if proxies[d.LocalTarget] == nil || proxies[d.ReturnTarget] == nil {
			return nil
		}
		// Validate local wrapper is pure DIRECT in the live proxy graph.
		if !localWrapperPureDirectProxy(d.LocalTarget, proxies) {
			return nil
		}
		dispatches = append(dispatches, returnRouteDispatch{spec: d, proxy: proxy, selector: selector})
	}
	return dispatches
}

func localWrapperPureDirectProxy(name string, proxies map[string]constant.Proxy) bool {
	visited := map[string]uint8{}
	return localWrapperWalkProxy(name, proxies, visited)
}

func localWrapperWalkProxy(name string, proxies map[string]constant.Proxy, visited map[string]uint8) bool {
	if visited[name] == 1 {
		return false
	}
	if visited[name] == 2 {
		return true
	}
	visited[name] = 1
	proxy := proxies[name]
	if proxy == nil {
		return false
	}
	if proxy.Type() == constant.Direct {
		visited[name] = 2
		return true
	}
	if isLeaseNetworkProxy(proxy) || proxy.Type() == constant.Reject || proxy.Type() == constant.RejectDrop {
		return false
	}
	group, ok := adapterAs[outboundgroup.ProxyGroup](proxy)
	if !ok || proxy.Type() != constant.Selector {
		return false
	}
	members := group.Proxies()
	if len(members) == 0 {
		return false
	}
	for _, member := range members {
		if member == nil || !localWrapperWalkProxy(member.Name(), proxies, visited) {
			return false
		}
	}
	visited[name] = 2
	return true
}

func restoreDispatchActivationLocked(policy *returnRoutePolicy, prevSelectedID string, proxies map[string]constant.Proxy) {
	policy.enabled = true
	for _, d := range policy.dispatches {
		if d.selector.Now() != d.spec.ReturnTarget {
			if err := d.selector.Set(d.spec.ReturnTarget); err == nil {
				closeConnectionsForSelection(d.spec.GroupName, d.selector.Now())
			}
		}
	}
	var target string
	for _, opt := range policy.spec.Options {
		if opt.ID == prevSelectedID {
			target = opt.Target
			break
		}
	}
	if target == "" || !returnRouteUsable(&policy.spec, target, proxies) || !returnRouteMember(&policy.spec, target, proxies) {
		policy.selectedID = ""
		return
	}
	policy.selectedID = prevSelectedID
	childProxy := proxies[policy.spec.GroupName]
	if childSelector, ok := adapterAs[pickableGroup](childProxy); ok {
		if childSelector.Now() != target {
			if err := childSelector.Set(target); err == nil {
				closeConnectionsForSelection(policy.spec.GroupName, childSelector.Now())
			}
		}
	}
}

func persistedReturnDispatchChoice(spec *clientbundle.ReturnRouteSpec, picks map[string]string) (bool, string) {
	if spec == nil || !spec.Valid() || !spec.ValidateDispatches() || len(spec.Dispatches) != 2 {
		return false, ""
	}
	for _, d := range spec.Dispatches {
		if picks[d.GroupName] != d.ReturnTarget {
			return false, ""
		}
	}
	for _, option := range spec.Options {
		if picks[spec.GroupName] == option.Target {
			return true, option.ID
		}
	}
	return true, ""
}

func dispatchForGroupLocked(state *routingLeaseState, groupName string) *returnRouteDispatch {
	if state == nil || state.returnRoute == nil || state.returnRoute.retired {
		return nil
	}
	for i := range state.returnRoute.dispatches {
		if state.returnRoute.dispatches[i].spec.GroupName == groupName {
			return &state.returnRoute.dispatches[i]
		}
	}
	return nil
}

func normalizeDispatchLocked(proxies map[string]constant.Proxy) {
	state := activeRoutingLease
	if state == nil || state.returnRoute == nil || state.returnRoute.retired || !state.returnRoute.enabled {
		return
	}
	rr := state.returnRoute
	for _, d := range rr.dispatches {
		if proxies[d.spec.GroupName] != d.proxy {
			rr.selectedID = ""
			return
		}
	}
	var target string
	for _, opt := range rr.spec.Options {
		if opt.ID == rr.selectedID {
			target = opt.Target
			break
		}
	}
	if target != "" && returnRouteUsable(&rr.spec, target, proxies) && returnRouteMember(&rr.spec, target, proxies) {
		return
	}
	rr.selectedID = ""
	if selector, ok := currentReturnRouteSelector(state, proxies); ok {
		setSelectorRejectLocked(rr.spec.GroupName, selector)
	}
}

func handleSetClientReturnRoute(params *SetClientReturnRouteParams) (*SetClientReturnRouteResult, error) {
	if params == nil || params.Enabled == nil {
		return nil, errDispatchEnabledMissing
	}

	selectMu.Lock()
	defer selectMu.Unlock()

	ensureRoutingLeaseFreshLocked()
	state := activeRoutingLease
	proxies := tunnel.AllProxies()

	if state == nil || state.returnRoute == nil || state.returnRoute.retired {
		return nil, errRoutingLeaseInvalid
	}
	if params.RoutingLease == nil || !state.matchesIdentity(params.RoutingLease) || params.RoutingLease.Token != state.token {
		return nil, errRoutingLeaseInvalid
	}

	rr := state.returnRoute
	if len(rr.dispatches) == 0 {
		return nil, errDispatchUnavailable
	}

	for _, d := range rr.dispatches {
		if proxies[d.spec.GroupName] != d.proxy || d.selector == nil {
			return nil, errRoutingLeaseInvalid
		}
	}

	childSelector, ok := currentReturnRouteSelector(state, proxies)
	if !ok {
		return nil, errRoutingLeaseInvalid
	}

	if *params.Enabled {
		return enableDispatchLocked(rr, params, childSelector, proxies)
	}
	return disableDispatchResultLocked(rr, childSelector, proxies)
}

func enableDispatchLocked(rr *returnRoutePolicy, params *SetClientReturnRouteParams, childSelector pickableGroup, proxies map[string]constant.Proxy) (*SetClientReturnRouteResult, error) {
	if params.OptionID == "" {
		return nil, errDispatchOptionRequired
	}
	var target string
	for _, opt := range rr.spec.Options {
		if opt.ID == params.OptionID {
			target = opt.Target
			break
		}
	}
	if target == "" {
		return nil, errDispatchOptionUnknown
	}
	if !returnRouteMember(&rr.spec, target, proxies) || !returnRouteUsable(&rr.spec, target, proxies) {
		return nil, errRoutingLeaseProxyNotAllowed
	}

	// Validate all dispatch parents can accept returnTarget before any writes.
	for _, d := range rr.dispatches {
		group, ok := adapterAs[outboundgroup.ProxyGroup](d.proxy)
		if !ok {
			return nil, errRoutingLeaseInvalid
		}
		found := false
		for _, m := range group.Proxies() {
			if m != nil && m.Name() == d.spec.ReturnTarget {
				found = true
				break
			}
		}
		if !found {
			return nil, errRoutingLeaseInvalid
		}
	}

	// Capture exact current values for rollback.
	childBefore := childSelector.Now()
	parentBefore := make([]string, len(rr.dispatches))
	for i, d := range rr.dispatches {
		parentBefore[i] = d.selector.Now()
	}

	// Atomic write: child first, then parents.
	if err := childSelector.Set(target); err != nil {
		return nil, err
	}
	for i, d := range rr.dispatches {
		if err := d.selector.Set(d.spec.ReturnTarget); err != nil {
			// Rollback to exact previous values.
			for j := i - 1; j >= 0; j-- {
				_ = rr.dispatches[j].selector.Set(parentBefore[j])
			}
			_ = childSelector.Set(childBefore)
			return nil, err
		}
	}

	// Commit: close connections for changed selectors.
	changed := false
	if childSelector.Now() != childBefore {
		changed = true
		closeConnectionsForSelection(rr.spec.GroupName, childSelector.Now())
	}
	for i, d := range rr.dispatches {
		if d.selector.Now() != parentBefore[i] {
			changed = true
			closeConnectionsForSelection(d.spec.GroupName, d.selector.Now())
		}
	}

	rr.enabled = true
	rr.selectedID = params.OptionID

	selections := make(map[string]string, len(rr.dispatches)+1)
	for _, d := range rr.dispatches {
		selections[d.spec.GroupName] = d.selector.Now()
	}
	selections[rr.spec.GroupName] = childSelector.Now()

	selectedID := params.OptionID
	refreshRouteLocked(false)
	return &SetClientReturnRouteResult{
		Changed:    changed,
		Enabled:    true,
		SelectedID: &selectedID,
		Selections: selections,
	}, nil
}

func disableDispatchResultLocked(rr *returnRoutePolicy, childSelector pickableGroup, proxies map[string]constant.Proxy) (*SetClientReturnRouteResult, error) {
	// Validate all parents can accept localTarget before any writes.
	for _, d := range rr.dispatches {
		group, ok := adapterAs[outboundgroup.ProxyGroup](d.proxy)
		if !ok {
			return nil, errRoutingLeaseInvalid
		}
		found := false
		for _, m := range group.Proxies() {
			if m != nil && m.Name() == d.spec.LocalTarget {
				found = true
				break
			}
		}
		if !found {
			return nil, errRoutingLeaseInvalid
		}
	}

	parentBefore := make([]string, len(rr.dispatches))
	for i, d := range rr.dispatches {
		parentBefore[i] = d.selector.Now()
	}

	for _, d := range rr.dispatches {
		if err := d.selector.Set(d.spec.LocalTarget); err != nil {
			return nil, err
		}
	}

	changed := false
	for i, d := range rr.dispatches {
		if d.selector.Now() != parentBefore[i] {
			changed = true
			closeConnectionsForSelection(d.spec.GroupName, d.selector.Now())
		}
	}

	rr.enabled = false
	rr.selectedID = ""

	selections := make(map[string]string, len(rr.dispatches))
	for _, d := range rr.dispatches {
		selections[d.spec.GroupName] = d.selector.Now()
	}

	refreshRouteLocked(false)
	return &SetClientReturnRouteResult{
		Changed:    changed,
		Enabled:    false,
		SelectedID: nil,
		Selections: selections,
	}, nil
}

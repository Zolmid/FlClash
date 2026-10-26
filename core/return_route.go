package core

import (
	"core/clientbundle"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type returnRoutePolicy struct {
	spec    clientbundle.ReturnRouteSpec
	proxy   constant.Proxy
	retired bool
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

func installReturnRouteLocked(state *routingLeaseState, spec *clientbundle.ReturnRouteSpec, proxies map[string]constant.Proxy) {
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
	copied := *spec
	copied.Options = append([]clientbundle.ReturnRouteOption(nil), spec.Options...)
	copied.Outbounds = append([]string(nil), spec.Outbounds...)
	state.returnRoute = &returnRoutePolicy{spec: copied, proxy: proxies[spec.GroupName]}
	normalizeReturnRouteLocked(proxies)
}

func returnRouteUsable(spec *clientbundle.ReturnRouteSpec, target string, proxies map[string]constant.Proxy) bool {
	whitelist := map[string]bool{}
	for _, name := range spec.Outbounds {
		whitelist[name] = true
	}
	// A role cannot borrow a sibling's exit through a cycle back to its parent.
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
	if state == nil || state.returnRoute == nil || state.returnRoute.retired ||
		proxies[state.returnRoute.spec.GroupName] != state.returnRoute.proxy {
		return nil, false
	}
	return returnRouteSelector(&state.returnRoute.spec, proxies)
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
	current := selector.Now()
	if returnRouteMember(spec, current, proxies) &&
		(current == directProxyName || returnRouteUsable(spec, current, proxies)) {
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
		return
	}
	if selector.Set(target) != nil {
		return
	}
	closeConnectionsForSelection(spec.GroupName, selector.Now())
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
	if !returnRouteMember(spec, params.ProxyName, proxies) {
		return nil, errRoutingLeaseProxyNotAllowed
	}
	if params.ProxyName != directProxyName && !returnRouteUsable(spec, params.ProxyName, proxies) {
		return nil, errRoutingLeaseProxyNotAllowed
	}
	return selector, nil
}

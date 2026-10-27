package clientbundle

import (
	"encoding/json"
	"maps"
	"strings"
)

type ReturnDispatchSpec struct {
	ID           string `json:"id"`
	GroupName    string `json:"groupName"`
	LocalTarget  string `json:"localTarget"`
	ReturnTarget string `json:"returnTarget"`
}

type ReturnRouteOption struct {
	ID     string `json:"id"`
	Target string `json:"target"`
}

type ReturnRouteSpec struct {
	GroupName  string               `json:"groupName"`
	Options    []ReturnRouteOption  `json:"options"`
	Outbounds  []string             `json:"outbounds"`
	Dispatches []ReturnDispatchSpec `json:"dispatches,omitempty"`
}

func (s *ReturnRouteSpec) UnmarshalJSON(data []byte) error {
	type plain ReturnRouteSpec
	var value plain
	if json.Unmarshal(data, &value) != nil {
		*s = ReturnRouteSpec{}
		return nil
	}
	*s = ReturnRouteSpec(value)
	return nil
}

func ReturnRouteName(name string) bool {
	lower := strings.ToLower(name)
	return SafeText(name) && lower != "direct" && lower != "reject" &&
		!strings.HasPrefix(lower, "clientzn.service.") && !strings.HasPrefix(lower, "zn.service.")
}

func (s *ReturnRouteSpec) Valid() bool {
	if s == nil || !ReturnRouteName(s.GroupName) || len(s.Options) != 3 || len(s.Outbounds) == 0 {
		return false
	}
	ids, targets := map[string]bool{}, map[string]bool{}
	for _, option := range s.Options {
		if !contains([]string{"direct", "hk_lite", "hk_optimized"}, option.ID) || ids[option.ID] ||
			!ReturnRouteName(option.Target) || option.Target == s.GroupName || targets[option.Target] {
			return false
		}
		ids[option.ID], targets[option.Target] = true, true
	}
	names := map[string]bool{}
	for _, name := range s.Outbounds {
		if !ReturnRouteName(name) || names[name] {
			return false
		}
		names[name] = true
	}
	return true
}

var validDispatchIDs = map[string]bool{
	"return_dispatch":       true,
	"return_media_dispatch": true,
}

func (s *ReturnRouteSpec) ValidateDispatches() bool {
	if s == nil || len(s.Dispatches) == 0 {
		return true
	}
	if len(s.Dispatches) != 2 {
		return false
	}
	reserved := map[string]bool{s.GroupName: true}
	for _, opt := range s.Options {
		reserved[opt.Target] = true
	}
	seenIDs := map[string]bool{}
	dispatchGroups := map[string]bool{}
	for _, d := range s.Dispatches {
		if !validDispatchIDs[d.ID] || seenIDs[d.ID] {
			return false
		}
		seenIDs[d.ID] = true
		if d.GroupName == "" || d.LocalTarget == "" || d.ReturnTarget == "" {
			return false
		}
		if !ReturnRouteName(d.GroupName) || !ReturnRouteName(d.LocalTarget) || !ReturnRouteName(d.ReturnTarget) {
			return false
		}
		if d.LocalTarget == d.ReturnTarget || d.LocalTarget == d.GroupName {
			return false
		}
		if d.ReturnTarget != s.GroupName {
			return false
		}
		if reserved[d.GroupName] || reserved[d.LocalTarget] || dispatchGroups[d.GroupName] {
			return false
		}
		dispatchGroups[d.GroupName] = true
	}
	if dispatchGroups[s.Dispatches[0].LocalTarget] || dispatchGroups[s.Dispatches[1].LocalTarget] {
		return false
	}
	return true
}

// LocalWrapperPureDirect validates that a local wrapper proxy, resolved through
// the given groups map, is a tree of nested selects whose every leaf is DIRECT.
func LocalWrapperPureDirect(name string, groups map[string]groupInfo) bool {
	visited := map[string]uint8{}
	return localWrapperWalk(name, groups, visited)
}

type groupInfo struct {
	Type    string
	Members []string
}

func localWrapperWalk(name string, groups map[string]groupInfo, visited map[string]uint8) bool {
	if visited[name] == 1 {
		return false
	}
	if visited[name] == 2 || name == "DIRECT" {
		return true
	}
	visited[name] = 1
	g, ok := groups[name]
	if !ok {
		return false
	}
	if g.Type != "select" {
		return false
	}
	if len(g.Members) == 0 {
		return false
	}
	for _, member := range g.Members {
		if !localWrapperWalk(member, groups, visited) {
			return false
		}
	}
	visited[name] = 2
	return true
}

func prepareReturnRoute(raw json.RawMessage, bundle *Bundle, groups []any) *ReturnRouteSpec {
	var roles []struct {
		ID      string              `json:"id"`
		Group   string              `json:"group"`
		Options []ReturnRouteOption `json:"options"`
	}
	if json.Unmarshal(raw, &roles) != nil {
		return nil
	}
	var result *ReturnRouteSpec
	for _, role := range roles {
		if role.ID != "return_route" {
			continue
		}
		if result != nil {
			return nil
		}
		result = &ReturnRouteSpec{GroupName: role.Group, Options: role.Options}
	}
	if result == nil {
		return nil
	}
	for _, outbound := range bundle.Outbounds {
		result.Outbounds = append(result.Outbounds, outbound.Name)
	}
	if !result.Valid() {
		return nil
	}
	var dispatches []ReturnDispatchSpec
	seenDispatchIDs := map[string]bool{}
	for _, role := range roles {
		if !validDispatchIDs[role.ID] {
			continue
		}
		if seenDispatchIDs[role.ID] {
			dispatches = nil
			break
		}
		seenDispatchIDs[role.ID] = true
		if len(role.Options) != 2 {
			dispatches = nil
			break
		}
		var localTarget, returnTarget string
		for _, opt := range role.Options {
			switch opt.ID {
			case "local":
				localTarget = opt.Target
			case "return":
				returnTarget = opt.Target
			}
		}
		if localTarget == "" || returnTarget == "" {
			dispatches = nil
			break
		}
		dispatches = append(dispatches, ReturnDispatchSpec{
			ID:           role.ID,
			GroupName:    role.Group,
			LocalTarget:  localTarget,
			ReturnTarget: returnTarget,
		})
	}
	if len(dispatches) == 2 {
		result.Dispatches = dispatches
	}
	if !result.ValidateDispatches() {
		result.Dispatches = nil
	}
	// Validate dispatch selectors exist as select groups in config.
	groupMap := map[string]groupInfo{}
	for _, raw := range groups {
		group, _ := raw.(map[string]any)
		name, _ := group["name"].(string)
		gType, _ := group["type"].(string)
		var members []string
		switch raw := group["proxies"].(type) {
		case []any:
			for _, v := range raw {
				if s, ok := v.(string); ok {
					members = append(members, s)
				}
			}
		case []string:
			members = raw
		}
		if name != "" {
			groupMap[name] = groupInfo{Type: gType, Members: members}
		}
	}
	for _, d := range result.Dispatches {
		g, ok := groupMap[d.GroupName]
		if !ok || g.Type != "select" {
			result.Dispatches = nil
			break
		}
		if !LocalWrapperPureDirect(d.LocalTarget, groupMap) {
			result.Dispatches = nil
			break
		}
	}
	names := map[string]bool{"DIRECT": true, "REJECT": true}
	for _, name := range result.Outbounds {
		names[name] = true
	}
	var selector map[string]any
	for _, raw := range groups {
		group, _ := raw.(map[string]any)
		name, _ := group["name"].(string)
		names[name] = true
		if name == result.GroupName {
			selector = group
		}
	}
	if selector == nil || selector["type"] != "select" {
		return nil
	}
	members := map[string]bool{}
	rawMembers, ok := selector["proxies"].([]any)
	if !ok {
		return nil
	}
	for _, raw := range rawMembers {
		name, _ := raw.(string)
		members[name] = true
	}
	for _, option := range result.Options {
		if !members[option.Target] || !names[option.Target] {
			return nil
		}
	}
	return result
}

func WithReturnRouteReject(groups []map[string]any, spec *ReturnRouteSpec) []map[string]any {
	if !spec.Valid() {
		return groups
	}
	for index, group := range groups {
		if group["name"] != spec.GroupName || group["type"] != "select" {
			continue
		}
		var members []string
		switch raw := group["proxies"].(type) {
		case []string:
			members = append(members, raw...)
		case []any:
			for _, value := range raw {
				name, ok := value.(string)
				if !ok {
					return groups
				}
				members = append(members, name)
			}
		default:
			return groups
		}
		for _, option := range spec.Options {
			if !contains(members, option.Target) {
				return groups
			}
		}
		if contains(members, "REJECT") {
			return groups
		}
		copied := append([]map[string]any(nil), groups...)
		copied[index] = maps.Clone(group)
		copied[index]["proxies"] = append(members, "REJECT")
		return copied
	}
	return groups
}

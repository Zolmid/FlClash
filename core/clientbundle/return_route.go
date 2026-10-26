package clientbundle

import (
	"encoding/json"
	"maps"
	"strings"
)

type ReturnRouteOption struct {
	ID     string `json:"id"`
	Target string `json:"target"`
}

type ReturnRouteSpec struct {
	GroupName string              `json:"groupName"`
	Options   []ReturnRouteOption `json:"options"`
	Outbounds []string            `json:"outbounds"`
}

// Optional client metadata must not invalidate the independent automatic lease.
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

// Only the prepared app configuration receives the blocking member, never v1 source bytes.
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

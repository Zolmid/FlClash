package clientbundle

import (
	"bytes"
	"encoding/json"
	"go.yaml.in/yaml/v3"
	"os"
	"testing"
	"time"
)

func TestPrepareReturnRouteUsesProducerMappingsAndAllDeliveredNames(t *testing.T) {
	body, err := os.ReadFile("../../packages/zolnit_client/test/fixtures/ui-groups-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	envelope, _ := json.Marshal(map[string]json.RawMessage{"data": body})
	prepared, code := Prepare(envelope, "account-1", "{}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	policy := prepared.ReturnRoute
	if !policy.Valid() || len(policy.Outbounds) != len(prepared.Bundle.Outbounds) {
		t.Fatal("missing complete optional policy")
	}
	for i, outbound := range prepared.Bundle.Outbounds {
		if policy.Outbounds[i] != outbound.Name {
			t.Fatal("whitelist did not come from delivered outbounds")
		}
	}
	var data map[string]any
	_ = json.Unmarshal(body, &data)
	if prepared.Bundle.Connection.Document != data["connection"].(map[string]any)["document"] {
		t.Fatal("Prepare changed v1 document bytes")
	}
	var app map[string]any
	if yaml.Unmarshal(prepared.Document, &app) != nil {
		t.Fatal("invalid prepared app config")
	}
	found := false
	for _, raw := range app["proxy-groups"].([]any) {
		group := raw.(map[string]any)
		if group["name"] == policy.GroupName {
			for _, name := range group["proxies"].([]any) {
				found = found || name == "REJECT"
			}
		}
	}
	if !found {
		t.Fatal("prepared app config has no real blocking member")
	}
	snapshot := append([]byte(nil), body...)
	_, code = Prepare(envelope, "account-1", "{}", time.Unix(1001, 0))
	if code != "" || !bytes.Equal(body, snapshot) {
		t.Fatal("Prepare mutated source input")
	}

	routing := data["routing"].(map[string]any)
	original := routing["ui_groups"]
	for _, bad := range []any{nil, 42, "bad", []any{}, []any{map[string]any{"id": "return_route", "group": policy.GroupName, "options": "bad"}}} {
		routing["ui_groups"] = bad
		changed, _ := json.Marshal(map[string]any{"data": data})
		next, code := Prepare(changed, "account-1", "{}", time.Unix(1001, 0))
		if code != "" || next.ReturnRoute != nil || len(next.Services) != len(prepared.Services) {
			t.Fatal("optional malformed mapping broke independent lease")
		}
	}
	routing["ui_groups"] = original
	groups := routing["ui_groups"].([]any)
	role := groups[0].(map[string]any)
	options := role["options"].([]any)
	options[1].(map[string]any)["target"] = "DIRECT"
	changed, _ := json.Marshal(map[string]any{"data": data})
	next, code := Prepare(changed, "account-1", "{}", time.Unix(1001, 0))
	if code != "" || next.ReturnRoute != nil {
		t.Fatal("reserved option was partially accepted")
	}
}

func TestReturnRouteRejectPreparationCopiesOnlyValidatedSelector(t *testing.T) {
	spec := &ReturnRouteSpec{GroupName: "return", Options: []ReturnRouteOption{{ID: "direct", Target: "a"}, {ID: "hk_lite", Target: "b"}, {ID: "hk_optimized", Target: "c"}}, Outbounds: []string{"leaf"}}
	members := []any{"a", "b", "c"}
	groups := []map[string]any{{"name": "return", "type": "select", "proxies": members}, {"name": "manual", "type": "select", "proxies": []any{"DIRECT"}}}
	before, _ := json.Marshal(groups)
	app := WithReturnRouteReject(groups, spec)
	after, _ := json.Marshal(groups)
	if !bytes.Equal(before, after) || len(app[0]["proxies"].([]string)) != 4 || app[1]["proxies"].([]any)[0] != "DIRECT" {
		t.Fatal("preparation changed source or unrelated selector")
	}
	twice := WithReturnRouteReject(app, spec)
	if len(twice[0]["proxies"].([]string)) != 4 {
		t.Fatal("blocking member duplicated")
	}
	for _, name := range []string{"direct", "DiReCt", "reject", "ReJeCt", "zn.service.ai", "zn.service.ai.manual", "clientzn.service.ai.manual"} {
		if ReturnRouteName(name) {
			t.Fatal("reserved or managed name accepted")
		}
	}
	invalid := *spec
	invalid.Options = nil
	unchanged := WithReturnRouteReject(groups, &invalid)
	encoded, _ := json.Marshal(unchanged)
	if !bytes.Equal(encoded, before) {
		t.Fatal("malformed optional policy changed config")
	}
}

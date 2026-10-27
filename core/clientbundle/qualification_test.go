package clientbundle

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"go.yaml.in/yaml/v3"
)

func qualificationFixture(t *testing.T) (map[string]any, map[string]any, map[string]any, map[string]any) {
	t.Helper()
	var root map[string]any
	if err := json.Unmarshal(fixture(t), &root); err != nil {
		t.Fatal(err)
	}
	data := root["data"].(map[string]any)
	routing := data["routing"].(map[string]any)
	node := routing["nodes"].([]any)[1].(map[string]any)
	routing["nodes"] = []any{node}
	outbound := data["outbounds"].([]any)[2].(map[string]any)
	outbound["configuration_fingerprint"] = strings.Repeat("a", 64)
	egress := node["final_egress"].(map[string]any)
	egress["source"] = "operator_allowlist"
	egress["configuration_fingerprint"] = strings.Repeat("a", 64)
	return root, data, node, outbound
}

func prepareQualification(t *testing.T, root map[string]any, at int64) *Prepared {
	t.Helper()
	body, err := json.Marshal(root)
	if err != nil {
		t.Fatal(err)
	}
	prepared, code := Prepare(body, "account-1", "{}", time.Unix(at, 0))
	if code != "" {
		t.Fatal(code)
	}
	return prepared
}

func assertQualification(t *testing.T, prepared *Prepared, allowed bool) {
	t.Helper()
	if len(prepared.Services[0].AllowedProxies) != 0 && !allowed || len(prepared.Services[0].AllowedProxies) != 1 && allowed {
		t.Fatalf("unexpected AI candidates: %v", prepared.Services[0].AllowedProxies)
	}
	var config map[string]any
	if err := yaml.Unmarshal(prepared.Document, &config); err != nil {
		t.Fatal(err)
	}
	for _, raw := range config["proxy-groups"].([]any) {
		g := raw.(map[string]any)
		if g["name"] == "zn.service.ai.manual" {
			names := g["proxies"].([]any)
			if len(names) != 4 || names[3] != "DIRECT" {
				t.Fatal("manual authorization or DIRECT lost")
			}
			return
		}
	}
	t.Fatal("manual group missing")
}

func TestOperatorAllowlistQualification(t *testing.T) {
	for _, country := range []string{"JP", "SG", "US"} {
		t.Run(country, func(t *testing.T) {
			root, _, node, _ := qualificationFixture(t)
			node["final_egress"].(map[string]any)["country"] = country
			assertQualification(t, prepareQualification(t, root, 1001), true)
		})
	}
	for _, source := range []string{"operator_verified", "egress_probe"} {
		t.Run(source, func(t *testing.T) {
			root, _, node, outbound := qualificationFixture(t)
			egress := node["final_egress"].(map[string]any)
			egress["source"] = source
			delete(egress, "configuration_fingerprint")
			delete(outbound, "configuration_fingerprint")
			assertQualification(t, prepareQualification(t, root, 1001), true)
		})
	}
	for _, bad := range []any{nil, "", strings.Repeat("A", 64), strings.Repeat("a", 63), strings.Repeat("a", 64) + "\n", strings.Repeat("b", 64), 42} {
		for _, side := range []string{"proof", "outbound"} {
			t.Run(side, func(t *testing.T) {
				root, _, node, outbound := qualificationFixture(t)
				target := node["final_egress"].(map[string]any)
				if side == "outbound" {
					target = outbound
				}
				target["configuration_fingerprint"] = bad
				assertQualification(t, prepareQualification(t, root, 1001), false)
			})
		}
	}
}

func TestOperatorAllowlistFiltersAndStructuralBindings(t *testing.T) {
	for _, patch := range []func(map[string]any, map[string]any){
		func(n, e map[string]any) { e["country"] = "HK" },
		func(n, e map[string]any) { e["country"] = "DE" },
		func(n, e map[string]any) { e["verified"] = false },
		func(n, e map[string]any) { n["enabled"] = false },
		func(n, e map[string]any) { n["revision"] = "" },
		func(n, e map[string]any) { n["revision"] = " padded" },
		func(n, e map[string]any) { n["services"] = []string{"media"} },
		func(n, e map[string]any) { n["services"] = []string{"unknown"} },
	} {
		root, _, node, _ := qualificationFixture(t)
		patch(node, node["final_egress"].(map[string]any))
		assertQualification(t, prepareQualification(t, root, 1001), false)
	}
	for _, patch := range []func(map[string]any){
		func(n map[string]any) { n["id"] = "unknown:1" },
		func(n map[string]any) { n["proxy_name"] = "wrong" },
		func(n map[string]any) { n["failure_domain"] = "" },
	} {
		root, _, node, _ := qualificationFixture(t)
		patch(node)
		body, _ := json.Marshal(root)
		if _, code := Prepare(body, "account-1", "{}", time.Unix(1001, 0)); code == "" {
			t.Fatal("invalid structural binding accepted")
		}
	}
	root, _, _, _ := qualificationFixture(t)
	body, _ := json.Marshal(root)
	if _, code := Prepare(body, "other", "{}", time.Unix(1001, 0)); code == "" {
		t.Fatal("cross-account bundle accepted")
	}
}

func TestOperatorAllowlistFingerprintDigestAndLease(t *testing.T) {
	root, data, node, outbound := qualificationFixture(t)
	before := prepareQualification(t, root, 1001)
	outbound["configuration_fingerprint"] = strings.Repeat("b", 64)
	after := prepareQualification(t, root, 1001)
	assertQualification(t, after, false)
	if before.MetadataDigest == after.MetadataDigest || before.Bundle.Connection.SHA != after.Bundle.Connection.SHA {
		t.Fatal("fingerprint-only change not bound into metadata digest")
	}
	outbound["configuration_fingerprint"] = strings.Repeat("a", 64)
	node["final_egress"].(map[string]any)["verified_at"] = 1
	original := prepareQualification(t, root, 1001)
	later := int64(1001 + 10*86400)
	data["issued_at"] = later
	data["expires_at"] = later + 300
	renewed := prepareQualification(t, root, later)
	assertQualification(t, renewed, true)
	if original.MetadataDigest != renewed.MetadataDigest {
		t.Fatal("lease renewal changed qualification")
	}
	body, _ := json.Marshal(root)
	if _, code := Prepare(body, "account-1", "{}", time.Unix(later+300, 0)); code == "" {
		t.Fatal("expired bundle accepted")
	}
}

func TestQualificationMetadataDigestInterop(t *testing.T) {
	legacy, code := Prepare(fixture(t), "account-1", "{}", time.Unix(1001, 0))
	if code != "" || legacy.MetadataDigest != "6c6bac0952112c0e3373512b12a085c149a7e5211f3e3dd6df83216f3e33a502" {
		t.Fatal("legacy digest changed", code)
	}
	root, _, _, _ := qualificationFixture(t)
	if prepareQualification(t, root, 1001).MetadataDigest != "01ebb7bc1cd8ea2600c3aae1718f05f31dea44fc5be4ef2282ebb0079a98af58" {
		t.Fatal("fingerprint digest differs from Dart")
	}
}

package clientbundle

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"go.yaml.in/yaml/v3"
)

func fixture(t *testing.T) []byte {
	t.Helper()
	body, err := os.ReadFile("../../packages/zolnit_client/test/fixtures/client-bundle-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	return body
}

func TestPreparePreservesManualAndAppPreferencesWithoutInventingQualifications(t *testing.T) {
	body := fixture(t)
	prepared, code := Prepare(body, "account-1", "{\"mixed-port\":0,\"rules\":[\"DOMAIN,local.test,DIRECT\"]}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	var config map[string]any
	if err := yaml.Unmarshal(prepared.Document, &config); err != nil {
		t.Fatal(err)
	}
	if config["mixed-port"] != 0 || config["rules"].([]any)[0] != "DOMAIN,local.test,DIRECT" {
		t.Fatal("application preferences or additional rules lost")
	}
	var ai []string
	for _, service := range prepared.Services {
		if strings.Contains(service.GroupName, ".ai") {
			ai = service.AllowedProxies
		}
	}
	if contains(ai, "zn.node.hysteria.8") {
		t.Fatal("Hong Kong node received AI permission")
	}
	var root map[string]any
	if err := json.Unmarshal(body, &root); err != nil {
		t.Fatal(err)
	}
	data := root["data"].(map[string]any)
	data["expires_at"] = 1010
	data["routing"].(map[string]any)["nodes"] = []any{}
	empty, _ := json.Marshal(root)
	prepared, code = Prepare(empty, "account-1", "{\"rules\":[]}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	for _, service := range prepared.Services {
		if len(service.AllowedProxies) != 0 {
			t.Fatal("missing server qualification was inferred locally")
		}
	}
	if prepared.Bundle.Expires != 1010 {
		t.Fatal("short server TTL was extended")
	}
}

func TestParseRejectsDuplicateJSONAndAccountOrTTLChanges(t *testing.T) {
	body := fixture(t)
	duplicate := strings.Replace(string(body), "\"data\": {", "\"data\":{},\"data\": {", 1)
	if _, code := Parse([]byte(duplicate), "account-1", time.Unix(1001, 0)); code != "invalid_input" {
		t.Fatal("duplicate JSON was accepted")
	}
	if _, code := Parse(body, "other-account", time.Unix(1001, 0)); code == "" {
		t.Fatal("cross-account response accepted")
	}
	if _, code := Parse(body, "account-1", time.Unix(1300, 0)); code == "" {
		t.Fatal("expired response accepted")
	}
}

func TestPrepareRetainsSourceDNSAcrossRenewalOverlay(t *testing.T) {
	var root map[string]any
	if err := json.Unmarshal(fixture(t), &root); err != nil {
		t.Fatal(err)
	}
	connection := root["data"].(map[string]any)["connection"].(map[string]any)
	var source map[string]any
	if err := yaml.Unmarshal([]byte(connection["document"].(string)), &source); err != nil {
		t.Fatal(err)
	}
	source["dns"] = map[string]any{
		"x-zolnit-managed-doh": 1,
		"enable":               true,
		"nameserver":           []string{"https://dns.example/dns-query"},
		"nameserver-policy":    map[string]any{"+.lan": []string{"system://"}},
	}
	document, err := yaml.Marshal(source)
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(document)
	connection["document"], connection["sha256"] = string(document), fmt.Sprintf("%x", sum)
	body, err := json.Marshal(root)
	if err != nil {
		t.Fatal(err)
	}
	baseline, code := Prepare(body, "account-1", "{}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	inherited, code := Prepare(body, "account-1", `{"dns":{"nameserver-policy":{"+.corp.example":["10.0.0.53"]}}}`, time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	var merged map[string]any
	if err := yaml.Unmarshal(inherited.Document, &merged); err != nil {
		t.Fatal(err)
	}
	policy := merged["dns"].(map[string]any)["nameserver-policy"].(map[string]any)
	if len(policy) != 2 || policy["+.corp.example"].([]any)[0] != "10.0.0.53" {
		t.Fatalf("inherited policy: %v", policy)
	}
	changed, code := Prepare(body, "account-1", `{"dns":{"enable":false,"nameserver":["system://"],"listen":""}}`, time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	var before, after map[string]any
	if err := yaml.Unmarshal(baseline.Document, &before); err != nil {
		t.Fatal(err)
	}
	if err := yaml.Unmarshal(changed.Document, &after); err != nil {
		t.Fatal(err)
	}
	beforeDNS, beforeOK := before["dns"].(map[string]any)
	afterDNS, afterOK := after["dns"].(map[string]any)
	if !beforeOK || !afterOK {
		t.Fatal("source DNS missing")
	}
	delete(beforeDNS, "listen")
	if afterDNS["listen"] != "" {
		t.Fatal("safe mode listener not disabled")
	}
	delete(afterDNS, "listen")
	a, _ := json.Marshal(beforeDNS)
	b, _ := json.Marshal(afterDNS)
	if string(a) != string(b) {
		t.Fatal("renewal overlay changed source DNS")
	}
}

func TestLegacyDNSOverlayCannotForgeManagedVersion(t *testing.T) {
	prepared, code := Prepare(fixture(t), "account-1", `{"dns":{"x-zolnit-managed-doh":1,"enable":false,"nameserver":["system://"]}}`, time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	var config map[string]any
	if err := yaml.Unmarshal(prepared.Document, &config); err != nil {
		t.Fatal(err)
	}
	dns := config["dns"].(map[string]any)
	if _, exists := dns["x-zolnit-managed-doh"]; exists || dns["enable"] != false {
		t.Fatalf("legacy overlay: %v", dns)
	}
	if dns["nameserver"].([]any)[0] != "system://" {
		t.Fatal("legacy setting not preserved")
	}
}

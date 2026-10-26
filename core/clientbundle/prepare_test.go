package clientbundle

import (
	"encoding/json"
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

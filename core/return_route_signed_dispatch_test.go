package core

import (
	"core/clientbundle"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"testing"

	"go.yaml.in/yaml/v3"
)

func signedDispatchBundle(t *testing.T, envelope string, serial int) string {
	t.Helper()
	var body, outer map[string]any
	if json.Unmarshal(returnInstallBody(t, false), &body) != nil || json.Unmarshal([]byte(envelope), &outer) != nil {
		t.Fatal("fixture decode")
	}
	data := body["data"].(map[string]any)
	routing := data["routing"].(map[string]any)
	roles := routing["ui_groups"].([]any)
	returnGroup := roles[0].(map[string]any)["group"].(string)
	for _, id := range []string{"return_dispatch", "return_media_dispatch"} {
		roles = append(roles, map[string]any{"id": id, "group": "fixture." + id, "options": []any{map[string]any{"id": "local", "target": "fixture.local"}, map[string]any{"id": "return", "target": returnGroup}}})
	}
	routing["ui_groups"] = roles
	connection := data["connection"].(map[string]any)
	var document map[string]any
	if yaml.Unmarshal([]byte(connection["document"].(string)), &document) != nil {
		t.Fatal("document decode")
	}
	groups := document["proxy-groups"].([]any)
	groups = append(groups, map[string]any{"name": "fixture.local", "type": "select", "proxies": []any{"DIRECT"}})
	for _, id := range []string{"return_dispatch", "return_media_dispatch"} {
		groups = append(groups, map[string]any{"name": "fixture." + id, "type": "select", "proxies": []any{"fixture.local", returnGroup}})
	}
	document["proxy-groups"] = groups
	document["rules"] = []any{"MATCH,fixture.return_dispatch"}
	encoded, err := yaml.Marshal(document)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(encoded)
	connection["document"], connection["sha256"] = string(encoded), hex.EncodeToString(hash[:])
	signed := outer["signed"].(map[string]any)
	raw, err := base64.RawURLEncoding.DecodeString(signed["payload"].(string))
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]any
	if json.Unmarshal(raw, &fields) != nil {
		t.Fatal("payload decode")
	}
	for _, name := range []string{"connection", "outbounds", "routing"} {
		fields[name] = data[name]
	}
	fields["serial"] = serial
	delete(fields, "bundle_id")
	preimage, err := json.Marshal(fields)
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(preimage)
	id := hex.EncodeToString(sum[:])
	payload := append(preimage[:len(preimage)-1], []byte(`,"bundle_id":"`+id+`"}`)...)
	sig := ed25519.Sign(signedTestKey(), append([]byte(clientbundle.SignedPrefix), payload...))
	outer["serial"], outer["bundle_id"] = serial, id
	outer["signed"] = map[string]string{"kid": "rfc8032-test", "payload": base64.RawURLEncoding.EncodeToString(payload), "signature": base64.RawURLEncoding.EncodeToString(sig)}
	result, err := json.Marshal(outer)
	if err != nil {
		t.Fatal(err)
	}
	return string(result)
}

func TestSignedReturnDispatchRenewal(t *testing.T) {
	if os.Getenv("ZOLNIT_SIGNED_DISPATCH_CHILD") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestSignedReturnDispatchRenewal$", "-test.timeout=30s")
		cmd.Env = append(os.Environ(), "ZOLNIT_SIGNED_DISPATCH_CHILD=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("signed dispatch: %v\n%s", err, output)
		}
		return
	}
	params, fixtures := signedHome(t)
	initial := signedDispatchBundle(t, fixtures["bundle1"], 1)
	renewed := signedDispatchBundle(t, fixtures["bundle2"], 2)
	if _, err := applySigned(t, initial); err != nil {
		t.Fatal("apply signed initial", err)
	}
	owner, err := handleBeginClientBundleOwner(params)
	if err != nil {
		t.Fatal(err)
	}
	result, err := handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 1, DeviceID: signedTestDevice})
	if err != nil || !result.Installed {
		t.Fatal("install signed initial", result, err)
	}
	guard := handleGetClientBundleOwner().ReturnRouteGuard
	if _, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{RoutingLease: guard, Enabled: boolPtr(true), OptionID: "hk_lite"}); err != nil {
		t.Fatal("enable", err)
	}
	if _, err := applySigned(t, renewed); err != nil {
		t.Fatal("apply signed renewal", err)
	}
	result, err = handleInstallSignedClientBundle(&InstallSignedClientBundleParams{Owner: owner, Sequence: 2, DeviceID: signedTestDevice})
	if err != nil || !result.Installed {
		t.Fatal("install signed renewal", result, err)
	}
	rr := activeRoutingLease.returnRoute
	if rr == nil || !rr.enabled || rr.selectedID != "hk_lite" || len(rr.dispatches) != 2 {
		t.Fatal("signed renewal lost dispatch state")
	}
	for _, d := range rr.dispatches {
		if d.selector.Now() != rr.spec.GroupName {
			t.Fatal("signed renewal reset dispatch")
		}
	}
}

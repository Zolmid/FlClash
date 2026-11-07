package clientbundle

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"testing"
	"time"
)

const (
	testAccount = "account-1"
	testDevice  = "0123456789abcdef0123456789abcdef"
	rfc8032Seed = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
	rfc8032Key  = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
)

type pair struct {
	key   string
	value any
}

func encodePairs(t *testing.T, pairs []pair) []byte {
	t.Helper()
	out := []byte{'{'}
	for index, p := range pairs {
		if index > 0 {
			out = append(out, ',')
		}
		var buffer bytes.Buffer
		enc := json.NewEncoder(&buffer)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(p.key); err != nil {
			t.Fatal(err)
		}
		if raw, ok := p.value.(json.RawMessage); ok {
			buffer.WriteString(":")
			buffer.Write(raw)
		} else {
			buffer.WriteString(":")
			if err := enc.Encode(p.value); err != nil {
				t.Fatal(err)
			}
		}
		out = append(out, bytes.ReplaceAll(buffer.Bytes(), []byte("\n"), nil)...)
	}
	return append(out, '}')
}

func testKey(t *testing.T) ed25519.PrivateKey {
	seed, _ := hex.DecodeString(rfc8032Seed)
	key := ed25519.NewKeyFromSeed(seed)
	if hex.EncodeToString(key.Public().(ed25519.PublicKey)) != rfc8032Key {
		t.Fatal("RFC 8032 public vector mismatch")
	}
	return key
}

func testTrust(t *testing.T) *Trust {
	t.Helper()
	public := testKey(t).Public().(ed25519.PublicKey)
	trust, err := ParseTrust([]byte(`{"public_key_map":{"rfc8032-test":"` + base64.RawURLEncoding.EncodeToString(public) + `"}}`))
	if err != nil {
		t.Fatal(err)
	}
	return trust
}

func v2Material(t *testing.T) []pair {
	t.Helper()
	var root struct {
		Data map[string]json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(fixture(t), &root); err != nil {
		t.Fatal(err)
	}
	var routing map[string]any
	if err := json.Unmarshal(root.Data["routing"], &routing); err != nil {
		t.Fatal(err)
	}
	for _, node := range routing["nodes"].([]any) {
		entry := node.(map[string]any)
		entry["valid_until"] = nil
		if entry["id"] == "hysteria:8" {
			entry["valid_until"] = 2000
		}
	}
	return []pair{{"connection", root.Data["connection"]}, {"outbounds", root.Data["outbounds"]}, {"routing", routing}}
}

type signSpec struct {
	kind     string
	serial   int64
	issued   int64
	expires  *int64
	material []pair
	account  string
}

func expiry(value int64) *int64 { return &value }

// sign mirrors SubscriptionSigner::seal: material first, binding fields next,
// bundle_id appended last over the encoding without it.
func sign(t *testing.T, spec signSpec) []byte {
	t.Helper()
	if spec.account == "" {
		spec.account = testAccount
	}
	var expires any
	if spec.expires != nil {
		expires = *spec.expires
	}
	pairs := append(append([]pair{}, spec.material...),
		pair{"schema_version", 2}, pair{"issuer", SignedIssuer}, pair{"audience", SignedAudience},
		pair{"kind", spec.kind}, pair{"account_id", spec.account}, pair{"device_id", testDevice},
		pair{"serial", spec.serial}, pair{"issued_at", spec.issued}, pair{"expires_at", expires})
	preimage := encodePairs(t, pairs)
	sum := sha256.Sum256(preimage)
	id := hex.EncodeToString(sum[:])
	payload := append(bytes.Clone(preimage[:len(preimage)-1]), []byte(`,"bundle_id":"`+id+`"}`)...)
	return envelopeFor(t, payload, []pair{{"schema_version", 2}, {"kind", spec.kind}, {"account_id", spec.account},
		{"device_id", testDevice}, {"serial", spec.serial}, {"issued_at", spec.issued}, {"expires_at", expires}, {"bundle_id", id}})
}

func envelopeFor(t *testing.T, payload []byte, mirrors []pair) []byte {
	t.Helper()
	signature := ed25519.Sign(testKey(t), append([]byte(SignedPrefix), payload...))
	return encodePairs(t, append(mirrors, pair{"signed", map[string]string{"kid": "rfc8032-test",
		"payload":   base64.RawURLEncoding.EncodeToString(payload),
		"signature": base64.RawURLEncoding.EncodeToString(signature)}}))
}

func bundle(t *testing.T, serial, issued int64, expires *int64) []byte {
	return sign(t, signSpec{kind: "bundle", serial: serial, issued: issued, expires: expires, material: v2Material(t)})
}

func state(t *testing.T, serial, issued int64, expires *int64, current string, refresh bool) []byte {
	return sign(t, signSpec{kind: "state", serial: serial, issued: issued, expires: expires,
		material: []pair{{"current_bundle_id", current}, {"needs_refresh", refresh}}})
}

func phpFixtures(t *testing.T) map[string]json.RawMessage {
	t.Helper()
	content, err := os.ReadFile("testdata/signed-v2-php.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixtures map[string]json.RawMessage
	if err := json.Unmarshal(content, &fixtures); err != nil {
		t.Fatal(err)
	}
	return fixtures
}

func TestVerifiesEnvelopesProducedByThePHPSigner(t *testing.T) {
	fixtures := phpFixtures(t)
	var public string
	_ = json.Unmarshal(fixtures["public_key"], &public)
	key, _ := base64.RawURLEncoding.DecodeString(public)
	if hex.EncodeToString(key) != rfc8032Key {
		t.Fatal("PHP fixture is not signed by the RFC 8032 public vector")
	}
	trust := testTrust(t)
	two, err := VerifyEnvelope(trust, fixtures["bundle2"], testAccount, testDevice)
	if err != nil || two.Kind != "bundle" || two.Serial != 2 || two.IssuedAt != 1100 || *two.ExpiresAt != 200000 {
		t.Fatal(err, two)
	}
	unlimited, err := VerifyEnvelope(trust, fixtures["unlimited"], testAccount, testDevice)
	if err != nil || unlimited.ExpiresAt != nil {
		t.Fatal("unlimited entitlement rejected", err)
	}
	current, err := VerifyEnvelope(trust, fixtures["state2"], testAccount, testDevice)
	if err != nil || current.Kind != "state" || current.CurrentBundleID != two.BundleID || current.NeedsRefresh {
		t.Fatal("state package", err)
	}
	revoked, err := VerifyEnvelope(trust, fixtures["revoked3"], testAccount, testDevice)
	if err != nil || revoked.Reason != "device_revoked" || revoked.ExpiresAt != nil {
		t.Fatal("revocation package", err)
	}
	if _, err := VerifyEnvelope(trust, fixtures["bundle1"], "account-2", testDevice); err == nil {
		t.Fatal("cross-account package accepted")
	}
	if _, err := VerifyEnvelope(trust, fixtures["bundle1"], testAccount, strings.Repeat("f", 32)); err == nil {
		t.Fatal("cross-device package accepted")
	}
}

func TestEmptyTrustFailsClosed(t *testing.T) {
	empty, err := ParseTrust([]byte(`{"public_key_map":{}}`))
	if err != nil || !empty.Empty() {
		t.Fatal("explicit empty trust fixture did not load", err)
	}
	if _, err := VerifyEnvelope(empty, phpFixtures(t)["bundle1"], testAccount, testDevice); !errors.Is(err, ErrUnknownSigningKey) {
		t.Fatal("empty verifier accepted a test-signed package", err)
	}
	for _, document := range []string{
		`{"public_key_map":{"a":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo","a":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"}}`,
		`{"public_key_map":{"a":"AAAA"}}`,
		`{"public_key_map":{"bad kid":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"}}`,
		`{"public_key_map":{},"test_keys":{}}`,
		`{}`,
	} {
		if _, err := ParseTrust([]byte(document)); err == nil {
			t.Fatal("invalid trust map accepted:", document)
		}
	}
}

func TestRejectsTamperedAndMalformedPackages(t *testing.T) {
	trust := testTrust(t)
	valid := bundle(t, 1, 1000, expiry(5000))
	if _, err := VerifyEnvelope(trust, valid, testAccount, testDevice); err != nil {
		t.Fatal(err)
	}
	var outer map[string]json.RawMessage
	_ = json.Unmarshal(valid, &outer)
	var signed map[string]string
	_ = json.Unmarshal(outer["signed"], &signed)
	payload, _ := base64.RawURLEncoding.DecodeString(signed["payload"])
	rewrite := func(field string, value any) []byte {
		copyOuter := map[string]any{}
		for k, v := range outer {
			copyOuter[k] = v
		}
		copySigned := map[string]string{}
		for k, v := range signed {
			copySigned[k] = v
		}
		if strings.HasPrefix(field, "signed.") {
			copySigned[strings.TrimPrefix(field, "signed.")] = value.(string)
		} else {
			copyOuter[field] = value
		}
		copyOuter["signed"] = copySigned
		out, _ := json.Marshal(copyOuter)
		return out
	}
	flipped := bytes.Clone(payload)
	flipped[10] ^= 1
	sig, _ := base64.RawURLEncoding.DecodeString(signed["signature"])
	sig[0] ^= 1
	mirrors := func(id string) []pair {
		return []pair{{"schema_version", 2}, {"kind", "bundle"}, {"account_id", testAccount}, {"device_id", testDevice},
			{"serial", 1}, {"issued_at", 1000}, {"expires_at", 5000}, {"bundle_id", id}}
	}
	id := outer["bundle_id"]
	var bundleID string
	_ = json.Unmarshal(id, &bundleID)
	cases := map[string][]byte{
		"payload changed":         rewrite("signed.payload", base64.RawURLEncoding.EncodeToString(flipped)),
		"signature changed":       rewrite("signed.signature", base64.RawURLEncoding.EncodeToString(sig)),
		"padded base64":           rewrite("signed.signature", base64.URLEncoding.EncodeToString(sig)),
		"standard alphabet":       rewrite("signed.payload", base64.StdEncoding.WithPadding(base64.NoPadding).EncodeToString(payload)+"+"),
		"unknown key id":          rewrite("signed.kid", "other"),
		"mirror serial":           rewrite("serial", 2),
		"mirror expiry":           rewrite("expires_at", nil),
		"mirror integral form":    rewrite("issued_at", json.Number("1000.0")),
		"extra envelope field":    rewrite("connection", "x"),
		"duplicate envelope key":  append(bytes.Clone(valid[:len(valid)-1]), []byte(`,"kind":"bundle"}`)...),
		"duplicate payload key":   envelopeFor(t, append([]byte(`{"kind":"state",`), payload[1:]...), mirrors(bundleID)),
		"invalid utf8 payload":    envelopeFor(t, bytes.Replace(payload, []byte("zolnit"), []byte("zol\xffit"), 1), mirrors(bundleID)),
		"wrong bundle id":         envelopeFor(t, bytes.Replace(payload, []byte(bundleID), []byte(strings.Repeat("0", 64)), 1), mirrors(strings.Repeat("0", 64))),
		"wrong issuer":            sign(t, signSpec{kind: "bundle", serial: 1, issued: 1000, material: append(v2Material(t), pair{"x", 1})}),
		"state with credentials":  sign(t, signSpec{kind: "state", serial: 1, issued: 1000, material: append(v2Material(t)[:1], pair{"current_bundle_id", bundleID}, pair{"needs_refresh", false})}),
		"revoked without reason":  sign(t, signSpec{kind: "revoked", serial: 1, issued: 1000}),
		"unsafe serial":           sign(t, signSpec{kind: "revoked", serial: 1 << 53, issued: 1000, material: []pair{{"reason", "x"}}}),
		"expiry before issuance":  bundle(t, 1, 1000, expiry(1000)),
		"bundle without routing":  sign(t, signSpec{kind: "bundle", serial: 1, issued: 1000, material: v2Material(t)[:2]}),
		"different account bound": sign(t, signSpec{kind: "bundle", serial: 1, issued: 1000, material: v2Material(t), account: "account-2"}),
	}
	delete(cases, "wrong issuer")
	issuer := bytes.Replace(payload, []byte(SignedIssuer), []byte("https://evil.example"), 1)
	issuerPreimage := append(bytes.Clone(issuer[:len(issuer)-len(`,"bundle_id":"`)-66]), '}')
	sum := sha256.Sum256(issuerPreimage)
	issuerID := hex.EncodeToString(sum[:])
	cases["wrong issuer"] = envelopeFor(t, append(bytes.Clone(issuerPreimage[:len(issuerPreimage)-1]), []byte(`,"bundle_id":"`+issuerID+`"}`)...), mirrors(issuerID))
	for name, envelope := range cases {
		if _, err := VerifyEnvelope(trust, envelope, testAccount, testDevice); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestSignedPreparationSeparatesQualificationLeaseFromSubscriptionExpiry(t *testing.T) {
	pkg, err := VerifyEnvelope(testTrust(t), phpFixtures(t)["bundle1"], testAccount, testDevice)
	if err != nil {
		t.Fatal(err)
	}
	early, code := PrepareSigned(pkg, `{"rules":[]}`, time.Unix(1001, 0))
	if code != "" || early.Bundle.Expires != 1301 || early.Bundle.Issued != 1001 {
		t.Fatal(code, early)
	}
	later, _ := PrepareSigned(pkg, `{"rules":[]}`, time.Unix(1100, 0))
	if later.Digest != early.Digest {
		t.Fatal("configuration digest changed without a material change")
	}
	near, _ := PrepareSigned(pkg, `{"rules":[]}`, time.Unix(1900, 0))
	if near.Bundle.Expires != 2000 {
		t.Fatal("lease outlived a node qualification", near.Bundle.Expires)
	}
	after, code := PrepareSigned(pkg, `{"rules":[]}`, time.Unix(2500, 0))
	if code != "" || after.Bundle.Expires != 2800 || after.Digest == early.Digest {
		t.Fatal("expired qualification stopped the subscription or was kept", code)
	}
	for _, service := range after.Services {
		if contains(service.AllowedProxies, "zn.node.hysteria.8") {
			t.Fatal("expired qualification still routes")
		}
	}
	if _, code := PrepareSigned(pkg, "", time.Unix(100000, 0)); code != "subscription_expired" {
		t.Fatal("expired subscription prepared", code)
	}
	tail, _ := PrepareSigned(pkg, "", time.Unix(99900, 0))
	if tail.Bundle.Expires != 100000 {
		t.Fatal("lease outlived the subscription")
	}
}

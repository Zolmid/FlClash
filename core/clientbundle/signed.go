package clientbundle

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	_ "embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"reflect"
	"regexp"
	"strconv"
	"unicode/utf8"
)

const (
	SignedPrefix   = "ZOLNIT-SUBSCRIPTION-V2\n"
	SignedIssuer   = "https://link.zolmid.com"
	SignedAudience = "zolnit-client-subscription-v2"

	maxSignedPayload = 5 << 20
	maxSafeInteger   = 1<<53 - 1
)

type SubscriptionError string

func (e SubscriptionError) Error() string { return string(e) }

const (
	ErrInvalidSigned     SubscriptionError = "invalid_signed_subscription"
	ErrUnknownSigningKey SubscriptionError = "unknown_signing_key"
	ErrInvalidTrust      SubscriptionError = "invalid_subscription_trust"
	ErrReplay            SubscriptionError = "subscription_replay"
	ErrTombstone         SubscriptionError = "subscription_tombstone"
	ErrExpired           SubscriptionError = "subscription_expired"
	ErrSignedRequired    SubscriptionError = "signed_subscription_required"
	ErrStoreCorrupt      SubscriptionError = "subscription_store_corrupt"
	ErrStoreClosed       SubscriptionError = "subscription_store_closed"
	ErrStoreBusy         SubscriptionError = "subscription_store_in_use"
	ErrStorePath         SubscriptionError = "subscription_store_path"
)

var (
	kidPattern    = regexp.MustCompile(`^[A-Za-z0-9._-]{1,64}$`)
	devicePattern = regexp.MustCompile(`^[a-f0-9]{32}$`)
	digestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
	integerToken  = regexp.MustCompile(`^(0|[1-9][0-9]{0,15})$`)
	mirrorFields  = []string{"schema_version", "kind", "account_id", "device_id", "serial", "issued_at", "expires_at", "bundle_id"}
)

//go:embed subscription_trust.json
var productionTrustJSON []byte

// Trust holds pinned Ed25519 public keys by key ID. Platform owners use
// ProductionTrust; ParseTrust exists for public test vectors and key review.
type Trust struct{ keys map[string]ed25519.PublicKey }

func ProductionTrust() (*Trust, error) { return ParseTrust(productionTrustJSON) }

func ParseTrust(content []byte) (*Trust, error) {
	if !strictDocument(content) {
		return nil, ErrInvalidTrust
	}
	var document struct {
		Keys map[string]string `json:"public_key_map"`
	}
	dec := json.NewDecoder(bytes.NewReader(content))
	dec.DisallowUnknownFields()
	if dec.Decode(&document) != nil || document.Keys == nil {
		return nil, ErrInvalidTrust
	}
	trust := &Trust{keys: map[string]ed25519.PublicKey{}}
	for kid, encoded := range document.Keys {
		key, ok := decodeBase64URL(encoded)
		if !kidPattern.MatchString(kid) || !ok || len(key) != ed25519.PublicKeySize {
			return nil, ErrInvalidTrust
		}
		trust.keys[kid] = ed25519.PublicKey(key)
	}
	return trust, nil
}

func (t *Trust) Empty() bool { return t == nil || len(t.keys) == 0 }

// SignedPackage is an authenticated v2 envelope. Digest is the SHA-256 of the
// exact signed payload bytes and is the replay-floor identity.
type SignedPackage struct {
	Kind            string
	AccountID       string
	DeviceID        string
	Serial          int64
	IssuedAt        int64
	ExpiresAt       *int64
	BundleID        string
	Digest          string
	Reason          string
	CurrentBundleID string
	NeedsRefresh    bool

	envelope []byte
	fields   map[string]json.RawMessage
}

func (p *SignedPackage) IsBundle() bool { return p.Kind == "bundle" }

func (p *SignedPackage) Envelope() []byte { return bytes.Clone(p.envelope) }

func (p *SignedPackage) expiredAt(now int64) bool { return p.ExpiresAt != nil && *p.ExpiresAt <= now }

func VerifyEnvelope(trust *Trust, envelope []byte, account, device string) (*SignedPackage, error) {
	if trust == nil || len(envelope) > maxInput || !strictDocument(envelope) ||
		!SafeText(account) || len(account) > 128 || !devicePattern.MatchString(device) {
		return nil, ErrInvalidSigned
	}
	var outer map[string]json.RawMessage
	if json.Unmarshal(envelope, &outer) != nil || len(outer) != len(mirrorFields)+1 {
		return nil, ErrInvalidSigned
	}
	var signed map[string]json.RawMessage
	if json.Unmarshal(outer["signed"], &signed) != nil || len(signed) != 3 {
		return nil, ErrInvalidSigned
	}
	kid, ok1 := jsonString(signed["kid"])
	encodedPayload, ok2 := jsonString(signed["payload"])
	encodedSignature, ok3 := jsonString(signed["signature"])
	if !ok1 || !ok2 || !ok3 {
		return nil, ErrInvalidSigned
	}
	key := trust.keys[kid]
	if key == nil {
		return nil, ErrUnknownSigningKey
	}
	payload, ok1 := decodeBase64URL(encodedPayload)
	signature, ok2 := decodeBase64URL(encodedSignature)
	if !ok1 || !ok2 || len(signature) != ed25519.SignatureSize || len(payload) > maxSignedPayload ||
		!ed25519.Verify(key, append([]byte(SignedPrefix), payload...), signature) || !strictDocument(payload) {
		return nil, ErrInvalidSigned
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(payload, &fields) != nil || fields == nil {
		return nil, ErrInvalidSigned
	}
	pkg, ok := parseSignedFields(fields, account, device)
	if !ok || !validBundleID(payload, pkg.BundleID) {
		return nil, ErrInvalidSigned
	}
	for _, name := range mirrorFields {
		mirror, present := outer[name]
		if !present || !sameJSON(mirror, fields[name]) {
			return nil, ErrInvalidSigned
		}
	}
	digest := sha256.Sum256(payload)
	pkg.Digest = hex.EncodeToString(digest[:])
	pkg.envelope = bytes.Clone(envelope)
	pkg.fields = fields
	return pkg, nil
}

func parseSignedFields(fields map[string]json.RawMessage, account, device string) (*SignedPackage, bool) {
	schema, okSchema := safeInteger(fields["schema_version"])
	issuer, okIssuer := jsonString(fields["issuer"])
	audience, okAudience := jsonString(fields["audience"])
	kind, okKind := jsonString(fields["kind"])
	accountID, okAccount := jsonString(fields["account_id"])
	deviceID, okDevice := jsonString(fields["device_id"])
	serial, okSerial := safeInteger(fields["serial"])
	issued, okIssued := safeInteger(fields["issued_at"])
	bundleID, okBundle := jsonString(fields["bundle_id"])
	if !okSchema || schema != 2 || !okIssuer || issuer != SignedIssuer || !okAudience || audience != SignedAudience ||
		!okKind || !okAccount || accountID != account || !okDevice || deviceID != device ||
		!okSerial || serial < 1 || !okIssued || issued < 1 || !okBundle || !digestPattern.MatchString(bundleID) {
		return nil, false
	}
	pkg := &SignedPackage{Kind: kind, AccountID: accountID, DeviceID: deviceID, Serial: serial, IssuedAt: issued, BundleID: bundleID}
	rawExpiry, present := fields["expires_at"]
	if !present {
		return nil, false
	}
	if string(rawExpiry) != "null" {
		expiry, ok := safeInteger(rawExpiry)
		if !ok || expiry <= issued {
			return nil, false
		}
		pkg.ExpiresAt = &expiry
	}
	_, hasConnection := fields["connection"]
	_, hasOutbounds := fields["outbounds"]
	switch kind {
	case "bundle":
		return pkg, jsonKind(fields["connection"], '{') && jsonKind(fields["outbounds"], '[') && jsonKind(fields["routing"], '{')
	case "revoked":
		reason, ok := jsonString(fields["reason"])
		pkg.Reason = reason
		return pkg, ok && SafeText(reason) && !hasConnection && !hasOutbounds
	case "state":
		current, ok := jsonString(fields["current_bundle_id"])
		refresh := string(fields["needs_refresh"])
		pkg.CurrentBundleID, pkg.NeedsRefresh = current, refresh == "true"
		return pkg, ok && digestPattern.MatchString(current) && (refresh == "true" || refresh == "false") &&
			!hasConnection && !hasOutbounds
	}
	return nil, false
}

// The signer appends bundle_id last and hashes the encoding without it, so the
// identity is checked on the exact signed bytes instead of a re-serialization.
func validBundleID(payload []byte, bundleID string) bool {
	suffix := []byte(`,"bundle_id":"` + bundleID + `"}`)
	if !bytes.HasSuffix(payload, suffix) {
		return false
	}
	preimage := append(bytes.Clone(payload[:len(payload)-len(suffix)]), '}')
	sum := sha256.Sum256(preimage)
	return hex.EncodeToString(sum[:]) == bundleID
}

func strictDocument(content []byte) bool {
	if !utf8.Valid(content) {
		return false
	}
	dec := json.NewDecoder(bytes.NewReader(content))
	dec.UseNumber()
	if !UniqueJSON(dec, 0) {
		return false
	}
	_, err := dec.Token()
	return err == io.EOF && jsonKind(bytes.TrimSpace(content), '{')
}

func jsonKind(raw json.RawMessage, first byte) bool { return len(raw) > 0 && raw[0] == first }

func jsonString(raw json.RawMessage) (string, bool) {
	var value string
	if !jsonKind(raw, '"') || json.Unmarshal(raw, &value) != nil {
		return "", false
	}
	return value, true
}

func safeInteger(raw json.RawMessage) (int64, bool) {
	if !integerToken.Match(raw) {
		return 0, false
	}
	value, err := strconv.ParseInt(string(raw), 10, 64)
	return value, err == nil && value <= maxSafeInteger
}

func sameJSON(a, b json.RawMessage) bool {
	var left, right any
	da, db := json.NewDecoder(bytes.NewReader(a)), json.NewDecoder(bytes.NewReader(b))
	da.UseNumber()
	db.UseNumber()
	return da.Decode(&left) == nil && db.Decode(&right) == nil && reflect.DeepEqual(left, right)
}

func decodeBase64URL(value string) ([]byte, bool) {
	decoded, err := base64.RawURLEncoding.Strict().DecodeString(value)
	return decoded, err == nil && len(decoded) > 0 && base64.RawURLEncoding.EncodeToString(decoded) == value
}

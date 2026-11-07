package clientbundle

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"strconv"
	"time"
)

const qualificationLease = 300

// V1 leases use wall time; their remaining lifetime uses rollback-safe
// subscription and qualification deadlines.
func projectSigned(pkg *SignedPackage, effective, wall int64) ([]byte, string) {
	if pkg == nil || !pkg.IsBundle() || pkg.fields == nil {
		return nil, "invalid_signed_subscription"
	}
	if pkg.expiredAt(effective) {
		return nil, "subscription_expired"
	}
	remaining := int64(qualificationLease)
	if pkg.ExpiresAt != nil {
		remaining = min(remaining, *pkg.ExpiresAt-effective)
	}
	var routing map[string]json.RawMessage
	var nodes []json.RawMessage
	if json.Unmarshal(pkg.fields["routing"], &routing) != nil || json.Unmarshal(routing["nodes"], &nodes) != nil {
		return nil, "invalid_bundle_metadata"
	}
	qualified := make([]json.RawMessage, 0, len(nodes))
	for _, raw := range nodes {
		var node map[string]json.RawMessage
		if json.Unmarshal(raw, &node) != nil || node == nil {
			return nil, "invalid_bundle_metadata"
		}
		if until, present := node["valid_until"]; present && string(until) != "null" {
			value, ok := safeInteger(until)
			if !ok {
				return nil, "invalid_bundle_metadata"
			}
			if value <= effective {
				continue
			}
			remaining = min(remaining, value-effective)
		}
		qualified = append(qualified, raw)
	}
	encodedNodes, err := json.Marshal(qualified)
	if err != nil {
		return nil, "invalid_bundle_metadata"
	}
	routing["nodes"] = encodedNodes
	encodedRouting, err := json.Marshal(routing)
	if err != nil {
		return nil, "invalid_bundle_metadata"
	}
	lease := wall + remaining
	issued, expires := strconv.FormatInt(wall, 10), strconv.FormatInt(lease, 10)
	identity := sha256.Sum256([]byte(pkg.BundleID + "\x00" + issued + "\x00" + expires))
	data := map[string]json.RawMessage{
		"schema_version": json.RawMessage("1"),
		"account_id":     pkg.fields["account_id"],
		"bundle_id":      json.RawMessage(strconv.Quote(hex.EncodeToString(identity[:]))),
		"issued_at":      json.RawMessage(issued),
		"expires_at":     json.RawMessage(expires),
		"connection":     pkg.fields["connection"],
		"outbounds":      pkg.fields["outbounds"],
		"routing":        encodedRouting,
	}
	body, err := json.Marshal(map[string]any{"data": data})
	if err != nil {
		return nil, "invalid_bundle_metadata"
	}
	return body, ""
}

// PrepareSigned keeps the configuration digest stable across short-lease
// renewals so they can reuse the running Core configuration.
func PrepareSigned(pkg *SignedPackage, overlay string, now time.Time) (*Prepared, string) {
	return prepareProjection(pkg, overlay, now.Unix(), now)
}

func prepareProjection(pkg *SignedPackage, overlay string, effective int64, wall time.Time) (*Prepared, string) {
	body, code := projectSigned(pkg, effective, wall.Unix())
	if code != "" {
		return nil, code
	}
	prepared, code := Prepare(body, pkg.AccountID, overlay, wall)
	if code != "" {
		return nil, code
	}
	stabilizeDigest(prepared, pkg, overlay)
	return prepared, ""
}

func stabilizeDigest(prepared *Prepared, pkg *SignedPackage, overlay string) {
	digest := sha256.Sum256([]byte(pkg.Digest + "\x00" + overlay + "\x00" + prepared.MetadataDigest))
	prepared.Digest = hex.EncodeToString(digest[:])
}

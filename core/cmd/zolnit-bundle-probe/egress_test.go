package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"strings"
	"testing"
)

func TestEgressObservationRejectsMalformedBodies(t *testing.T) {
	key := bytes.Repeat([]byte{'1'}, 32)
	for _, body := range []string{
		"", "{", "null", "[]", "true", "42", `"value"`,
		`{"ip":"8.8.8.8","country":"US"} {}`,
		`{"ip":"8.8.8.8","country":"US"}garbage`,
		`{"ip":"8.8.8.8","ip":"1.1.1.1","country":"US"}`,
		`{"ip":"8.8.8.8","country":"US","country":"SG"}`,
		`{"ip":"8.8.8.8","co\u0075ntry":"US","country":"SG"}`,
		`{"ip":"8.8.8.8","country":"US","extra":{"x":1,"x":2}}`,
		`{"ip":"8.8.8.8","country":"US","extra":[{"x":1,"x":2}]}`,
		strings.Repeat(" ", 4097),
		string([]byte{'{', '"', 255, '"', ':', '1', '}'}),
	} {
		country, marker, code := parseEgressObservation([]byte(body), key)
		if country != "" || marker != "" || code != "invalid_egress_observation" {
			t.Fatal("malformed body was not rejected with sanitized output")
		}
	}
}

func TestEgressObservationRejectsNonPublicIPs(t *testing.T) {
	key := bytes.Repeat([]byte{'1'}, 32)
	for _, ip := range []string{
		"", "invalid", "8.8.8.8:443", " 8.8.8.8", "008.8.8.8", "8.8.8.8/32",
		"0.0.0.0", "0.1.2.3", "10.1.2.3", "127.0.0.1", "169.254.1.2",
		"172.16.1.2", "192.168.1.2", "100.64.0.1", "100.127.255.255",
		"192.0.0.9", "192.0.2.1", "192.88.99.1", "198.18.0.1", "198.19.255.255",
		"198.51.100.1", "203.0.113.1", "224.0.0.1", "239.255.255.255", "240.0.0.1", "255.255.255.255",
		"::", "::1", "::8.8.8.8", "::ffff:10.1.2.3", "::ffff:192.0.2.1", "::ffff:c000:201",
		"fc00::1", "fd00::1", "fe80::1", "ff02::1", "2001:4860::1%en0",
		"64:ff9b::808:808", "100::1", "2001::1", "2001:2::1", "2001:20::1",
		"2001:db8::1", "2002:808:808::1", "3fff::1", "4000::1",
	} {
		body, err := json.Marshal(map[string]string{"ip": ip, "country": "US"})
		if err != nil {
			t.Fatal("synthetic fixture encoding failed")
		}
		country, marker, code := parseEgressObservation(body, key)
		if country != "" || marker != "" || code != "invalid_egress_ip" {
			t.Fatal("invalid address was not rejected with sanitized output")
		}
	}
	for _, body := range []string{`{"country":"US"}`, `{"ip":null,"country":"US"}`, `{"ip":123,"country":"US"}`, `{"IP":"8.8.8.8","country":"US"}`} {
		country, marker, code := parseEgressObservation([]byte(body), key)
		if country != "" || marker != "" || code != "invalid_egress_ip" {
			t.Fatal("invalid IP field accepted")
		}
	}
}

func TestEgressObservationRequiresISOAlpha2Country(t *testing.T) {
	key := bytes.Repeat([]byte{'1'}, 32)
	for _, field := range []string{`null`, `""`, `"us"`, `"XX"`, `"T1"`, `"EU"`, `"XK"`, `"USA"`, `" US"`, `"US "`, `12`, `[]`, `{}`, `true`} {
		country, marker, code := parseEgressObservation([]byte(`{"ip":"8.8.8.8","country":`+field+`}`), key)
		if country != "" || marker != "" || code != "invalid_egress_country" {
			t.Fatal("invalid country accepted")
		}
	}
	for _, body := range []string{`{"ip":"8.8.8.8"}`, `{"ip":"8.8.8.8","Country":"US"}`} {
		country, marker, code := parseEgressObservation([]byte(body), key)
		if country != "" || marker != "" || code != "invalid_egress_country" {
			t.Fatal("missing country accepted")
		}
	}
	for _, value := range []string{"US", "SG", "CN", "HK", "TW", "AQ", "AX", "BQ", "SS", "ZW"} {
		country, marker, code := parseEgressObservation([]byte(`{"ip":"8.8.8.8","country":"`+value+`"}`), key)
		if country != value || len(marker) != 68 || code != "" {
			t.Fatal("ISO country rejected")
		}
	}
}

func TestEgressObservationKeyAndBodyLimits(t *testing.T) {
	body := []byte(`{"ip":"8.8.8.8","country":"US"}`)
	for _, key := range [][]byte{nil, {}, bytes.Repeat([]byte{1}, 31), bytes.Repeat([]byte{1}, 33), make([]byte, 32)} {
		country, marker, code := parseEgressObservation(body, key)
		if country != "" || marker != "" || code != "invalid_egress_key" {
			t.Fatal("invalid key accepted")
		}
	}
	key := make([]byte, 32)
	key[31] = 1
	padded := append(bytes.Clone(body), bytes.Repeat([]byte{' '}, 4096-len(body))...)
	if _, _, code := parseEgressObservation(padded, key); code != "" {
		t.Fatal("4096-byte body rejected")
	}
	padded = append(padded, ' ')
	if country, marker, code := parseEgressObservation(padded, key); country != "" || marker != "" || code != "invalid_egress_observation" {
		t.Fatal("oversized body accepted")
	}
}

func TestEgressObservationMarkerContract(t *testing.T) {
	key := bytes.Repeat([]byte{'1'}, 32)
	body := []byte(`{"ip":"8.8.8.8","country":"US"}`)
	originalBody, originalKey := bytes.Clone(body), bytes.Clone(key)
	country, marker, code := parseEgressObservation(body, key)
	if country != "US" || code != "" || marker != "eg1.3f23bb4379292e3b45c3d4c9c0630b0cc7e18d93b0bede8de69fa2c8013fea43" {
		t.Fatal("HMAC contract mismatch")
	}
	if !bytes.Equal(body, originalBody) || !bytes.Equal(key, originalKey) {
		t.Fatal("parser modified caller input")
	}
	if decoded, err := hex.DecodeString(strings.TrimPrefix(marker, "eg1.")); err != nil || len(decoded) != 32 {
		t.Fatal("marker format mismatch")
	}
	for _, equivalent := range []string{
		`{"ip":"8.8.8.8","country":"US"}`,
		`{"country":"SG","ip":"::ffff:8.8.8.8"}`,
		`{"ip":"::ffff:808:808","country":"TW","proxy_id":"synthetic"}`,
		` {"country":"CN","ip":"8.8.8.8","extra":true} `,
	} {
		_, same, code := parseEgressObservation([]byte(equivalent), key)
		if code != "" || same != marker {
			t.Fatal("canonical IP or country independence mismatch")
		}
	}
	rotated := bytes.Clone(key)
	rotated[0] ^= 1
	if _, other, code := parseEgressObservation(body, rotated); code != "" || other == marker {
		t.Fatal("rotated key did not change marker")
	}
	if _, other, code := parseEgressObservation([]byte(`{"ip":"1.1.1.1","country":"US"}`), key); code != "" || other == marker {
		t.Fatal("different IP did not change marker")
	}
	_, v6, code := parseEgressObservation([]byte(`{"ip":"2001:4860:4860::8888","country":"US"}`), key)
	if code != "" {
		t.Fatal("public IPv6 rejected")
	}
	_, expanded, code := parseEgressObservation([]byte(`{"ip":"2001:4860:4860:0000:0000:0000:0000:8888","country":"US"}`), key)
	if code != "" || expanded != v6 {
		t.Fatal("canonical IPv6 mismatch")
	}
}

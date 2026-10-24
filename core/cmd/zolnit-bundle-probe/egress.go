package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/netip"
	"strings"
	"unicode/utf8"
)

const egressObservationURL = "https://api.country.is/"

const egressCountryCodes = " AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ " +
	"BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM " +
	"DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS " +
	"GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN " +
	"KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ " +
	"MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM " +
	"PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV " +
	"SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI " +
	"VN VU WF WS YE YT ZA ZM ZW "

func parseEgressObservation(body []byte, key []byte) (country, marker, code string) {
	if len(key) != 32 || bytes.Equal(key, make([]byte, 32)) {
		return "", "", "invalid_egress_key"
	}
	if len(body) == 0 || len(body) > 4096 || !utf8.Valid(body) {
		return "", "", "invalid_egress_observation"
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.UseNumber()
	if !uniqueJSON(dec, 0) {
		return "", "", "invalid_egress_observation"
	}
	if _, err := dec.Token(); err != io.EOF {
		return "", "", "invalid_egress_observation"
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(body, &fields) != nil || fields == nil {
		return "", "", "invalid_egress_observation"
	}
	var rawIP string
	if json.Unmarshal(fields["ip"], &rawIP) != nil || rawIP == "" {
		return "", "", "invalid_egress_ip"
	}
	ip, err := netip.ParseAddr(rawIP)
	if err != nil || ip.Zone() != "" {
		return "", "", "invalid_egress_ip"
	}
	ip = ip.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
		return "", "", "invalid_egress_ip"
	}
	// Global-unicast alone includes special-use IPv4 and IPv6 ranges.
	for _, reserved := range []string{
		"0.0.0.0/8", "100.64.0.0/10", "192.0.0.0/24", "192.0.2.0/24",
		"192.88.99.0/24", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "240.0.0.0/4",
		"2001::/23", "2001:db8::/32", "2002::/16", "3fff::/20",
	} {
		if netip.MustParsePrefix(reserved).Contains(ip) {
			return "", "", "invalid_egress_ip"
		}
	}
	if ip.Is6() && !netip.MustParsePrefix("2000::/3").Contains(ip) {
		return "", "", "invalid_egress_ip"
	}
	if json.Unmarshal(fields["country"], &country) != nil || len(country) != 2 ||
		!strings.Contains(egressCountryCodes, " "+country+" ") {
		return "", "", "invalid_egress_country"
	}
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write([]byte("zolnit-egress-observation/eg1\x00" + egressObservationURL + "\x00" + ip.String()))
	return country, "eg1." + hex.EncodeToString(mac.Sum(nil)), ""
}

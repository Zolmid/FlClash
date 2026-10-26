package clientbundle

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"go.yaml.in/yaml/v3"
	"io"
	"regexp"
	"strings"
	"time"
)

const maxInput = 8 << 20
const bundlePath = "/api/v1/zolnit/client/bundle"

var nodeID = regexp.MustCompile(`^[a-z][a-z0-9-]*:[1-9][0-9]*$`)
var safeID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$`)
var protocolTypes = map[string]bool{"ss": true, "ssr": true, "socks5": true, "http": true, "vmess": true, "vless": true, "trojan": true, "hysteria": true, "hysteria2": true, "tuic": true, "snell": true, "anytls": true}

type Bundle struct {
	Schema     int    `json:"schema_version"`
	Account    string `json:"account_id"`
	ID         string `json:"bundle_id"`
	Issued     int64  `json:"issued_at"`
	Expires    int64  `json:"expires_at"`
	Connection struct {
		Engine   string `json:"engine"`
		Format   string `json:"format"`
		SHA      string `json:"sha256"`
		Document string `json:"document"`
	} `json:"connection"`
	Outbounds []struct {
		ID      string `json:"id"`
		Name    string `json:"proxy_name"`
		Display string `json:"display_name"`
	} `json:"outbounds"`
	Routing struct {
		Version   int    `json:"version"`
		Authority string `json:"authority"`
		Revision  string `json:"revision"`
		Services  []struct {
			ID     string `json:"id"`
			Group  string `json:"group"`
			Auto   string `json:"automatic"`
			Manual string `json:"manual"`
		} `json:"services"`
		Nodes []struct {
			ID            string `json:"id"`
			Name          string `json:"proxy_name"`
			Exit          string `json:"exit_id"`
			FailureDomain string `json:"failure_domain"`
		} `json:"nodes"`
	} `json:"routing"`
}
type Frame struct {
	Observation struct {
		Key string `json:"key_b64u"`
	} `json:"observation"`
	Status int    `json:"http_status"`
	Path   string `json:"source_path"`
	Body   struct {
		Data  *Bundle `json:"data"`
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	} `json:"body"`
}
type Validated struct {
	Bundle         *Bundle
	Proxies        map[string]map[string]any
	Names          map[string]string
	ObservationKey string
	IPV6           bool
}

func Parse(body []byte, account string, now time.Time) (*Validated, string) {
	if len(body) > maxInput {
		return nil, "invalid_input"
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	if !UniqueJSON(dec, 0) {
		return nil, "invalid_input"
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, "invalid_input"
	}
	frame := append([]byte(`{"http_status":200,"source_path":"/api/v1/zolnit/client/bundle","body":`), body...)
	frame = append(frame, '}')
	return ValidateFrame(bytes.NewReader(frame), account, func() time.Time { return now })
}

func SafeText(value string) bool {
	if value == "" || len(value) > 256 || strings.TrimSpace(value) != value {
		return false
	}
	for _, r := range value {
		if r < 32 || r == 127 {
			return false
		}
	}
	return true
}
func UniqueJSON(dec *json.Decoder, depth int) bool {
	if depth > 32 {
		return false
	}
	token, err := dec.Token()
	if err != nil {
		return false
	}
	delim, ok := token.(json.Delim)
	if !ok {
		return true
	}
	switch delim {
	case '{':
		seen := map[string]bool{}
		for dec.More() {
			key, e := dec.Token()
			s, ok := key.(string)
			if e != nil || !ok || seen[s] {
				return false
			}
			seen[s] = true
			if !UniqueJSON(dec, depth+1) {
				return false
			}
		}
		end, e := dec.Token()
		return e == nil && end == json.Delim('}')
	case '[':
		for dec.More() {
			if !UniqueJSON(dec, depth+1) {
				return false
			}
		}
		end, e := dec.Token()
		return e == nil && end == json.Delim(']')
	}
	return false
}
func ValidateFrame(input io.Reader, account string, clock func() time.Time) (*Validated, string) {
	content, err := io.ReadAll(io.LimitReader(input, maxInput+1))
	if err != nil || len(content) > maxInput {
		return nil, "invalid_input"
	}
	defer clear(content)
	now := clock()
	dec := json.NewDecoder(strings.NewReader(string(content)))
	dec.UseNumber()
	if !UniqueJSON(dec, 0) {
		return nil, "invalid_input"
	}
	if _, e := dec.Token(); e != io.EOF {
		return nil, "invalid_input"
	}
	var envelope Frame
	if json.Unmarshal(content, &envelope) != nil || envelope.Path != bundlePath {
		return nil, "invalid_api_frame"
	}
	if envelope.Status != 200 {
		switch {
		case envelope.Status == 401 && envelope.Body.Error.Code == "unauthenticated":
			return nil, "unauthenticated"
		case envelope.Status == 403 && envelope.Body.Error.Code == "entitlement_unavailable":
			return nil, "entitlement_unavailable"
		case envelope.Status == 503 && envelope.Body.Error.Code == "bundle_unavailable":
			return nil, "bundle_unavailable"
		default:
			return nil, "client_api_unavailable"
		}
	}
	b := envelope.Body.Data
	if b == nil || b.Schema != 1 || !SafeText(account) || b.Account != account || !SafeText(b.ID) {
		return nil, "invalid_bundle_binding"
	}
	if b.Issued > now.Unix() || b.Issued < now.Unix()-300 || b.Expires <= now.Unix() || b.Expires <= b.Issued || b.Expires-b.Issued > 300 {
		return nil, "invalid_bundle_ttl"
	}
	hash := sha256.Sum256([]byte(b.Connection.Document))
	if b.Connection.Engine != "mihomo" || b.Connection.Format != "yaml" || b.Connection.Document == "" || hex.EncodeToString(hash[:]) != b.Connection.SHA {
		return nil, "invalid_connection_hash"
	}
	if len(b.Outbounds) == 0 || len(b.Outbounds) > 4096 || b.Routing.Version != 1 || b.Routing.Authority != "zolnit" || !SafeText(b.Routing.Revision) || len(b.Routing.Services) == 0 || len(b.Routing.Services) > 16 || b.Routing.Nodes == nil || len(b.Routing.Nodes) > 4096 {
		return nil, "invalid_bundle_metadata"
	}
	names := map[string]string{}
	ids := map[string]string{}
	for _, o := range b.Outbounds {
		expected := "zn.node." + strings.Replace(o.ID, ":", ".", 1)
		if !nodeID.MatchString(o.ID) || o.Name != expected || !SafeText(o.Display) || names[o.ID] != "" || ids[o.Name] != "" {
			return nil, "invalid_outbound_mapping"
		}
		names[o.ID] = o.Name
		ids[o.Name] = o.ID
	}
	services := map[string]bool{}
	for _, s := range b.Routing.Services {
		g := "zn.service." + s.ID
		if !safeID.MatchString(s.ID) || s.Group != g || s.Auto != g+".auto" || s.Manual != g+".manual" || services[s.ID] {
			return nil, "invalid_service_mapping"
		}
		services[s.ID] = true
	}
	nodes := map[string]bool{}
	for _, n := range b.Routing.Nodes {
		if names[n.ID] != n.Name || nodes[n.ID] || !safeID.MatchString(n.Exit) || !safeID.MatchString(n.FailureDomain) {
			return nil, "invalid_node_mapping"
		}
		nodes[n.ID] = true
	}
	var document map[string]any
	if yaml.Unmarshal([]byte(b.Connection.Document), &document) != nil {
		return nil, "invalid_connection_yaml"
	}
	ipv6 := false
	if value, exists := document["ipv6"]; exists {
		var ok bool
		ipv6, ok = value.(bool)
		if !ok {
			return nil, "invalid_connection_ipv6"
		}
	}
	raw, ok := document["proxies"].([]any)
	if !ok || len(raw) != len(names) {
		return nil, "invalid_outbound_mapping"
	}
	if providers := document["proxy-providers"]; providers != nil {
		m, ok := providers.(map[string]any)
		if !ok || len(m) > 0 {
			return nil, "dynamic_proxies_unsupported"
		}
	}
	groups, ok := document["proxy-groups"].([]any)
	if !ok {
		return nil, "invalid_service_mapping"
	}
	groupNames := map[string]bool{}
	for _, raw := range groups {
		g, ok := raw.(map[string]any)
		if !ok {
			return nil, "invalid_service_mapping"
		}
		name, ok := g["name"].(string)
		if !ok || !SafeText(name) || groupNames[name] || ids[name] != "" {
			return nil, "invalid_service_mapping"
		}
		groupNames[name] = true
	}
	for _, service := range b.Routing.Services {
		if !groupNames[service.Group] || groupNames[service.Auto] || groupNames[service.Manual] {
			return nil, "invalid_service_mapping"
		}
	}
	proxies := map[string]map[string]any{}
	for _, value := range raw {
		p, ok := value.(map[string]any)
		if !ok {
			return nil, "invalid_outbound_mapping"
		}
		name, _ := p["name"].(string)
		kind, _ := p["type"].(string)
		if ids[name] == "" || proxies[name] != nil {
			return nil, "invalid_outbound_mapping"
		}
		if !protocolTypes[kind] {
			return nil, "unsupported_proxy_type"
		}
		proxies[name] = p
	}
	return &Validated{Bundle: b, Proxies: proxies, Names: names, ObservationKey: envelope.Observation.Key, IPV6: ipv6}, ""
}

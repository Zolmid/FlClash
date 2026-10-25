package main

import (
	"context"
	"crypto/sha256"
	"crypto/tls"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"flag"
	"io"
	"log"
	"mime"
	"net"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/proxydialer"
	C "github.com/metacubex/mihomo/constant"
	CL "github.com/metacubex/mihomo/log"
	"github.com/sirupsen/logrus"
	"go.yaml.in/yaml/v3"
)

var sourceCommit = "unversioned"

const maxInput = 8 << 20
const bundlePath = "/api/v1/zolnit/client/bundle"

var nodeID = regexp.MustCompile(`^[a-z][a-z0-9-]*:[1-9][0-9]*$`)
var safeID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$`)
var targets = map[string]string{"gstatic": "https://www.gstatic.com/generate_204", "cloudflare": "https://www.cloudflare.com/cdn-cgi/trace"}
var protocolTypes = map[string]bool{"ss": true, "ssr": true, "socks5": true, "http": true, "vmess": true, "vless": true, "trojan": true, "hysteria": true, "hysteria2": true, "tuic": true, "snell": true, "anytls": true}

type bundle struct {
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
type frame struct {
	Observation struct {
		Key string `json:"key_b64u"`
	} `json:"observation"`
	Status int    `json:"http_status"`
	Path   string `json:"source_path"`
	Body   struct {
		Data  *bundle `json:"data"`
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	} `json:"body"`
}
type options struct {
	account, outbound, target string
	probe                     bool
	observe                   bool
	targetExplicit            bool
	timeout                   time.Duration
}
type report struct {
	FailureStage string `json:"failure_stage,omitempty"`
	OK           bool   `json:"ok"`
	Code         string `json:"code"`
	CoreVersion  string `json:"core_version"`
	SourceCommit string `json:"source_commit"`
	Mode         string `json:"mode"`
	Outbounds    int    `json:"outbound_count,omitempty"`
	Nodes        int    `json:"routing_node_count"`
	Hash         bool   `json:"sha256_verified"`
	Mapping      bool   `json:"mapping_verified"`
	Target       string `json:"target,omitempty"`
	Status       int    `json:"http_status,omitempty"`
	Latency      int64  `json:"latency_ms,omitempty"`
	Country      string `json:"country_code,omitempty"`
	EgressTag    string `json:"egress_tag,omitempty"`
}
type validated struct {
	bundle         *bundle
	proxies        map[string]map[string]any
	names          map[string]string
	observationKey string
	ipv6           bool
}

func safeText(value string) bool {
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
func uniqueJSON(dec *json.Decoder, depth int) bool {
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
			if !uniqueJSON(dec, depth+1) {
				return false
			}
		}
		end, e := dec.Token()
		return e == nil && end == json.Delim('}')
	case '[':
		for dec.More() {
			if !uniqueJSON(dec, depth+1) {
				return false
			}
		}
		end, e := dec.Token()
		return e == nil && end == json.Delim(']')
	}
	return false
}
func validate(input io.Reader, account string, clock func() time.Time) (*validated, string) {
	content, err := io.ReadAll(io.LimitReader(input, maxInput+1))
	if err != nil || len(content) > maxInput {
		return nil, "invalid_input"
	}
	defer clear(content)
	now := clock()
	dec := json.NewDecoder(strings.NewReader(string(content)))
	dec.UseNumber()
	if !uniqueJSON(dec, 0) {
		return nil, "invalid_input"
	}
	if _, e := dec.Token(); e != io.EOF {
		return nil, "invalid_input"
	}
	var envelope frame
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
	if b == nil || b.Schema != 1 || !safeText(account) || b.Account != account || !safeText(b.ID) {
		return nil, "invalid_bundle_binding"
	}
	if b.Issued > now.Unix() || b.Issued < now.Unix()-300 || b.Expires <= now.Unix() || b.Expires <= b.Issued || b.Expires-b.Issued > 300 {
		return nil, "invalid_bundle_ttl"
	}
	hash := sha256.Sum256([]byte(b.Connection.Document))
	if b.Connection.Engine != "mihomo" || b.Connection.Format != "yaml" || b.Connection.Document == "" || hex.EncodeToString(hash[:]) != b.Connection.SHA {
		return nil, "invalid_connection_hash"
	}
	if len(b.Outbounds) == 0 || len(b.Outbounds) > 4096 || b.Routing.Version != 1 || b.Routing.Authority != "zolnit" || !safeText(b.Routing.Revision) || len(b.Routing.Services) == 0 || len(b.Routing.Services) > 16 || b.Routing.Nodes == nil || len(b.Routing.Nodes) > 4096 {
		return nil, "invalid_bundle_metadata"
	}
	names := map[string]string{}
	ids := map[string]string{}
	for _, o := range b.Outbounds {
		expected := "zn.node." + strings.Replace(o.ID, ":", ".", 1)
		if !nodeID.MatchString(o.ID) || o.Name != expected || !safeText(o.Display) || names[o.ID] != "" || ids[o.Name] != "" {
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
		if !ok || !safeText(name) || groupNames[name] || ids[name] != "" {
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
	return &validated{bundle: b, proxies: proxies, names: names, observationKey: envelope.Observation.Key, ipv6: ipv6}, ""
}
func buildProxy(v *validated, name string, stack map[string]bool, owned *[]C.Proxy) (C.Proxy, string) {
	if stack[name] || len(stack) >= 8 || v.proxies[name] == nil {
		return nil, "invalid_dialer_chain"
	}
	stack[name] = true
	defer delete(stack, name)
	mapping := v.proxies[name]
	for _, key := range []string{"interface-name", "routing-mark", "certificate", "private-key"} {
		if _, ok := mapping[key]; ok {
			return nil, "unsupported_proxy_option"
		}
	}
	next := proxyNetworkDialer(mapping, nil)
	if value, exists := mapping["dialer-proxy"]; exists {
		dependency, ok := value.(string)
		if !ok || dependency == "" {
			return nil, "invalid_dialer_chain"
		}
		p, code := buildProxy(v, dependency, stack, owned)
		if code != "" {
			return nil, code
		}
		next = proxyNetworkDialer(mapping, proxydialer.New(p, false))
	}
	proxy, err := adapter.ParseProxy(mapping, adapter.WithDialerForAPI(next))
	if err != nil {
		return nil, "core_proxy_invalid"
	}
	*owned = append(*owned, proxy)
	return proxy, ""
}
func isolatedTransport(proxy C.Proxy) *http.Transport {
	return &http.Transport{
		Proxy: nil, DisableKeepAlives: true, DisableCompression: true, MaxResponseHeaderBytes: 8192, TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12},
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			meta := &C.Metadata{NetWork: C.TCP, Type: C.INNER}
			if err := meta.SetRemoteAddress(address); err != nil {
				return nil, err
			}
			conn, err := proxy.DialContext(ctx, meta)
			if err == nil {
				if deadline, ok := ctx.Deadline(); ok {
					_ = conn.SetDeadline(deadline)
				}
			}
			if err != nil {
				err = &networkPhaseError{stage: classifyNetworkFailure(err, "proxy_tls"), cause: err}
			}
			return conn, err
		},
	}
}
func isolatedClient(proxy C.Proxy) *http.Client {
	return &http.Client{Transport: isolatedTransport(proxy), CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
}
func isolatedHTTP(ctx context.Context, proxy C.Proxy, target string) (int, error) {
	client := isolatedClient(proxy)
	defer client.CloseIdleConnections()
	request, err := http.NewRequestWithContext(ctx, http.MethodHead, target, nil)
	if err != nil {
		return 0, err
	}
	response, err := client.Do(request)
	if err != nil {
		return 0, err
	}
	defer response.Body.Close()
	return response.StatusCode, nil
}
func isolatedEgress(ctx context.Context, proxy C.Proxy, key []byte, failureStage ...*string) (country, marker, code string, status int) {
	client := isolatedClient(proxy)
	defer client.CloseIdleConnections()
	return requestEgress(ctx, client, key, failureStage...)
}
func requestEgress(ctx context.Context, client *http.Client, key []byte, failureStage ...*string) (country, marker, code string, status int) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, egressObservationURL, nil)
	if err != nil {
		return "", "", "egress_request_failed", 0
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Accept-Encoding", "identity")
	request.Header.Set("User-Agent", "ZolNit-Core-Probe/1")
	response, err := client.Do(request)
	if err != nil {
		setFailureStage(failureStage, err)
		return "", "", "isolated_connection_failed", 0
	}
	defer response.Body.Close()
	status = response.StatusCode
	if status != http.StatusOK {
		return "", "", "egress_http_status", status
	}
	media, _, err := mime.ParseMediaType(response.Header.Get("Content-Type"))
	encoding := response.Header.Get("Content-Encoding")
	if err != nil || media != "application/json" || (encoding != "" && encoding != "identity") {
		return "", "", "egress_response_invalid", status
	}
	if response.ContentLength > 4096 {
		return "", "", "egress_response_too_large", status
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, 4097))
	defer clear(body)
	if err != nil {
		setFailureStage(failureStage, err)
		return "", "", "isolated_connection_failed", status
	}
	if len(body) > 4096 {
		return "", "", "egress_response_too_large", status
	}
	country, marker, code = parseEgressObservation(body, key)
	return country, marker, code, status
}
func execute(input io.Reader, opt options, now func() time.Time) (r report) {
	r = report{Code: "invalid_arguments", CoreVersion: C.Version, SourceCommit: sourceCommit, Mode: "validate"}
	defer func() {
		if recover() != nil {
			r.OK = false
			r.Code = "core_probe_failed"
		}
	}()
	if !safeText(opt.account) || opt.timeout < time.Second || opt.timeout > 20*time.Second || targets[opt.target] == "" || (opt.observe && (opt.probe || opt.targetExplicit)) {
		return r
	}
	v, code := validate(input, opt.account, now)
	if code != "" {
		r.Code = code
		return r
	}
	r.Outbounds = len(v.names)
	r.Nodes = len(v.bundle.Routing.Nodes)
	r.Hash = true
	r.Mapping = true
	r.Code = "validated"
	r.OK = true
	if !opt.probe && !opt.observe {
		return r
	}
	r.Mode = "explicit_manual_probe"
	r.Target = opt.target
	r.OK = false
	var observationKey []byte
	if opt.observe {
		r.Mode = "egress_observation"
		r.Target = "country_is"
		if len(v.observationKey) != 43 {
			r.Code = "observation_context_required"
			return r
		}
		var err error
		observationKey, err = base64.RawURLEncoding.Strict().DecodeString(v.observationKey)
		defer clear(observationKey)
		nonzero := false
		for _, b := range observationKey {
			if b != 0 {
				nonzero = true
			}
		}
		if err != nil || len(observationKey) != 32 || !nonzero {
			r.Code = "observation_context_required"
			return r
		}
	}
	name := v.names[opt.outbound]
	if name == "" {
		r.Code = "outbound_required"
		return r
	}
	restoreNetwork := applyRuntimeNetwork(v.ipv6)
	defer restoreNetwork()
	owned := []C.Proxy{}
	defer func() {
		for i := len(owned) - 1; i >= 0; i-- {
			_ = owned[i].Close()
		}
	}()
	p, code := buildProxy(v, name, map[string]bool{}, &owned)
	if code != "" {
		r.Code = code
		r.FailureStage = "parse_proxy"
		return r
	}
	at := now()
	expiry := time.Unix(v.bundle.Expires, 0)
	if !expiry.After(at) {
		r.Code = "invalid_bundle_ttl"
		return r
	}
	deadline := at.Add(opt.timeout)
	if expiry.Before(deadline) {
		deadline = expiry
	}
	ctx, cancel := context.WithDeadline(context.Background(), deadline)
	defer cancel()
	start := time.Now()
	var status int
	var err error
	var country, marker, observationCode string
	if opt.observe {
		country, marker, observationCode, status = isolatedEgress(ctx, p, observationKey, &r.FailureStage)
	} else {
		status, err = isolatedHTTP(ctx, p, targets[opt.target])
	}
	r.Latency = time.Since(start).Milliseconds()
	if !now().Before(expiry) {
		r.Code = "invalid_bundle_ttl"
		return r
	}
	if opt.observe {
		r.Status = status
		if observationCode != "" {
			r.Code = observationCode
			return r
		}
		r.Country = country
		r.EgressTag = marker
		r.Code = "egress_observation_ok"
		r.OK = true
		return r
	}
	if err != nil {
		r.Code = "isolated_connection_failed"
		r.FailureStage = classifyNetworkFailure(err, "target_tls")
		return r
	}
	r.Status = status
	if status < 200 || status >= 300 {
		r.Code = "unexpected_http_status"
		return r
	}
	r.OK = true
	r.Code = "isolated_connection_ok"
	return r
}
func main() {
	log.SetOutput(io.Discard)
	logrus.SetOutput(io.Discard)
	CL.SetLevel(CL.SILENT)
	flags := flag.NewFlagSet("zolnit-bundle-probe", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	opt := options{}
	flags.StringVar(&opt.account, "account-id", "", "expected account identity")
	flags.StringVar(&opt.outbound, "outbound-id", "", "explicit outbound identity")
	flags.StringVar(&opt.target, "target", "gstatic", "gstatic or cloudflare")
	flags.BoolVar(&opt.probe, "probe", false, "perform a single isolated HTTPS HEAD through the explicit outbound")
	flags.BoolVar(&opt.observe, "observe-egress", false, "observe country and private egress marker through one fixed HTTPS endpoint")
	seconds := flags.Int("timeout-seconds", 10, "connection deadline from 1 through20seconds")
	versionOnly := flags.Bool("version", false, "report compiled source and Core version without reading stdin")
	if flags.Parse(os.Args[1:]) != nil || flags.NArg() != 0 {
		_ = json.NewEncoder(os.Stdout).Encode(report{Code: "invalid_arguments", CoreVersion: C.Version, SourceCommit: sourceCommit})
		os.Exit(2)
	}
	flags.Visit(func(f *flag.Flag) {
		if f.Name == "target" {
			opt.targetExplicit = true
		}
	})
	if *versionOnly {
		_ = json.NewEncoder(os.Stdout).Encode(report{OK: true, Code: "version", CoreVersion: C.Version, SourceCommit: sourceCommit, Mode: "metadata"})
		return
	}
	opt.timeout = time.Duration(*seconds) * time.Second
	result := execute(os.Stdin, opt, time.Now)
	_ = json.NewEncoder(os.Stdout).Encode(result)
	if !result.OK {
		os.Exit(1)
	}
}

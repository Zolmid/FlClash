//go:build zolnit_acceptance

package core

import (
	"bufio"
	"bytes"
	stdcontext "context"
	"core/clientbundle"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	AP "github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/structure"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/log"
	RC "github.com/metacubex/mihomo/rules/common"
	RL "github.com/metacubex/mihomo/rules/logic"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

const acceptanceCoreSHA = "8380d0e7462f061a964323e9bf3129a236fcc5d5"
const acceptanceMaxLine = 8 << 20

var acceptanceMutex sync.Mutex
var acceptanceSHA = regexp.MustCompile(`^[a-f0-9]{40}$`)

type acceptanceCommand struct {
	Schema     int             `json:"schema_version"`
	Action     string          `json:"action"`
	Frame      json.RawMessage `json:"frame,omitempty"`
	Role       string          `json:"role,omitempty"`
	URL        string          `json:"url,omitempty"`
	Outbound   string          `json:"outbound_id,omitempty"`
	CNProvider string          `json:"cn_provider,omitempty"`
	Enabled    *bool           `json:"enabled,omitempty"`
}

type acceptanceReport struct {
	Schema    int    `json:"schema_version"`
	Action    string `json:"action"`
	OK        bool   `json:"ok"`
	Code      string `json:"code"`
	Source    string `json:"source_commit"`
	CoreSHA   string `json:"core_sha"`
	Version   string `json:"core_version"`
	Sequence  uint64 `json:"sequence"`
	Hash      string `json:"connection_sha256,omitempty"`
	Outbounds int    `json:"outbound_count"`
	Providers int    `json:"provider_count"`
	Status    int    `json:"http_status,omitempty"`
}

func acceptanceDecode(line []byte) (*acceptanceCommand, bool) {
	d := json.NewDecoder(bytes.NewReader(line))
	if !clientbundle.UniqueJSON(d, 0) {
		return nil, false
	}
	if _, err := d.Token(); err != io.EOF {
		return nil, false
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(line, &fields) != nil {
		return nil, false
	}
	var c acceptanceCommand
	if json.Unmarshal(line, &c) != nil || c.Schema != 1 {
		return nil, false
	}
	allowed := map[string]bool{"schema_version": true, "action": true}
	switch c.Action {
	case "install", "renew":
		allowed["frame"] = true
	case "select_return", "assert_stale_return", "assert_unavailable_return":
		allowed["role"] = true
	case "set_return_routing":
		allowed["enabled"] = true
		allowed["role"] = true
	case "probe":
		for _, key := range []string{"url", "outbound_id", "role", "cn_provider"} {
			allowed[key] = true
		}
	case "probe_local_return":
		allowed["url"], allowed["cn_provider"] = true, true
	case "inspect", "finish":
	default:
		return nil, false
	}
	for key, value := range fields {
		if !allowed[key] || bytes.Equal(value, []byte("null")) {
			return nil, false
		}
	}
	switch c.Action {
	case "select_return", "assert_stale_return", "assert_unavailable_return":
		if !acceptanceRole(c.Role) {
			return nil, false
		}
	case "set_return_routing":
		if c.Enabled == nil || (*c.Enabled && !acceptanceRole(c.Role)) || (!*c.Enabled && c.Role != "") {
			return nil, false
		}
	case "probe_local_return":
		if c.CNProvider == "" {
			return nil, false
		}
	}
	if c.Action == "probe" && (c.Role != "" && !acceptanceRole(c.Role) || c.Role != "" && c.Outbound != "" || c.Role != "" && c.CNProvider == "" || c.Role == "" && c.CNProvider != "" || c.Role == "" && c.Outbound == "") {
		return nil, false
	}
	return &c, true
}

func acceptanceRole(role string) bool {
	return role == "direct" || role == "hk_lite" || role == "hk_optimized"
}

func acceptanceURL(address string) (*url.URL, bool) {
	u, err := url.Parse(address)
	return u, err == nil && u.Scheme == "https" && u.Hostname() != "" && u.User == nil && u.RawQuery == "" && !u.ForceQuery && u.Fragment == "" && !strings.Contains(address, "#")
}

func acceptancePublicRule(address string) bool {
	u, ok := acceptanceURL(address)
	if !ok || u.Port() != "" {
		return false
	}
	if u.Hostname() == "cdn.jsdelivr.net" {
		return strings.HasPrefix(u.Path, "/gh/MetaCubeX/meta-rules-dat@meta/")
	}
	return u.Hostname() == "raw.githubusercontent.com" && (strings.HasPrefix(u.Path, "/MetaCubeX/meta-rules-dat/") || strings.HasPrefix(u.Path, "/SagerNet/sing-geosite/") || strings.HasPrefix(u.Path, "/SagerNet/sing-geoip/"))
}

func acceptanceUnsafe(value any) bool {
	switch v := value.(type) {
	case map[string]any:
		for key, item := range v {
			switch strings.ToLower(key) {
			case "certificate", "private-key", "ca", "ca-str", "client-fingerprint-file", "health-check":
				return true
			}
			if acceptanceUnsafe(item) {
				return true
			}
		}
	case []any:
		for _, item := range v {
			if acceptanceUnsafe(item) {
				return true
			}
		}
	}
	return false
}

func acceptanceRuleType(tp, payload string, depth int) error {
	if depth > 32 {
		return errors.New("rule nesting limit")
	}
	parse := func(tp, payload, target string, params []string, subRules map[string][]C.Rule) (C.Rule, error) {
		return RC.NewMatch("DIRECT"), acceptanceRuleType(tp, payload, depth+1)
	}
	var err error
	switch tp {
	case "GEOIP", "SRC-GEOIP", "GEOSITE", "IP-ASN", "SRC-IP-ASN":
		return errors.New("implicit geodata unsupported")
	case "AND":
		_, err = RL.NewAND(payload, "DIRECT", parse)
	case "OR":
		_, err = RL.NewOR(payload, "DIRECT", parse)
	case "NOT":
		_, err = RL.NewNOT(payload, "DIRECT", parse)
	case "SUB-RULE":
		_, err = RL.NewSubRule(payload, "DIRECT", nil, parse)
	}
	return err
}
func acceptanceRulesSafe(value any, target ...bool) bool {
	needTarget := len(target) == 0 || target[0]
	switch rules := value.(type) {
	case string:
		tp, payload, _, _ := RC.ParseRulePayload(rules, needTarget)
		return acceptanceRuleType(tp, payload, 0) == nil
	case []any:
		for _, rule := range rules {
			if !acceptanceRulesSafe(rule, needTarget) {
				return false
			}
		}
	case map[string]any:
		for _, rules := range rules {
			if !acceptanceRulesSafe(rules, needTarget) {
				return false
			}
		}
	}
	return true
}

func acceptanceOverlay(bundle *clientbundle.Bundle, home string) (string, bool) {
	var document map[string]any
	if yaml.Unmarshal([]byte(bundle.Connection.Document), &document) != nil || !acceptanceRulesSafe(document["rules"]) || !acceptanceRulesSafe(document["sub-rules"]) {
		return "", false
	}
	if tls, exists := document["tls"]; exists {
		options, ok := tls.(map[string]any)
		if !ok || len(options) != 0 {
			return "", false
		}
	}
	if acceptanceUnsafe(document["proxies"]) {
		return "", false
	}
	if value, exists := document["proxy-providers"]; exists {
		providers, ok := value.(map[string]any)
		if !ok || len(providers) != 0 {
			return "", false
		}
	}
	groups, ok := document["proxy-groups"].([]any)
	if !ok {
		return "", false
	}
	for _, raw := range groups {
		group, ok := raw.(map[string]any)
		if !ok || (group["type"] != "select" && group["type"] != "url-test" && group["type"] != "fallback") {
			return "", false
		}
		for _, key := range []string{"use", "include-all", "include-all-providers", "include-all-proxies"} {
			if value, exists := group[key]; exists && value != 0 && value != false {
				return "", false
			}
		}
	}
	providers := map[string]any{}
	if original, exists := document["rule-providers"]; exists {
		rules, ok := original.(map[string]any)
		if !ok {
			return "", false
		}
		for name, value := range rules {
			if name == "default" {
				return "", false
			}
			for _, service := range bundle.Routing.Services {
				if name == service.Group || name == service.Auto || name == service.Manual {
					return "", false
				}
			}
			p, ok := value.(map[string]any)
			if !ok || !clientbundle.SafeText(name) || p["behavior"] == "classical" && !acceptanceRulesSafe(p["payload"], false) {
				return "", false
			}
			for _, group := range groups {
				if group.(map[string]any)["name"] == name {
					return "", false
				}
			}
			allowed := map[string]bool{"type": true, "behavior": true, "format": true, "url": true, "path": true, "interval": true, "size-limit": true, "payload": true, "proxy": true}
			for key := range p {
				if !allowed[key] {
					return "", false
				}
			}
			if reference, exists := p["proxy"]; exists {
				found := reference == "DIRECT"
				for _, outbound := range bundle.Outbounds {
					found = found || reference == outbound.Name
				}
				for _, raw := range groups {
					found = found || reference == raw.(map[string]any)["name"]
				}
				if !found {
					return "", false
				}
			}
			switch p["type"] {
			case "inline":
				delete(p, "path")
				delete(p, "url")
			case "http":
				if p["behavior"] == "classical" {
					return "", false
				}
				address, _ := p["url"].(string)
				if !acceptancePublicRule(address) {
					return "", false
				}
				hash := sha256.Sum256([]byte(name + address))
				p["path"] = filepath.Join(home, hex.EncodeToString(hash[:])+".rules")
			default:
				return "", false
			}
			p["interval"], p["size-limit"] = 0, 8<<20
			providers[name] = p
		}
	}
	overlay := map[string]any{
		"port": 0, "socks-port": 0, "mixed-port": 0, "redir-port": 0, "tproxy-port": 0, "ss-config": "", "vmess-config": "",
		"allow-lan": false, "mode": "rule", "log-level": "silent", "external-controller": "", "external-controller-tls": "",
		"external-controller-unix": "", "external-controller-pipe": "", "external-ui": "", "external-ui-url": "", "external-doh-server": "", "secret": "",
		"listeners": []any{}, "tunnels": []any{}, "tun": map[string]any{"enable": false}, "tuic-server": map[string]any{"enable": false},
		"dns": map[string]any{"enable": false, "listen": ""}, "ntp": map[string]any{"enable": false, "write-to-system": false},
		"iptables": map[string]any{"enable": false}, "sniffer": map[string]any{"enable": false}, "tls": map[string]any{},
		"profile": map[string]any{"store-selected": false, "store-fake-ip": false}, "geo-auto-update": false, "etag-support": false,
		"find-process-mode": "off", "rule-providers": providers, "proxy-providers": map[string]any{},
	}
	encoded, err := json.Marshal(overlay)
	return string(encoded), err == nil
}

type acceptanceSession struct {
	home         string
	owner        *ClientBundleOwnerGuard
	prepared     *clientbundle.Prepared
	stale        *RoutingLeaseGuard
	targets      map[string]string
	returnGroup  string
	sequence     uint64
	initializers []*acceptanceInitializer
	closers      []io.Closer
	timeout      time.Duration
}

type acceptanceInitializer struct {
	done    chan struct{}
	once    sync.Once
	success atomic.Bool
	initial func() error
}

func (i *acceptanceInitializer) Initial() (err error) {
	i.once.Do(func() {
		defer close(i.done)
		defer func() {
			if recover() != nil {
				err = errors.New("acceptance initializer failed")
			}
		}()
		err = i.initial()
		i.success.Store(err == nil)
	})
	if !i.success.Load() && err == nil {
		err = errors.New("acceptance initializer failed")
	}
	return
}

type acceptanceProxyProvider struct {
	P.ProxyProvider
	init *acceptanceInitializer
}

func (p *acceptanceProxyProvider) Initial() error { return p.init.Initial() }
func (*acceptanceProxyProvider) HealthCheck()     {}
func (*acceptanceProxyProvider) Touch()           {}

type acceptanceRuleProvider struct {
	P.RuleProvider
	init *acceptanceInitializer
}

func (p *acceptanceRuleProvider) Initial() error { return p.init.Initial() }
func (p *acceptanceRuleProvider) Count() int {
	if !p.init.success.Load() {
		return 0
	}
	return p.RuleProvider.Count()
}
func (p *acceptanceRuleProvider) Match(m *C.Metadata, h C.RuleMatchHelper) bool {
	return p.init.success.Load() && p.RuleProvider.Match(m, h)
}

func (s *acceptanceSession) track(initial func() error) *acceptanceInitializer {
	i := &acceptanceInitializer{done: make(chan struct{}), initial: initial}
	s.initializers = append(s.initializers, i)
	return i
}
func (s *acceptanceSession) drain(timeout time.Duration) bool {
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	for _, i := range s.initializers {
		select {
		case <-i.done:
		case <-timer.C:
			return false
		}
	}
	return true
}
func (s *acceptanceSession) ready(timeout time.Duration) bool {
	if !s.drain(timeout) {
		return false
	}
	for _, i := range s.initializers {
		if !i.success.Load() {
			return false
		}
	}
	for _, p := range currentConfig.RuleProviders {
		if p.Count() <= 0 {
			return false
		}
	}
	return true
}

// The pinned apply helper has no interception before hub starts provider Initial.
func (s *acceptanceSession) apply(prepared *clientbundle.Prepared, previous *SetupParams) (bool, error) {
	if err := guardReturnDispatchReplacement(prepared, previous); err != nil {
		return false, err
	}
	lease := &RoutingLeaseSpec{AccountID: "2", AccountGeneration: previous.RoutingLease.AccountGeneration,
		BundleID: prepared.Bundle.ID, ConfigurationDigest: prepared.Digest, ExpiresAt: time.Unix(prepared.Bundle.Expires, 0).UnixMilli(),
		ConnectionDigest: prepared.Bundle.Connection.SHA, MetadataDigest: prepared.MetadataDigest, RenewalOverlay: previous.RoutingLease.RenewalOverlay, ReturnRoute: prepared.ReturnRoute}
	for _, service := range prepared.Services {
		lease.Services = append(lease.Services, RoutingLeaseServiceSpec{GroupName: service.GroupName, AutomaticGroup: service.AutomaticGroup, ManualGroup: service.ManualGroup, AllowedProxies: service.AllowedProxies})
	}
	params := *previous
	params.RoutingLease = lease
	if reuseClientBundleConfigurationLocked(&params) {
		return applyPreparedClientBundleLocked(prepared, previous)
	}
	raw, err := unmarshalRawConfig(prepared.Document)
	if err != nil {
		return false, err
	}
	cfg, err := parsePlatformConfig(withReturnRouteReject(raw, lease))
	if err != nil {
		return false, err
	}
	for _, proxy := range cfg.Proxies {
		s.closers = append(s.closers, proxy)
	}
	before := len(s.initializers)
	if err = s.quietProviders(cfg, raw); err != nil {
		for _, i := range s.initializers[before:] {
			i.initial = func() error { return errors.New("provider preparation failed") }
			_ = i.Initial()
		}
		return false, err
	}
	params.SelectedMap = map[string]string{}
	selectMu.Lock()
	for name, proxy := range tunnel.AllProxies() {
		if selector, ok := adapterAs[pickableGroup](proxy); ok {
			params.SelectedMap[name] = selector.Now()
		}
	}
	selectMu.Unlock()
	for _, service := range prepared.Services {
		params.SelectedMap[service.GroupName] = service.ManualGroup
		params.SelectedMap[service.ManualGroup] = "DIRECT"
	}
	clearRoutingLeaseForConfigChange()
	applyParsedConfigLocked(cfg, &params, nil)
	rememberClientBundleSetupLocked(&params)
	return true, nil
}

func (s *acceptanceSession) quietProviders(cfg *config.Config, raw *config.RawConfig) error {
	for name, original := range cfg.Providers {
		closer, ok := original.(io.Closer)
		if !ok {
			return errors.New("unsupported provider")
		}
		if err := closer.Close(); err != nil {
			return err
		}
		quiet, err := AP.NewCompatibleProvider(name, original.Proxies(), AP.NewHealthCheck(original.Proxies(), "", 5000, 0, true, nil))
		if err != nil {
			return err
		}
		s.closers = append(s.closers, quiet)
		cfg.Providers[name] = &acceptanceProxyProvider{ProxyProvider: quiet, init: s.track(quiet.Initial)}
	}
	mappings := map[string]map[string]any{}
	for _, mapping := range raw.ProxyGroup {
		name, _ := mapping["name"].(string)
		mappings[name] = mapping
	}
	for name, proxy := range cfg.Proxies {
		var base **outboundgroup.GroupBase
		switch group := proxy.Adapter().(type) {
		case *outboundgroup.Selector:
			base = &group.GroupBase
		case *outboundgroup.URLTest:
			base = &group.GroupBase
		case *outboundgroup.Fallback:
			base = &group.GroupBase
		default:
			continue
		}
		group := proxy.Adapter().(interface{ Providers() []P.ProxyProvider })
		providers := []P.ProxyProvider{}
		for _, provider := range group.Providers() {
			providers = append(providers, cfg.Providers[provider.Name()])
		}
		var opt outboundgroup.GroupCommonOption
		if mapping := mappings[name]; mapping != nil {
			if err := structure.NewDecoder(structure.Option{TagName: "group", WeaklyTypedInput: true}).Decode(mapping, &opt); err != nil {
				return err
			}
		}
		*base = outboundgroup.NewGroupBase(outboundgroup.GroupBaseOption{Name: name, Type: proxy.Type(), Hidden: (*base).Hidden(), Icon: (*base).Icon(),
			Filter: opt.Filter, ExcludeFilter: opt.ExcludeFilter, ExcludeType: opt.ExcludeType, TestTimeout: opt.TestTimeout, MaxFailedTimes: opt.MaxFailedTimes,
			EmptyFallback: (*base).EmptyFallback(), Providers: providers, UsePosition: opt.UsePosition})
	}
	for name, p := range cfg.RuleProviders {
		if closer, ok := p.(io.Closer); ok {
			s.closers = append(s.closers, closer)
		}
		cfg.RuleProviders[name] = &acceptanceRuleProvider{RuleProvider: p, init: s.track(p.Initial)}
	}
	return nil
}

func (s *acceptanceSession) install(c *acceptanceCommand, timeout time.Duration) string {
	if (c.Action == "install") != (s.sequence == 0) {
		return "invalid_sequence"
	}
	valid, code := clientbundle.ValidateFrame(bytes.NewReader(c.Frame), "2", routingLeaseNow)
	if code != "" {
		return "invalid_frame"
	}
	var frame struct {
		Status int             `json:"http_status"`
		Path   string          `json:"source_path"`
		Body   json.RawMessage `json:"body"`
	}
	d := json.NewDecoder(bytes.NewReader(c.Frame))
	d.DisallowUnknownFields()
	if d.Decode(&frame) != nil {
		return "invalid_frame"
	}
	overlay, safe := acceptanceOverlay(valid.Bundle, s.home)
	if !safe {
		return "unsafe_configuration"
	}
	prepared, code := clientbundle.Prepare(frame.Body, "2", overlay, routingLeaseNow())
	if code != "" {
		return "invalid_bundle"
	}
	if s.sequence != 0 {
		if len(prepared.Services) != len(s.prepared.Services) {
			return "unsupported_services"
		}
		for i, service := range prepared.Services {
			if service.GroupName != s.prepared.Services[i].GroupName {
				return "unsupported_services"
			}
		}
		context := handleGetClientBundleOwner()
		if context == nil {
			return "invalid_owner"
		}
		s.stale = context.ReturnRouteGuard
	}
	if s.sequence == 0 {
		previous := &SetupParams{SelectedMap: map[string]string{}, RoutingLease: &RoutingLeaseSpec{AccountID: "2", AccountGeneration: 1, RenewalOverlay: overlay}}
		for _, service := range prepared.Services {
			previous.SelectedMap[service.GroupName] = service.ManualGroup
			previous.SelectedMap[service.ManualGroup] = "DIRECT"
		}
		applied, err := func() (bool, error) {
			configMu.Lock()
			defer configMu.Unlock()
			applied, err := s.apply(prepared, previous)
			selectMu.Lock()
			defer selectMu.Unlock()
			patchSelectGroupLocked(previous.SelectedMap)
			refreshRouteLocked(true)
			return applied, err
		}()
		if err != nil || !applied {
			return "install_failed"
		}
		context := handleGetClientBundleOwner()
		if context == nil {
			return "invalid_owner"
		}
		s.owner, err = handleBeginClientBundleOwner(&BeginClientBundleOwnerParams{ClientBundleOwnerContext: *context, SessionEpoch: 1, OwnerID: 1, Generation: 1})
		if err != nil {
			return "invalid_owner"
		}
	} else {
		configMu.Lock()
		clientBundleSetup.RoutingLease.RenewalOverlay = overlay
		configMu.Unlock()
	}
	applied, err := handleInstallClientBundle(&InstallClientBundleParams{Owner: s.owner, Sequence: s.sequence + 1, Body: string(frame.Body)})
	if err != nil || !applied {
		return "install_failed"
	}
	s.sequence++
	s.prepared = prepared
	s.returnGroup = ""
	s.targets = map[string]string{}
	if prepared.ReturnRoute != nil {
		s.returnGroup = prepared.ReturnRoute.GroupName
		for _, option := range prepared.ReturnRoute.Options {
			s.targets[option.ID] = option.Target
		}
	}
	if !s.ready(timeout) {
		return "rules_not_ready"
	}
	return "ok"
}

func (s *acceptanceSession) returnWrite(c *acceptanceCommand) string {
	context := handleGetClientBundleOwner()
	if context == nil || s.returnGroup == "" {
		return "return_unavailable"
	}
	spec := s.prepared.ReturnRoute
	target := s.targets[c.Role]
	if target == "" {
		return "return_unavailable"
	}
	guard := context.ReturnRouteGuard
	if guard == nil || (spec == nil && c.Action != "assert_unavailable_return") {
		return "return_unavailable"
	}
	if c.Action == "assert_stale_return" {
		if s.stale == nil || *s.stale == *guard {
			return "missing_stale_guard"
		}
		guard = s.stale
	}
	if c.Action == "assert_unavailable_return" && spec != nil && returnRouteUsable(spec, target, tunnel.AllProxies()) && returnRouteMember(spec, target, tunnel.AllProxies()) {
		return "return_still_available"
	}
	result := handleChangeProxy(&ChangeProxyParams{GroupName: s.returnGroup, ProxyName: target, RoutingLease: guard})
	rejected := result.Message != ""
	if rejected != (c.Action != "select_return") {
		return "return_check_failed"
	}
	return "ok"
}

func (s *acceptanceSession) setReturnRouting(c *acceptanceCommand) string {
	context := handleGetClientBundleOwner()
	if context == nil || context.ReturnRouteGuard == nil {
		return "return_unavailable"
	}
	if s.prepared == nil || s.prepared.ReturnRoute == nil {
		return "return_unavailable"
	}
	enabled := c.Enabled != nil && *c.Enabled
	result, err := handleSetClientReturnRoute(&SetClientReturnRouteParams{
		RoutingLease: context.ReturnRouteGuard,
		Enabled:      &enabled,
		OptionID:     c.Role,
	})
	if err != nil {
		return "dispatch_failed"
	}
	if result.Enabled != enabled {
		return "dispatch_state_mismatch"
	}
	if enabled && (result.SelectedID == nil || *result.SelectedID != c.Role) {
		return "dispatch_selection_mismatch"
	}
	if enabled && len(result.Selections) < 3 {
		return "dispatch_selection_incomplete"
	}
	if !enabled && len(result.Selections) < 2 {
		return "dispatch_selection_incomplete"
	}
	return "ok"
}

func (s *acceptanceSession) probe(c *acceptanceCommand, timeout time.Duration) (string, int) {
	u, safe := acceptanceURL(c.URL)
	local := c.Action == "probe_local_return"
	if !safe || c.Outbound == "" && c.Role == "" && !local {
		return "invalid_probe", 0
	}
	proxy := ""
	if c.Outbound != "" {
		for _, outbound := range s.prepared.Bundle.Outbounds {
			if outbound.ID == c.Outbound {
				proxy = outbound.Name
			}
		}
		if proxy == "" || !isLeaseNetworkProxy(tunnel.AllProxies()[proxy]) {
			return "invalid_outbound", 0
		}
	}
	var guard *RoutingLeaseGuard
	if c.Role != "" || local {
		context := handleGetClientBundleOwner()
		if context == nil || context.ReturnRouteGuard == nil || s.prepared.ReturnRoute == nil {
			return "return_unavailable", 0
		}
		guard = context.ReturnRouteGuard
		provider := currentConfig.RuleProviders[c.CNProvider]
		if provider == nil || !s.ready(timeout) {
			return "rules_not_ready", 0
		}
		metadata := &C.Metadata{NetWork: C.TCP, Type: C.INNER}
		port := u.Port()
		if port == "" {
			port = "443"
		}
		ctx, cancel := stdcontext.WithTimeout(stdcontext.Background(), timeout)
		defer cancel()
		resolve := func() {
			if !metadata.DstIP.IsValid() {
				metadata.DstIP, _ = resolver.ResolveIP(ctx, metadata.Host)
			}
		}
		if metadata.SetRemoteAddress(net.JoinHostPort(u.Hostname(), port)) != nil || !provider.Match(metadata, C.RuleMatchHelper{ResolveIP: resolve, FindProcess: func() {}, CheckPassRule: func(string) bool { return false }}) {
			return "cn_rule_mismatch", 0
		}
		if !s.dispatchProbeState(c.Role, nil, local) {
			return "return_dispatch_mismatch", 0
		}
		selector, ok := returnRouteSelector(s.prepared.ReturnRoute, tunnel.AllProxies())
		if !local && (!ok || selector.Now() != s.targets[c.Role]) {
			return "return_selection_mismatch", 0
		}
	}
	follow := false
	result := handleProbe(&ProbeParams{Url: c.URL, ProxyName: proxy, Timeout: timeout.Milliseconds(), MaxBody: 0, FollowRedirects: &follow})
	if result == nil || result.Error != "" {
		return "probe_failed", 0
	}
	if result.StatusCode < 200 || result.StatusCode >= 300 {
		return "probe_status", result.StatusCode
	}
	if c.Role != "" || local {
		context := handleGetClientBundleOwner()
		selector, selected := returnRouteSelector(s.prepared.ReturnRoute, tunnel.AllProxies())
		if context == nil || context.ReturnRouteGuard == nil || *context.ReturnRouteGuard != *guard ||
			!s.dispatchProbeState(c.Role, result.Chains, local) ||
			(!local && (!selected || selector.Now() != s.targets[c.Role] || !nativeContains(result.Chains, s.prepared.ReturnRoute.GroupName) || !nativeContains(result.Chains, s.targets[c.Role]))) {
			return "return_route_mismatch", result.StatusCode
		}
	}
	if local {
		if len(result.Chains) == 0 || result.Chains[0] != directProxyName || nativeContains(result.Chains, s.prepared.ReturnRoute.GroupName) {
			return "return_route_mismatch", result.StatusCode
		}
		return "ok", result.StatusCode
	}
	if !s.physicalChain(result.Chains) || proxy != "" && !nativeContains(result.Chains, proxy) {
		return "probe_leaf_mismatch", result.StatusCode
	}
	return "ok", result.StatusCode
}

func (s *acceptanceSession) dispatchProbeState(role string, chain []string, local bool) bool {
	if s.prepared == nil || s.prepared.ReturnRoute == nil {
		return false
	}
	if len(s.prepared.ReturnRoute.Dispatches) == 0 {
		return !local
	}
	selectMu.Lock()
	defer selectMu.Unlock()
	state := activeRoutingLease
	if state == nil || state.returnRoute == nil || state.returnRoute.retired || state.returnRoute.blocked {
		return false
	}
	rr := state.returnRoute
	if len(rr.dispatches) != 2 || rr.enabled == local || (!local && rr.selectedID != role) {
		return false
	}
	matched := chain == nil
	proxies := tunnel.AllProxies()
	for _, d := range rr.dispatches {
		target := d.spec.ReturnTarget
		if local {
			target = d.spec.LocalTarget
		}
		if proxies[d.spec.GroupName] != d.proxy || d.selector.Now() != target {
			return false
		}
		matched = matched || nativeContains(chain, d.spec.GroupName) && nativeContains(chain, target)
	}
	return matched
}

func (s *acceptanceSession) physicalChain(chain []string) bool {
	if len(chain) == 0 {
		return false
	}
	for _, outbound := range s.prepared.Bundle.Outbounds {
		if chain[0] == outbound.Name && isLeaseNetworkProxy(tunnel.AllProxies()[outbound.Name]) {
			return true
		}
	}
	return false
}

var acceptanceRemoveHome = os.RemoveAll
var acceptanceClose = func(closer io.Closer) error { return closer.Close() }

func acceptanceSafeCall(fn func() bool) (ok bool) {
	defer func() {
		if recover() != nil {
			ok = false
		}
	}()
	return fn()
}
func (s *acceptanceSession) cleanup(oldHome string) bool {
	ok := acceptanceSafeCall(func() bool { configMu.Lock(); defer configMu.Unlock(); stopClientBundleRoutingLocked(); return true })
	for _, closer := range s.closers {
		ok = acceptanceSafeCall(func() bool { return acceptanceClose(closer) == nil }) && ok
	}
	ok = s.drain(s.timeout) && ok
	ok = acceptanceSafeCall(handleShutdown) && ok
	C.SetHomeDir(oldHome)
	ok = acceptanceSafeCall(func() bool { return acceptanceRemoveHome(s.home) == nil }) && ok
	return ok
}

func RunClientBundleAcceptance(input io.Reader, output io.Writer, sourceCommit string, timeout time.Duration) (result bool) {
	report := acceptanceReport{Schema: 1, Action: "input", Source: sourceCommit, CoreSHA: acceptanceCoreSHA, Version: C.Version}
	emit := func(code string) bool {
		report.Code, report.OK = code, code == "ok"
		return json.NewEncoder(output).Encode(report) == nil
	}
	defer func() {
		if recover() != nil {
			report.Action = "input"
			report.Code = "acceptance_panic"
			report.OK = false
			result = false
			_ = acceptanceSafeCall(func() bool { return json.NewEncoder(output).Encode(report) == nil })
		}
	}()
	if !acceptanceSHA.MatchString(sourceCommit) {
		report.Source = ""
		emit("invalid_source")
		return false
	}
	if timeout < time.Second || timeout > 20*time.Second {
		emit("invalid_timeout")
		return false
	}
	if !acceptanceMutex.TryLock() {
		emit("core_busy")
		return false
	}
	defer acceptanceMutex.Unlock()
	if isInit.Load() || isRunning.Load() || currentConfig != nil {
		emit("core_busy")
		return false
	}
	home, err := os.MkdirTemp("", "zolnit-acceptance-")
	if err != nil {
		emit("home_failed")
		return false
	}
	for _, name := range []string{"config.yaml", "cache.db"} {
		if os.Mkdir(filepath.Join(home, name), 0700) != nil {
			_ = os.RemoveAll(home)
			emit("home_failed")
			return false
		}
	}
	oldHome := C.Path.HomeDir()
	log.SetLevel(log.SILENT)
	s := &acceptanceSession{home: home, targets: map[string]string{}, timeout: timeout}
	configMu.Lock()
	oldApply := clientBundleApply
	clientBundleApply = s.apply
	configMu.Unlock()
	finished := false
	defer func() {
		clean := s.cleanup(oldHome)
		configMu.Lock()
		clientBundleApply = oldApply
		configMu.Unlock()
		if !clean {
			result = false
			emit("cleanup_failed")
		} else if finished {
			result = emit("ok")
		}
	}()
	if !handleInitClash(&InitParams{HomeDir: home}) {
		emit("init_failed")
		return false
	}
	limited := &io.LimitedReader{R: input, N: (64 << 20) + 1}
	scanner := bufio.NewScanner(limited)
	scanner.Buffer(make([]byte, 4096), acceptanceMaxLine+1)
	for scanner.Scan() {
		if len(scanner.Bytes()) > acceptanceMaxLine {
			report.Action = "input"
			emit("invalid_command")
			return false
		}
		c, ok := acceptanceDecode(scanner.Bytes())
		if !ok {
			report.Action = "input"
			emit("invalid_command")
			return false
		}
		report.Action, report.Status = c.Action, 0
		code := "ok"
		switch c.Action {
		case "install", "renew":
			code = s.install(c, timeout)
		default:
			if s.sequence == 0 {
				code = "not_installed"
				break
			}
			switch c.Action {
			case "select_return", "assert_stale_return", "assert_unavailable_return":
				code = s.returnWrite(c)
			case "set_return_routing":
				code = s.setReturnRouting(c)
			case "probe", "probe_local_return":
				code, report.Status = s.probe(c, timeout)
			case "inspect":
				if !s.ready(timeout) {
					code = "rules_not_ready"
				}
			case "finish":
				if scanner.Scan() || scanner.Err() != nil || limited.N == 0 {
					emit("invalid_command")
					return false
				}
				finished = true
				return true
			}
		}
		report.Sequence = s.sequence
		if s.prepared != nil {
			report.Hash = s.prepared.Bundle.Connection.SHA
			report.Outbounds = len(s.prepared.Bundle.Outbounds)
			report.Providers = len(currentConfig.RuleProviders)
		}
		if !emit(code) || code != "ok" {
			return false
		}
	}
	report.Action = "input"
	if scanner.Err() != nil || limited.N == 0 {
		emit("invalid_command")
		return false
	}
	emit("unfinished")
	return false
}

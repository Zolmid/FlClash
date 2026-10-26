//go:build zolnit_acceptance

package core

import (
	"bytes"
	"core/clientbundle"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

func acceptanceFixture(t *testing.T, one, downgrade bool, endpoint, priority string, empty bool) map[string]any {
	t.Helper()
	var body map[string]any
	if json.Unmarshal(returnInstallBody(t, downgrade), &body) != nil {
		t.Fatal("fixture decode")
	}
	data := body["data"].(map[string]any)
	data["account_id"], data["issued_at"], data["expires_at"] = "2", time.Now().Unix(), time.Now().Unix()+240
	connection := data["connection"].(map[string]any)
	var document map[string]any
	if yaml.Unmarshal([]byte(connection["document"].(string)), &document) != nil {
		t.Fatal("document decode")
	}
	outbounds := data["outbounds"].([]any)
	if one {
		outbounds = outbounds[:1]
		data["outbounds"] = outbounds
	}
	host, port, err := net.SplitHostPort(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	var portNumber int
	for _, digit := range port {
		portNumber = portNumber*10 + int(digit-'0')
	}
	proxies := []any{}
	for _, raw := range outbounds {
		proxies = append(proxies, map[string]any{"type": "http", "name": raw.(map[string]any)["proxy_name"], "server": host, "port": portNumber, "password": "PUBLIC_SYNTHETIC_MARKER"})
	}
	document["proxies"] = proxies
	physical := outbounds[0].(map[string]any)["proxy_name"].(string)
	role := data["routing"].(map[string]any)["ui_groups"].([]any)[0].(map[string]any)
	returnGroup := role["group"].(string)
	for _, raw := range document["proxy-groups"].([]any) {
		group := raw.(map[string]any)
		if group["name"] != returnGroup && !(downgrade && group["proxies"].([]any)[0] == "REJECT") {
			group["proxies"] = []any{physical}
		}
	}
	payload := []any{"127.0.0.0/8"}
	if empty {
		payload = []any{}
	}
	document["rule-providers"] = map[string]any{"synthetic-cn": map[string]any{"type": "inline", "behavior": "ipcidr", "payload": payload}}
	document["rules"] = []any{"RULE-SET,synthetic-cn," + returnGroup, "MATCH,DIRECT"}
	if priority != "" {
		document["rules"] = append([]any{priority}, document["rules"].([]any)...)
	}
	document["mixed-port"], document["external-controller"] = 7890, "127.0.0.1:9090"
	document["dns"] = map[string]any{"enable": true, "listen": "127.0.0.1:1053"}
	document["tun"] = map[string]any{"enable": true, "auto-route": true}
	document["profile"] = map[string]any{"store-selected": true, "store-fake-ip": true}
	document["ntp"] = map[string]any{"enable": true, "write-to-system": true}
	document["listeners"] = []any{map[string]any{"name": "forbidden", "type": "http", "port": 10099}}
	document["tunnels"] = []any{map[string]any{"network": "tcp", "address": "127.0.0.1:10098", "target": "127.0.0.1:1"}}
	encoded, err := yaml.Marshal(document)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(encoded)
	connection["document"], connection["sha256"] = string(encoded), hex.EncodeToString(hash[:])
	return body
}

func acceptanceLine(value any) string { data, _ := json.Marshal(value); return string(data) + "\n" }
func acceptanceAction(action string) map[string]any {
	return map[string]any{"schema_version": 1, "action": action}
}
func acceptanceInstall(action string, body map[string]any) string {
	c := acceptanceAction(action)
	c["frame"] = map[string]any{"http_status": 200, "source_path": "/api/v1/zolnit/client/bundle", "body": body}
	return acceptanceLine(c)
}
func acceptanceReturn(action, role string) string {
	c := acceptanceAction(action)
	c["role"] = role
	return acceptanceLine(c)
}

type acceptanceStages struct {
	parts  []string
	before func(int)
	index  int
}

func (s *acceptanceStages) Read(p []byte) (int, error) {
	if s.index >= len(s.parts) {
		return 0, io.EOF
	}
	if s.before != nil {
		s.before(s.index)
	}
	n := copy(p, s.parts[s.index])
	s.parts[s.index] = s.parts[s.index][n:]
	if s.parts[s.index] == "" {
		s.index++
	}
	return n, nil
}

func TestAcceptanceVerticalIsolated(t *testing.T) {
	scenario := os.Getenv("ZOLNIT_ACCEPTANCE_CHILD")
	if scenario == "" {
		for _, name := range []string{"three", "one", "available", "priority", "probe", "empty", "malformed", "oversize", "trailing", "cn_mismatch", "absent", "manual_expired", "and", "dst", "leaf", "authoritative", "cleanup_remove", "cleanup_close", "panic"} {
			t.Run(name, func(t *testing.T) {
				command := exec.Command(os.Args[0], "-test.run=^TestAcceptanceVerticalIsolated$", "-test.timeout=20s")
				command.Env = append(os.Environ(), "ZOLNIT_ACCEPTANCE_CHILD="+name)
				if output, err := command.CombinedOutput(); err != nil {
					t.Fatalf("isolated %s: %v\n%s", name, err, output)
				}
			})
		}
		return
	}
	destination := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	defer destination.Close()
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		target, _ := url.Parse(destination.URL)
		if r.Method != "CONNECT" || r.Host != target.Host {
			w.WriteHeader(403)
			return
		}
		upstream, err := net.DialTimeout("tcp", target.Host, time.Second)
		if err != nil {
			w.WriteHeader(502)
			return
		}
		defer upstream.Close()
		conn, _, err := w.(http.Hijacker).Hijack()
		if err != nil {
			return
		}
		defer conn.Close()
		_, _ = io.WriteString(conn, "HTTP/1.1 200 Connection Established\r\n\r\n")
		go func() { _, _ = io.Copy(upstream, conn); _ = upstream.Close() }()
		_, _ = io.Copy(conn, upstream)
	}))
	defer proxy.Close()
	proxyURL, _ := url.Parse(proxy.URL)
	priority := ""
	if scenario == "priority" {
		priority = "IP-CIDR,127.0.0.0/8,DIRECT,no-resolve"
	}
	initial := acceptanceFixture(t, scenario == "one", false, proxyURL.Host, priority, scenario == "empty")

	var healthRequests atomic.Int32
	health := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { healthRequests.Add(1); w.WriteHeader(204) }))
	defer health.Close()
	if scenario == "authoritative" {
		initial = acceptanceAuthoritativeFixture(t, proxyURL.Host, health.URL)
	}
	if scenario == "and" || scenario == "dst" || scenario == "leaf" {
		acceptanceMutateDocument(t, initial, func(document map[string]any) {
			role := initial["data"].(map[string]any)["routing"].(map[string]any)["ui_groups"].([]any)[0].(map[string]any)
			group := role["group"].(string)
			rule := "AND,((IP-CIDR,127.0.0.0/8),(NETWORK,TCP))," + group
			if scenario == "dst" {
				u, _ := url.Parse(destination.URL)
				rule = "DST-PORT," + u.Port() + "," + group
			}
			document["rules"] = []any{rule, "MATCH,DIRECT"}
			if scenario == "leaf" {
				target := role["options"].([]any)[1].(map[string]any)["target"]
				for _, raw := range document["proxy-groups"].([]any) {
					g := raw.(map[string]any)
					if g["name"] == target {
						g["proxies"] = append([]any{"DIRECT"}, g["proxies"].([]any)...)
					}
				}
			}
		})
	}
	original, _ := json.Marshal(initial)
	parts := []string{acceptanceInstall("install", initial)}
	expected, success := "ok", true
	switch scenario {
	case "one", "three", "absent", "manual_expired":
		renewal := acceptanceFixture(t, scenario == "one", true, proxyURL.Host, "", false)
		if scenario == "absent" {
			delete(renewal["data"].(map[string]any)["routing"].(map[string]any), "ui_groups")
		}
		parts = append(parts, acceptanceReturn("select_return", "hk_optimized"), acceptanceInstall("renew", renewal), acceptanceReturn("assert_stale_return", "hk_lite"), acceptanceReturn("assert_unavailable_return", "hk_optimized"), acceptanceReturn("select_return", "hk_lite"))
	case "available":
		parts = append(parts, acceptanceReturn("assert_unavailable_return", "hk_lite"))
		expected, success = "return_still_available", false
	case "empty":
		expected, success = "rules_not_ready", false
	case "probe", "priority", "cn_mismatch", "and", "dst", "leaf", "authoritative":
		parts = append(parts, acceptanceReturn("select_return", "hk_lite"))
		probe := acceptanceAction("probe")
		probe["url"], probe["role"], probe["cn_provider"] = destination.URL, "hk_lite", "synthetic-cn"
		if scenario == "cn_mismatch" {
			probe["url"] = "https://192.0.2.1/"
			expected, success = "cn_rule_mismatch", false
		}
		parts = append(parts, acceptanceLine(probe))
		if scenario == "priority" {
			expected, success = "return_route_mismatch", false
		}
		if scenario == "leaf" {
			expected, success = "probe_leaf_mismatch", false
		}
	case "malformed":
		parts = []string{`{"schema_version":1,"schema_version":1,"action":"finish","secret":"PUBLIC_SYNTHETIC_MARKER"}` + "\n"}
		expected, success = "invalid_command", false
	case "oversize":
		parts = []string{strings.Repeat(" ", acceptanceMaxLine+2)}
		expected, success = "invalid_command", false
	}
	if scenario == "absent" {
		parts = []string{parts[0], parts[1], parts[2], acceptanceReturn("assert_unavailable_return", "hk_optimized")}
		expected, success = "return_unavailable", false
	}
	parts = append(parts, acceptanceLine(acceptanceAction("inspect")), acceptanceLine(acceptanceAction("finish")))
	if scenario == "trailing" {
		parts = append(parts, acceptanceLine(acceptanceAction("inspect")))
		expected, success = "invalid_command", false
	}

	if scenario == "cleanup_remove" {
		original := acceptanceRemoveHome
		acceptanceRemoveHome = func(path string) error {
			if err := original(path); err != nil {
				return err
			}
			return errors.New("PUBLIC_SYNTHETIC_MARKER")
		}
		expected, success = "cleanup_failed", false
	}
	if scenario == "cleanup_close" {
		original := acceptanceClose
		acceptanceClose = func(closer io.Closer) error {
			if err := original(closer); err != nil {
				return err
			}
			return errors.New("PUBLIC_SYNTHETIC_MARKER")
		}
		expected, success = "cleanup_failed", false
	}
	if scenario == "panic" {
		expected, success = "acceptance_panic", false
	}
	oldHome := C.Path.HomeDir()
	var owned string
	var loaded atomic.Int32
	oldHook := executor.DefaultProviderLoadedHook
	executor.DefaultProviderLoadedHook = func(name string) {
		if name == "synthetic-cn" {
			loaded.Add(1)
		}
		if oldHook != nil {
			oldHook(name)
		}
	}
	countedHook := reflect.ValueOf(executor.DefaultProviderLoadedHook).Pointer()
	input := &acceptanceStages{parts: parts, before: func(index int) {
		if index == 0 || currentConfig == nil {
			return
		}
		owned = C.Path.HomeDir()
		if scenario == "panic" {
			panic("PUBLIC_SYNTHETIC_MARKER")
		}
		if scenario == "manual_expired" && index == 4 {
			if guard := handleGetRoutingLease(); guard != nil {
				handleInvalidateRoutingLease(guard)
			}
			if handleGetRoutingLease() != nil || handleGetClientBundleOwner().ReturnRouteGuard == nil {
				t.Fatal("manual authority regression missing")
			}
		}
		if index == 1 {
			if (&acceptanceSession{initializers: []*acceptanceInitializer{{done: make(chan struct{})}}}).ready(10 * time.Millisecond) {
				t.Fatal("config ACK masqueraded as loaded rules")
			}
		}
		if scenario == "authoritative" {
			time.Sleep(10 * time.Millisecond)
			for _, provider := range currentConfig.Providers {
				provider.HealthCheck()
			}
			if healthRequests.Load() != 0 {
				t.Fatal("autonomous health networking")
			}
			spec := clientBundleSetup.RoutingLease.ReturnRoute
			if tunnel.AllProxies()[spec.Options[1].Target].Type() != C.URLTest || tunnel.AllProxies()[spec.Options[2].Target].Type() != C.Fallback {
				t.Fatal("group types changed")
			}
		}
		cfg := currentConfig
		if cfg.General.MixedPort != 0 || cfg.General.Tun.Enable || cfg.DNS.Enable || cfg.DNS.Listen != "" || cfg.Controller.ExternalController != "" || len(cfg.Listeners) != 0 || len(cfg.Tunnels) != 0 || cfg.NTP.Enable || cfg.NTP.WriteToSystem || cfg.Profile.StoreSelected || cfg.Profile.StoreFakeIP {
			t.Fatal("unsafe applied overlay")
		}
		for _, service := range clientBundleSetup.RoutingLease.Services {
			selector, ok := adapterAs[pickableGroup](tunnel.AllProxies()[service.GroupName])
			if !ok || selector.Now() != service.ManualGroup {
				t.Fatal("automatic service probing enabled")
			}
		}
		entries, err := os.ReadDir(owned)
		if err != nil {
			t.Fatal(err)
		}
		for _, entry := range entries {
			if !entry.IsDir() {
				t.Fatal("inline acceptance wrote a file")
			}
		}
		if err := ca.AddCertificate(string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: destination.Certificate().Raw}))); err != nil {
			t.Fatal(err)
		}
	}}
	var output bytes.Buffer
	result := RunClientBundleAcceptance(input, &output, strings.Repeat("a", 40), time.Second)
	if result != success {
		t.Fatalf("success=%v reports=%s", result, output.String())
	}
	var last acceptanceReport
	for _, line := range bytes.Split(bytes.TrimSpace(output.Bytes()), []byte("\n")) {
		if json.Unmarshal(line, &last) != nil {
			t.Fatal("invalid output")
		}
	}
	if !success && (scenario == "cleanup_close" || scenario == "cleanup_remove") {
		for _, line := range bytes.Split(bytes.TrimSpace(output.Bytes()), []byte("\n")) {
			var report acceptanceReport
			_ = json.Unmarshal(line, &report)
			if report.Action == "finish" && report.OK {
				t.Fatal("finish succeeded before cleanup")
			}
		}
	}
	if last.Code != expected {
		t.Fatalf("code=%s expected=%s reports=%s", last.Code, expected, output.String())
	}
	for _, marker := range []string{"PUBLIC_SYNTHETIC_MARKER", destination.URL, "synthetic-cn", "zn.node.", "zn.group.", "CONNECTION_CREDENTIAL", "uuid", "body", "Chains"} {
		if strings.Contains(output.String(), marker) {
			t.Fatalf("unredacted marker %s", marker)
		}
	}
	after, _ := json.Marshal(initial)
	if !bytes.Equal(original, after) {
		t.Fatal("source object mutated")
	}
	if owned != "" {
		if _, err := os.Stat(owned); !os.IsNotExist(err) {
			t.Fatal("home not cleaned")
		}
	}
	if C.Path.HomeDir() != oldHome || isInit.Load() || currentConfig != nil {
		t.Fatal("core not released")
	}
	if reflect.ValueOf(executor.DefaultProviderLoadedHook).Pointer() != countedHook {
		t.Fatal("ordinary provider hook changed")
	}
	if scenario == "authoritative" {
		second := acceptanceInstall("install", initial) + acceptanceLine(acceptanceAction("finish"))
		output.Reset()
		if !RunClientBundleAcceptance(strings.NewReader(second), &output, strings.Repeat("a", 40), time.Second) {
			t.Fatalf("second invocation failed %s", output.String())
		}
		if reflect.ValueOf(executor.DefaultProviderLoadedHook).Pointer() != countedHook {
			t.Fatal("hook retained across calls")
		}
		if healthRequests.Load() != 0 {
			t.Fatal("repeat invocation health networking")
		}
	}
	if success && loaded.Load() == 0 {
		t.Fatal("ordinary loaded hook not forwarded")
	}
}

func TestAcceptanceVerticalCommandAndFrameGuards(t *testing.T) {
	for _, line := range []string{
		`{"schema_version":1,"action":"inspect","role":"direct"}`,
		`{"schema_version":1,"action":"probe","url":"https://example.test","role":"direct","is_cn":true}`,
		`{"schema_version":1,"action":"select_return","role":"invented"}`,
		`{"schema_version":1,"action":"finish"} {}`,
		`{"schema_version":1,"action":"renew","frame":{"body":{"data":1,"data":2}}}`,
		`{"schema_version":1,"action":"finish","action":"inspect"}`,
		`{"schema_version":1,"action":"assert_unavailable_return","role":null}`,
	} {
		if _, ok := acceptanceDecode([]byte(line)); ok {
			t.Fatal("unsafe command accepted")
		}
	}
	for _, address := range []string{"http://example.test/", "https://user@example.test/", "https://example.test/?a", "https://example.test/?", "https://example.test/#", "https://example.test/#f"} {
		if _, ok := acceptanceURL(address); ok {
			t.Fatal("unsafe URL accepted")
		}
	}
	body := acceptanceFixture(t, false, false, "127.0.0.1:1", "", false)
	for _, kind := range []string{"account", "status", "ttl", "unknown", "source", "trailing", "size"} {
		t.Run(kind, func(t *testing.T) {
			encoded, _ := json.Marshal(body)
			var clone map[string]any
			_ = json.Unmarshal(encoded, &clone)
			frame := map[string]any{"http_status": 200, "source_path": "/api/v1/zolnit/client/bundle", "body": clone}
			switch kind {
			case "account":
				clone["data"].(map[string]any)["account_id"] = "3"
			case "status":
				frame["http_status"] = 403
			case "ttl":
				clone["data"].(map[string]any)["expires_at"] = 0
			case "unknown":
				frame["secret"] = "PUBLIC_SYNTHETIC_MARKER"
			case "source":
				frame["source_path"] = "/private"
			}
			raw, _ := json.Marshal(frame)
			if kind == "trailing" {
				raw = append(raw, []byte(" {}")...)
			}
			if kind == "size" {
				raw = []byte(strings.Repeat(" ", acceptanceMaxLine+1))
			}
			session := &acceptanceSession{home: t.TempDir(), targets: map[string]string{}}
			if code := session.install(&acceptanceCommand{Action: "install", Frame: raw}, time.Second); code != "invalid_frame" {
				t.Fatalf("unexpected code %s", code)
			}
		})
	}
	validated, code := clientbundle.Parse([]byte(acceptanceLine(body)), "2", time.Now())
	if code != "" {
		t.Fatal(code)
	}
	overlay, ok := acceptanceOverlay(validated.Bundle, t.TempDir())
	if !ok || !strings.Contains(overlay, `"store-selected":false`) {
		t.Fatal("safe overlay failed")
	}
	var document map[string]any
	_ = yaml.Unmarshal([]byte(validated.Bundle.Connection.Document), &document)
	for _, kind := range []string{"file", "background", "geodata", "credential-file", "provider-collision", "tls-file", "external-provider"} {
		t.Run(kind, func(t *testing.T) {
			raw, _ := yaml.Marshal(document)
			var clone map[string]any
			_ = yaml.Unmarshal(raw, &clone)
			switch kind {
			case "tls-file":
				clone["tls"] = map[string]any{"ech-key": "/private/secret"}
			case "external-provider":
				clone["proxy-providers"] = map[string]any{"unsafe": map[string]any{"type": "http", "url": "https://example.test/private"}}
			case "file":
				clone["rule-providers"] = map[string]any{"unsafe": map[string]any{"type": "file", "path": "/private/secret"}}
			case "background":
				clone["proxy-groups"].([]any)[0].(map[string]any)["type"] = "load-balance"
			case "geodata":
				clone["rules"] = []any{"GEOIP,CN,DIRECT"}
			case "provider-collision":
				clone["rule-providers"] = map[string]any{"zn.service.ai.auto": map[string]any{"type": "inline", "behavior": "ipcidr", "payload": []any{"127.0.0.0/8"}}}
			case "credential-file":
				clone["proxies"].([]any)[0].(map[string]any)["certificate"] = "/private/secret"
			}
			encoded, _ := yaml.Marshal(clone)
			bundle := *validated.Bundle
			bundle.Connection.Document = string(encoded)
			if _, ok := acceptanceOverlay(&bundle, t.TempDir()); ok {
				t.Fatal("unsafe configuration accepted")
			}
		})
	}
}

func acceptanceMutateDocument(t *testing.T, body map[string]any, mutate func(map[string]any)) {
	t.Helper()
	connection := body["data"].(map[string]any)["connection"].(map[string]any)
	var document map[string]any
	if yaml.Unmarshal([]byte(connection["document"].(string)), &document) != nil {
		t.Fatal("fixture document")
	}
	mutate(document)
	encoded, err := yaml.Marshal(document)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(encoded)
	connection["document"], connection["sha256"] = string(encoded), hex.EncodeToString(hash[:])
}

func acceptanceAuthoritativeFixture(t *testing.T, endpoint, health string) map[string]any {
	t.Helper()
	raw, err := os.ReadFile("../packages/zolnit_client/test/fixtures/ui-groups-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var data map[string]any
	if json.Unmarshal(raw, &data) != nil {
		t.Fatal("producer fixture")
	}
	data["account_id"], data["issued_at"], data["expires_at"] = "2", time.Now().Unix(), time.Now().Unix()+240
	data["routing"].(map[string]any)["nodes"] = []any{}
	body := map[string]any{"data": data}
	host, port, _ := net.SplitHostPort(endpoint)
	var portNumber int
	for _, c := range port {
		portNumber = portNumber*10 + int(c-'0')
	}
	acceptanceMutateDocument(t, body, func(document map[string]any) {
		for _, raw := range document["proxies"].([]any) {
			proxy := raw.(map[string]any)
			name := proxy["name"]
			clear(proxy)
			proxy["name"], proxy["type"], proxy["server"], proxy["port"] = name, "http", host, portNumber
		}
		for _, raw := range document["proxy-groups"].([]any) {
			group := raw.(map[string]any)
			if group["type"] != "select" {
				group["url"], group["interval"], group["lazy"] = health, 1, false
			}
		}
		ai := document["rule-providers"].(map[string]any)["ai"].(map[string]any)
		reference := ai["proxy"]
		document["rule-providers"] = map[string]any{
			"ai":           map[string]any{"type": "inline", "behavior": "domain", "payload": []any{"geosite-cn.example"}, "proxy": reference},
			"synthetic-cn": map[string]any{"type": "inline", "behavior": "ipcidr", "payload": []any{"127.0.0.0/8"}},
		}
		role := data["routing"].(map[string]any)["ui_groups"].([]any)[0].(map[string]any)
		document["rules"] = []any{"RULE-SET,synthetic-cn," + role["group"].(string), "MATCH,DIRECT"}
	})
	return body
}

func TestAcceptanceVerticalRuleTypesAndProviderReferences(t *testing.T) {
	for _, rule := range []string{"RULE-SET,geosite-cn,DIRECT", "DOMAIN,geoip,DIRECT", "DOMAIN-SUFFIX,geosite.example,DIRECT", "AND,((DOMAIN,geoip),(RULE-SET,geosite-cn)),DIRECT", "DOMAIN-REGEX,^(GEOIP,CN)$,DIRECT"} {
		if !acceptanceRulesSafe(rule) {
			t.Fatalf("ordinary rule rejected %s", rule)
		}
	}
	for _, rule := range []string{"GEOIP,CN,DIRECT", "GEOSITE,cn,DIRECT", "IP-ASN,123,DIRECT", "AND,((DOMAIN,geoip),(NOT,((GEOIP,CN)))),DIRECT", "SUB-RULE,(GEOSITE,cn),branch"} {
		if acceptanceRulesSafe(rule) {
			t.Fatalf("implicit geodata allowed %s", rule)
		}
	}
	body := acceptanceAuthoritativeFixture(t, "127.0.0.1:1", "http://127.0.0.1:1/check")
	acceptanceMutateDocument(t, body, func(document map[string]any) {
		provider := document["rule-providers"].(map[string]any)["ai"].(map[string]any)
		provider["type"], provider["url"] = "http", "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/cn.mrs"
		delete(provider, "payload")
	})
	encoded, _ := json.Marshal(body)
	valid, code := clientbundle.Parse(encoded, "2", time.Now())
	if code != "" {
		t.Fatal(code)
	}
	before := valid.Bundle.Connection.Document
	overlay, safe := acceptanceOverlay(valid.Bundle, t.TempDir())
	if !safe {
		t.Fatal("authoritative group/provider shape rejected")
	}
	prepared, code := clientbundle.Prepare(encoded, "2", overlay, time.Now())
	if code != "" {
		t.Fatal(code)
	}
	if valid.Bundle.Connection.Document != before {
		t.Fatal("source mutated")
	}
	var config map[string]any
	_ = yaml.Unmarshal(prepared.Document, &config)
	originalProxy := config["rule-providers"].(map[string]any)["ai"].(map[string]any)["proxy"]
	if originalProxy == nil || originalProxy == "DIRECT" {
		t.Fatal("provider proxy not preserved")
	}
	for _, bad := range []string{"https://user:secret@cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/cn.mrs", "https://cdn.jsdelivr.net/gh/untrusted/private@main/a", "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/a?token=secret"} {
		if acceptancePublicRule(bad) {
			t.Fatal("credential or arbitrary mirror accepted")
		}
	}
	if _, ok := acceptanceDecode([]byte(`{"schema_version":1,"action":"probe","url":"https://example.test"}`)); ok {
		t.Fatal("meaningless probe accepted")
	}
	session := &acceptanceSession{}
	init := session.track(func() error { panic("PUBLIC_SYNTHETIC_MARKER") })
	if err := init.Initial(); err == nil || strings.Contains(err.Error(), "PUBLIC_SYNTHETIC_MARKER") || !session.drain(time.Second) {
		t.Fatal("initializer panic not drained/redacted")
	}
}

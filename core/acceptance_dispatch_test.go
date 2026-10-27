//go:build zolnit_acceptance

package core

import (
	"bytes"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/tunnel"
)

type dispatchAuditWriter struct {
	bytes.Buffer
	onReport func(acceptanceReport)
}

func (w *dispatchAuditWriter) Write(data []byte) (int, error) {
	for _, line := range bytes.Split(data, []byte{10}) {
		var report acceptanceReport
		if json.Unmarshal(line, &report) == nil && w.onReport != nil {
			w.onReport(report)
		}
	}
	return w.Buffer.Write(data)
}

func dispatchProtocolFixture(t *testing.T, server *protocolServer, fingerprint string, renewed, bypass, missing bool) map[string]any {
	t.Helper()
	body := protocolFixture(t, "vless", server, fingerprint, false)
	data := body["data"].(map[string]any)
	roles := data["routing"].(map[string]any)["ui_groups"].([]any)
	returnGroup := roles[0].(map[string]any)["group"].(string)
	if renewed {
		data["bundle_id"] = "dispatch-renewed"
	}
	for _, id := range []string{"return_dispatch", "return_media_dispatch"} {
		roles = append(roles, map[string]any{"id": id, "group": "fixture." + id,
			"options": []any{map[string]any{"id": "local", "target": "fixture.local"}, map[string]any{"id": "return", "target": returnGroup}}})
	}
	if missing {
		roles = roles[:1]
	}
	data["routing"].(map[string]any)["ui_groups"] = roles
	acceptanceMutateDocument(t, body, func(document map[string]any) {
		groups := document["proxy-groups"].([]any)
		groups = append(groups, map[string]any{"name": "fixture.local", "type": "select", "proxies": []any{"DIRECT"}})
		for _, name := range []string{"fixture.return_dispatch", "fixture.return_media_dispatch"} {
			groups = append(groups, map[string]any{"name": name, "type": "select", "proxies": []any{"fixture.local", returnGroup}})
		}
		document["proxy-groups"] = groups
		target := "fixture.return_dispatch"
		if bypass {
			target = returnGroup
		}
		document["rules"] = []any{"RULE-SET,synthetic-cn," + target, "MATCH,DIRECT"}
		if renewed {
			document["rule-providers"].(map[string]any)["synthetic-cn"].(map[string]any)["payload"] = []any{"127.0.0.0/8", "192.0.2.0/24"}
		}
	})
	return body
}

func TestAcceptanceReturnDispatchIsolated(t *testing.T) {
	scenario := os.Getenv("ZOLNIT_ACCEPTANCE_DISPATCH_CHILD")
	if scenario == "" {
		for _, name := range []string{"normal", "disabled", "bypass_parent", "metadata_loss"} {
			t.Run(name, func(t *testing.T) {
				command := exec.Command(os.Args[0], "-test.run=^TestAcceptanceReturnDispatchIsolated$", "-test.timeout=40s")
				command.Env = append(os.Environ(), "ZOLNIT_ACCEPTANCE_DISPATCH_CHILD="+name)
				if output, err := command.CombinedOutput(); err != nil {
					t.Fatalf("isolated dispatch %s: %v\n%s", name, err, output)
				}
			})
		}
		return
	}
	cert, key, fingerprint, err := ca.NewRandomTLSKeyPair(ca.KeyPairTypeP256)
	if err != nil {
		t.Fatal("synthetic certificate")
	}
	var hits atomic.Int32
	destination := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.WriteHeader(204)
	}))
	defer destination.Close()
	forwarder := &protocolTunnel{allowedAddr: destination.Listener.Addr().String()}
	server := startVLESSInbound(t, forwarder, cert, key)
	defer server.listener.Close()
	initial := dispatchProtocolFixture(t, server, fingerprint, false, scenario == "bypass_parent", false)
	renewed := dispatchProtocolFixture(t, server, fingerprint, true, false, scenario == "metadata_loss")
	set := func(enabled bool, role string) string {
		value := acceptanceAction("set_return_routing")
		value["enabled"] = enabled
		if role != "" {
			value["role"] = role
		}
		return acceptanceLine(value)
	}
	probe := func(role string, local bool) string {
		value := acceptanceAction("probe")
		value["url"], value["cn_provider"] = destination.URL, "synthetic-cn"
		if local {
			value["action"] = "probe_local_return"
		} else {
			value["role"] = role
		}
		return acceptanceLine(value)
	}
	parts := []string{acceptanceInstall("install", initial)}
	if scenario == "disabled" {
		parts = append(parts, acceptanceReturn("select_return", "direct"), probe("direct", false))
	} else {
		if scenario == "normal" {
			parts = append(parts, probe("", true))
		}
		for _, role := range []string{"direct", "hk_lite", "hk_optimized"} {
			parts = append(parts, set(true, role))
			if scenario != "metadata_loss" {
				parts = append(parts, probe(role, false))
			}
		}
		parts = append(parts, acceptanceInstall("renew", renewed))
		parts = append(parts, acceptanceReturn("assert_stale_return", "hk_lite"), probe("hk_optimized", false))
		parts = append(parts, set(false, ""), probe("", true))
	}
	parts = append(parts, acceptanceLine(acceptanceAction("finish")))
	blocked := false
	output := &dispatchAuditWriter{onReport: func(report acceptanceReport) {
		if scenario == "metadata_loss" && report.Action == "renew" && report.Code == "install_failed" {
			selectMu.Lock()
			defer selectMu.Unlock()
			state := activeRoutingLease
			if state == nil || state.returnRoute == nil || !state.returnRoute.blocked {
				t.Fatal("replacement did not block revoked dispatch")
			}
			for _, d := range state.returnRoute.dispatches {
				if d.selector.Now() != d.spec.ReturnTarget {
					t.Fatal("replacement leaked local")
				}
			}
			selector, ok := returnRouteSelector(&state.returnRoute.spec, tunnel.AllProxies())
			blocked = ok && selector.Now() == "REJECT"
		}
	}}
	input := &acceptanceStages{parts: parts, before: func(index int) {
		if index > 0 && currentConfig != nil {
			if ca.AddCertificate(string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: destination.Certificate().Raw}))) != nil {
				t.Fatal("synthetic trust")
			}
		}
	}}
	ok := RunClientBundleAcceptance(input, output, strings.Repeat("a", 40), 10*time.Second)
	if ok != (scenario == "normal") {
		t.Fatalf("dispatch result: %s", output.String())
	}
	var last acceptanceReport
	for _, line := range bytes.Split(bytes.TrimSpace(output.Bytes()), []byte{10}) {
		_ = json.Unmarshal(line, &last)
	}
	expected := map[string]string{"normal": "ok", "disabled": "return_dispatch_mismatch", "bypass_parent": "return_route_mismatch", "metadata_loss": "install_failed"}[scenario]
	if last.Code != expected || scenario == "metadata_loss" && !blocked {
		t.Fatalf("dispatch proof failed: %s", output.String())
	}
	if scenario == "normal" && (hits.Load() != 6 || forwarder.forwards.Load() != 4) {
		t.Fatalf("network counts %d/%d", hits.Load(), forwarder.forwards.Load())
	}
	if scenario == "bypass_parent" && hits.Load() != 1 || scenario == "disabled" && hits.Load() != 0 {
		t.Fatal("negative did not exercise intended path")
	}
	if isInit.Load() || currentConfig != nil {
		t.Fatal("acceptance Core not cleaned")
	}
}

//go:build zolnit_acceptance

package core

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener/inbound"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

const protocolTestUUID = "00000000-0000-4000-8000-000000000001"
const protocolTestPassword = "acceptance-protocol-synthetic-password"

type protocolTunnel struct {
	allowedAddr string
	forwards    atomic.Int32
}

func (pt *protocolTunnel) HandleTCPConn(conn net.Conn, metadata *C.Metadata) {
	defer conn.Close()
	if !metadata.DstIP.Is4() || !metadata.DstIP.IsLoopback() {
		return
	}
	target := net.JoinHostPort(metadata.DstIP.String(), fmt.Sprintf("%d", metadata.DstPort))
	if target != pt.allowedAddr {
		return
	}
	upstream, err := net.DialTimeout("tcp", target, 3*time.Second)
	if err != nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		defer upstream.Close()
		io.Copy(upstream, conn)
	}()
	go func() {
		defer wg.Done()
		defer conn.Close()
		io.Copy(conn, upstream)
	}()
	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-ctx.Done():
		conn.Close()
		upstream.Close()
		<-done
	}
	pt.forwards.Add(1)
}

func (pt *protocolTunnel) HandleUDPPacket(packet C.UDPPacket, metadata *C.Metadata) {}

func (pt *protocolTunnel) NatTable() C.NatTable { return nil }

type protocolServer struct {
	listener C.InboundListener
	addr     string
	port     int
}

func startVLESSInbound(t *testing.T, tun C.Tunnel, cert, key string) *protocolServer {
	t.Helper()
	opts := &inbound.VlessOption{
		BaseOption: inbound.BaseOption{
			NameStr: "protocol_test_vless",
			Listen:  "127.0.0.1",
			Port:    "0",
		},
		Users: []inbound.VlessUser{
			{Username: "acceptance", UUID: protocolTestUUID},
		},
		Certificate: cert,
		PrivateKey:  key,
	}
	in, err := inbound.NewVless(opts)
	if err != nil {
		t.Fatalf("VLESS inbound: %v", err)
	}
	if err := in.Listen(tun); err != nil {
		t.Fatalf("VLESS listen: %v", err)
	}
	addrPort, err := netip.ParseAddrPort(in.Address())
	if err != nil {
		in.Close()
		t.Fatalf("VLESS address: %v", err)
	}
	return &protocolServer{listener: in, addr: addrPort.Addr().String(), port: int(addrPort.Port())}
}

func startHysteria2Inbound(t *testing.T, tun C.Tunnel, cert, key string) *protocolServer {
	t.Helper()
	opts := &inbound.Hysteria2Option{
		BaseOption: inbound.BaseOption{
			NameStr: "protocol_test_hy2",
			Listen:  "127.0.0.1",
			Port:    "0",
		},
		Users:       map[string]string{"acceptance": protocolTestPassword},
		Certificate: cert,
		PrivateKey:  key,
	}
	in, err := inbound.NewHysteria2(opts)
	if err != nil {
		t.Fatalf("HY2 inbound: %v", err)
	}
	if err := in.Listen(tun); err != nil {
		t.Fatalf("HY2 listen: %v", err)
	}
	addrPort, err := netip.ParseAddrPort(in.Address())
	if err != nil {
		in.Close()
		t.Fatalf("HY2 address: %v", err)
	}
	return &protocolServer{listener: in, addr: addrPort.Addr().String(), port: int(addrPort.Port())}
}

func protocolFixture(t *testing.T, proxyType string, server *protocolServer, fingerprint string, downgrade bool) map[string]any {
	t.Helper()
	var body map[string]any
	if json.Unmarshal(returnInstallBody(t, downgrade), &body) != nil {
		t.Fatal("fixture decode")
	}
	data := body["data"].(map[string]any)
	data["account_id"] = "2"
	data["issued_at"] = time.Now().Unix()
	data["expires_at"] = time.Now().Unix() + 240

	connection := data["connection"].(map[string]any)
	var document map[string]any
	if yaml.Unmarshal([]byte(connection["document"].(string)), &document) != nil {
		t.Fatal("document decode")
	}

	outbounds := data["outbounds"].([]any)
	outbounds = outbounds[:1]
	proxyName := outbounds[0].(map[string]any)["proxy_name"].(string)
	data["outbounds"] = outbounds

	var proxy map[string]any
	switch proxyType {
	case "vless":
		proxy = map[string]any{
			"type": "vless", "name": proxyName,
			"server": server.addr, "port": server.port,
			"uuid": protocolTestUUID, "tls": true,
			"fingerprint": fingerprint,
		}
	case "hysteria2":
		proxy = map[string]any{
			"type": "hysteria2", "name": proxyName,
			"server": server.addr, "port": server.port,
			"password":    protocolTestPassword,
			"fingerprint": fingerprint,
		}
	}
	document["proxies"] = []any{proxy}

	role := data["routing"].(map[string]any)["ui_groups"].([]any)[0].(map[string]any)
	returnGroup := role["group"].(string)
	for _, raw := range document["proxy-groups"].([]any) {
		group := raw.(map[string]any)
		if group["name"] != returnGroup && !(downgrade && group["proxies"].([]any)[0] == "REJECT") {
			group["proxies"] = []any{proxyName}
		}
	}

	document["rule-providers"] = map[string]any{
		"synthetic-cn": map[string]any{
			"type": "inline", "behavior": "ipcidr",
			"payload": []any{"127.0.0.0/8"},
		},
	}
	document["rules"] = []any{
		"RULE-SET,synthetic-cn," + returnGroup,
		"MATCH,DIRECT",
	}

	document["mixed-port"] = 7890
	document["external-controller"] = "127.0.0.1:9090"
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
	connection["document"] = string(encoded)
	connection["sha256"] = hex.EncodeToString(hash[:])
	return body
}

func protocolRedactedFatal(t *testing.T, msg string, secrets []string, detail string) {
	t.Helper()
	safe := detail
	for i, s := range secrets {
		safe = strings.ReplaceAll(safe, s, fmt.Sprintf("[REDACTED-%d]", i))
	}
	t.Fatalf("%s: %s", msg, safe)
}

func TestAcceptanceProtocolIsolated(t *testing.T) {
	scenario := os.Getenv("ZOLNIT_ACCEPTANCE_PROTOCOL_CHILD")
	if scenario == "" {
		for _, name := range []string{"vless_tcp", "hysteria2_quic", "vless_bad_uuid", "hy2_bad_password"} {
			t.Run(name, func(t *testing.T) {
				command := exec.Command(os.Args[0], "-test.run=^TestAcceptanceProtocolIsolated$", "-test.timeout=30s")
				command.Env = append(os.Environ(), "ZOLNIT_ACCEPTANCE_PROTOCOL_CHILD="+name)
				output, err := command.CombinedOutput()
				if err != nil {
					t.Fatalf("isolated %s: %v\n%s", name, err, output)
				}
			})
		}
		return
	}

	cert, key, fingerprint, err := ca.NewRandomTLSKeyPair(ca.KeyPairTypeP256)
	if err != nil {
		t.Fatal(err)
	}
	secrets := []string{protocolTestUUID, protocolTestPassword, cert, key, fingerprint}

	var destinationRequests atomic.Int32
	destination := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		destinationRequests.Add(1)
		w.WriteHeader(204)
	}))
	defer destination.Close()

	destAddr := destination.Listener.Addr().String()
	tun := &protocolTunnel{allowedAddr: destAddr}

	if scenario == "vless_bad_uuid" || scenario == "hy2_bad_password" {
		var server *protocolServer
		switch scenario {
		case "vless_bad_uuid":
			server = startVLESSInbound(t, tun, cert, key)
		case "hy2_bad_password":
			server = startHysteria2Inbound(t, tun, cert, key)
		}
		defer server.listener.Close()

		var badProxy map[string]any
		switch scenario {
		case "vless_bad_uuid":
			badProxy = map[string]any{
				"type": "vless", "name": "zn.node.bad",
				"server": server.addr, "port": server.port,
				"uuid": "ffffffff-ffff-4fff-bfff-ffffffffffff", "tls": true,
				"fingerprint": fingerprint,
			}
		case "hy2_bad_password":
			badProxy = map[string]any{
				"type": "hysteria2", "name": "zn.node.bad",
				"server": server.addr, "port": server.port,
				"password":    "wrong-credential-value",
				"fingerprint": fingerprint,
			}
		}

		var body map[string]any
		if json.Unmarshal(returnInstallBody(t, false), &body) != nil {
			t.Fatal("fixture decode")
		}
		data := body["data"].(map[string]any)
		data["account_id"] = "2"
		data["issued_at"] = time.Now().Unix()
		data["expires_at"] = time.Now().Unix() + 240
		connection := data["connection"].(map[string]any)
		var document map[string]any
		if yaml.Unmarshal([]byte(connection["document"].(string)), &document) != nil {
			t.Fatal("document decode")
		}
		outbounds := data["outbounds"].([]any)
		outbounds = outbounds[:1]
		proxyName := outbounds[0].(map[string]any)["proxy_name"].(string)
		badProxy["name"] = proxyName
		data["outbounds"] = outbounds
		document["proxies"] = []any{badProxy}
		role := data["routing"].(map[string]any)["ui_groups"].([]any)[0].(map[string]any)
		returnGroup := role["group"].(string)
		for _, raw := range document["proxy-groups"].([]any) {
			group := raw.(map[string]any)
			if group["name"] != returnGroup {
				group["proxies"] = []any{proxyName}
			}
		}
		document["rule-providers"] = map[string]any{"synthetic-cn": map[string]any{"type": "inline", "behavior": "ipcidr", "payload": []any{"127.0.0.0/8"}}}
		document["rules"] = []any{"RULE-SET,synthetic-cn," + returnGroup, "MATCH,DIRECT"}
		document["mixed-port"] = 7890
		document["external-controller"] = "127.0.0.1:9090"
		document["dns"] = map[string]any{"enable": true, "listen": "127.0.0.1:1053"}
		document["tun"] = map[string]any{"enable": true, "auto-route": true}
		document["profile"] = map[string]any{"store-selected": true, "store-fake-ip": true}
		document["ntp"] = map[string]any{"enable": true, "write-to-system": true}
		document["listeners"] = []any{map[string]any{"name": "forbidden", "type": "http", "port": 10099}}
		document["tunnels"] = []any{map[string]any{"network": "tcp", "address": "127.0.0.1:10098", "target": "127.0.0.1:1"}}
		encoded, _ := yaml.Marshal(document)
		hash := sha256.Sum256(encoded)
		connection["document"] = string(encoded)
		connection["sha256"] = hex.EncodeToString(hash[:])

		parts := []string{acceptanceInstall("install", body)}
		parts = append(parts, acceptanceReturn("select_return", "hk_lite"))
		probe := acceptanceAction("probe")
		probe["url"] = destination.URL
		probe["role"] = "hk_lite"
		probe["cn_provider"] = "synthetic-cn"
		parts = append(parts, acceptanceLine(probe))
		parts = append(parts, acceptanceLine(acceptanceAction("inspect")))
		parts = append(parts, acceptanceLine(acceptanceAction("finish")))

		input := &acceptanceStages{parts: parts, before: func(index int) {
			if index > 0 && currentConfig != nil {
				if err := ca.AddCertificate(string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: destination.Certificate().Raw}))); err != nil {
					t.Fatal("test destination certificate could not be trusted")
				}
			}
		}}
		var output bytes.Buffer
		result := RunClientBundleAcceptance(input, &output, strings.Repeat("a", 40), 10*time.Second)
		if result {
			t.Fatal("bad credential scenario should fail")
		}
		var last acceptanceReport
		for _, line := range bytes.Split(bytes.TrimSpace(output.Bytes()), []byte{10}) {
			_ = json.Unmarshal(line, &last)
		}
		if last.Action != "probe" || last.Code != "probe_failed" {
			t.Fatal("bad credential must fail during the actual protocol probe")
		}
		if destinationRequests.Load() != 0 || tun.forwards.Load() != 0 {
			t.Fatal("bad credential reached destination")
		}
		for _, s := range secrets {
			if strings.Contains(output.String(), s) {
				protocolRedactedFatal(t, "unredacted secret in negative output", secrets, output.String())
			}
		}
		if isInit.Load() || currentConfig != nil {
			t.Fatal("Core not released after negative")
		}
		return
	}

	var server *protocolServer
	var proxyType string
	switch scenario {
	case "vless_tcp":
		server = startVLESSInbound(t, tun, cert, key)
		proxyType = "vless"
	case "hysteria2_quic":
		server = startHysteria2Inbound(t, tun, cert, key)
		proxyType = "hysteria2"
	default:
		t.Fatalf("unknown scenario: %s", scenario)
	}
	defer server.listener.Close()

	if scenario == "vless_tcp" {
		conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", server.port), time.Second)
		if err != nil {
			t.Fatalf("VLESS TCP not reachable: %v", err)
		}
		conn.Close()
	}

	initial := protocolFixture(t, proxyType, server, fingerprint, false)
	renewal := protocolFixture(t, proxyType, server, fingerprint, true)
	original, _ := json.Marshal(initial)

	parts := []string{acceptanceInstall("install", initial)}
	parts = append(parts, acceptanceReturn("select_return", "hk_optimized"))

	probe1 := acceptanceAction("probe")
	probe1["url"] = destination.URL
	probe1["role"] = "hk_optimized"
	probe1["cn_provider"] = "synthetic-cn"
	parts = append(parts, acceptanceLine(probe1))

	parts = append(parts, acceptanceInstall("renew", renewal))
	parts = append(parts, acceptanceReturn("assert_stale_return", "hk_lite"))
	parts = append(parts, acceptanceReturn("assert_unavailable_return", "hk_optimized"))
	parts = append(parts, acceptanceReturn("select_return", "hk_lite"))

	probe2 := acceptanceAction("probe")
	probe2["url"] = destination.URL
	probe2["role"] = "hk_lite"
	probe2["cn_provider"] = "synthetic-cn"
	parts = append(parts, acceptanceLine(probe2))

	parts = append(parts, acceptanceLine(acceptanceAction("inspect")))
	parts = append(parts, acceptanceLine(acceptanceAction("finish")))

	oldHook := executor.DefaultProviderLoadedHook
	executor.DefaultProviderLoadedHook = func(name string) {
		if oldHook != nil {
			oldHook(name)
		}
	}

	input := &acceptanceStages{parts: parts, before: func(index int) {
		if index == 0 || currentConfig == nil {
			return
		}
		cfg := currentConfig
		if cfg.General.MixedPort != 0 || cfg.General.Tun.Enable || cfg.DNS.Enable ||
			cfg.DNS.Listen != "" || cfg.Controller.ExternalController != "" ||
			len(cfg.Listeners) != 0 || len(cfg.Tunnels) != 0 ||
			cfg.NTP.Enable || cfg.NTP.WriteToSystem ||
			cfg.Profile.StoreSelected || cfg.Profile.StoreFakeIP {
			t.Fatal("unsafe applied overlay")
		}
		for _, service := range clientBundleSetup.RoutingLease.Services {
			selector, ok := adapterAs[pickableGroup](tunnel.AllProxies()[service.GroupName])
			if !ok || selector.Now() != service.ManualGroup {
				t.Fatal("automatic service probing enabled")
			}
		}
		if err := ca.AddCertificate(string(pem.EncodeToMemory(&pem.Block{
			Type: "CERTIFICATE", Bytes: destination.Certificate().Raw,
		}))); err != nil {
			t.Fatal(err)
		}
	}}

	var output bytes.Buffer
	result := RunClientBundleAcceptance(input, &output, strings.Repeat("a", 40), 10*time.Second)
	if !result {
		protocolRedactedFatal(t, "acceptance failed", secrets, output.String())
	}

	var reports []acceptanceReport
	for _, line := range bytes.Split(bytes.TrimSpace(output.Bytes()), []byte{10}) {
		var rpt acceptanceReport
		if json.Unmarshal(line, &rpt) != nil {
			protocolRedactedFatal(t, "invalid output line", secrets, string(line))
		}
		reports = append(reports, rpt)
	}

	expectedActions := []string{"install", "select_return", "probe", "renew", "assert_stale_return", "assert_unavailable_return", "select_return", "probe", "inspect", "finish"}
	if len(reports) != len(expectedActions) {
		t.Fatalf("expected %d reports, got %d", len(expectedActions), len(reports))
	}
	for index, action := range expectedActions {
		if reports[index].Action != action || !reports[index].OK {
			t.Fatal("missing or unsuccessful acceptance action")
		}
	}
	for i := 1; i < len(reports); i++ {
		if reports[i].Sequence < reports[i-1].Sequence {
			t.Fatalf("report sequence not monotonic at index %d: %d < %d", i, reports[i].Sequence, reports[i-1].Sequence)
		}
	}

	if reports[0].Action != "install" || reports[0].Sequence != 1 || !reports[0].OK {
		t.Fatal("first report must be successful install at sequence 1")
	}

	probeCount := 0
	for _, rpt := range reports {
		if rpt.Action == "probe" {
			probeCount++
			if rpt.Status != http.StatusNoContent {
				t.Fatalf("probe report status=%d expected 204", rpt.Status)
			}
		}
	}
	if probeCount != 2 {
		t.Fatalf("expected 2 probe reports, got %d", probeCount)
	}

	renewFound := false
	for _, rpt := range reports {
		if rpt.Action == "renew" {
			renewFound = true
			if rpt.Sequence <= 1 || !rpt.OK {
				t.Fatal("renew report must be ok with sequence > 1")
			}
		}
	}
	if !renewFound {
		t.Fatal("missing renew report")
	}

	if tun.forwards.Load() < 2 {
		t.Fatalf("tunnel forwards=%d, expected at least 2 (one per probe)", tun.forwards.Load())
	}
	if destinationRequests.Load() < 2 {
		t.Fatalf("destination requests=%d, expected at least 2", destinationRequests.Load())
	}

	last := reports[len(reports)-1]
	if last.Code != "ok" {
		protocolRedactedFatal(t, "final code not ok: "+last.Code, secrets, output.String())
	}

	for _, s := range secrets {
		if strings.Contains(output.String(), s) {
			protocolRedactedFatal(t, "unredacted secret in output", secrets, output.String())
		}
	}
	for _, marker := range []string{
		"synthetic-cn", "zn.node.", "zn.group.",
	} {
		if strings.Contains(output.String(), marker) {
			t.Fatalf("unredacted marker: %s", marker)
		}
	}

	after, _ := json.Marshal(initial)
	if !bytes.Equal(original, after) {
		t.Fatal("source object mutated")
	}

	if isInit.Load() || currentConfig != nil {
		t.Fatal("Core not released")
	}
}

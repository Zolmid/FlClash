//go:build !windows && !ios && !android

package observation_test

import (
	"bufio"
	"bytes"
	"core/observation"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

type coreProcess struct {
	cmd      *exec.Cmd
	conn     net.Conn
	listener *net.UnixListener
	next     int
	done     chan error
}

func startCore(t *testing.T, binaryPath, home string) *coreProcess {
	t.Helper()
	socketDir, err := os.MkdirTemp("", "zo-")
	if err != nil {
		t.Fatal("isolated IPC directory failed")
	}
	t.Cleanup(func() { _ = os.RemoveAll(socketDir) })
	socket := filepath.Join(socketDir, "ipc.sock")
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
	if err != nil {
		t.Fatal("isolated IPC listener failed")
	}
	p := &coreProcess{cmd: exec.Command(binaryPath, socket), listener: listener, done: make(chan error, 1)}
	p.cmd.Stdout = io.Discard
	p.cmd.Stderr = io.Discard
	if p.cmd.Start() != nil {
		t.Fatal("isolated Core start failed")
	}
	go func() { p.done <- p.cmd.Wait() }()
	_ = listener.SetDeadline(time.Now().Add(5 * time.Second))
	p.conn, err = listener.Accept()
	if err != nil {
		_ = p.cmd.Process.Kill()
		t.Fatal("isolated Core IPC connection failed")
	}
	t.Cleanup(func() {
		_ = p.conn.Close()
		_ = p.listener.Close()
		select {
		case <-p.done:
		case <-time.After(4 * time.Second):
			_ = p.cmd.Process.Kill()
			<-p.done
		}
	})
	p.call(t, "initClash", map[string]any{"home-dir": home, "version": 0, "routing-observation": true})
	return p
}
func (p *coreProcess) call(t *testing.T, method string, args any) json.RawMessage {
	t.Helper()
	p.next++
	id := strconv.Itoa(p.next)
	payload, _ := json.Marshal(map[string]any{"id": id, "method": method, "arguments": args})
	_ = p.conn.SetDeadline(time.Now().Add(5 * time.Second))
	header := make([]byte, 4)
	binary.LittleEndian.PutUint32(header, uint32(len(payload)))
	if _, e := io.Copy(p.conn, bytes.NewReader(append(header, payload...))); e != nil {
		t.Fatal("Core control write failed")
	}
	for {
		if _, e := io.ReadFull(p.conn, header); e != nil {
			t.Fatal("Core control read failed")
		}
		n := binary.LittleEndian.Uint32(header)
		if n > 1<<20 {
			t.Fatal("oversized Core response")
		}
		data := make([]byte, int(n))
		if _, e := io.ReadFull(p.conn, data); e != nil {
			t.Fatal("Core response failed")
		}
		var r struct {
			ID     string          `json:"id"`
			Result json.RawMessage `json:"result"`
			Error  any             `json:"error"`
		}
		if json.Unmarshal(data, &r) != nil {
			t.Fatal("invalid Core response")
		}
		if r.ID != id {
			continue
		}
		if r.Error != nil {
			t.Fatalf("Core RPC %s failed", method)
		}
		return r.Result
	}
}
func (p *coreProcess) stop(t *testing.T) {
	t.Helper()
	p.call(t, "shutdown", nil)
	_ = p.conn.Close()
	select {
	case e := <-p.done:
		if e != nil {
			t.Fatal("Core shutdown failed")
		}
		p.done <- nil
	case <-time.After(4 * time.Second):
		t.Fatal("Core did not exit")
	}
}
func readUntil(t *testing.T, file string, predicate func(observation.Snapshot) bool) observation.Snapshot {
	t.Helper()
	end := time.Now().Add(4 * time.Second)
	for time.Now().Before(end) {
		f, e := os.Open(file)
		if e == nil {
			s, err := observation.Read(f)
			_ = f.Close()
			if err == nil && predicate(s) {
				return s
			}
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("passive snapshot did not reach expected state")
	return observation.Snapshot{}
}
func setup(t *testing.T, p *coreProcess, expiry int64) {
	t.Helper()
	p.call(t, "setupConfig", map[string]any{"selected-map": map[string]string{"zn.service.ai": "zn.service.ai.auto"}, "test-url": "", "routing-lease": map[string]any{
		"accountId": "synthetic-account", "accountGeneration": 3, "bundleId": "synthetic-bundle", "configurationDigest": "synthetic-digest", "expiresAt": expiry,
		"services": []any{map[string]any{"groupName": "zn.service.ai", "automaticGroup": "zn.service.ai.auto", "manualGroup": "zn.service.ai.manual", "allowedProxies": []string{"zn.node.socks5.1"}}},
	}})
}
func guard(t *testing.T, p *coreProcess) map[string]any {
	t.Helper()
	var g map[string]any
	if json.Unmarshal(p.call(t, "getRoutingLease", nil), &g) != nil || g == nil {
		t.Fatal("guard unavailable")
	}
	return g
}
func TestObserverWithRealCoreProcesses(t *testing.T) {
	coreBinary, readerBinary := os.Getenv("ZOLNIT_TEST_CORE_BINARY"), os.Getenv("ZOLNIT_TEST_OBSERVER_BINARY")
	if coreBinary == "" || readerBinary == "" {
		t.Skip("requires explicitly built isolated Core and read-only observer binaries")
	}
	home, e := filepath.EvalSymlinks(t.TempDir())
	if e != nil {
		t.Fatal(e)
	}
	profile := `mixed-port: 0
port: 0
socks-port: 0
external-controller: ''
mode: rule
dns: {enable: false}
tun: {enable: false}
ntp: {enable: false}
geo-auto-update: false
proxies:
  - {name: zn.node.socks5.1, type: socks5, server: 192.0.2.1, port: 9}
  - {name: zn.node.socks5.2, type: socks5, server: 198.51.100.1, port: 9}
proxy-groups:
  - {name: zn.service.ai.auto, type: select, proxies: [REJECT, zn.node.socks5.1]}
  - {name: zn.service.ai.manual, type: select, proxies: [zn.node.socks5.1, zn.node.socks5.2, DIRECT]}
  - {name: zn.service.ai, type: select, proxies: [zn.service.ai.auto, zn.service.ai.manual, DIRECT]}
rules: [MATCH,REJECT]
`
	profile = strings.Replace(profile, "rules: [MATCH,REJECT]", "rules: ['MATCH,REJECT']", 1)
	if os.WriteFile(filepath.Join(home, "config.yaml"), []byte(profile), 0600) != nil {
		t.Fatal("synthetic config write failed")
	}
	p := startCore(t, coreBinary, home)
	setup(t, p, time.Now().Add(1200*time.Millisecond).UnixMilli())
	p.call(t, "changeProxy", map[string]any{"group-name": "zn.service.ai.manual", "proxy-name": "zn.node.socks5.2"})
	g := guard(t, p)
	p.call(t, "changeProxy", map[string]any{"group-name": "zn.service.ai.auto", "proxy-name": "zn.node.socks5.1", "routing-lease": g})
	file := filepath.Join(home, "diagnostics", "lease-observation-desktop.json")
	before := readUntil(t, file, func(s observation.Snapshot) bool {
		return s.State.LeasePresent && len(s.State.Groups) == 1 && s.State.Groups[0].Automatic == "proxy"
	})
	output, err := exec.Command(readerBinary, "--file", file, "--expect-role", "desktop", "--watch-seconds", "2", "--interval-ms", "100").Output()
	if err != nil {
		t.Fatal("independent passive observer failed")
	}
	scanner := bufio.NewScanner(bytes.NewReader(output))
	found := false
	for scanner.Scan() {
		var r struct {
			Snapshot observation.Snapshot `json:"snapshot"`
		}
		if json.Unmarshal(scanner.Bytes(), &r) != nil {
			t.Fatal("invalid independent observer output")
		}
		for _, event := range r.Snapshot.Events {
			if event.Kind == "query_expired" {
				t.Fatal("a query triggered expiry during passive phase")
			}
			if event.Kind == "watchdog" && event.State.Revoked && event.State.DeadlineElapsed && len(event.State.Groups) == 1 && event.State.Groups[0].Automatic == "reject" {
				found = true
			}
		}
	}
	if !found {
		t.Fatal("no actual Core watchdog evidence from independent observer")
	}
	expired := readUntil(t, file, func(s observation.Snapshot) bool { return s.State.Revoked && s.State.DeadlineResult() == "rejected" })
	if expired.State.Groups[0].ManualTag != before.State.Groups[0].ManualTag {
		t.Fatal("TTL changed manual selection")
	}
	expiry := time.Now().Add(10 * time.Second).UnixMilli()
	setup(t, p, expiry)
	old := guard(t, p)
	oldPID, oldTag := p.cmd.Process.Pid, expired.State.InstanceTag
	p.stop(t)
	next := startCore(t, coreBinary, home)
	setup(t, next, expiry)
	newState := readUntil(t, file, func(s observation.Snapshot) bool {
		return s.ProducerPID != oldPID && s.State.LeasePresent && s.State.InstanceTag != oldTag
	})
	var rejected struct {
		Message string `json:"message"`
	}
	_ = json.Unmarshal(next.call(t, "changeProxy", map[string]any{"group-name": "zn.service.ai.auto", "proxy-name": "zn.node.socks5.1", "routing-lease": old}), &rejected)
	if rejected.Message == "" {
		t.Fatal("old process guard was accepted by replacement Core")
	}
	newState = readUntil(t, file, func(s observation.Snapshot) bool {
		for _, e := range s.Events {
			if e.Kind == "write_rejected" {
				return true
			}
		}
		return false
	})
	if newState.State.Groups[0].Automatic != "reject" {
		t.Fatal("stale write altered new Selector")
	}
	fresh := guard(t, next)
	next.call(t, "changeProxy", map[string]any{"group-name": "zn.service.ai.auto", "proxy-name": "zn.node.socks5.1", "routing-lease": fresh})
	_ = readUntil(t, file, func(s observation.Snapshot) bool { return s.State.Groups[0].Automatic == "proxy" })
	next.stop(t)
	fmt.Println("isolated actual Core processes: passive watchdog, manual preservation, independent reader, restart and stale-write rejection passed; no App/Extension/Helper device evidence")
}

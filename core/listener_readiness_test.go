package core

import (
	"encoding/json"
	"net"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
)

func TestStartListenerReportsOccupiedMixedPort(t *testing.T) {
	occupied, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	previous := currentConfig
	currentConfig = &config.Config{General: &config.General{Inbound: config.Inbound{MixedPort: occupied.Addr().(*net.TCPAddr).Port}}}
	defer func() { handleStopListener(); currentConfig = previous }()
	replies := make(chan []byte, 1)
	dispatchMethodCall(&MethodCall{Method: startListenerMethod}, func(data []byte) { replies <- data })
	var frame []byte
	select {
	case frame = <-replies:
	case <-time.After(10 * time.Second):
		t.Fatal("start did not reply")
	}
	var response MethodResponse
	if err := json.Unmarshal(frame, &response); err != nil {
		t.Fatal(err)
	}
	if response.Error == nil || response.Error.Code != "proxy_listener_unavailable" {
		t.Fatalf("start result = %#v, want listener error", response)
	}
	if isRunning.Load() {
		t.Fatal("failed listener remained running")
	}
}

func TestTunFailureReachesStartAndHotUpdateRPC(t *testing.T) {
	previousConfig, previousCreate, previousRead := currentConfig, recreateDesktopTun, desktopTunConfig
	defer func() {
		handleStopListener()
		currentConfig = previousConfig
		recreateDesktopTun = previousCreate
		desktopTunConfig = previousRead
	}()
	recreateDesktopTun = func(_ LC.Tun, _ C.Tunnel) {}
	desktopTunConfig = func() LC.Tun { return LC.Tun{} }
	currentConfig = &config.Config{General: &config.General{Inbound: config.Inbound{Tun: LC.Tun{Enable: true}}}, Controller: &config.Controller{}}
	call := func(method CoreMethod, args string) MethodResponse {
		t.Helper()
		replies := make(chan []byte, 1)
		dispatchMethodCall(&MethodCall{Method: method, Arguments: json.RawMessage(args)}, func(data []byte) { replies <- data })
		select {
		case frame := <-replies:
			var result MethodResponse
			if err := json.Unmarshal(frame, &result); err != nil {
				t.Fatal(err)
			}
			return result
		case <-time.After(10 * time.Second):
			t.Fatal("RPC timed out")
			return MethodResponse{}
		}
	}
	if got := call(startListenerMethod, "null"); got.Error == nil || got.Error.Code != "tun_unavailable" {
		t.Fatalf("start = %#v", got)
	}
	isRunning.Store(true)
	if got := call(updateConfigMethod, `{"tun":{"enable":true}}`); got.Error == nil || got.Error.Code != "tun_unavailable" {
		t.Fatalf("update = %#v", got)
	}
}

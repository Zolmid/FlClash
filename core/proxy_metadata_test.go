package core

import (
	"encoding/json"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
)

type metadataAdapter struct{ *outbound.Base }

func (node *metadataAdapter) ProxyInfo() C.ProxyInfo {
	info := node.Base.ProxyInfo()
	info.SMUX = true
	info.DialerProxy = "upstream"
	return info
}

func (*metadataAdapter) SupportUOT() bool { return true }

func (*metadataAdapter) MarshalJSON() ([]byte, error) {
	panic("node metadata must not encode the adapter or its history")
}

func TestSlimProxyViewIncludesRuntimeCapabilitiesWithoutAdapterEncoding(t *testing.T) {
	proxy := adapter.NewProxy(&metadataAdapter{outbound.NewBase(outbound.BaseOption{
		Name: "node", Type: C.Vmess, UDP: true, XUDP: true, TFO: true, MPTCP: true,
		ProviderName: "subscription", Interface: "en0", RoutingMark: 42,
	})})
	data, err := json.Marshal(proxyView(proxy))
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]any
	if err := json.Unmarshal(data, &payload); err != nil {
		t.Fatal(err)
	}
	for key, want := range map[string]any{
		"name": "node", "type": "Vmess", "udp": true, "uot": true,
		"xudp": true, "tfo": true, "mptcp": true, "smux": true,
		"provider-name": "subscription", "interface": "en0",
		"routing-mark": float64(42), "dialer-proxy": "upstream",
	} {
		if got := payload[key]; got != want {
			t.Errorf("%s = %v, want %v", key, got, want)
		}
	}
	for _, key := range []string{"history", "extra", "alive"} {
		if _, exists := payload[key]; exists {
			t.Errorf("unconsumed runtime field %q was encoded", key)
		}
	}
}

package core

import (
	"io"
	"net"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func TestProxyOnlyTrafficLeavesOutADirectProxyOfAnyName(t *testing.T) {
	direct := outbound.NewDirectWithOption(outbound.DirectOption{Name: "直连"})
	reject := outbound.NewRejectWithOption(outbound.RejectOption{Name: "HK"})
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"直连": adapter.NewProxy(direct),
		"HK": adapter.NewProxy(reject),
	}, nil)
	t.Cleanup(func() { tunnel.UpdateProxies(nil, nil) })

	for _, test := range []struct {
		outbound constant.ProxyAdapter
		proxied  int64
	}{
		{direct, 0},
		{reject, 5},
	} {
		statistic.DefaultManager.ResetStatistic()
		local, remote := net.Pipe()
		go func() { _, _ = io.Copy(io.Discard, remote) }()
		tracker := statistic.NewTCPTracker(
			outbound.NewConn(local, test.outbound),
			statistic.DefaultManager,
			&constant.Metadata{},
			nil,
			0,
			0,
			true,
		)

		if _, err := tracker.Write([]byte("hello")); err != nil {
			t.Fatalf("write through %s: %v", test.outbound.Name(), err)
		}
		_ = tracker.Close()
		_ = remote.Close()

		all, _ := statistic.DefaultManager.TotalTraffic(false)
		proxied, _ := statistic.DefaultManager.TotalTraffic(true)
		if all != 5 || proxied != test.proxied {
			t.Errorf("%s: total %d, proxied %d; want 5 and %d", test.outbound.Name(), all, proxied, test.proxied)
		}
	}
	statistic.DefaultManager.ResetStatistic()
}

func TestSelectionClosingMatchesTheGroupAndImmediatePick(t *testing.T) {
	for _, test := range []struct {
		chain constant.Chain
		want  bool
	}{
		{constant.Chain{"old", "group"}, true},
		{constant.Chain{"new", "group"}, false},
		{constant.Chain{"old", "other-group"}, false},
		{constant.Chain{"node", "inner-old", "group", "outer"}, true},
		{constant.Chain{"node", "new", "group", "outer"}, false},
		{constant.Chain{"group"}, true},
		{nil, false},
	} {
		if got := chainUsesOtherSelection(test.chain, "group", "new"); got != test.want {
			t.Errorf("chain %v should close=%v, got %v", test.chain, test.want, got)
		}
	}
}

func TestReselectingTheCurrentNodeClosesOnlyStaleConnections(t *testing.T) {
	previousManager := statistic.DefaultManager
	previousProxies, previousProviders := tunnel.Proxies(), tunnel.ProvidersSnapshot()
	statistic.DefaultManager = &statistic.Manager{}
	t.Cleanup(func() {
		statistic.DefaultManager = previousManager
		tunnel.UpdateProxies(previousProxies, previousProviders)
	})
	recordRoutes(t)
	group := selectorGroup(t, "selector", "node-a", "node-b")
	tunnel.UpdateProxies(map[string]constant.Proxy{"selector": group}, nil)
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "selector", ProxyName: "node-b"}); !result.Changed {
		t.Fatalf("initial selection failed: %+v", result)
	}
	tracked := func(name string) statistic.Tracker {
		local, remote := net.Pipe()
		t.Cleanup(func() { _ = local.Close(); _ = remote.Close() })
		conn := outbound.NewConn(local, outbound.NewDirectWithOption(outbound.DirectOption{Name: name}))
		conn.AppendToChains(group)
		return statistic.NewTCPTracker(conn, statistic.DefaultManager, &constant.Metadata{}, nil, 0, 0, true)
	}
	stale, current := tracked("node-a"), tracked("node-b")
	t.Cleanup(func() { _ = stale.Close(); _ = current.Close() })
	result := handleChangeProxy(&ChangeProxyParams{
		GroupName: "selector", ProxyName: "node-b", CloseConnections: true,
	})
	if result.Message != "" || result.Changed {
		t.Fatalf("reselection changed the current pick: %+v", result)
	}
	if statistic.DefaultManager.Get(stale.ID()) != nil || statistic.DefaultManager.Get(current.ID()) == nil {
		t.Fatal("reselection did not isolate the stale connection")
	}
}

package core

import (
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func handleGetTraffic(onlyStatisticsProxy bool) Traffic {
	up, down := statistic.DefaultManager.NowTraffic(onlyStatisticsProxy)
	return Traffic{Up: up, Down: down}
}

func handleGetTotalTraffic(onlyStatisticsProxy bool) Traffic {
	up, down := statistic.DefaultManager.TotalTraffic(onlyStatisticsProxy)
	return Traffic{Up: up, Down: down}
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func handleGetConnections() *statistic.Snapshot {
	return statistic.DefaultManager.Snapshot()
}

func handleGetConnectionCount() int {
	count := 0
	statistic.DefaultManager.Range(func(statistic.Tracker) bool {
		count++
		return true
	})
	return count
}

func handleCloseConnections() bool {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
	return true
}

func closeConnectionsForSelection(groupName, proxyName string) {
	statistic.DefaultManager.Range(func(connection statistic.Tracker) bool {
		if chainUsesOtherSelection(connection.Info().Chain, groupName, proxyName) {
			_ = connection.Close()
		}
		return true
	})
}

func chainUsesOtherSelection(chain constant.Chain, groupName, proxyName string) bool {
	for index, name := range chain {
		if name == groupName {
			return index == 0 || chain[index-1] != proxyName
		}
	}
	return false
}

func handleResetConnections() bool {
	resolver.ResetConnection()
	return true
}

// A connection that went out over a network the device has left hangs until
// TCP gives up on it, and so do the DNS clients' pooled connections.
func handleResetNetwork() {
	handleCloseConnections()
	resolver.ResetConnection()
}

func handleCloseConnection(connectionId string) bool {
	c := statistic.DefaultManager.Get(connectionId)
	if c == nil {
		return false
	}
	_ = c.Close()
	return true
}

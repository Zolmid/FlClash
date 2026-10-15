//go:build android

package core

import (
	"strings"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/log"
)

var (
	dnsUpdateMu  sync.Mutex
	dnsUpdateSeq atomic.Uint64
)

func handleUpdateDns(value string) {
	// An empty server list must stay nil: mihomo treats [""] as "udp://:".
	var addr []string
	if value != "" {
		addr = strings.Split(value, ",")
	}
	seq := dnsUpdateSeq.Add(1)
	safeGo("updateDns", func() {
		dnsUpdateMu.Lock()
		defer dnsUpdateMu.Unlock()
		if seq != dnsUpdateSeq.Load() {
			return
		}
		log.Infoln("[DNS] updateDns %s", value)
		dns.UpdateSystemDNS(addr)
		dns.FlushCacheWithDefaultResolver()
	})
}

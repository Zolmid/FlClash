package core

import (
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestTestDelaySkipsStaleQueuedProbe(t *testing.T) {
	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	tunnel.UpdateProxies(map[string]constant.Proxy{"queued": namedProxy("queued")}, nil)
	defer tunnel.UpdateProxies(nil, nil)
	for i := 0; i < delayTestConcurrency; i++ {
		delayTestSlots <- struct{}{}
	}
	defer func() {
		for i := 0; i < delayTestConcurrency; i++ {
			<-delayTestSlots
		}
	}()
	done := make(chan *Delay, 1)
	go func() {
		done <- handleTestDelay(&TestDelayParams{ProxyName: "queued", TestUrl: server.URL, Timeout: 1000})
	}()
	select {
	case <-done:
		t.Fatal("probe did not wait for a slot")
	case <-time.After(50 * time.Millisecond):
	}
	selectMu.Lock()
	previous := routingConfigurationGeneration
	routingConfigurationGeneration++
	selectMu.Unlock()
	defer func() {
		selectMu.Lock()
		routingConfigurationGeneration = previous
		selectMu.Unlock()
	}()
	<-delayTestSlots
	result := <-done
	delayTestSlots <- struct{}{}
	if result != nil || requests.Load() != 0 {
		t.Fatalf("stale queued probe: result=%v requests=%d", result, requests.Load())
	}
}

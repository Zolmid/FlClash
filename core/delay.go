package core

import (
	"context"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/constant"
)

const (
	delayTestConcurrency    = 50
	defaultTestURL          = "https://www.gstatic.com/generate_204"
	defaultDelayTestTimeout = 5 * time.Second
)

var (
	delayTestSlots     = make(slots, delayTestConcurrency)
	anyDelayTestStatus utils.IntRanges[uint16]

	testURL                 atomic.Pointer[string]
	missingDelayTestProxyAt atomic.Int64
)

func setTestURL(url string) {
	if url == "" {
		return
	}
	constant.DefaultTestURL = url
	testURL.Store(&url)
}

func currentTestURL() string {
	if url := testURL.Load(); url != nil && *url != "" {
		return *url
	}
	return defaultTestURL
}

const (
	delayTimedOut int32 = -1
	delayFailed   int32 = -2
)

func delayValue(delay uint16, timedOut bool) int32 {
	switch {
	case delay > 0:
		return int32(delay)
	case timedOut:
		return delayTimedOut
	default:
		return delayFailed
	}
}

// A name the tunnel does not know is what an apply that fell back to the
// default config looks like: every node of the profile fails its test. Say so
// once a second, not once per node, so the log names the real failure.
func reportMissingDelayTestProxy(name string) {
	now := time.Now().UnixNano()
	last := missingDelayTestProxyAt.Load()
	if last != 0 && now-last < int64(time.Second) {
		return
	}
	if !missingDelayTestProxyAt.CompareAndSwap(last, now) {
		return
	}
	logError("delay test: %q is not part of the applied config", name)
}

func lookupDelayTestProxy(name string) constant.Proxy {
	if proxy := lookupProxy(name); proxy != nil {
		return proxy
	}
	configMu.Lock()
	defer configMu.Unlock()
	if clientBundleRouting == nil || clientBundleRouting.policy.Expires <= routingLeaseNow().Unix() || !matchesClientBundleOwnerLocked(clientBundleRouting.owner) {
		return nil
	}
	mapping := clientBundleRouting.proxies[name]
	if mapping == nil {
		return nil
	}
	if dialer, _ := mapping["dialer-proxy"].(string); dialer != "" {
		return nil
	}
	proxy, err := adapter.ParseProxy(mapping)
	if err != nil {
		logError("delay test: cannot construct bundle proxy %q", name)
		return nil
	}
	return proxy
}

// A nil answer means no current observation was obtained for the proxy.
func handleTestDelay(params *TestDelayParams) *Delay {
	url := params.TestUrl
	if url == "" {
		url = currentTestURL()
	}
	result := &Delay{Name: params.ProxyName, Url: url, Value: delayFailed}

	selectMu.Lock()
	generation := routingConfigurationGeneration
	lease := activeRoutingLease
	guarded := lease != nil && !lease.revoked && routingLeaseNow().Before(lease.deadline)
	selectMu.Unlock()
	proxy := lookupDelayTestProxy(params.ProxyName)
	if proxy == nil {
		reportMissingDelayTestProxy(params.ProxyName)
		return nil
	}

	timeout := timeoutFromMillis(params.Timeout, defaultDelayTestTimeout)
	if !delayTestSlots.acquireWithin(context.Background(), timeout) {
		return nil
	}
	defer delayTestSlots.release()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	delay, err := proxy.URLTest(ctx, url, anyDelayTestStatus)
	selectMu.Lock()
	current := generation == routingConfigurationGeneration &&
		(!guarded || (activeRoutingLease == lease && !lease.revoked && routingLeaseNow().Before(lease.deadline)))
	selectMu.Unlock()
	if !current {
		return nil
	}
	if err != nil {
		delay = 0
	}
	result.Value = delayValue(delay, ctx.Err() != nil)
	return result
}

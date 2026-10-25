package core

import (
	"math"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

type routingProbeOrigin struct {
	active    bool
	until     time.Time
	forever   bool
	throttles uint
}
type routingProbeLimits struct {
	mu      sync.Mutex
	starts  []time.Time
	origins map[string]*routingProbeOrigin
	active  int
	now     func() time.Time
}

var automaticRoutingProbes = &routingProbeLimits{now: time.Now}

func (l *routingProbeLimits) acquire(address string) (func(int, string), bool) {
	parsed, err := url.Parse(address)
	if err != nil || (parsed.Scheme != "https" && parsed.Scheme != "http") || parsed.Host == "" {
		return nil, false
	}
	port := parsed.Port()
	if port == "" {
		if parsed.Scheme == "https" {
			port = "443"
		} else {
			port = "80"
		}
	}
	origin := strings.ToLower(parsed.Scheme + "://" + net.JoinHostPort(parsed.Hostname(), port))
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	first := 0
	for first < len(l.starts) && now.Sub(l.starts[first]) >= time.Minute {
		first++
	}
	l.starts = append(l.starts[:0], l.starts[first:]...)
	if l.origins == nil {
		l.origins = make(map[string]*routingProbeOrigin)
	}
	state := l.origins[origin]
	if state == nil {
		if len(l.origins) >= 32 {
			return nil, false
		}
		state = &routingProbeOrigin{}
		l.origins[origin] = state
	}
	if l.active >= 2 || len(l.starts) >= 30 || state.active || state.forever || now.Before(state.until) {
		return nil, false
	}
	l.starts = append(l.starts, now)
	l.active++
	state.active = true
	var once sync.Once
	return func(status int, retryAfter string) {
		once.Do(func() {
			l.mu.Lock()
			defer l.mu.Unlock()
			l.active--
			state.active = false
			if status != 429 {
				state.throttles = 0
				return
			}
			state.throttles++
			fallback := time.Duration(60*(1<<min(state.throttles-1, 3))) * time.Second
			if fallback > 5*time.Minute {
				fallback = 5 * time.Minute
			}
			deadline := l.now().Add(fallback)
			if retryAfter != "" {
				if seconds, e := strconv.ParseUint(retryAfter, 10, 64); e == nil {
					if seconds > uint64(math.MaxInt64/int64(time.Second)) {
						state.forever = true
						return
					}
					deadline = l.now().Add(max(30*time.Second, time.Duration(seconds)*time.Second))
				} else if date, e := http.ParseTime(retryAfter); e == nil {
					if delta := date.Sub(l.now()); delta == time.Duration(math.MaxInt64) {
						state.forever = true
						return
					}
					deadline = l.now().Add(max(30*time.Second, date.Sub(l.now())))
				} else if strings.Trim(retryAfter, "0123456789") == "" {
					state.forever = true
					return
				}
			}
			if deadline.After(state.until) {
				state.until = deadline
			}
		})
	}, true
}

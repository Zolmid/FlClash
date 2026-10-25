package core

import (
	"fmt"
	"net/http"
	"testing"
	"time"
)

func TestAutomaticProbePhysicalBudgetAndConcurrency(t *testing.T) {
	now := time.Now()
	l := routingProbeLimits{now: func() time.Time { return now }}
	a, ok := l.acquire("https://origin-a.invalid/models")
	if !ok {
		t.Fatal("first request rejected")
	}
	if _, ok = l.acquire("https://origin-a.invalid/other"); ok {
		t.Fatal("same origin overlapped")
	}
	b, ok := l.acquire("https://origin-b.invalid/")
	if !ok {
		t.Fatal("second origin rejected")
	}
	if _, ok = l.acquire("https://origin-c.invalid/"); ok {
		t.Fatal("concurrency exceeded two")
	}
	a(200, "")
	a(200, "")
	b(200, "")
	for i := 2; i < 30; i++ {
		complete, admitted := l.acquire("https://origin-a.invalid/" + fmt.Sprint(i))
		if !admitted {
			t.Fatal("budget undercount")
		}
		complete(200, "")
	}
	if _, ok = l.acquire("https://origin-b.invalid/new-node"); ok {
		t.Fatal("physical window exceeded thirty")
	}
	now = now.Add(time.Minute)
	complete, admitted := l.acquire("https://origin-a.invalid/")
	if !admitted {
		t.Fatal("new window unavailable")
	}
	complete(200, "")
}
func TestAutomaticProbeNativeCoolingOutlivesHostAndNodeChanges(t *testing.T) {
	now := time.Now()
	l := routingProbeLimits{now: func() time.Time { return now }}
	complete, ok := l.acquire("https://origin.invalid/node-a")
	if !ok {
		t.Fatal("not admitted")
	}
	complete(429, "120")
	now = now.Add(119 * time.Second)
	if _, ok = l.acquire("https://origin.invalid/node-b"); ok {
		t.Fatal("node change escaped cooling")
	}
	if _, ok = l.acquire("https://origin.invalid:443/node-b"); ok {
		t.Fatal("default port alias escaped origin cooling")
	}
	now = now.Add(time.Second)
	complete, ok = l.acquire("https://origin.invalid/node-c")
	if !ok {
		t.Fatal("cooling did not end")
	}
	complete(429, now.Add(180*time.Second).UTC().Format(http.TimeFormat))
	now = now.Add(179 * time.Second)
	if _, ok = l.acquire("https://origin.invalid/node-d"); ok {
		t.Fatal("HTTP date escaped cooling")
	}
	now = now.Add(time.Second)
	complete, ok = l.acquire("https://origin.invalid/node-e")
	if !ok {
		t.Fatal("date cooling did not end")
	}
	complete(429, "99999999999999999999999999999999")
	now = now.Add(time.Hour)
	if _, ok = l.acquire("https://origin.invalid/node-f"); ok {
		t.Fatal("overflow shortened cooling")
	}
}

package core

import (
	"encoding/json"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"
)

func nativeRoutingFixture(t *testing.T) (*clientBundleRoutingState, nativeRoutingService, []nativeRoutingNode, *time.Time) {
	t.Helper()
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/qualified-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var envelope struct{ Data nativeRoutingPolicy }
	if err = json.Unmarshal(body, &envelope); err != nil {
		t.Fatal(err)
	}
	now := time.Unix(1001, 0)
	w := &clientBundleRoutingState{policy: envelope.Data, revision: 1,
		samples: map[string]map[string]nativeProviderSample{}, choices: map[string]*nativeRoutingChoice{},
		now: func() time.Time { return now }}
	for _, service := range w.policy.Routing.Services {
		if service.Kind == "ai" {
			nodes := []nativeRoutingNode{}
			for _, node := range w.policy.Routing.Nodes {
				if nativeRoutingEligible(service, node) {
					nodes = append(nodes, node)
				}
			}
			return w, service, nodes, &now
		}
	}
	t.Fatal("producer has no AI service")
	return nil, nativeRoutingService{}, nil, nil
}

func seedNativeProvider(w *clientBundleRoutingState, s nativeRoutingService, n nativeRoutingNode, batch uint64, delay int64) {
	key := nativeRoutingSubject(w.policy, s, n)
	for _, provider := range s.Providers {
		w.record(nativeRoutingJob{key: key, provider: provider, revision: w.revision, batch: batch},
			&ProbeResult{StatusCode: 200, Delay: delay, Body: "healthy public page"})
	}
}

func TestClientBundleRoutingProviderFreshnessAndRenewalDoNotBorrowTime(t *testing.T) {
	w, s, nodes, now := nativeRoutingFixture(t)
	if len(nodes) != 6 {
		t.Fatalf("qualified AI candidates=%d", len(nodes))
	}
	seedNativeProvider(w, s, nodes[0], 1, 100)
	if _, _, ok := w.score(s, nodes[0], *now); !ok {
		t.Fatal("fresh declared providers unavailable")
	}
	key := nativeRoutingSubject(w.policy, s, nodes[0])
	first := w.samples[key][s.Providers[0]].at
	*now = now.Add(89 * time.Second)
	w.record(nativeRoutingJob{key: key, provider: s.Providers[0], revision: 1, batch: 2},
		&ProbeResult{StatusCode: 200, Delay: 50})
	w.policy.ID = "renewed-synthetic"
	w.policy.Expires = 1300
	if nativeRoutingSubject(w.policy, s, nodes[0]) != key {
		t.Fatal("TTL renewal changed physical policy identity")
	}
	*now = now.Add(2 * time.Second)
	if _, _, ok := w.score(s, nodes[0], *now); ok {
		t.Fatal("one provider renewed the other providers")
	}
	if !w.samples[key][s.Providers[1]].at.Equal(first) {
		t.Fatal("cached sample time was renewed")
	}
}

func TestClientBundleRoutingNeutralAndOldResultsCannotCreateSuccess(t *testing.T) {
	w, s, nodes, now := nativeRoutingFixture(t)
	seedNativeProvider(w, s, nodes[0], 2, 100)
	key := nativeRoutingSubject(w.policy, s, nodes[0])
	before := w.samples[key][s.Providers[0]]
	*now = now.Add(time.Second)
	for _, result := range []*ProbeResult{{StatusCode: 429, Error: "failed"}, {StatusCode: 403, Body: "edge"}, {StatusCode: 200, Body: "Just a moment"}} {
		w.record(nativeRoutingJob{key: key, provider: s.Providers[0], revision: 1, batch: 3}, result)
	}
	w.record(nativeRoutingJob{key: key, provider: s.Providers[0], revision: 0, batch: 10}, &ProbeResult{StatusCode: 200, Delay: 1})
	w.record(nativeRoutingJob{key: key, provider: s.Providers[0], revision: 1, batch: 1}, &ProbeResult{StatusCode: 200, Delay: 1})
	if w.samples[key][s.Providers[0]] != before {
		t.Fatal("neutral or old reply changed a sample")
	}
}

func TestClientBundleRoutingStickyChoiceNeedsDistinctAggregateImprovement(t *testing.T) {
	w, s, nodes, now := nativeRoutingFixture(t)
	seedNativeProvider(w, s, nodes[0], 1, 200)
	seedNativeProvider(w, s, nodes[1], 1, 50)
	state := &nativeRoutingChoice{proxy: nodes[0].Name, switched: *now}
	if got := w.decide(s, nodes[:2], state, *now); got != nodes[0].Name {
		t.Fatal("minimum hold was ignored")
	}
	*now = now.Add(61 * time.Second)
	if got := w.decide(s, nodes[:2], state, *now); got != nodes[0].Name {
		t.Fatal("one aggregate improvement switched")
	}
	for index := 0; index < 5; index++ {
		if got := w.decide(s, nodes[:2], state, *now); got != nodes[0].Name {
			t.Fatal("cached result counted as new confirmation")
		}
	}
	seedNativeProvider(w, s, nodes[1], 2, 50)
	if got := w.decide(s, nodes[:2], state, *now); got != nodes[1].Name {
		t.Fatal("confirmed qualified improvement was ignored")
	}
	cross := nodes[1]
	cross.Egress.Country = "HK"
	cross.Services = append(cross.Services, s.ID)
	s.Countries = append(s.Countries, "HK")
	if nativeRoutingEligible(s, cross) {
		t.Fatal("HK entered AI")
	}
	cross = nodes[1]
	cross.Services = []string{}
	if nativeRoutingEligible(s, cross) {
		t.Fatal("HTTP health created missing service membership")
	}
}

func TestClientBundleRoutingTransportFailureRequiresActualRecovery(t *testing.T) {
	w, s, nodes, now := nativeRoutingFixture(t)
	seedNativeProvider(w, s, nodes[0], 1, 100)
	key := nativeRoutingSubject(w.policy, s, nodes[0])
	job := nativeRoutingJob{key: key, provider: s.Providers[0], revision: 1, batch: 2}
	w.record(job, &ProbeResult{Error: "timeout"})
	if _, _, ok := w.score(s, nodes[0], *now); ok {
		t.Fatal("failed provider remained healthy")
	}
	*now = now.Add(time.Second)
	job.batch = 3
	w.record(job, &ProbeResult{StatusCode: 200, Delay: 100})
	if _, _, ok := w.score(s, nodes[0], *now); ok {
		t.Fatal("single recovery sample bypassed confirmation")
	}
	*now = now.Add(time.Second)
	job.batch = 4
	w.record(job, &ProbeResult{StatusCode: 200, Delay: 100})
	if _, _, ok := w.score(s, nodes[0], *now); !ok {
		t.Fatal("real confirmed recovery was ignored")
	}
}

func TestClientBundleRoutingProviderURLParityWithSharedClient(t *testing.T) {
	raw, err := os.ReadFile("../packages/zolnit_client/lib/src/routing_manifest.dart")
	if err != nil {
		t.Fatal(err)
	}
	head := strings.SplitN(string(raw), "};", 2)[0]
	matches := regexp.MustCompile("'([a-z_]+)': '([^']+)'").FindAllStringSubmatch(head, -1)
	if len(matches) != len(nativeRegionPolicy.URLs) {
		t.Fatal("provider catalog drift")
	}
	for _, match := range matches {
		if nativeRegionPolicy.URLs[match[1]] != match[2] {
			t.Fatal("probe URL drift")
		}
	}
	for provider, countries := range nativeRegionPolicy.Countries {
		if !slices.IsSorted(countries) || len(countries) == 0 {
			t.Fatalf("invalid region policy for %s", provider)
		}
	}
}

func TestClientBundleRoutingUnknownProbeDoesNotExpelQualifiedCurrent(t *testing.T) {
	w, s, nodes, now := nativeRoutingFixture(t)
	seedNativeProvider(w, s, nodes[0], 1, 100)
	state := &nativeRoutingChoice{proxy: nodes[0].Name, switched: *now}
	key := nativeRoutingSubject(w.policy, s, nodes[0])
	*now = now.Add(91 * time.Second)
	for _, provider := range s.Providers {
		w.record(nativeRoutingJob{key: key, provider: provider, revision: 1, batch: 2},
			&ProbeResult{StatusCode: 403, Body: "Cloudflare forbidden"})
		w.record(nativeRoutingJob{key: key, provider: provider, revision: 1, batch: 3},
			&ProbeResult{StatusCode: 429, Error: "failed"})
	}
	if _, _, healthy := w.score(s, nodes[0], *now); healthy {
		t.Fatal("unknown probes forged fresh health")
	}
	if selected := w.decide(s, nodes, state, *now); selected != nodes[0].Name {
		t.Fatal("qualified current was expelled by unknown probing")
	}
	empty := &nativeRoutingChoice{}
	if selected := w.decide(s, nodes, empty, *now); selected != "" {
		t.Fatal("unknown probing selected a new candidate")
	}
	w.record(nativeRoutingJob{key: key, provider: s.Providers[0], revision: 1, batch: 4}, &ProbeResult{Error: "timeout"})
	if selected := w.decide(s, nodes, state, *now); selected != "" {
		t.Fatal("confirmed transport failure was treated as unknown")
	}
}

func TestClientBundleRoutingIdleBackoffAndRealTrafficReactivation(t *testing.T) {
	w, _, _, now := nativeRoutingFixture(t)
	if !w.probeDue(*now, Traffic{}) {
		t.Fatal("initial bounded probing was skipped")
	}
	w.lastCycle = *now
	*now = now.Add(30 * time.Second)
	if w.probeDue(*now, Traffic{}) {
		t.Fatal("idle hard cap became continuous target load")
	}
	*now = now.Add(30 * time.Second)
	if !w.probeDue(*now, Traffic{}) {
		t.Fatal("idle retry was lost")
	}
	w.lastCycle = *now
	*now = now.Add(31 * time.Second)
	if !w.probeDue(*now, Traffic{Up: 1}) {
		t.Fatal("real traffic did not reactivate probing")
	}
}

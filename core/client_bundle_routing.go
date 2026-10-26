package core

import (
	"context"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"
)

//go:embed client_bundle_routing_regions.json
var nativeRegionPolicyJSON []byte

var nativeRegionPolicy = func() struct {
	Countries map[string][]string
	URLs      map[string]string
} {
	var value struct {
		Countries map[string][]string
		URLs      map[string]string
	}
	if json.Unmarshal(nativeRegionPolicyJSON, &value) != nil {
		panic("invalid routing region policy")
	}
	return value
}()

type nativeRoutingService struct {
	ID        string   `json:"id"`
	Kind      string   `json:"kind"`
	Group     string   `json:"group"`
	Auto      string   `json:"automatic"`
	Providers []string `json:"providers"`
	Countries []string `json:"allowed_countries"`
}
type nativeRoutingNode struct {
	ID            string   `json:"id"`
	Name          string   `json:"proxy_name"`
	Enabled       bool     `json:"enabled"`
	Exit          string   `json:"exit_id"`
	FailureDomain string   `json:"failure_domain"`
	Services      []string `json:"services"`
	Revision      string   `json:"revision"`
	Egress        struct {
		Country  string `json:"country"`
		Source   string `json:"source"`
		Verified bool   `json:"verified"`
	} `json:"final_egress"`
}
type nativeRoutingPolicy struct {
	ID         string `json:"bundle_id"`
	Expires    int64  `json:"expires_at"`
	Connection struct {
		SHA string `json:"sha256"`
	} `json:"connection"`
	Routing struct {
		Services []nativeRoutingService `json:"services"`
		Nodes    []nativeRoutingNode    `json:"nodes"`
	} `json:"routing"`
}
type nativeProviderSample struct {
	at             time.Time
	latency        float64
	failed         bool
	batch          uint64
	failures, good int
	coolUntil      time.Time
}
type nativeRoutingChoice struct {
	proxy, challenger    string
	switched             time.Time
	examined             uint64
	improvements, cursor int
}
type nativeRoutingJob struct {
	ctx                  context.Context
	revision             uint64
	batch                uint64
	key, provider, proxy string
}
type clientBundleRoutingState struct {
	mu            sync.Mutex
	ctx           context.Context
	cancel        context.CancelFunc
	probeCancel   context.CancelFunc
	pulse         chan struct{}
	jobs          chan nativeRoutingJob
	owner         *ClientBundleOwnerGuard
	policy        nativeRoutingPolicy
	revision      uint64
	batch         uint64
	samples       map[string]map[string]nativeProviderSample
	choices       map[string]*nativeRoutingChoice
	lastCycle     time.Time
	lastTraffic   Traffic
	demand        bool
	idleCycles    uint
	serviceCursor int
	now           func() time.Time
	probe         func(context.Context, *ProbeParams) *ProbeResult
	origins       map[string]chan struct{}
}

var clientBundleRouting *clientBundleRoutingState

func stopClientBundleRoutingLocked() {
	if clientBundleRouting != nil {
		clientBundleRouting.cancel()
	}
	clientBundleRouting = nil
}

func replaceClientBundleRoutingLocked(body []byte, owner *ClientBundleOwnerGuard) {
	var envelope struct {
		Data nativeRoutingPolicy `json:"data"`
	}
	if json.Unmarshal(body, &envelope) != nil || owner == nil {
		return
	}
	policy := envelope.Data
	current := clientBundleRouting
	if current == nil || *current.owner != *owner {
		stopClientBundleRoutingLocked()
		ctx, cancel := context.WithCancel(context.Background())
		identity := *owner
		current = &clientBundleRoutingState{ctx: ctx, cancel: cancel, owner: &identity,
			pulse: make(chan struct{}, 1), jobs: make(chan nativeRoutingJob, 12),
			samples: map[string]map[string]nativeProviderSample{}, choices: map[string]*nativeRoutingChoice{},
			origins: map[string]chan struct{}{}, now: routingLeaseNow,
			probe: func(ctx context.Context, p *ProbeParams) *ProbeResult {
				return runProbe(ctx, probeRequest{automatic: true, method: "GET", url: p.Url,
					proxyName: p.ProxyName, timeout: 5 * time.Second, maxBody: 4096, noRedirect: true})
			}}
		for _, address := range nativeRegionPolicy.URLs {
			parsed, _ := url.Parse(address)
			current.origins[parsed.Scheme+"://"+parsed.Host] = make(chan struct{}, 1)
		}
		clientBundleRouting = current
		safeGo("client bundle routing", func() { current.loop() })
		for index := 0; index < 2; index++ {
			safeGo("client bundle provider", func() { current.work() })
		}
	}
	current.mu.Lock()
	if current.probeCancel != nil {
		current.probeCancel()
	}
	current.policy = policy
	current.revision++
	valid := map[string]bool{}
	for _, service := range policy.Routing.Services {
		for _, node := range policy.Routing.Nodes {
			if nativeRoutingEligible(service, node) {
				valid[nativeRoutingSubject(policy, service, node)] = true
			}
		}
	}
	for key := range current.samples {
		if !valid[key] {
			delete(current.samples, key)
		}
	}
	current.mu.Unlock()
	select {
	case current.pulse <- struct{}{}:
	default:
	}
}

func nativeContains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
func nativeRoutingEligible(service nativeRoutingService, node nativeRoutingNode) bool {
	if !node.Enabled || !node.Egress.Verified || node.Exit == "" || node.FailureDomain == "" ||
		node.Revision == "" ||
		!nativeContains([]string{"operator_verified", "egress_probe"}, node.Egress.Source) ||
		!nativeContains(node.Services, service.ID) || !nativeContains(service.Countries, node.Egress.Country) ||
		(service.Kind == "ai" && node.Egress.Country == "HK") || len(service.Providers) == 0 {
		return false
	}
	for _, provider := range service.Providers {
		aiProvider := provider != "netflix" && provider != "operator"
		if (service.Kind == "ai") != aiProvider {
			return false
		}
		if nativeRegionPolicy.URLs[provider] == "" ||
			!nativeContains(nativeRegionPolicy.Countries[provider], node.Egress.Country) {
			return false
		}
	}
	return true
}
func nativeRoutingSubject(policy nativeRoutingPolicy, service nativeRoutingService, node nativeRoutingNode) string {
	value, _ := json.Marshal([]any{policy.Connection.SHA, service, node})
	hash := sha256.Sum256(value)
	return hex.EncodeToString(hash[:])
}

func (w *clientBundleRoutingState) loop() {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-w.ctx.Done():
			return
		case <-w.pulse:
		case <-timer.C:
		}
		w.step()
		if !timer.Stop() {
			select {
			case <-timer.C:
			default:
			}
		}
		timer.Reset(w.delay())
	}
}
func (w *clientBundleRoutingState) delay() time.Duration {
	w.mu.Lock()
	defer w.mu.Unlock()
	now := w.now()
	delay := time.Second * 5
	for _, providers := range w.samples {
		for _, sample := range providers {
			until := sample.at.Add(90 * time.Second).Sub(now)
			if until > 0 && until < delay {
				delay = until
			}
		}
	}
	return max(time.Millisecond*10, delay)
}

func (w *clientBundleRoutingState) step() {
	configMu.Lock()
	defer configMu.Unlock()
	if clientBundleRouting != w || !matchesClientBundleOwnerLocked(w.owner) {
		return
	}
	lease := handleGetRoutingLease()
	if lease == nil || lease.AccountID != w.owner.AccountID {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if lease.BundleID != w.policy.ID {
		return
	}
	now := w.now()
	probing := w.probeDue(now, handleGetTotalTraffic(false))
	var probeContext context.Context
	if probing {
		if w.probeCancel != nil {
			w.probeCancel()
		}
		probeContext, w.probeCancel = context.WithCancel(w.ctx)
		w.lastCycle = now
		w.batch++
	}
	services := w.policy.Routing.Services
	jobs := 0
	for index := 0; index < len(services); index++ {
		service := services[(index+w.serviceCursor)%len(services)]
		selectMu.Lock()
		actual := activeRoutingLease
		mode := actual != nil && actual.matchesGuard(lease) && actual.services[service.Auto] != nil &&
			actual.services[service.Auto].policySelector.Now() == service.Auto
		actualProxy := ""
		if mode {
			actualProxy = actual.services[service.Auto].automaticSelector.Now()
		}
		selectMu.Unlock()
		if !mode {
			continue
		}
		choice := w.choices[service.ID]
		if choice == nil {
			choice = &nativeRoutingChoice{}
			w.choices[service.ID] = choice
		}
		candidates := []nativeRoutingNode{}
		for _, node := range w.policy.Routing.Nodes {
			if nativeRoutingEligible(service, node) {
				candidates = append(candidates, node)
			}
		}
		observed := ""
		for _, node := range candidates {
			if node.Name == actualProxy {
				observed = node.Name
			}
		}
		if choice.proxy != observed {
			choice.proxy, choice.switched = observed, now
		}
		best := w.decide(service, candidates, choice, now)
		target := "REJECT"
		if best != "" {
			target = best
		}
		result := handleChangeProxy(&ChangeProxyParams{GroupName: service.Auto, ProxyName: target,
			CloseConnections: true, RoutingLease: lease})
		if result.Message == "" && best != "" && choice.proxy != best {
			choice.proxy, choice.switched, choice.challenger, choice.improvements = best, now, "", 0
		}
		if !probing || len(candidates) == 0 || jobs >= 12 {
			continue
		}
		current := candidates[0]
		for _, node := range candidates {
			if node.Name == choice.proxy {
				current = node
			}
		}
		targets := []nativeRoutingNode{current}
		if len(candidates) > 1 {
			for offset := 0; offset < len(candidates); offset++ {
				node := candidates[(choice.cursor+offset)%len(candidates)]
				if node.Name != current.Name {
					targets = append(targets, node)
					choice.cursor = (choice.cursor + offset + 1) % len(candidates)
					break
				}
			}
		}
		for _, node := range targets {
			for _, provider := range service.Providers {
				if jobs >= 12 {
					break
				}
				job := nativeRoutingJob{ctx: probeContext, revision: w.revision,
					key: nativeRoutingSubject(w.policy, service, node), provider: provider, proxy: node.Name, batch: w.batch}
				if previous := w.samples[job.key][provider]; now.Before(previous.coolUntil) {
					continue
				}
				select {
				case w.jobs <- job:
					jobs++
				default:
				}
			}
		}
	}
	if probing && len(services) > 0 {
		w.serviceCursor = (w.serviceCursor + 1) % len(services)
	}
}

func (w *clientBundleRoutingState) probeDue(now time.Time, traffic Traffic) bool {
	if traffic != w.lastTraffic {
		w.demand = true
	}
	w.lastTraffic = traffic
	interval := 30 * time.Second
	if !w.demand {
		interval = min(5*time.Minute, interval*time.Duration(1<<min(w.idleCycles, 4)))
	}
	if !w.lastCycle.IsZero() && now.Sub(w.lastCycle) < interval {
		return false
	}
	if w.demand {
		w.idleCycles = 0
	} else {
		w.idleCycles = min(w.idleCycles+1, 4)
	}
	w.demand = false
	return true
}

func (w *clientBundleRoutingState) score(service nativeRoutingService, node nativeRoutingNode, now time.Time) (float64, uint64, bool) {
	providers := w.samples[nativeRoutingSubject(w.policy, service, node)]
	score := 0.0
	observed := ^uint64(0)
	for _, provider := range service.Providers {
		sample, ok := providers[provider]
		if !ok || sample.failed || now.Before(sample.at) || !now.Before(sample.at.Add(90*time.Second)) {
			return 0, 0, false
		}
		score += sample.latency
		observed = min(observed, sample.batch)
	}
	return score / float64(len(service.Providers)), observed, true
}
func (w *clientBundleRoutingState) decide(service nativeRoutingService, nodes []nativeRoutingNode, state *nativeRoutingChoice, now time.Time) string {
	for _, node := range nodes {
		if node.Name != state.proxy {
			continue
		}
		if _, _, fresh := w.score(service, node, now); fresh {
			break
		}
		failed := false
		for _, sample := range w.samples[nativeRoutingSubject(w.policy, service, node)] {
			failed = failed || sample.failed
		}
		if !failed {
			return node.Name
		}
	}
	type candidate struct {
		name     string
		score    float64
		observed uint64
	}
	healthy := []candidate{}
	for _, node := range nodes {
		if score, at, ok := w.score(service, node, now); ok {
			healthy = append(healthy, candidate{node.Name, score, at})
		}
	}
	if len(healthy) == 0 {
		return ""
	}
	sort.Slice(healthy, func(i, j int) bool {
		if healthy[i].score == healthy[j].score {
			return healthy[i].name < healthy[j].name
		}
		return healthy[i].score < healthy[j].score
	})
	best := healthy[0]
	var current *candidate
	for index := range healthy {
		if healthy[index].name == state.proxy {
			current = &healthy[index]
		}
	}
	if current == nil {
		return best.name
	}
	if best.name == current.name {
		state.challenger = ""
		state.improvements = 0
		return current.name
	}
	gain := current.score - best.score
	if now.Sub(state.switched) < 60*time.Second || gain < 20 || gain < current.score*0.2 {
		return current.name
	}
	if state.challenger != best.name || state.examined != best.observed {
		if state.challenger == best.name {
			state.improvements++
		} else {
			state.challenger = best.name
			state.improvements = 1
		}
		state.examined = best.observed
	}
	if state.improvements >= 2 {
		return best.name
	}
	return current.name
}

func (w *clientBundleRoutingState) work() {
	for {
		select {
		case <-w.ctx.Done():
			return
		case job := <-w.jobs:
			if job.ctx.Err() != nil {
				continue
			}
			address := nativeRegionPolicy.URLs[job.provider]
			parsed, _ := url.Parse(address)
			origin := w.origins[parsed.Scheme+"://"+parsed.Host]
			select {
			case origin <- struct{}{}:
			case <-job.ctx.Done():
				continue
			}
			result := w.probe(job.ctx, &ProbeParams{Url: address, ProxyName: job.proxy, AutomaticRouting: true, Timeout: 5000, MaxBody: 4096})
			<-origin
			if job.ctx.Err() != nil || result == nil {
				continue
			}
			w.record(job, result)
		}
	}
}

func (w *clientBundleRoutingState) record(job nativeRoutingJob, result *ProbeResult) {
	usable, failed := nativeRoutingTransport(job.provider, result)
	if !usable && !failed {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if job.revision != w.revision {
		return
	}
	if w.samples[job.key] == nil {
		w.samples[job.key] = map[string]nativeProviderSample{}
	}
	old := w.samples[job.key][job.provider]
	if !old.at.IsZero() && (job.batch <= old.batch || w.now().Before(old.at)) {
		return
	}
	next := nativeProviderSample{at: w.now(), latency: float64(result.Delay), failed: failed, batch: job.batch}
	if failed {
		next.failures = old.failures + 1
		if next.failures >= 2 {
			next.coolUntil = next.at.Add(min(5*time.Minute, 15*time.Second*time.Duration(1<<min(next.failures-2, 5))))
		}
	} else if old.failed {
		next.good = old.good + 1
		if next.at.Sub(old.at) > 90*time.Second {
			next.good = 1
		}
		next.failed = next.good < 2
		if next.failed {
			next.failures = old.failures
			next.coolUntil = old.coolUntil
		}
	} else if !old.at.IsZero() {
		next.latency = old.latency*0.75 + next.latency*0.25
	}
	w.samples[job.key][job.provider] = next
	select {
	case w.pulse <- struct{}{}:
	default:
	}
}

func nativeRoutingTransport(provider string, result *ProbeResult) (bool, bool) {
	if nativeRegionPolicy.URLs[provider] == "" {
		return false, false
	}
	if result == nil || result.StatusCode == 429 {
		return false, false
	}
	if result.Error != "" {
		return false, true
	}
	if result.Delay < 0 {
		return false, false
	}
	var decoded map[string]any
	_ = json.Unmarshal([]byte(result.Body), &decoded)
	apiError, _ := decoded["error"].(map[string]any)
	if result.StatusCode == 401 {
		if provider == "openai_api" {
			kind, _ := apiError["type"].(string)
			return kind != "", false
		}
		if provider == "gemini_api" {
			return apiError["status"] == "UNAUTHENTICATED" && apiError["code"] == float64(401), false
		}
		return false, false
	}
	if provider == "operator" {
		return result.StatusCode == 204, false
	}
	if result.StatusCode != 200 {
		return false, false
	}
	body := strings.Join(strings.Fields(strings.ToLower(result.Body)), "")
	for _, marker := range []string{"cf-chl", "challenge-platform", "justamoment", "verifyhuman", "verifyyouarehuman", "verifyyou'rehuman", "verifythatyouarehuman"} {
		if strings.Contains(body, marker) {
			return false, false
		}
	}
	if _, exists := decoded["error"]; exists {
		return false, false
	}
	return true, false
}

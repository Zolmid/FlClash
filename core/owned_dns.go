package core

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/config"
	D "github.com/miekg/dns"
)

var activeOwnedDNS atomic.Pointer[ownedDNSResolver]

type OwnedDNSConfig struct {
	Hosts         []string `json:"hosts"`
	Relay         string   `json:"relay"`
	Strict        bool     `json:"strict"`
	Authorization string   `json:"authorization"`
}

type ownedDNSAnswer struct {
	Addresses []string `json:"addresses"`
	TTL       int      `json:"ttl"`
}

type ownedDNSCache struct {
	ips   []netip.Addr
	until time.Time
}

type ownedDNSResolver struct {
	revoked atomic.Bool
	resolver.Resolver
	config OwnedDNSConfig
	hosts  map[string]bool
	mu     sync.Mutex
	cache  map[string]ownedDNSCache
}

func newOwnedDNSResolver(config *OwnedDNSConfig, fallback resolver.Resolver) (*ownedDNSResolver, error) {
	if config == nil {
		return nil, nil
	}
	endpoint, err := url.Parse(config.Relay)
	if err != nil || endpoint.Scheme != "https" || endpoint.Host != "link.zolmid.com" ||
		endpoint.Path != "/api/v1/zolnit/client/httpdns" || endpoint.RawQuery != "" || endpoint.Fragment != "" || endpoint.User != nil ||
		len(config.Hosts) == 0 || len(config.Hosts) > 256 {
		return nil, errors.New("invalid owned DNS configuration")
	}
	hosts := map[string]bool{}
	for _, host := range config.Hosts {
		if host != strings.ToLower(host) || strings.HasSuffix(host, ".") || strings.ContainsAny(host, "*/:@ ") ||
			(host != "link.zolmid.com" && !strings.HasSuffix(host, ".nodes.zolmid.com")) {
			return nil, errors.New("invalid owned DNS hostname")
		}
		hosts[host] = true
	}
	if !hosts["link.zolmid.com"] {
		return nil, errors.New("missing owned DNS bootstrap host")
	}
	return &ownedDNSResolver{Resolver: fallback, config: *config, hosts: hosts, cache: map[string]ownedDNSCache{}}, nil
}

func validateOwnedAddresses(values []string) ([]netip.Addr, error) {
	if len(values) == 0 || len(values) > 32 {
		return nil, errors.New("invalid owned DNS answer")
	}
	ips := make([]netip.Addr, 0, len(values))
	for _, value := range values {
		ip, err := netip.ParseAddr(value)
		if err != nil || ip.Zone() != "" || ip.IsUnspecified() || ip.IsLoopback() || ip.IsMulticast() {
			return nil, errors.New("invalid owned DNS address")
		}
		ips = append(ips, ip.Unmap())
	}
	return ips, nil
}

func dialOwnedAddresses(ctx context.Context, network, port string, ips []netip.Addr) (net.Conn, error) {
	var failure error
	for _, ip := range ips {
		attempt, cancel := context.WithTimeout(ctx, 4*time.Second)
		familyNetwork := network
		if strings.HasPrefix(network, "tcp") {
			if ip.Is6() {
				familyNetwork = "tcp6"
			} else {
				familyNetwork = "tcp4"
			}
		}
		conn, err := dialer.DialContext(attempt, familyNetwork, net.JoinHostPort(ip.String(), port))
		cancel()
		if err == nil {
			return conn, nil
		}
		failure = err
	}
	return nil, failure
}

func (r *ownedDNSResolver) lookup(ctx context.Context, host string) ([]netip.Addr, error) {
	host = strings.TrimSuffix(strings.ToLower(host), ".")
	if r.hosts[host] && r.revoked.Load() {
		return nil, errors.New("owned DNS session revoked")
	}
	if !r.hosts[host] {
		return r.fallback(ctx, host)
	}
	r.mu.Lock()
	cached, ok := r.cache[host]
	r.mu.Unlock()
	if ok && time.Now().Before(cached.until) {
		return append([]netip.Addr(nil), cached.ips...), nil
	}
	var answer ownedDNSAnswer
	var err error
	if host == "link.zolmid.com" {
		answer, err = publicOwnedDNSBootstrap(ctx)
	} else {
		answer, err = r.relay(ctx, host)
	}
	if err != nil {
		if !r.config.Strict {
			return r.fallback(ctx, host)
		}
		return nil, err
	}
	if r.revoked.Load() {
		return nil, errors.New("owned DNS session revoked")
	}
	ips, err := validateOwnedAddresses(answer.Addresses)
	if err != nil || answer.TTL < 0 || answer.TTL > 86400 {
		return nil, errors.New("invalid owned DNS answer")
	}
	if answer.TTL > 0 {
		r.mu.Lock()
		r.cache[host] = ownedDNSCache{ips: ips, until: time.Now().Add(time.Duration(answer.TTL) * time.Second)}
		r.mu.Unlock()
	}
	return append([]netip.Addr(nil), ips...), nil
}

func (r *ownedDNSResolver) fallback(ctx context.Context, host string) ([]netip.Addr, error) {
	if r.Resolver != nil && r.Resolver.Invalid() {
		return r.Resolver.LookupIP(ctx, host)
	}
	return resolver.SystemResolver.LookupIP(ctx, host)
}

func (r *ownedDNSResolver) relay(ctx context.Context, host string) (ownedDNSAnswer, error) {
	var answer ownedDNSAnswer
	if !strings.HasPrefix(r.config.Authorization, "Bearer ") {
		return answer, errors.New("owned DNS unauthenticated")
	}
	ips, err := r.lookup(ctx, "link.zolmid.com")
	if err != nil {
		return answer, err
	}
	transport := &http.Transport{Proxy: nil, DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
		h, port, err := net.SplitHostPort(address)
		if err != nil || h != "link.zolmid.com" || port != "443" {
			return nil, errors.New("owned DNS relay origin")
		}
		return dialOwnedAddresses(ctx, network, port, ips)
	}, TLSHandshakeTimeout: 5 * time.Second}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 8 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	req, _ := http.NewRequestWithContext(ctx, "GET", r.config.Relay+"?host="+url.QueryEscape(host), nil)
	req.Header.Set("Authorization", r.config.Authorization)
	req.Header.Set("Accept", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return answer, errors.New("owned DNS relay unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 || !strings.HasPrefix(resp.Header.Get("Content-Type"), "application/json") {
		return answer, errors.New("owned DNS relay rejected")
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 8193))
	if err != nil || len(body) > 8192 || json.Unmarshal(body, &answer) != nil {
		return answer, errors.New("invalid owned DNS relay response")
	}
	return answer, nil
}

type ownedDNSBootstrapQuery func(context.Context, uint16) (ownedDNSAnswer, error)

func publicOwnedDNSBootstrap(ctx context.Context) (ownedDNSAnswer, error) {
	return collectOwnedDNSBootstrap(ctx, queryOwnedDNSBootstrap)
}

func collectOwnedDNSBootstrap(ctx context.Context, query ownedDNSBootstrapQuery) (ownedDNSAnswer, error) {
	type result struct {
		family uint16
		answer ownedDNSAnswer
		err    error
	}
	results := make(chan result, 2)
	for _, qtype := range []uint16{D.TypeA, D.TypeAAAA} {
		go func(qtype uint16) { answer, err := query(ctx, qtype); results <- result{qtype, answer, err} }(qtype)
	}
	answers := make(map[uint16]ownedDNSAnswer)
	for i := 0; i < 2; i++ {
		select {
		case value := <-results:
			if value.err == nil {
				answers[value.family] = value.answer
			}
		case <-ctx.Done():
			return ownedDNSAnswer{}, ctx.Err()
		}
	}
	combined := ownedDNSAnswer{TTL: 86400}
	for _, family := range []uint16{D.TypeA, D.TypeAAAA} {
		value := answers[family]
		if _, err := validateOwnedAddresses(value.Addresses); err != nil {
			continue
		}
		if value.TTL < 0 || value.TTL > 86400 {
			continue
		}
		combined.Addresses = append(combined.Addresses, value.Addresses...)
		if value.TTL < combined.TTL {
			combined.TTL = value.TTL
		}
	}
	if _, err := validateOwnedAddresses(combined.Addresses); err != nil {
		return ownedDNSAnswer{}, errors.New("owned DNS bootstrap unavailable")
	}
	return combined, nil
}

var ownedDNSBootstrapLiterals = []string{"223.5.5.5", "2400:3200::1", "223.6.6.6", "2400:3200:baba::1"}

type ownedDNSBootstrapExchange func(context.Context, uint16, string) (ownedDNSAnswer, error)

func queryOwnedDNSBootstrap(ctx context.Context, qtype uint16) (ownedDNSAnswer, error) {
	return raceOwnedDNSBootstrap(ctx, qtype, exchangeOwnedDNSBootstrap)
}

func raceOwnedDNSBootstrap(ctx context.Context, qtype uint16, exchange ownedDNSBootstrapExchange) (ownedDNSAnswer, error) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	type result struct {
		answer ownedDNSAnswer
		err    error
	}
	results := make(chan result, len(ownedDNSBootstrapLiterals))
	for index, literal := range ownedDNSBootstrapLiterals {
		go func(index int, literal string) {
			timer := time.NewTimer(time.Duration(index) * 150 * time.Millisecond)
			defer timer.Stop()
			select {
			case <-timer.C:
			case <-ctx.Done():
				return
			}
			answer, err := exchange(ctx, qtype, literal)
			results <- result{answer, err}
		}(index, literal)
	}
	for range ownedDNSBootstrapLiterals {
		select {
		case value := <-results:
			if value.err == nil {
				return value.answer, nil
			}
		case <-ctx.Done():
			return ownedDNSAnswer{}, ctx.Err()
		}
	}
	return ownedDNSAnswer{}, errors.New("owned DNS bootstrap unavailable")
}

func exchangeOwnedDNSBootstrap(ctx context.Context, qtype uint16, literal string) (ownedDNSAnswer, error) {
	answer := ownedDNSAnswer{TTL: 86400}
	query := new(D.Msg)
	query.SetQuestion("link.zolmid.com.", qtype)
	wire, _ := query.Pack()
	transport := &http.Transport{DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
		return dialOwnedAddresses(ctx, network, "443", []netip.Addr{netip.MustParseAddr(literal)})
	}, TLSHandshakeTimeout: 2 * time.Second}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 2 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	req, _ := http.NewRequestWithContext(ctx, "GET", "https://dns.alidns.com/dns-query?dns="+base64.RawURLEncoding.EncodeToString(wire), nil)
	req.Header.Set("Accept", "application/dns-message")
	resp, err := client.Do(req)
	if err != nil {
		return ownedDNSAnswer{}, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 65536))
	response := new(D.Msg)
	if err != nil || resp.StatusCode != 200 || len(body) > 65535 || response.Unpack(body) != nil ||
		response.Id != query.Id || !response.Response || response.Rcode != D.RcodeSuccess ||
		len(response.Question) != 1 || response.Question[0] != query.Question[0] {
		return ownedDNSAnswer{}, errors.New("invalid owned DNS bootstrap response")
	}

	for _, rr := range response.Answer {
		if int(rr.Header().Ttl) < answer.TTL {
			answer.TTL = int(rr.Header().Ttl)
		}
		switch value := rr.(type) {
		case *D.A:
			answer.Addresses = append(answer.Addresses, value.A.String())
		case *D.AAAA:
			answer.Addresses = append(answer.Addresses, value.AAAA.String())
		}
	}
	return answer, nil
}

func (r *ownedDNSResolver) LookupIP(ctx context.Context, host string) ([]netip.Addr, error) {
	return r.lookup(ctx, host)
}
func (r *ownedDNSResolver) LookupIPv4(ctx context.Context, host string) ([]netip.Addr, error) {
	return r.family(ctx, host, true)
}
func (r *ownedDNSResolver) LookupIPv6(ctx context.Context, host string) ([]netip.Addr, error) {
	return r.family(ctx, host, false)
}
func (r *ownedDNSResolver) family(ctx context.Context, host string, v4 bool) ([]netip.Addr, error) {
	if !r.hosts[strings.TrimSuffix(strings.ToLower(host), ".")] && r.Resolver != nil && r.Resolver.Invalid() {
		if v4 {
			return r.Resolver.LookupIPv4(ctx, host)
		}
		return r.Resolver.LookupIPv6(ctx, host)
	}
	ips, err := r.lookup(ctx, host)
	if err != nil {
		return nil, err
	}
	result := []netip.Addr{}
	for _, ip := range ips {
		if ip.Is4() == v4 {
			result = append(result, ip)
		}
	}
	if len(result) == 0 {
		return nil, resolver.ErrIPNotFound
	}
	return result, nil
}
func (r *ownedDNSResolver) Invalid() bool { return true }
func (r *ownedDNSResolver) ResolveECH(ctx context.Context, host string) ([]byte, error) {
	if r.hosts[host] {
		return nil, resolver.ErrIPNotFound
	}
	if r.Resolver != nil {
		return r.Resolver.ResolveECH(ctx, host)
	}
	return nil, resolver.ErrIPNotFound
}
func (r *ownedDNSResolver) ExchangeContext(ctx context.Context, msg *D.Msg) (*D.Msg, error) {
	if len(msg.Question) != 1 || r.hosts[strings.TrimSuffix(strings.ToLower(msg.Question[0].Name), ".")] {
		return nil, errors.New("owned DNS raw query unavailable")
	}
	if r.Resolver != nil {
		return r.Resolver.ExchangeContext(ctx, msg)
	}
	return nil, resolver.ErrIPNotFound
}
func (r *ownedDNSResolver) ClearCache() {
	r.mu.Lock()
	r.cache = map[string]ownedDNSCache{}
	r.mu.Unlock()
	if r.Resolver != nil {
		r.Resolver.ClearCache()
	}
}
func (r *ownedDNSResolver) ResetConnection() {
	r.ClearCache()
	if r.Resolver != nil {
		r.Resolver.ResetConnection()
	}
}

func ownedDNSForConfig(cfg *config.Config, binding *OwnedDNSConfig) (*ownedDNSResolver, error) {
	if binding == nil {
		return nil, nil
	}
	copied := *binding
	copied.Hosts = append([]string(nil), copied.Hosts...)
	hosts := map[string]bool{}
	for _, host := range copied.Hosts {
		hosts[host] = true
	}
	add := func(address string) {
		host, _, err := net.SplitHostPort(address)
		if err == nil && strings.HasSuffix(host, ".nodes.zolmid.com") && !hosts[host] {
			hosts[host] = true
			copied.Hosts = append(copied.Hosts, host)
		}
	}
	for _, proxy := range cfg.Proxies {
		add(proxy.Addr())
	}
	for _, provider := range cfg.Providers {
		for _, proxy := range provider.Proxies() {
			add(proxy.Addr())
		}
	}
	owned, err := newOwnedDNSResolver(&copied, nil)
	if err != nil {
		return nil, err
	}
	for host := range owned.hosts {
		if cfg.Hosts != nil && cfg.Hosts.Search(host) != nil {
			return nil, errors.New("owned DNS host override forbidden")
		}
	}
	return owned, nil
}

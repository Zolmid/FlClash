package core

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/dns"
	D "github.com/miekg/dns"
)

const dnsInitiatorManual = "manual"

type DnsQueryParams struct {
	Domain string `json:"domain"`
	Type   string `json:"type"`
}

var (
	manualDnsMu      sync.Mutex
	manualDnsWaiters = map[D.Question][]chan DnsQuery{}
)

func handleQueryDns(params *DnsQueryParams) (DnsQuery, error) {
	r := resolver.DefaultResolver
	if r == nil {
		return DnsQuery{}, errors.New("DNS section is disabled")
	}
	domain := strings.TrimSuffix(strings.TrimSpace(params.Domain), ".")
	if domain == "" {
		return DnsQuery{}, errors.New("domain is empty")
	}
	qType, ok := D.StringToType[strings.ToUpper(strings.TrimSpace(params.Type))]
	if !ok {
		return DnsQuery{}, fmt.Errorf("invalid query type: %s", params.Type)
	}
	msg := new(D.Msg)
	msg.SetQuestion(D.Fqdn(domain), qType)
	question := msg.Question[0]

	observed := watchManualDnsQuery(question)
	defer unwatchManualDnsQuery(question, observed)

	ctx, cancel := context.WithTimeout(
		resolver.WithInitiator(context.Background(), dnsInitiatorManual),
		resolver.DefaultDNSTimeout,
	)
	defer cancel()
	start := time.Now()
	resp, err := r.ExchangeContext(ctx, msg)
	// The traced record carries the upstream and cache state, but it is missing
	// when the exchange joined another in-flight query or the context expired.
	select {
	case query := <-observed:
		return query, nil
	default:
	}
	return newDnsQuery(dns.QueryRecord{
		Question:  question,
		Msg:       resp,
		Initiator: dnsInitiatorManual,
		Start:     start,
		Err:       err,
	}), nil
}

func watchManualDnsQuery(question D.Question) chan DnsQuery {
	observed := make(chan DnsQuery, 1)
	manualDnsMu.Lock()
	defer manualDnsMu.Unlock()
	manualDnsWaiters[question] = append(manualDnsWaiters[question], observed)
	return observed
}

func unwatchManualDnsQuery(question D.Question, observed chan DnsQuery) {
	manualDnsMu.Lock()
	defer manualDnsMu.Unlock()
	waiters := slices.DeleteFunc(manualDnsWaiters[question], func(waiter chan DnsQuery) bool {
		return waiter == observed
	})
	if len(waiters) == 0 {
		delete(manualDnsWaiters, question)
		return
	}
	manualDnsWaiters[question] = waiters
}

func observeManualDnsQuery(record dns.QueryRecord, query DnsQuery) {
	if record.Initiator != dnsInitiatorManual {
		return
	}
	manualDnsMu.Lock()
	defer manualDnsMu.Unlock()
	for _, waiter := range manualDnsWaiters[record.Question] {
		select {
		case waiter <- query:
		default:
		}
	}
}

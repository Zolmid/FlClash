package core

import (
	"context"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/dns"
	D "github.com/miekg/dns"
	"net"
	"testing"
)

type manualDnsClient struct{}

func (manualDnsClient) Address() string  { return "udp://192.0.2.53:53" }
func (manualDnsClient) ResetConnection() {}
func (manualDnsClient) ExchangeContext(ctx context.Context, request *D.Msg) (*D.Msg, error) {
	response := new(D.Msg)
	response.SetReply(request)
	response.Answer = []D.RR{&D.A{
		Hdr: D.RR_Header{Name: request.Question[0].Name, Rrtype: D.TypeA, Class: D.ClassINET, Ttl: 60},
		A:   net.IPv4(192, 0, 2, 1),
	}}
	return response, nil
}

func TestManualDnsQueryUsesTheCoreResolverAndKeepsTraceMetadata(t *testing.T) {
	previous := resolver.DefaultResolver
	t.Cleanup(func() { resolver.DefaultResolver = previous })
	resolver.DefaultResolver = dns.NewResolverFromClient(manualDnsClient{})
	query, err := handleQueryDns(&DnsQueryParams{Domain: "example.test", Type: "a"})
	if err != nil {
		t.Fatal(err)
	}
	if query.Initiator != dnsInitiatorManual || query.Upstream != "udp://192.0.2.53:53" || query.Rcode != "NOERROR" {
		t.Fatalf("manual DNS trace = %+v", query)
	}
	if len(query.Answers) != 1 || query.Answers[0] != "192.0.2.1" {
		t.Fatalf("answers = %v", query.Answers)
	}
	if len(manualDnsWaiters) != 0 {
		t.Fatal("manual DNS query left a waiter registered")
	}
}

func TestManualDnsQueryReceivesOnlyManualRecords(t *testing.T) {
	question := dnsQuestion("manual.test", D.TypeA)
	observed := watchManualDnsQuery(question)
	defer unwatchManualDnsQuery(question, observed)

	for _, record := range []dns.QueryRecord{
		{Question: question, Initiator: resolver.InitiatorApp, Upstream: "app"},
		{Question: dnsQuestion("other.test", D.TypeA), Initiator: dnsInitiatorManual},
		{Question: question, Initiator: dnsInitiatorManual, Upstream: "udp://1.1.1.1:53", Cached: true},
	} {
		observeManualDnsQuery(record, newDnsQuery(record))
	}

	select {
	case query := <-observed:
		if query.Upstream != "udp://1.1.1.1:53" || !query.Cached || query.Initiator != "manual" {
			t.Fatalf("query = %+v", query)
		}
	default:
		t.Fatal("manual record was not delivered")
	}
	unwatchManualDnsQuery(question, observed)
	if _, ok := manualDnsWaiters[question]; ok {
		t.Fatal("waiter was not removed")
	}
}

func TestHandleQueryDnsRejectsInvalidRequests(t *testing.T) {
	previous := resolver.DefaultResolver
	t.Cleanup(func() { resolver.DefaultResolver = previous })

	resolver.DefaultResolver = nil
	if _, err := handleQueryDns(&DnsQueryParams{Domain: "example.com", Type: "A"}); err == nil {
		t.Fatal("want an error while DNS is disabled")
	}

	resolver.DefaultResolver = dns.NewResolverFromClient(nil)
	for _, params := range []DnsQueryParams{
		{Domain: " ", Type: "A"},
		{Domain: "example.com", Type: "BOGUS"},
	} {
		if _, err := handleQueryDns(&params); err == nil {
			t.Fatalf("params = %+v, want an error", params)
		}
	}
}

package core

import (
	"context"
	"crypto/tls"
	"encoding/base64"
	"errors"
	"io"
	"net"
	"net/http"
	"net/netip"
	"strings"
	"sync"
	"time"

	D "github.com/miekg/dns"
)

const firstPartyECHHost = "link.zolmid.com"

var firstPartyECHCache struct {
	sync.Mutex
	config []byte
	until  time.Time
}

func firstPartyECHConfig(ctx context.Context) []byte {
	firstPartyECHCache.Lock()
	defer firstPartyECHCache.Unlock()
	if time.Now().Before(firstPartyECHCache.until) {
		return append([]byte(nil), firstPartyECHCache.config...)
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	config, ttl := queryFirstPartyECH(ctx)
	if ctx.Err() == nil {
		if len(config) == 0 {
			ttl = 10
		}
		if ttl > 0 {
			firstPartyECHCache.config = append([]byte(nil), config...)
			firstPartyECHCache.until = time.Now().Add(time.Duration(min(ttl, 300)) * time.Second)
		}
	}
	return config
}

func queryFirstPartyECH(ctx context.Context) ([]byte, int) {
	query := new(D.Msg)
	query.SetQuestion(firstPartyECHHost+".", D.TypeHTTPS)
	wire, err := query.Pack()
	if err != nil {
		return nil, 0
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	type answer struct {
		config []byte
		ttl    int
	}
	answers := make(chan answer, len(ownedDNSBootstrapLiterals))
	url := "https://dns.alidns.com/dns-query?dns=" + base64.RawURLEncoding.EncodeToString(wire)
	for n, literal := range ownedDNSBootstrapLiterals {
		go func() {
			timer := time.NewTimer(time.Duration(n) * 150 * time.Millisecond)
			defer timer.Stop()
			select {
			case <-timer.C:
			case <-ctx.Done():
				return
			}
			config, ttl := exchangeFirstPartyECH(ctx, query, url, literal)
			answers <- answer{config, ttl}
		}()
	}
	for range ownedDNSBootstrapLiterals {
		select {
		case reply := <-answers:
			if len(reply.config) > 0 {
				return reply.config, reply.ttl
			}
		case <-ctx.Done():
			return nil, 0
		}
	}
	return nil, 0
}

func exchangeFirstPartyECH(ctx context.Context, query *D.Msg, url, literal string) ([]byte, int) {
	transport := &http.Transport{DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
		return dialOwnedAddresses(ctx, network, "443", []netip.Addr{netip.MustParseAddr(literal)})
	}, TLSHandshakeTimeout: 2 * time.Second}
	defer transport.CloseIdleConnections()
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, 0
	}
	req.Header.Set("Accept", "application/dns-message")
	resp, err := transport.RoundTrip(req)
	if err != nil {
		return nil, 0
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 || !strings.HasPrefix(resp.Header.Get("Content-Type"), "application/dns-message") {
		return nil, 0
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 65536))
	msg := new(D.Msg)
	if err != nil || len(body) > 65535 || msg.Unpack(body) != nil || msg.Id != query.Id || !msg.Response || msg.Truncated ||
		msg.Rcode != D.RcodeSuccess || len(msg.Question) != 1 || msg.Question[0] != query.Question[0] {
		return nil, 0
	}
	return extractFirstPartyECH(msg)
}

func extractFirstPartyECH(msg *D.Msg) ([]byte, int) {
	var selected []byte
	var priority uint16 = 65535
	ttl := 0
	for _, rr := range msg.Answer {
		record, ok := rr.(*D.HTTPS)
		if !ok || record.Hdr.Name != firstPartyECHHost+"." || record.Hdr.Class != D.ClassINET || record.Priority == 0 || record.Priority > priority || record.Target != "." {
			continue
		}
		var candidate []byte
		mandatory := false
		for _, value := range record.Value {
			switch v := value.(type) {
			case *D.SVCBMandatory:
				mandatory = true
			case *D.SVCBECHConfig:
				candidate = v.ECH
			}
		}
		if mandatory || len(candidate) < 4 || len(candidate) > 16384 || int(candidate[0])<<8|int(candidate[1]) != len(candidate)-2 {
			continue
		}
		selected, priority, ttl = append([]byte(nil), candidate...), record.Priority, int(record.Hdr.Ttl)
	}
	return selected, ttl
}

func enableFirstPartyECH(transport *http.Transport) {
	dial := transport.DialContext
	config := transport.TLSClientConfig.Clone()
	if config == nil {
		config = &tls.Config{MinVersion: tls.VersionTLS12}
	}
	config.ServerName = firstPartyECHHost
	transport.DialTLSContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(address)
		if err != nil || host != firstPartyECHHost || port != "443" {
			return nil, firstPartyHTTPError("invalid_request")
		}
		ech := firstPartyECHConfig(ctx)
		handshake := func(ech []byte) (net.Conn, bool, error) {
			conn, err := dial(ctx, network, address)
			if err != nil {
				return nil, false, err
			}
			c := config.Clone()
			c.EncryptedClientHelloConfigList = ech
			if len(ech) > 0 {
				c.MinVersion = tls.VersionTLS13
			}
			tracked := &firstPartyECHConn{Conn: conn}
			tlsConn := tls.Client(tracked, c)
			handshakeCtx, cancel := context.WithTimeout(ctx, transport.TLSHandshakeTimeout)
			defer cancel()
			if err = tlsConn.HandshakeContext(handshakeCtx); err != nil {
				conn.Close()
				return nil, !tracked.wrote, err
			}
			return tlsConn, false, nil
		}
		conn, beforeClientHello, err := handshake(ech)
		var rejected *tls.ECHRejectionError
		if len(ech) > 0 && err != nil && ctx.Err() == nil && (errors.As(err, &rejected) || beforeClientHello) {
			conn, _, err = handshake(nil)
		}
		return conn, err
	}
}

type firstPartyECHConn struct {
	net.Conn
	wrote bool
}

func (c *firstPartyECHConn) Write(p []byte) (int, error) {
	c.wrote = true
	return c.Conn.Write(p)
}

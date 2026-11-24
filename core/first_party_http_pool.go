package core

import (
	"context"
	"crypto/sha256"
	"crypto/tls"
	"encoding/json"
	"net"
	"net/http"
	"strings"
	"time"
)

type firstPartyHTTPPoolKey struct {
	client     string
	policy     [32]byte
	owned      *ownedDNSResolver
	generation uint64
}

type firstPartyHTTPPool struct {
	transport *http.Transport
	until     time.Time
	cancel    context.CancelFunc
}

func (s *firstPartyHTTPService) resetIdle() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for key, pool := range s.pools {
		pool.cancel()
		pool.transport.CloseIdleConnections()
		delete(s.pools, key)
	}
}

func (s *firstPartyHTTPService) pooledTransport(params FirstPartyHTTPParams) (*http.Transport, error) {
	var authorization string
	for key, value := range params.Headers {
		if strings.EqualFold(key, "authorization") {
			authorization = value
		}
	}
	var addresses []string
	if params.Addresses != nil {
		ips, err := validateOwnedAddresses(params.Addresses)
		if err != nil {
			return nil, firstPartyHTTPError("invalid_request")
		}
		for _, ip := range ips {
			addresses = append(addresses, ip.String())
		}
	}
	policy, _ := json.Marshal(struct {
		Authorization string
		Addresses     []string
		OwnedOnly     bool
	}{authorization, addresses, params.OwnedDNSOnly})
	key := firstPartyHTTPPoolKey{client: params.ClientID, policy: sha256.Sum256(policy), owned: activeOwnedDNS.Load()}
	s.mu.Lock()
	defer s.mu.Unlock()
	if key.owned != nil {
		key.owned.mu.Lock()
		key.generation = key.owned.generation
		key.owned.mu.Unlock()
	}
	if s.pools == nil {
		s.pools = make(map[firstPartyHTTPPoolKey]*firstPartyHTTPPool)
	}
	for cached, pool := range s.pools {
		if !time.Now().Before(pool.until) || cached.client == key.client && cached != key {
			pool.cancel()
			pool.transport.CloseIdleConnections()
			delete(s.pools, cached)
		}
	}
	if pool := s.pools[key]; pool != nil {
		return pool.transport, nil
	}
	if len(s.pools) >= firstPartyHTTPConcurrency {
		for cached, pool := range s.pools {
			pool.cancel()
			pool.transport.CloseIdleConnections()
			delete(s.pools, cached)
			break
		}
	}
	transport := s.transport()
	if params.Addresses != nil {
		ips, _ := validateOwnedAddresses(params.Addresses)
		transport = firstPartyHTTPTransport(func(ctx context.Context, network, address string) (net.Conn, error) {
			_, port, _ := net.SplitHostPort(address)
			return dialOwnedAddresses(ctx, network, port, ips)
		})
	}
	if key.owned != nil || params.Addresses != nil {
		enableFirstPartyECH(transport)
	}
	generation, cancel := context.WithCancel(context.Background())
	dial := transport.DialContext
	transport.DialContext = guardFirstPartyDial(generation, dial)
	if transport.DialTLSContext != nil {
		transport.DialTLSContext = guardFirstPartyDial(generation, transport.DialTLSContext)
	} else {
		transport.DialTLSContext = guardFirstPartyDial(generation, func(ctx context.Context, network, address string) (net.Conn, error) {
			conn, err := dial(ctx, network, address)
			if err != nil {
				return nil, err
			}
			config := transport.TLSClientConfig.Clone()
			if config.ServerName == "" {
				config.ServerName, _, _ = net.SplitHostPort(address)
			}
			secure := tls.Client(conn, config)
			handshake, finish := context.WithTimeout(ctx, transport.TLSHandshakeTimeout)
			defer finish()
			if err = secure.HandshakeContext(handshake); err != nil {
				conn.Close()
				return nil, err
			}
			return secure, nil
		})
	}
	s.pools[key] = &firstPartyHTTPPool{transport, time.Now().Add(30 * time.Second), cancel}
	return transport, nil
}

func guardFirstPartyDial(generation context.Context, dial func(context.Context, string, string) (net.Conn, error)) func(context.Context, string, string) (net.Conn, error) {
	return func(ctx context.Context, network, address string) (net.Conn, error) {
		attempt, cancel := context.WithCancel(ctx)
		stop := context.AfterFunc(generation, cancel)
		defer stop()
		defer cancel()
		if generation.Err() != nil {
			return nil, context.Canceled
		}
		conn, err := dial(attempt, network, address)
		if generation.Err() != nil || attempt.Err() != nil {
			if conn != nil {
				conn.Close()
			}
			return nil, context.Canceled
		}
		return conn, err
	}
}

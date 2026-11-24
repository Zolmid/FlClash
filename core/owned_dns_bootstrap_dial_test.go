package core

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

func TestBootstrapDialFirstFamilyAndLateFallback(t *testing.T) {
	for _, first := range []uint16{D.TypeA, D.TypeAAAA} {
		for _, failFirst := range []bool{false, true} {
			t.Run(net.JoinHostPort(D.TypeToString[first], map[bool]string{true: "fallback", false: "early"}[failFirst]), func(t *testing.T) {
				listener, err := net.Listen("tcp4", "127.0.0.1:0")
				if err != nil {
					t.Fatal(err)
				}
				defer listener.Close()
				accepted := make(chan net.Conn, 1)
				go func() { conn, _ := listener.Accept(); accepted <- conn }()
				defer func() {
					listener.Close()
					if conn := <-accepted; conn != nil {
						conn.Close()
					}
				}()
				query := func(ctx context.Context, family uint16) (ownedDNSAnswer, error) {
					if family != first {
						select {
						case <-time.After(180 * time.Millisecond):
						case <-ctx.Done():
							return ownedDNSAnswer{}, ctx.Err()
						}
					}
					address := "192.0.2.1"
					if family == D.TypeAAAA {
						address = "2001:db8::1"
					}
					return ownedDNSAnswer{Addresses: []string{address}, TTL: 30}, nil
				}
				attempts := 0
				start := time.Now()
				conn, err := dialOwnedBootstrap(context.Background(), "tcp", "443", query,
					func(ctx context.Context, network, port string, ips []netip.Addr) (net.Conn, error) {
						attempts++
						if time.Since(start) < 35*time.Millisecond {
							t.Error("grace omitted")
						}
						if failFirst && attempts == 1 {
							return nil, errors.New("first family sockets failed")
						}
						var d net.Dialer
						return d.DialContext(ctx, "tcp4", listener.Addr().String())
					})
				if err != nil {
					t.Fatal(err)
				}
				conn.Close()
				if !failFirst && time.Since(start) > 160*time.Millisecond {
					t.Fatal("waited for late family")
				}
				if failFirst && attempts != 2 {
					t.Fatalf("fallback attempts %d", attempts)
				}
			})
		}
	}
}

func TestBootstrapDialBothNoneAndCancellation(t *testing.T) {
	for _, cancelled := range []bool{false, true} {
		ctx, cancel := context.WithCancel(context.Background())
		if cancelled {
			cancel()
		}
		defer cancel()
		_, err := dialOwnedBootstrap(ctx, "tcp", "443", func(ctx context.Context, family uint16) (ownedDNSAnswer, error) {
			return ownedDNSAnswer{}, errors.New("no usable family")
		}, func(context.Context, string, string, []netip.Addr) (net.Conn, error) {
			t.Fatal("dialed empty answer")
			return nil, nil
		})
		if err == nil {
			t.Fatal("accepted empty/cancelled bootstrap")
		}
	}
	seen := 0
	_, _ = dialOwnedBootstrap(context.Background(), "tcp", "443", func(ctx context.Context, family uint16) (ownedDNSAnswer, error) {
		address := "192.0.2.1"
		if family == D.TypeAAAA {
			address = "2001:db8::1"
		}
		return ownedDNSAnswer{Addresses: []string{address}, TTL: 30}, nil
	}, func(_ context.Context, _, _ string, ips []netip.Addr) (net.Conn, error) {
		seen = len(ips)
		return nil, errors.New("synthetic")
	})
	if seen != 2 {
		t.Fatalf("both ready: %d", seen)
	}
}

func TestBootstrapDialLateFamilyBeatsBlackholeAndCleansLoser(t *testing.T) {
	for _, cancelCaller := range []bool{false, true} {
		ctx, cancel := context.WithCancel(context.Background())
		cleaned := make(chan struct{})
		started := make(chan struct{})
		query := func(ctx context.Context, family uint16) (ownedDNSAnswer, error) {
			if family == D.TypeAAAA {
				select {
				case <-time.After(150 * time.Millisecond):
				case <-ctx.Done():
					return ownedDNSAnswer{}, ctx.Err()
				}
				return ownedDNSAnswer{Addresses: []string{"2001:db8::1"}, TTL: 30}, nil
			}
			return ownedDNSAnswer{Addresses: []string{"192.0.2.1"}, TTL: 30}, nil
		}
		peer, winner := net.Pipe()
		defer peer.Close()
		if cancelCaller {
			go func() { <-started; cancel() }()
		}
		conn, err := dialOwnedBootstrap(ctx, "tcp", "443", query, func(ctx context.Context, _, _ string, ips []netip.Addr) (net.Conn, error) {
			if ips[0].Is4() {
				close(started)
				<-ctx.Done()
				close(cleaned)
				return nil, ctx.Err()
			}
			return winner, nil
		})
		cancel()
		if cancelCaller && err == nil {
			t.Fatal("cancelled caller succeeded")
		}
		if !cancelCaller && (err != nil || conn != winner) {
			t.Fatal("late family lost", err)
		}
		if conn != nil {
			conn.Close()
		} else {
			winner.Close()
		}
		select {
		case <-cleaned:
		case <-time.After(time.Second):
			t.Fatal("loser did not stop")
		}
	}
}

func TestBootstrapDialDeadlineClosesLateSocket(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 80*time.Millisecond)
	defer cancel()
	peer, late := net.Pipe()
	defer peer.Close()
	_, err := dialOwnedBootstrap(ctx, "tcp", "443", func(_ context.Context, family uint16) (ownedDNSAnswer, error) {
		address := "192.0.2.1"
		if family == D.TypeAAAA {
			address = "2001:db8::1"
		}
		return ownedDNSAnswer{Addresses: []string{address}, TTL: 30}, nil
	}, func(ctx context.Context, _, _ string, _ []netip.Addr) (net.Conn, error) {
		<-ctx.Done()
		return late, nil
	})
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal("deadline not preserved", err)
	}
	peer.SetReadDeadline(time.Now().Add(time.Second))
	if _, err := peer.Read(make([]byte, 1)); err == nil {
		t.Fatal("late socket remained open")
	} else if timeout, ok := err.(net.Error); ok && timeout.Timeout() {
		t.Fatal("late socket leaked")
	}
}

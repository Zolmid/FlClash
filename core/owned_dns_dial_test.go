package core

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/dialer"
)

func TestOwnedDNSDialStaggersOtherFamilyAndClosesLateWinner(t *testing.T) {
	for _, first := range []string{"192.0.2.1", "2001:db8::1"} {
		t.Run(first, func(t *testing.T) {
			ips := []netip.Addr{netip.MustParseAddr(first), netip.MustParseAddr("192.0.2.2"), netip.MustParseAddr("2001:db8::2")}
			if ips[0].Is6() {
				ips[1], ips[2] = ips[2], ips[1]
			}
			release, closed := make(chan struct{}), make(chan struct{})
			var calls atomic.Int32
			dial := func(ctx context.Context, network, address string, _ ...dialer.Option) (net.Conn, error) {
				n := calls.Add(1)
				if n == 1 {
					<-release
					left, right := net.Pipe()
					go func() { defer close(closed); defer right.Close(); var data [1]byte; _, _ = right.Read(data[:]) }()
					return left, nil
				}
				host, _, _ := net.SplitHostPort(address)
				if netip.MustParseAddr(host).Is4() == ips[0].Is4() {
					t.Error("same family was not interleaved")
				}
				left, right := net.Pipe()
				t.Cleanup(func() { right.Close() })
				return left, nil
			}
			start := time.Now()
			conn, err := raceOwnedAddresses(context.Background(), "tcp", "443", ips, dial)
			if err != nil {
				t.Fatal(err)
			}
			conn.Close()
			elapsed := time.Since(start)
			if elapsed < 200*time.Millisecond || elapsed > time.Second {
				t.Fatalf("stagger elapsed %v", elapsed)
			}
			close(release)
			select {
			case <-closed:
			case <-time.After(time.Second):
				t.Fatal("late losing socket leaked")
			}
			if calls.Load() != 2 {
				t.Fatalf("attempt count %d", calls.Load())
			}
		})
	}
}

func TestOwnedDNSDialCancellationAndFamilyEligibility(t *testing.T) {
	for _, network := range []string{"tcp4", "tcp6"} {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
		var calls atomic.Int32
		_, err := raceOwnedAddresses(ctx, network, "443", []netip.Addr{netip.MustParseAddr("192.0.2.1"), netip.MustParseAddr("2001:db8::1")},
			func(ctx context.Context, family, _ string, _ ...dialer.Option) (net.Conn, error) {
				calls.Add(1)
				if family != network {
					t.Errorf("ineligible family %s", family)
				}
				<-ctx.Done()
				return nil, ctx.Err()
			})
		cancel()
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatal(err)
		}
		if calls.Load() != 1 {
			t.Fatalf("attempt count %d", calls.Load())
		}
	}
}

func TestOwnedDNSDialImmediateFailureDoesNotWaitForStagger(t *testing.T) {
	var calls atomic.Int32
	start := time.Now()
	conn, err := raceOwnedAddresses(context.Background(), "tcp", "443", []netip.Addr{netip.MustParseAddr("192.0.2.1"), netip.MustParseAddr("2001:db8::1")},
		func(context.Context, string, string, ...dialer.Option) (net.Conn, error) {
			calls.Add(1)
			if calls.Load() == 1 {
				return nil, errors.New("unreachable")
			}
			left, right := net.Pipe()
			t.Cleanup(func() { right.Close() })
			return left, nil
		})
	if err != nil {
		t.Fatal(err)
	}
	conn.Close()
	if time.Since(start) > 200*time.Millisecond {
		t.Fatal("immediate failure waited for stagger")
	}
}

func TestOwnedDNSGenerationCancelsBetweenCacheAndApply(t *testing.T) {
	r := ownedDNSFixture(t)
	r.cache["node.nodes.zolmid.com"] = ownedDNSCache{ips: []netip.Addr{netip.MustParseAddr("192.0.2.1")}, until: time.Now().Add(time.Minute)}
	ctx, finish := r.track(context.Background())
	defer finish()
	if _, err := r.lookup(ctx, "node.nodes.zolmid.com"); err != nil {
		t.Fatal(err)
	}
	r.invalidateCache()
	if !errors.Is(ctx.Err(), context.Canceled) {
		t.Fatal("completed DNS escaped network invalidation")
	}
	if _, err := r.lookup(ctx, "node.nodes.zolmid.com"); !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
}

func TestOwnedDNSCoalescesWaitersWithoutSharingCallerCancellation(t *testing.T) {
	r := ownedDNSFixture(t)
	started, release := make(chan struct{}), make(chan struct{})
	var queries atomic.Int32
	r.query = func(ctx context.Context, host string) (ownedDNSAnswer, error) {
		if queries.Add(1) == 1 {
			close(started)
		}
		select {
		case <-release:
			return ownedDNSAnswer{Addresses: []string{"192.0.2.1"}, TTL: 30}, nil
		case <-ctx.Done():
			return ownedDNSAnswer{}, ctx.Err()
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	first := make(chan error, 1)
	go func() { _, err := r.lookup(ctx, "node.nodes.zolmid.com"); first <- err }()
	<-started
	second := make(chan error, 1)
	go func() { _, err := r.lookup(context.Background(), "node.nodes.zolmid.com"); second <- err }()
	cancel()
	if err := <-first; !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	close(release)
	if err := <-second; err != nil {
		t.Fatal(err)
	}
	if queries.Load() != 1 {
		t.Fatalf("queries=%d", queries.Load())
	}
	if _, err := r.lookup(context.Background(), "node.nodes.zolmid.com"); err != nil || queries.Load() != 1 {
		t.Fatal("TTL cache missed", err)
	}
}

func TestOwnedDNSGenerationCancelsSharedQueryAndRejectsLateResult(t *testing.T) {
	r := ownedDNSFixture(t)
	started, cancelled, release := make(chan struct{}), make(chan struct{}), make(chan struct{})
	r.query = func(ctx context.Context, host string) (ownedDNSAnswer, error) {
		close(started)
		<-ctx.Done()
		close(cancelled)
		<-release
		return ownedDNSAnswer{Addresses: []string{"192.0.2.1"}, TTL: 30}, nil
	}
	result := make(chan error, 1)
	go func() { _, err := r.lookup(context.Background(), "node.nodes.zolmid.com"); result <- err }()
	<-started
	r.invalidateCache()
	select {
	case err := <-result:
		if err == nil {
			t.Fatal("stale query accepted")
		}
	case <-time.After(time.Second):
		t.Fatal("caller cancellation waited for upstream")
	}
	select {
	case <-cancelled:
	case <-time.After(time.Second):
		t.Fatal("upstream not cancelled")
	}
	close(release)
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.cache) != 0 {
		t.Fatal("late result cached")
	}
}

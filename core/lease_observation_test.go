package core

import (
	"bytes"
	"core/observation"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

func observationHome(t *testing.T) string {
	t.Helper()
	home, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return home
}

func startTestLeaseObservation(t *testing.T, home string) string {
	t.Helper()
	if err := configureRoutingLeaseObservation(home, true); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(stopRoutingLeaseObservation)
	_, role := leaseObservationRole()
	return filepath.Join(home, "diagnostics", "lease-observation-"+role+".json")
}

func waitLeaseObservation(t *testing.T, path string, accept func(observation.Snapshot) bool) observation.Snapshot {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		data, err := os.ReadFile(path)
		if err == nil {
			snapshot, err := observation.Read(bytes.NewReader(data))
			if err == nil && accept(snapshot) {
				return snapshot
			}
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("observation did not reach expected state")
	return observation.Snapshot{}
}

func TestLeaseObservationPureQueryExpiredDoesNotRevoke(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	previousAfter := routingLeaseAfterFunc
	routingLeaseAfterFunc = func(time.Duration, func()) *time.Timer { return nil }
	t.Cleanup(func() { routingLeaseAfterFunc = previousAfter })
	path := startTestLeaseObservation(t, observationHome(t))
	guard := fix.install(fix.spec(time.Second))
	if guard == nil {
		t.Fatal("lease not installed")
	}
	result := handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "us-exit", RoutingLease: guard})
	if result.Message != "" {
		t.Fatal(result.Message)
	}
	selectMu.Lock()
	fix.now = fix.now.Add(2 * time.Second)
	lease, token, timer := activeRoutingLease, activeRoutingLease.token, activeRoutingLease.timer
	events := append([]observation.Event{}, leaseObservationEvents...)
	sequence := leaseObservationSequence
	selectMu.Unlock()
	first := handleGetRoutingLeaseObservation()
	second := handleGetRoutingLeaseObservation()
	if err := first.Validate(); err != nil {
		t.Fatal(err)
	}
	if !first.State.DeadlineElapsed || first.State.Revoked || first.State.Groups[0].Automatic != "proxy" {
		t.Fatalf("unexpected snapshot: %+v", first.State)
	}
	selectMu.Lock()
	unchanged := activeRoutingLease == lease && !lease.revoked && lease.token == token && lease.timer == timer && sequence == leaseObservationSequence && reflect.DeepEqual(events, leaseObservationEvents)
	selectMu.Unlock()
	if !unchanged || !reflect.DeepEqual(first.State, second.State) || groupNow(t, fix.auto) != "us-exit" {
		t.Fatal("pure query mutated lease, selector, timer or events")
	}
	stopRoutingLeaseObservation()
	final := waitLeaseObservation(t, path, func(s observation.Snapshot) bool { return s.ProducerState == "stopped" })
	if final.State.Revoked {
		t.Fatal("observation shutdown revoked lease")
	}
}

func TestLeaseObservationWatchdogWritesRejectWithoutFrontend(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	path := startTestLeaseObservation(t, observationHome(t))
	guard := fix.install(fix.spec(150 * time.Millisecond))
	if guard == nil {
		t.Fatal("lease not installed")
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "AI 自动", ProxyName: "us-exit", RoutingLease: guard}); result.Message != "" {
		t.Fatal(result.Message)
	}
	currentRoute.mu.Lock()
	defer currentRoute.mu.Unlock()
	snapshot := waitLeaseObservation(t, path, func(s observation.Snapshot) bool {
		for _, event := range s.Events {
			if event.Kind == "watchdog" && event.State.Revoked && len(event.State.Groups) == 1 && event.State.Groups[0].Automatic == "reject" {
				return true
			}
		}
		return false
	})
	if !snapshot.State.Revoked || snapshot.State.Groups[0].Automatic != "reject" {
		t.Fatal("watchdog evidence missing")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{"acct-1", "bundle-1", "digest-1", "us-exit", "sg-exit", "AI 服务", "127.0.0.1", guard.InstanceID, guard.Token} {
		if strings.Contains(string(data), secret) {
			t.Fatalf("sensitive value leaked: %q", secret)
		}
	}
	for _, key := range []string{"account", "bundle", "token", "digest", "guard"} {
		if strings.Contains(string(data), key) {
			t.Fatalf("sensitive key leaked: %s", key)
		}
	}
	if len(data) > observation.MaxBytes {
		t.Fatal("oversized observation")
	}
	if runtime.GOOS != "windows" {
		file, err := os.Stat(path)
		if err != nil || file.Mode().Perm() != 0600 {
			t.Fatal("file permissions")
		}
		directory, err := os.Stat(filepath.Dir(path))
		if err != nil || directory.Mode().Perm() != 0700 {
			t.Fatal("directory permissions")
		}
	}
}

func TestLeaseObservationDisabledAndUnsafePaths(t *testing.T) {
	stopRoutingLeaseObservation()
	home := observationHome(t)
	if err := configureRoutingLeaseObservation(home, false); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(home, "diagnostics")); !os.IsNotExist(err) {
		t.Fatal("disabled observation created diagnostics")
	}
	if runtime.GOOS == "windows" {
		t.Skip("Unix symlink permission checks")
	}
	outside := observationHome(t)
	if err := os.Symlink(outside, filepath.Join(home, "diagnostics")); err != nil {
		t.Fatal(err)
	}
	if err := configureRoutingLeaseObservation(home, true); err == nil {
		stopRoutingLeaseObservation()
		t.Fatal("accepted symlink diagnostics")
	}
	if err := os.Remove(filepath.Join(home, "diagnostics")); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(home, "diagnostics"), 0700); err != nil {
		t.Fatal(err)
	}
	_, role := leaseObservationRole()
	target := filepath.Join(home, "diagnostics", "lease-observation-"+role+".json")
	sensitive := filepath.Join(outside, "private")
	if err := os.WriteFile(sensitive, []byte("unchanged"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(sensitive, target); err != nil {
		t.Fatal(err)
	}
	if err := configureRoutingLeaseObservation(home, true); err == nil {
		stopRoutingLeaseObservation()
		t.Fatal("accepted symlink target")
	}
	data, err := os.ReadFile(sensitive)
	if err != nil || string(data) != "unchanged" {
		t.Fatal("symlink target changed")
	}
	linkedHome := filepath.Join(observationHome(t), "linked-home")
	if err := os.Symlink(home, linkedHome); err != nil {
		t.Fatal(err)
	}
	if err := configureRoutingLeaseObservation(linkedHome, true); err == nil {
		stopRoutingLeaseObservation()
		t.Fatal("accepted symlink home")
	}
}

func TestLeaseObservationRingPrivacyAndImmutableSnapshots(t *testing.T) {
	fix := newRoutingLeaseFixture(t)
	startTestLeaseObservation(t, observationHome(t))
	guard := fix.install(fix.spec(time.Minute))
	if guard == nil {
		t.Fatal("lease not installed")
	}
	before := handleGetRoutingLeaseObservation()
	encodedBefore, _ := json.Marshal(before)
	for i := 0; i < 12; i++ {
		if result := handleChangeProxy(&ChangeProxyParams{GroupName: "AI 服务 · 手动", ProxyName: "sg-exit"}); result.Message != "" {
			t.Fatal(result.Message)
		}
	}
	after := handleGetRoutingLeaseObservation()
	if len(after.Events) != observation.MaxEvents {
		t.Fatalf("ring size = %d", len(after.Events))
	}
	if err := after.Validate(); err != nil {
		t.Fatal(err)
	}
	for _, event := range after.Events {
		if event.Kind != "manual" {
			t.Fatalf("unexpected event: %s", event.Kind)
		}
	}
	encodedAgain, _ := json.Marshal(before)
	if !bytes.Equal(encodedBefore, encodedAgain) {
		t.Fatal("snapshot mutated after capture")
	}
	resetRoutingLeaseInstance()
	absent := handleGetRoutingLeaseObservation()
	if absent.State.LeasePresent || len(absent.State.InstanceTag) != 64 || absent.State.InstanceTag == before.State.InstanceTag {
		t.Fatal("missing fresh instance tag without lease")
	}
	if err := absent.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestLeaseObservationHeartbeatIndependentOfRPC(t *testing.T) {
	path := startTestLeaseObservation(t, observationHome(t))
	first := waitLeaseObservation(t, path, func(s observation.Snapshot) bool { return s.ProducerState == "running" })
	next := waitLeaseObservation(t, path, func(s observation.Snapshot) bool { return s.UptimeMS >= first.UptimeMS+900 })
	if len(next.Events) != len(first.Events) {
		t.Fatal("heartbeat fabricated an event")
	}
}

func TestLeaseObservationOldTemporaryFileDoesNotBlockNewSamples(t *testing.T) {
	home := observationHome(t)
	if err := os.Mkdir(filepath.Join(home, "diagnostics"), 0700); err != nil {
		t.Fatal(err)
	}
	_, role := leaseObservationRole()
	old := filepath.Join(home, "diagnostics", ".lease-observation-"+role+".json."+strconv.Itoa(os.Getpid())+".1.tmp")
	if err := os.WriteFile(old, []byte("retained"), 0600); err != nil {
		t.Fatal(err)
	}
	path := startTestLeaseObservation(t, home)
	_ = waitLeaseObservation(t, path, func(s observation.Snapshot) bool { return s.ProducerState == "running" })
	data, err := os.ReadFile(old)
	if err != nil || string(data) != "retained" {
		t.Fatal("unowned temporary file was changed")
	}
}

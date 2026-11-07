package clientbundle

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type testClock struct {
	wall    int64
	elapsed time.Duration
}

func (c *testClock) options() StoreOptions {
	return StoreOptions{Now: func() time.Time { return time.Unix(c.wall, 0) }, Elapsed: func() time.Duration { return c.elapsed }}
}

func openStore(t *testing.T, dir string, clock *testClock) *SubscriptionStore {
	t.Helper()
	store, err := OpenSubscriptionStore(dir, testTrust(t), clock.options())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(store.Close)
	return store
}

func mustApply(t *testing.T, store *SubscriptionStore, envelope []byte) ApplyResult {
	t.Helper()
	result, err := applyEnvelope(store, envelope)
	if err != nil {
		t.Fatal(err)
	}
	return result
}

func installedSerial(t *testing.T, store *SubscriptionStore) int64 {
	t.Helper()
	status, err := store.Status(testAccount, testDevice)
	if err != nil {
		t.Fatal(err)
	}
	if status.Package == nil {
		return 0
	}
	return status.Package.Serial
}

func TestStorePersistsAcrossRestartAndOrdersSerials(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1001}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	if result := mustApply(t, store, fixtures["bundle1"]); !result.Installed || !result.Changed {
		t.Fatal("first bundle not installed", result)
	}
	if result := mustApply(t, store, fixtures["bundle1"]); !result.Installed || result.Changed {
		t.Fatal("same serial and bytes are not idempotent", result)
	}
	store.Close()
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 1 {
		t.Fatal("installed package lost across restart")
	}
	body, pkg, err := store.Project(testAccount, testDevice)
	if err != nil || pkg.Serial != 1 {
		t.Fatal("restarted package does not project", err)
	}
	if prepared, code := Prepare(body, testAccount, "{}", time.Unix(1001, 0)); code != "" || prepared.Bundle.Expires > 1301 {
		t.Fatal("restarted projection does not prepare", code)
	}
	if _, err := applyEnvelope(store, bundle(t, 1, 1050, expiry(100000))); !errors.Is(err, ErrReplay) {
		t.Fatal("same serial with different bytes accepted", err)
	}
	mustApply(t, store, fixtures["bundle2"])
	if _, err := applyEnvelope(store, fixtures["bundle1"]); !errors.Is(err, ErrReplay) {
		t.Fatal("lower serial accepted", err)
	}
	store.Close()
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 2 {
		t.Fatal("newer package not retained")
	}
	if _, err := applyEnvelope(store, fixtures["bundle1"]); !errors.Is(err, ErrReplay) {
		t.Fatal("floor did not survive restart", err)
	}
}

func TestRevocationTombstoneSurvivesPayloadDeletionAndRestart(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle2"])
	if result := mustApply(t, store, fixtures["revoked3"]); !result.Revoked || result.Installed {
		t.Fatal("revocation not applied", result)
	}
	if _, err := os.Stat(filepath.Join(dir, packageFileName)); !os.IsNotExist(err) {
		t.Fatal("credential payload kept after signed revocation")
	}
	floor, _ := os.ReadFile(filepath.Join(dir, floorFileName))
	if strings.Contains(string(floor), "CREDENTIAL") || strings.Contains(string(floor), "PASSWORD") {
		t.Fatal("floor file carries credentials")
	}
	store.Close()
	store = openStore(t, dir, clock)
	for _, replay := range []string{"bundle1", "bundle2"} {
		if _, err := applyEnvelope(store, fixtures[replay]); err == nil {
			t.Fatal("replay after revocation accepted:", replay)
		}
	}
	if _, err := applyEnvelope(store, bundle(t, 3, 1300, expiry(100000))); !errors.Is(err, ErrReplay) {
		t.Fatal("same serial as tombstone accepted", err)
	}
	if result := mustApply(t, store, fixtures["revoked3"]); result.Changed || !result.Revoked {
		t.Fatal("repeated revocation not idempotent", result)
	}
	if _, _, err := store.Project(testAccount, testDevice); !errors.Is(err, ErrTombstone) {
		t.Fatal("revoked package prepared", err)
	}
	if status, _ := store.Status(testAccount, testDevice); !status.HasFloor || !status.Revoked || status.Package != nil {
		t.Fatal("tombstone status lost", status)
	}
	if result := mustApply(t, store, fixtures["unlimited"]); !result.Installed {
		t.Fatal("newer authorized bundle rejected after revocation")
	}
}

func TestExpiryResistsWallClockRollback(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1000}
	store := openStore(t, dir, clock)
	mustApply(t, store, bundle(t, 1, 1000, expiry(5000)))
	if status, _ := store.Status(testAccount, testDevice); status.RecheckAfter != time.Hour {
		t.Fatal("distant expiry must use a bounded recheck", status.RecheckAfter)
	}
	clock.wall, clock.elapsed = 900, 4100*time.Second
	status, err := store.Status(testAccount, testDevice)
	if err != nil || status.Package != nil || !status.Expired {
		t.Fatal("wall-clock rollback extended a finite entitlement", status, err)
	}
	if _, err := os.Stat(filepath.Join(dir, packageFileName)); !os.IsNotExist(err) {
		t.Fatal("expired credentials kept")
	}
	if _, err := applyEnvelope(store, bundle(t, 1, 1000, expiry(5000))); !errors.Is(err, ErrExpired) {
		t.Fatal("expired package reinstalled", err)
	}
	store.Close()

	other, rollback := t.TempDir(), &testClock{wall: 4900}
	store = openStore(t, other, rollback)
	mustApply(t, store, bundle(t, 1, 4900, expiry(5000)))
	store.Close()
	rollback.wall, rollback.elapsed = 100, 0
	store = openStore(t, other, rollback)
	status, _ = store.Status(testAccount, testDevice)
	if status.Package == nil || status.RecheckAfter != 100*time.Second {
		t.Fatal("authenticated time not retained across restart", status)
	}
	rollback.elapsed = 100 * time.Second
	if status, _ = store.Status(testAccount, testDevice); status.Package != nil {
		t.Fatal("monotonic deadline ignored after restart with rolled-back clock")
	}
	if _, _, err := store.Project(testAccount, testDevice); !errors.Is(err, ErrExpired) {
		t.Fatal("expired package prepared", err)
	}
}

func TestUnlimitedEntitlementNeverArmsAnOverflowingTimer(t *testing.T) {
	clock := &testClock{wall: 1300}
	store := openStore(t, t.TempDir(), clock)
	mustApply(t, store, phpFixtures(t)["unlimited"])
	clock.wall = 1 << 40
	status, err := store.Status(testAccount, testDevice)
	if err != nil || status.Package == nil || status.RecheckAfter != time.Hour {
		t.Fatal("unlimited entitlement expired or armed an unbounded timer", status, err)
	}
}

func TestFailedRefreshesPreserveInstalledPackage(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle2"])
	tampered := []byte(strings.Replace(string(fixtures["bundle1"]), "\"serial\": 1", "\"serial\": 3", 1))
	for name, response := range map[string][]byte{
		"empty":             nil,
		"truncated":         fixtures["bundle2"][:40],
		"unsigned 401":      []byte(`{"error":{"code":"unauthenticated"}}`),
		"unsigned 403":      []byte(`{"error":{"code":"device_unauthorized"}}`),
		"tampered mirror":   tampered,
		"wrong account":     sign(t, signSpec{kind: "revoked", serial: 9, issued: 1300, material: []pair{{"reason", "x"}}, account: "account-2"}),
		"stale in-flight":   fixtures["bundle1"],
		"invalid structure": sign(t, signSpec{kind: "bundle", serial: 9, issued: 1300, material: []pair{{"connection", map[string]any{}}, {"outbounds", []any{}}, {"routing", map[string]any{}}}}),
	} {
		if _, err := applyEnvelope(store, response); err == nil {
			t.Fatal("failed refresh accepted:", name)
		}
		if installedSerial(t, store) != 2 {
			t.Fatal("failed refresh removed the valid package:", name)
		}
	}
	store.Close()
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 2 {
		t.Fatal("failed refreshes changed durable state")
	}
	if _, err := applyEnvelope(store, sign(t, signSpec{kind: "bundle", serial: 3, issued: 1300, material: v2Material(t)})); err != nil {
		t.Fatal("rejected structure advanced the floor", err)
	}
}

func TestSignedStateNeverInstallsAndTracksFreshness(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	result, err := applyEnvelope(store, fixtures["state2"])
	if err != nil || result.Installed || !result.NeedsRefresh {
		t.Fatal("state without an installed bundle must ask for the bundle", result, err)
	}
	if status, _ := store.Status(testAccount, testDevice); status.HasFloor {
		t.Fatal("state package created a payload floor")
	}
	two := mustApply(t, store, fixtures["bundle2"]).Package
	if result := mustApply(t, store, fixtures["state2"]); result.NeedsRefresh || !result.Installed {
		t.Fatal("current state requested a refresh", result)
	}
	if result := mustApply(t, store, state(t, 2, 1300, expiry(200000), two.BundleID, true)); !result.NeedsRefresh {
		t.Fatal("needs_refresh ignored")
	}
	if result := mustApply(t, store, state(t, 5, 1300, expiry(200000), two.BundleID, false)); !result.NeedsRefresh {
		t.Fatal("newer server serial ignored")
	}
	if _, err := applyEnvelope(store, state(t, 1, 1400, expiry(200000), two.BundleID, false)); !errors.Is(err, ErrReplay) {
		t.Fatal("stale state accepted", err)
	}
	clock.wall = 2600
	if result := mustApply(t, store, state(t, 2, 2400, expiry(2500), two.BundleID, true)); !result.Expired {
		t.Fatal("authenticated absolute expiry ignored", result)
	}
	if installedSerial(t, store) != 0 {
		t.Fatal("expired package still installed")
	}
	if _, err := applyEnvelope(store, fixtures["bundle2"]); !errors.Is(err, ErrExpired) {
		t.Fatal("expired bytes reinstalled", err)
	}
}

func TestCorruptStoreFailsClosed(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1001}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle1"])
	store.Close()

	packagePath := filepath.Join(dir, packageFileName)
	content, _ := os.ReadFile(packagePath)
	if err := os.WriteFile(packagePath, []byte(strings.Replace(string(content), `"format":1`, `"format":1,"format":1`, 1)), 0600); err != nil {
		t.Fatal(err)
	}
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 0 {
		t.Fatal("corrupt package installed")
	}
	if _, err := applyEnvelope(store, bundle(t, 1, 1001, expiry(9000))); !errors.Is(err, ErrReplay) {
		t.Fatal("floor lost with the corrupt package", err)
	}
	store.Close()

	floorPath := filepath.Join(dir, floorFileName)
	floor, _ := os.ReadFile(floorPath)
	for _, corrupt := range [][]byte{[]byte("{"), append(floor, ' '),
		[]byte(strings.Replace(string(floor), `"format":1`, `"format":1,"format":1`, 1)),
		[]byte(strings.Replace(string(floor), `"serial":1`, `"serial":-1`, 1))} {
		if err := os.WriteFile(floorPath, corrupt, 0600); err != nil {
			t.Fatal(err)
		}
		broken, err := OpenSubscriptionStore(dir, testTrust(t), clock.options())
		if !errors.Is(err, ErrStoreCorrupt) {
			t.Fatal("corrupt floor opened", string(corrupt), err)
		}
		if _, err := applyEnvelope(broken, fixtures["bundle1"]); !errors.Is(err, ErrStoreCorrupt) || broken.AllowsUnsigned(testAccount) {
			t.Fatal("corrupt store accepted material")
		}
		broken.Close()
	}
	broken, _ := OpenSubscriptionStore(dir, testTrust(t), clock.options())
	defer broken.Close()
	if err := broken.ResetCorrupt(); err != nil {
		t.Fatal(err)
	}
	if mustApply(t, broken, fixtures["bundle1"]); installedSerial(t, broken) != 1 {
		t.Fatal("explicit reset did not recover")
	}
	if matches, _ := filepath.Glob(floorPath + ".corrupt-*"); len(matches) != 1 {
		t.Fatal("corrupt floor not quarantined", matches)
	}
}

func TestCrashBetweenFloorAndPackageNeverInstallsStalePackage(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1001}
	store := openStore(t, dir, clock)
	mustApply(t, store, phpFixtures(t)["bundle1"])
	store.Close()
	advanced, _ := json.Marshal(storeState{Format: storeFormat, AuthenticatedTime: 1100, Floors: []ReplayFloor{{
		AccountID: testAccount, DeviceID: testDevice, Serial: 2, Digest: strings.Repeat("a", 64)}}})
	if err := os.WriteFile(filepath.Join(dir, floorFileName), advanced, 0600); err != nil {
		t.Fatal(err)
	}
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 0 {
		t.Fatal("package below the floor installed")
	}
	if _, err := os.Stat(filepath.Join(dir, packageFileName)); !os.IsNotExist(err) {
		t.Fatal("stale package not removed")
	}
}

func TestStoreOwnershipPathAndSignOut(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1001}
	store := openStore(t, dir, clock)
	if _, err := OpenSubscriptionStore(dir, testTrust(t), clock.options()); !errors.Is(err, ErrStoreBusy) {
		t.Fatal("second owner opened the same store", err)
	}
	for _, path := range []string{"relative", dir + "/../" + filepath.Base(dir)} {
		if _, err := OpenSubscriptionStore(path, testTrust(t), clock.options()); !errors.Is(err, ErrStorePath) {
			t.Fatal("unsafe path accepted", path)
		}
	}
	if _, err := OpenSubscriptionStore(filepath.Join(t.TempDir(), "x"), nil, clock.options()); err == nil {
		t.Fatal("store opened without trust")
	}
	mustApply(t, store, phpFixtures(t)["bundle1"])
	if err := store.SignOut(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, packageFileName)); !os.IsNotExist(err) {
		t.Fatal("sign-out kept credentials")
	}
	status, _ := store.Status(testAccount, testDevice)
	if status.Package != nil || !status.HasFloor {
		t.Fatal("sign-out removed the floor or kept the package")
	}
	if _, err := applyEnvelope(store, bundle(t, 1, 1001, expiry(9000))); !errors.Is(err, ErrReplay) {
		t.Fatal("floor did not survive sign-out", err)
	}
}

func applyEnvelope(store *SubscriptionStore, envelope []byte) (ApplyResult, error) {
	return store.Apply(testAccount, testDevice, envelope, nil)
}

func TestUnsignedMaterialRefusedOnceSignedFloorExists(t *testing.T) {
	store := openStore(t, t.TempDir(), &testClock{wall: 1001})
	if !store.AllowsUnsigned(testAccount) {
		t.Fatal("legacy path refused without a signed floor")
	}
	if _, _, err := store.Project(testAccount, testDevice); !errors.Is(err, ErrSignedRequired) {
		t.Fatal("projection invented a package", err)
	}
	mustApply(t, store, phpFixtures(t)["bundle1"])
	if store.AllowsUnsigned(testAccount) {
		t.Fatal("unsigned material may overwrite a signed floor")
	}
	if !store.AllowsUnsigned("account-2") {
		t.Fatal("another account lost its legacy path")
	}
}

func TestRuntimeValidationFailureRetainsPreviousPackage(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle1"])
	rejected := errors.New("runtime rejected configuration")
	if _, err := store.Apply(testAccount, testDevice, fixtures["bundle2"], func(*Prepared) error { return rejected }); !errors.Is(err, rejected) {
		t.Fatal("runtime validation ignored", err)
	}
	if installedSerial(t, store) != 1 {
		t.Fatal("rejected material replaced the working package")
	}
	validated := false
	if _, err := store.Apply(testAccount, testDevice, fixtures["bundle2"], func(prepared *Prepared) error {
		validated = len(prepared.Document) > 0
		return nil
	}); err != nil || !validated || installedSerial(t, store) != 2 {
		t.Fatal("validated material not committed", err)
	}
}

func TestProjectionUsesWallBaseWithRollbackSafeLifetime(t *testing.T) {
	clock := &testClock{wall: 4900}
	store := openStore(t, t.TempDir(), clock)
	mustApply(t, store, bundle(t, 1, 4900, expiry(5000)))
	clock.wall = 100
	body, _, err := store.Project(testAccount, testDevice)
	if err != nil {
		t.Fatal(err)
	}
	var projected struct {
		Data struct {
			Issued  int64 `json:"issued_at"`
			Expires int64 `json:"expires_at"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &projected); err != nil || projected.Data.Issued != 100 || projected.Data.Expires != 200 {
		t.Fatal("rolled-back wall clock extended the projected lease", projected.Data)
	}
	if prepared, code := Prepare(body, testAccount, "{}", time.Unix(100, 0)); code != "" || prepared.Bundle.Expires != 200 {
		t.Fatal("projection is not a valid v1 lease", code)
	}
}

func TestStoreLockExcludesAnotherProcess(t *testing.T) {
	if dir := os.Getenv("ZN_STORE_LOCK_DIR"); dir != "" {
		store, err := OpenSubscriptionStore(dir, testTrust(t), StoreOptions{})
		if err != nil {
			t.Fatal(err)
		}
		defer store.Close()
		_, _ = os.Stdout.WriteString("locked\n")
		_, _ = io.ReadAll(os.Stdin)
		return
	}
	dir := t.TempDir()
	helper := exec.Command(os.Args[0], "-test.run=^TestStoreLockExcludesAnotherProcess$")
	helper.Env = append(os.Environ(), "ZN_STORE_LOCK_DIR="+dir)
	stdin, _ := helper.StdinPipe()
	stdout, _ := helper.StdoutPipe()
	if err := helper.Start(); err != nil {
		t.Fatal(err)
	}
	line, err := bufio.NewReader(stdout).ReadString('\n')
	if err != nil || line != "locked\n" {
		t.Fatal("helper did not take the lock", line, err)
	}
	if _, err := OpenSubscriptionStore(dir, testTrust(t), StoreOptions{}); !errors.Is(err, ErrStoreBusy) {
		t.Fatal("second process opened a locked store", err)
	}
	_ = stdin.Close()
	if err := helper.Wait(); err != nil {
		t.Fatal(err)
	}
	store := openStore(t, dir, &testClock{wall: 1001})
	mustApply(t, store, phpFixtures(t)["bundle1"])
}

func failWrites(t *testing.T, name string) {
	t.Helper()
	t.Cleanup(func() { storeWrite = writeAtomic })
	storeWrite = func(dir, file string, content []byte) error {
		if file == name {
			return errors.New("injected write failure")
		}
		return writeAtomic(dir, file, content)
	}
}

func TestFailedPackageWriteKeepsPreviousPackageAcrossReopen(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle1"])
	failWrites(t, packageFileName)
	if _, err := applyEnvelope(store, fixtures["bundle2"]); err == nil {
		t.Fatal("failed package write reported success")
	}
	if installedSerial(t, store) != 1 {
		t.Fatal("failed update dropped the working package in memory")
	}
	store.Close()
	storeWrite = writeAtomic
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 1 {
		t.Fatal("failed update stranded the working package below its floor")
	}
	if result := mustApply(t, store, fixtures["bundle2"]); !result.Installed {
		t.Fatal("update not retryable after a failed write")
	}
}

func TestFailedFloorWriteNeverReadmitsAnOlderSerial(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	fixtures := phpFixtures(t)
	store := openStore(t, dir, clock)
	mustApply(t, store, fixtures["bundle1"])
	failWrites(t, floorFileName)
	if _, err := applyEnvelope(store, fixtures["bundle2"]); err == nil {
		t.Fatal("failed floor write reported success")
	}
	older := bundle(t, 1, 1100, expiry(100000))
	if _, err := applyEnvelope(store, older); !errors.Is(err, ErrReplay) {
		t.Fatal("older serial admitted while the floor write was pending", err)
	}
	store.Close()
	storeWrite = writeAtomic
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 2 {
		t.Fatal("verified newer package was not adopted on reopen")
	}
	if _, err := applyEnvelope(store, fixtures["bundle1"]); !errors.Is(err, ErrReplay) {
		t.Fatal("reopen did not raise the floor to the adopted package", err)
	}
	store.Close()
	content, _ := os.ReadFile(filepath.Join(dir, floorFileName))
	if !strings.Contains(string(content), "\"serial\":2") || strings.Contains(string(content), "CREDENTIAL") {
		t.Fatal("healed floor missing or carries credentials", string(content))
	}
}

func TestFirstInstallSurvivesAMissingFloorWrite(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	failWrites(t, floorFileName)
	store := openStore(t, dir, clock)
	_, _ = applyEnvelope(store, phpFixtures(t)["bundle1"])
	store.Close()
	storeWrite = writeAtomic
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 1 || store.AllowsUnsigned(testAccount) {
		t.Fatal("first verified package lost or left the unsigned path open")
	}
}

func TestPendingFloorKeepsAuthenticatedDeadlineAfterClockRollback(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1000}
	failWrites(t, floorFileName)
	store := openStore(t, dir, clock)
	if _, err := applyEnvelope(store, bundle(t, 1, 4900, expiry(5000))); err == nil {
		t.Fatal("floor failure was not injected")
	}
	if status, err := store.Status(testAccount, testDevice); err != nil || status.Package == nil || status.RecheckAfter != 100*time.Second {
		t.Fatal("pending floor lost authenticated time", status, err)
	}
	store.Close()
	clock.wall, clock.elapsed = 900, 0
	store = openStore(t, dir, clock)
	if status, err := store.Status(testAccount, testDevice); err != nil || status.Package == nil || status.RecheckAfter != 100*time.Second {
		t.Fatal("reopen lost the verified package clock", status, err)
	}
	storeWrite = writeAtomic
	clock.elapsed = 100 * time.Second
	if status, err := store.Status(testAccount, testDevice); err != nil || !status.Expired || status.Package != nil {
		t.Fatal("rollback extended a partially committed package", status, err)
	}
}

func TestPartialFirstInstallCannotLoseReplayFloorOnSignOut(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	failWrites(t, floorFileName)
	store := openStore(t, dir, clock)
	fixtures := phpFixtures(t)
	if _, err := applyEnvelope(store, fixtures["bundle2"]); err == nil {
		t.Fatal("floor failure was not injected")
	}
	if store.AllowsUnsigned(testAccount) || store.SignOut() == nil {
		t.Fatal("pending signed floor allowed downgrade or unsafe removal")
	}
	store.Close()

	storeWrite = writeAtomic
	store = openStore(t, dir, clock)
	if installedSerial(t, store) != 2 {
		t.Fatal("partial install was lost")
	}
	if err := store.SignOut(); err != nil {
		t.Fatal(err)
	}
	store.Close()

	store = openStore(t, dir, clock)
	if _, err := applyEnvelope(store, fixtures["bundle1"]); !errors.Is(err, ErrReplay) {
		t.Fatal("sign-out lost the recovered replay floor", err)
	}
}

func TestExpiredPackageUnlinkFailureRetriedAfterReopen(t *testing.T) {
	dir, clock := t.TempDir(), &testClock{wall: 1200}
	store := openStore(t, dir, clock)
	fixtures := phpFixtures(t)
	mustApply(t, store, fixtures["bundle1"])
	clock.wall = 100001
	storeRemove = func(string) error { return os.ErrPermission }
	t.Cleanup(func() { storeRemove = os.Remove })
	if status, err := store.Status(testAccount, testDevice); !status.Expired || !errors.Is(err, os.ErrPermission) {
		t.Fatal("failed unlink concealed authoritative expiry", status, err)
	}
	store.Close()
	store = openStore(t, dir, clock)
	if status, err := store.Status(testAccount, testDevice); !status.Expired || !errors.Is(err, os.ErrPermission) || status.Package != nil {
		t.Fatal("reopen restored expired credentials or hid the failed unlink", status, err)
	}
	store.Close()
	storeRemove = os.Remove
	store = openStore(t, dir, clock)
	if _, err := os.Stat(filepath.Join(dir, packageFileName)); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("successful reopen did not remove the retired package", err)
	}
	if _, err := applyEnvelope(store, fixtures["bundle1"]); !errors.Is(err, ErrExpired) {
		t.Fatal("expired package resurrected after cleanup", err)
	}
}

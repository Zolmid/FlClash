package clientbundle

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const (
	floorFileName   = "subscription-v2-floor.json"
	packageFileName = "subscription-v2-package.json"
	storeFormat     = 1
	lockFileName    = "subscription-v2.lock"
	maxRecheck      = time.Hour
	lockWait        = 3 * time.Second
)

var (
	processStart = time.Now()
	storeWrite   = writeAtomic
	storeRemove  = os.Remove
)

var openStores = struct {
	sync.Mutex
	dirs map[string]bool
}{dirs: map[string]bool{}}

// WithNoSignedState keeps the store lock through a legacy commit when trust is unavailable.
func WithNoSignedState(dir string, run func() error) error {
	if !filepath.IsAbs(dir) || filepath.Clean(dir) != dir {
		return ErrStorePath
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	info, err := os.Lstat(dir)
	if err != nil || !info.IsDir() {
		return ErrStorePath
	}
	unlock, err := lockStore(dir)
	if err != nil {
		return err
	}
	defer unlock()
	for _, name := range []string{floorFileName, packageFileName} {
		if _, err := os.Lstat(filepath.Join(dir, name)); err == nil {
			return ErrSignedRequired
		} else if !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	return run()
}

// StoreOptions.Floor lets a caller that reopens the store per operation keep
// its own process-wide monotonic lower bound on the effective time.
type StoreOptions struct {
	Now     func() time.Time
	Elapsed func() time.Duration
	Floor   func() int64
}

// SubscriptionStore is the single owner of one installation's signed v2 state.
// Floors hold no credentials and outlive the package. A newer package is
// written before its floor and a verified package above the floor is adopted
// on open, so a failed write never strands the last working package; removals
// write the floor first.
type SubscriptionStore struct {
	mu            sync.Mutex
	dir           string
	trust         *Trust
	now           func() time.Time
	elapsed       func() time.Duration
	floor         func() int64
	anchorWall    int64
	anchorElapsed time.Duration
	state         storeState
	installed     *SignedPackage
	corrupt       bool
	cleanupErr    error
	closed        bool
	unlock        func()
}

// SessionIntent is stored under the same interprocess lock as subscriptions.
func (s *SubscriptionStore) SessionIntent() (uint64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.sessionIntentLocked()
}

func (s *SubscriptionStore) sessionIntentLocked() (uint64, error) {
	if err := s.usableLocked(); err != nil {
		return 0, err
	}
	content, err := readRegular(s.dir, "subscription-v2-session.json")
	if errors.Is(err, os.ErrNotExist) {
		return 0, nil
	}
	var state struct {
		Intent *uint64 `json:"intent"`
	}
	if err != nil || !strictDocument(content) || json.Unmarshal(content, &state) != nil || state.Intent == nil || *state.Intent > maxSafeInteger {
		return 0, ErrStoreCorrupt
	}
	return *state.Intent, nil
}

func (s *SubscriptionStore) AdvanceSessionIntent() (uint64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	intent, err := s.sessionIntentLocked()
	if err != nil || intent == maxSafeInteger {
		return 0, ErrStoreCorrupt
	}
	intent++
	content, err := json.Marshal(struct {
		Intent uint64 `json:"intent"`
	}{intent})
	if err == nil {
		err = writeAtomic(s.dir, "subscription-v2-session.json", content)
	}
	return intent, err
}

type storeState struct {
	Format            int           `json:"format"`
	AuthenticatedTime int64         `json:"authenticated_time"`
	Floors            []ReplayFloor `json:"floors"`
}

type storedPackage struct {
	Format    int    `json:"format"`
	AccountID string `json:"account_id"`
	DeviceID  string `json:"device_id"`
	Envelope  string `json:"envelope"`
}

type ApplyResult struct {
	Package      *SignedPackage
	Installed    bool
	Changed      bool
	NeedsRefresh bool
	Revoked      bool
	Expired      bool
}

type SubscriptionStatus struct {
	Package      *SignedPackage
	HasFloor     bool
	Revoked      bool
	Expired      bool
	RecheckAfter time.Duration
}

// OpenSubscriptionStore needs an absolute, clean, app-owned dir. A corrupt
// floor yields a fail-closed store together with ErrStoreCorrupt.
func OpenSubscriptionStore(dir string, trust *Trust, options StoreOptions) (*SubscriptionStore, error) {
	if !filepath.IsAbs(dir) || filepath.Clean(dir) != dir {
		return nil, ErrStorePath
	}
	if trust == nil {
		return nil, ErrInvalidTrust
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	if info, err := os.Lstat(dir); err != nil || !info.IsDir() {
		return nil, ErrStorePath
	}
	openStores.Lock()
	if openStores.dirs[dir] {
		openStores.Unlock()
		return nil, ErrStoreBusy
	}
	openStores.dirs[dir] = true
	openStores.Unlock()
	unlock, err := lockStore(dir)
	if err != nil {
		openStores.Lock()
		delete(openStores.dirs, dir)
		openStores.Unlock()
		return nil, err
	}
	s := &SubscriptionStore{dir: dir, trust: trust, now: options.Now, elapsed: options.Elapsed, unlock: unlock, floor: options.Floor}
	if s.now == nil {
		s.now = time.Now
	}
	if s.elapsed == nil {
		s.elapsed = func() time.Duration { return time.Since(processStart) }
	}
	s.state = storeState{Format: storeFormat, Floors: []ReplayFloor{}}
	err = s.loadLocked()
	s.anchorWall = max(s.now().Unix(), s.state.AuthenticatedTime)
	if s.installed != nil {
		s.anchorWall = max(s.anchorWall, s.installed.IssuedAt)
	}
	s.anchorElapsed = s.elapsed()
	return s, err
}

func (s *SubscriptionStore) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return
	}
	s.closed, s.installed = true, nil
	s.unlock()
	openStores.Lock()
	delete(openStores.dirs, s.dir)
	openStores.Unlock()
}

func (s *SubscriptionStore) loadLocked() error {
	content, err := readRegular(s.dir, floorFileName)
	if err != nil && !errors.Is(err, os.ErrNotExist) || err == nil && !s.parseStateLocked(content) {
		s.corrupt = true
		return ErrStoreCorrupt
	}
	content, err = readRegular(s.dir, packageFileName)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	var stored storedPackage
	if err != nil || !strictDocument(content) || json.Unmarshal(content, &stored) != nil || stored.Format != storeFormat {
		s.removePackageLocked()
		return nil
	}
	pkg, err := VerifyEnvelope(s.trust, []byte(stored.Envelope), stored.AccountID, stored.DeviceID)
	floor, _ := s.floorLocked(stored.AccountID, stored.DeviceID)
	current := err == nil && pkg.IsBundle() && floor.Serial == pkg.Serial && floor.Digest == pkg.Digest &&
		!floor.Revoked && !floor.Expired
	if !current && (err != nil || !pkg.IsBundle() || pkg.Serial <= floor.Serial) {
		s.removePackageLocked()
		return nil
	}
	s.installed = pkg
	if !current {
		next := ReplayFloor{AccountID: pkg.AccountID, DeviceID: pkg.DeviceID, Serial: pkg.Serial, Digest: pkg.Digest}
		_ = s.commitStateLocked(s.withFloor(next, pkg.IssuedAt))
	}
	return nil
}

func (s *SubscriptionStore) parseStateLocked(content []byte) bool {
	if !strictDocument(content) {
		return false
	}
	dec := json.NewDecoder(bytes.NewReader(content))
	dec.DisallowUnknownFields()
	var state storeState
	if dec.Decode(&state) != nil || state.Format != storeFormat || state.AuthenticatedTime < 0 ||
		state.AuthenticatedTime > maxSafeInteger || state.Floors == nil {
		return false
	}
	seen := map[[2]string]bool{}
	for _, floor := range state.Floors {
		key := [2]string{floor.AccountID, floor.DeviceID}
		if seen[key] || !SafeText(floor.AccountID) || !devicePattern.MatchString(floor.DeviceID) ||
			floor.Serial < 1 || floor.Serial > maxSafeInteger || !digestPattern.MatchString(floor.Digest) ||
			(floor.Revoked && floor.Expired) {
			return false
		}
		seen[key] = true
	}
	s.state = state
	return true
}

// ResetCorrupt quarantines unreadable state and starts empty. It forfeits the
// replay floor, so only an explicit owner decision may call it.
func (s *SubscriptionStore) ResetCorrupt() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return ErrStoreClosed
	}
	if !s.corrupt {
		return nil
	}
	suffix := ".corrupt-" + time.Now().UTC().Format("20060102T150405.000000000")
	for _, name := range []string{floorFileName, packageFileName} {
		path := filepath.Join(s.dir, name)
		if _, err := os.Lstat(path); err == nil {
			if err = os.Rename(path, path+suffix); err != nil {
				return err
			}
		}
	}
	s.state, s.installed, s.corrupt = storeState{Format: storeFormat, Floors: []ReplayFloor{}}, nil, false
	return nil
}

func (s *SubscriptionStore) usableLocked() error {
	switch {
	case s.closed:
		return ErrStoreClosed
	case s.corrupt:
		return ErrStoreCorrupt
	}
	return nil
}

// Never behind the highest authenticated time or this process's monotonic
// clock, so moving the wall clock back cannot extend a finite entitlement.
func (s *SubscriptionStore) effectiveNowLocked() int64 {
	monotonic := s.anchorWall + int64((s.elapsed()-s.anchorElapsed)/time.Second)
	if s.floor != nil {
		monotonic = max(monotonic, s.floor())
	}
	return max(s.now().Unix(), monotonic, s.state.AuthenticatedTime)
}

func (s *SubscriptionStore) floorLocked(account, device string) (ReplayFloor, int) {
	for index, floor := range s.state.Floors {
		if floor.AccountID == account && floor.DeviceID == device {
			return floor, index
		}
	}
	return ReplayFloor{AccountID: account, DeviceID: device}, -1
}

// effectiveFloorLocked also counts an installed package whose floor write
// has not landed yet, so a partial commit never readmits an older serial.
func (s *SubscriptionStore) effectiveFloorLocked(account, device string) ReplayFloor {
	floor, _ := s.floorLocked(account, device)
	if s.installedFor(account, device) && s.installed.Serial > floor.Serial {
		return ReplayFloor{AccountID: account, DeviceID: device, Serial: s.installed.Serial, Digest: s.installed.Digest}
	}
	return floor
}

func (s *SubscriptionStore) withFloor(next ReplayFloor, authenticated int64) storeState {
	state := storeState{Format: storeFormat, AuthenticatedTime: max(s.state.AuthenticatedTime, authenticated)}
	state.Floors = make([]ReplayFloor, 0, len(s.state.Floors)+1)
	replaced := false
	for _, floor := range s.state.Floors {
		if floor.AccountID == next.AccountID && floor.DeviceID == next.DeviceID {
			floor, replaced = next, true
		}
		state.Floors = append(state.Floors, floor)
	}
	if !replaced && next.Serial > 0 {
		state.Floors = append(state.Floors, next)
	}
	return state
}

func (s *SubscriptionStore) commitStateLocked(state storeState) error {
	content, err := json.Marshal(state)
	if err == nil {
		err = storeWrite(s.dir, floorFileName, content)
	}
	if err == nil {
		s.state = state
	}
	return err
}

func (s *SubscriptionStore) installLocked(pkg *SignedPackage) error {
	content, err := json.Marshal(storedPackage{Format: storeFormat, AccountID: pkg.AccountID,
		DeviceID: pkg.DeviceID, Envelope: string(pkg.envelope)})
	if err == nil {
		err = storeWrite(s.dir, packageFileName, content)
	}
	if err == nil {
		s.installed = pkg
	}
	return err
}

func (s *SubscriptionStore) removePackageLocked() {
	s.installed = nil
	err := storeRemove(filepath.Join(s.dir, packageFileName))
	s.cleanupErr = nil
	if err == nil {
		syncDir(s.dir)
	} else if !errors.Is(err, os.ErrNotExist) {
		s.cleanupErr = err
	}
}

func (s *SubscriptionStore) installedFor(account, device string) bool {
	return s.installed != nil && s.installed.AccountID == account && s.installed.DeviceID == device
}

// Apply records one signed envelope. A package already persisted when its
// floor write fails is recovered on open. Validation precedes either write.
func (s *SubscriptionStore) Apply(account, device string, envelope []byte, validate func(*Prepared) error) (ApplyResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.usableLocked(); err != nil {
		return ApplyResult{}, err
	}
	pkg, err := VerifyEnvelope(s.trust, envelope, account, device)
	if err != nil {
		return ApplyResult{}, err
	}
	now := max(s.effectiveNowLocked(), pkg.IssuedAt)
	s.anchorWall, s.anchorElapsed = now, s.elapsed()
	floor := s.effectiveFloorLocked(account, device)
	same := floor.Serial == pkg.Serial && floor.Digest == pkg.Digest
	switch pkg.Kind {
	case "bundle":
		return s.applyBundleLocked(pkg, floor, same, now, validate)
	case "revoked":
		return s.applyRevokedLocked(pkg, floor, same)
	default:
		return s.applyStateLocked(pkg, floor, now)
	}
}

func (s *SubscriptionStore) applyRevokedLocked(pkg *SignedPackage, floor ReplayFloor, same bool) (ApplyResult, error) {
	if same && !floor.Revoked {
		return ApplyResult{}, ErrReplay
	}
	if !same {
		if err := floor.Accept(pkg.Serial, pkg.Digest, true); err != nil {
			return ApplyResult{}, err
		}
		next := ReplayFloor{AccountID: pkg.AccountID, DeviceID: pkg.DeviceID, Serial: pkg.Serial, Digest: pkg.Digest, Revoked: true}
		if err := s.commitStateLocked(s.withFloor(next, pkg.IssuedAt)); err != nil {
			return ApplyResult{}, err
		}
	}
	if s.installedFor(pkg.AccountID, pkg.DeviceID) {
		s.removePackageLocked()
	}
	return ApplyResult{Package: pkg, Changed: !same, Revoked: true}, nil
}

func (s *SubscriptionStore) applyBundleLocked(pkg *SignedPackage, floor ReplayFloor, same bool, now int64, validate func(*Prepared) error) (ApplyResult, error) {
	if same {
		switch {
		case floor.Revoked:
			return ApplyResult{}, ErrTombstone
		case floor.Expired || pkg.expiredAt(now):
			return ApplyResult{}, ErrExpired
		}
	} else if err := floor.Accept(pkg.Serial, pkg.Digest, false); err != nil {
		return ApplyResult{}, err
	}
	next := ReplayFloor{AccountID: pkg.AccountID, DeviceID: pkg.DeviceID, Serial: pkg.Serial, Digest: pkg.Digest}
	if pkg.expiredAt(now) {
		next.Expired = true
		if err := s.commitStateLocked(s.withFloor(next, pkg.IssuedAt)); err != nil {
			return ApplyResult{}, err
		}
		if s.installedFor(pkg.AccountID, pkg.DeviceID) {
			s.removePackageLocked()
		}
		return ApplyResult{Package: pkg, Changed: true, Expired: true}, nil
	}
	prepared, code := prepareProjection(pkg, "", now, s.now())
	if code != "" {
		return ApplyResult{}, SubscriptionError(code)
	}
	if validate != nil {
		if err := validate(prepared); err != nil {
			return ApplyResult{}, err
		}
	}
	if same && s.installedFor(pkg.AccountID, pkg.DeviceID) && s.installed.Digest == pkg.Digest {
		return ApplyResult{Package: pkg, Installed: true}, nil
	}
	if s.installed != nil && !s.installedFor(pkg.AccountID, pkg.DeviceID) {
		if err := s.persistInstalledFloorLocked(); err != nil {
			return ApplyResult{}, err
		}
	}
	if err := s.installLocked(pkg); err != nil {
		return ApplyResult{}, err
	}
	if err := s.commitStateLocked(s.withFloor(next, pkg.IssuedAt)); err != nil {
		return ApplyResult{}, err
	}
	return ApplyResult{Package: pkg, Installed: true, Changed: true}, nil
}

// A state package reuses the current bundle's serial with fresh bytes, so it
// is checked against the serial only and never moves the digest floor.
func (s *SubscriptionStore) applyStateLocked(pkg *SignedPackage, floor ReplayFloor, now int64) (ApplyResult, error) {
	if pkg.Serial < floor.Serial {
		return ApplyResult{}, ErrReplay
	}
	installed := s.installedFor(pkg.AccountID, pkg.DeviceID)
	result := ApplyResult{Package: pkg, Installed: installed, Revoked: floor.Revoked}
	result.NeedsRefresh = pkg.NeedsRefresh || pkg.Serial > floor.Serial || !installed ||
		s.installed.BundleID != pkg.CurrentBundleID
	next := floor
	if installed && pkg.expiredAt(now) && floor.Serial == s.installed.Serial {
		next.Expired = true
		result.Installed, result.Expired = false, true
	}
	if next == floor && pkg.IssuedAt <= s.state.AuthenticatedTime {
		return result, nil
	}
	if err := s.commitStateLocked(s.withFloor(next, pkg.IssuedAt)); err != nil {
		return ApplyResult{}, err
	}
	if result.Expired {
		s.removePackageLocked()
	}
	result.Changed = true
	return result, nil
}

// Status expires the package once the account subscription ends. RecheckAfter
// is capped so no timer is armed for an unlimited or distant expiry.
func (s *SubscriptionStore) Status(account, device string) (SubscriptionStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.statusLocked(account, device)
}

func (s *SubscriptionStore) statusLocked(account, device string) (SubscriptionStatus, error) {
	if err := s.usableLocked(); err != nil {
		return SubscriptionStatus{}, err
	}
	now := s.effectiveNowLocked()
	floor := s.effectiveFloorLocked(account, device)
	status := SubscriptionStatus{HasFloor: floor.Serial > 0, Revoked: floor.Revoked, Expired: floor.Expired, RecheckAfter: maxRecheck}
	if !s.installedFor(account, device) {
		if status.Revoked || status.Expired {
			return status, s.cleanupErr
		}
		return status, nil
	}
	if s.installed.expiredAt(now) {
		floor.Expired = true
		status.Expired = true
		if err := s.commitStateLocked(s.withFloor(floor, now)); err != nil {
			return status, err
		}
		s.removePackageLocked()
		return status, s.cleanupErr
	}
	status.Package = s.installed
	if s.installed.ExpiresAt != nil {
		status.RecheckAfter = min(maxRecheck, time.Duration(*s.installed.ExpiresAt-now)*time.Second)
	}
	return status, nil
}

// Project returns the installed package as a v1 body with a short lease; it
// needs no network and is repeated to renew that lease.
func (s *SubscriptionStore) Project(account, device string) ([]byte, *SignedPackage, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	status, err := s.statusLocked(account, device)
	if err != nil {
		return nil, nil, err
	}
	switch {
	case status.Package != nil:
	case status.Revoked:
		return nil, nil, ErrTombstone
	case status.Expired:
		return nil, nil, ErrExpired
	default:
		return nil, nil, ErrSignedRequired
	}
	body, code := projectSigned(status.Package, s.effectiveNowLocked(), s.now().Unix())
	if code != "" {
		return nil, nil, SubscriptionError(code)
	}
	return body, status.Package, nil
}

// AllowsUnsigned is false once this installation holds a v2 floor for the
// account, or the floor is unreadable.
func (s *SubscriptionStore) AllowsUnsigned(account string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.usableLocked() != nil {
		return false
	}
	if s.installed != nil && s.installed.AccountID == account {
		return false
	}
	for _, floor := range s.state.Floors {
		if floor.AccountID == account {
			return false
		}
	}
	return true
}

func (s *SubscriptionStore) persistInstalledFloorLocked() error {
	if s.installed == nil {
		return nil
	}
	pkg := s.installed
	floor, _ := s.floorLocked(pkg.AccountID, pkg.DeviceID)
	if floor.Serial >= pkg.Serial {
		return nil
	}
	return s.commitStateLocked(s.withFloor(s.effectiveFloorLocked(pkg.AccountID, pkg.DeviceID), pkg.IssuedAt))
}

// SignOut removes credentials; replay floors survive for this installation.
func (s *SubscriptionStore) SignOut() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return ErrStoreClosed
	}
	if err := s.persistInstalledFloorLocked(); err != nil {
		return err
	}
	s.removePackageLocked()
	if _, err := os.Lstat(filepath.Join(s.dir, packageFileName)); !errors.Is(err, os.ErrNotExist) {
		return errors.New("subscription package removal failed")
	}
	return nil
}

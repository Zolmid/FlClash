package core

import (
	"core/observation"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/constant/features"
	"github.com/metacubex/mihomo/tunnel"
)

var (
	leaseObservationStarted  = time.Now()
	leaseObservationControl  sync.Mutex
	leaseObserver            *routingLeaseObserver
	leaseObservationEvents   []observation.Event
	leaseObservationSequence uint64
	errUnsafeObservationPath = errors.New("unsafe_observation_path")
)

type routingLeaseObserver struct {
	home          string
	root          *os.Root
	directory     os.FileInfo
	name          string
	latest        chan observation.Snapshot
	stop          chan struct{}
	producerDone  chan struct{}
	writerDone    chan struct{}
	writeSequence uint64
	lastFailure   string
}

func leaseObservationRole() (string, string) {
	if runtime.GOOS == "ios" {
		if features.WithLowMemory {
			return "ios", "ios_extension"
		}
		return "ios", "ios_app"
	}
	if features.Android {
		return "android", "android_service"
	}
	return runtime.GOOS, "desktop"
}

func leaseObservationTag(domain, value string) string {
	sum := sha256.Sum256([]byte("zolnit.routing_observation.v1\x00" + domain + "\x00" + routingLeaseInstanceID + "\x00" + value))
	return hex.EncodeToString(sum[:])
}

func leaseObservationStateLocked() observation.State {
	state := observation.State{InstanceTag: leaseObservationTag("instance", routingLeaseInstanceID), ConfigurationGeneration: routingConfigurationGeneration, Groups: []observation.Group{}}
	lease := activeRoutingLease
	if lease == nil {
		return state
	}
	state.LeasePresent, state.Revoked = true, lease.revoked
	now := routingLeaseNow()
	remaining := lease.deadline.Sub(now)
	wallRemaining := time.UnixMilli(lease.expiresAt).Sub(now)
	if wallRemaining < remaining {
		remaining = wallRemaining
	}
	state.DeadlineElapsed = remaining <= 0
	if remaining > 0 {
		state.RemainingMS = remaining.Milliseconds()
	}
	proxies := tunnel.AllProxies()
	for i, svc := range lease.serviceOrder {
		if i >= observation.MaxGroups {
			break
		}
		g := observation.Group{Index: i, Mode: "other", Automatic: "missing"}
		if svc == nil {
			state.Groups = append(state.Groups, g)
			continue
		}
		if svc.policySelector != nil && proxies[svc.groupName] == svc.policyProxy {
			switch svc.policySelector.Now() {
			case svc.automaticGroup:
				g.Mode = "auto"
			case svc.manualGroup:
				g.Mode = "manual"
			case directProxyName:
				g.Mode = "direct"
			}
		}
		if svc.automaticSelector != nil && proxies[svc.automaticGroup] == svc.automaticProxy {
			if svc.automaticSelector.Now() == rejectProxyName {
				g.Automatic = "reject"
			} else {
				g.Automatic = "proxy"
			}
		}
		if svc.manualProxy != nil && proxies[svc.manualGroup] == svc.manualProxy {
			if manual, ok := adapterAs[pickableGroup](svc.manualProxy); ok {
				g.ManualTag = leaseObservationTag("manual_choice", manual.Now())
			}
		}
		state.Groups = append(state.Groups, g)
	}
	return state
}

func leaseObservationSnapshotLocked() observation.Snapshot {
	platform, role := leaseObservationRole()
	version := C.Version
	if version == "" {
		version = "unknown"
	}
	producer := "stopped"
	if leaseObserver != nil {
		producer = "running"
	}
	return observation.Snapshot{SchemaVersion: 1, Kind: observation.Kind, CoreVersion: version, ProducerPID: os.Getpid(), Platform: platform, Role: role, SampledAtUnixMS: time.Now().UnixMilli(), UptimeMS: time.Since(leaseObservationStarted).Milliseconds(), ProducerState: producer, State: leaseObservationStateLocked(), Events: append([]observation.Event{}, leaseObservationEvents...)}
}

func handleGetRoutingLeaseObservation() observation.Snapshot {
	selectMu.Lock()
	defer selectMu.Unlock()
	return leaseObservationSnapshotLocked()
}

func queueLeaseObservationLocked() {
	if leaseObserver == nil {
		return
	}
	snapshot := leaseObservationSnapshotLocked()
	select {
	case leaseObserver.latest <- snapshot:
	default:
		select {
		case <-leaseObserver.latest:
		default:
		}
		select {
		case leaseObserver.latest <- snapshot:
		default:
		}
	}
}

func recordLeaseObservationLocked(kind, reason string) {
	if leaseObserver == nil {
		return
	}
	leaseObservationSequence++
	event := observation.Event{Sequence: leaseObservationSequence, AtUnixMS: time.Now().UnixMilli(), UptimeMS: time.Since(leaseObservationStarted).Milliseconds(), Kind: kind, Reason: reason, State: leaseObservationStateLocked()}
	if len(leaseObservationEvents) == observation.MaxEvents {
		leaseObservationEvents = leaseObservationEvents[1:]
	}
	leaseObservationEvents = append(leaseObservationEvents, event)
	queueLeaseObservationLocked()
}

func openObservationDirectory(home string) (*os.Root, error) {
	absolute, err := filepath.Abs(home)
	if err != nil || home == "" {
		return nil, errUnsafeObservationPath
	}
	volume := filepath.VolumeName(absolute)
	root, err := os.OpenRoot(volume + string(os.PathSeparator))
	if err != nil {
		return nil, err
	}
	parts := strings.Split(strings.TrimPrefix(absolute[len(volume):], string(os.PathSeparator)), string(os.PathSeparator))
	parts = append(parts, "diagnostics")
	for i, part := range parts {
		if part == "" {
			continue
		}
		if i == len(parts)-1 {
			if err = root.Mkdir(part, 0700); err != nil && !os.IsExist(err) {
				root.Close()
				return nil, err
			}
		}
		info, e := root.Lstat(part)
		if e != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			root.Close()
			return nil, errUnsafeObservationPath
		}
		next, e := root.OpenRoot(part)
		if e != nil {
			root.Close()
			return nil, e
		}
		opened, e := next.Stat(".")
		root.Close()
		if e != nil || !os.SameFile(info, opened) {
			next.Close()
			return nil, errUnsafeObservationPath
		}
		root = next
	}
	if runtime.GOOS != "windows" {
		if err = root.Chmod(".", 0700); err != nil {
			root.Close()
			return nil, err
		}
		var directory *os.File
		directory, err = root.Open(".")
		if err == nil {
			err = reclaimPrivateFileOwnership(directory)
			_ = directory.Close()
		}
		if err != nil {
			root.Close()
			return nil, err
		}
	}
	return root, nil
}

func observationTargetSafe(root *os.Root, name string) error {
	info, err := root.Lstat(name)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return errUnsafeObservationPath
	}
	return nil
}

func (o *routingLeaseObserver) write(snapshot observation.Snapshot) error {
	if err := snapshot.Validate(); err != nil {
		return err
	}
	data, err := json.Marshal(snapshot)
	if err != nil {
		return err
	}
	if len(data) > observation.MaxBytes {
		return observation.ErrSnapshotTooLarge
	}
	root, err := openObservationDirectory(o.home)
	if err != nil {
		return err
	}
	defer root.Close()
	info, err := root.Stat(".")
	if err != nil || !os.SameFile(info, o.directory) {
		return errUnsafeObservationPath
	}
	if err = observationTargetSafe(root, o.name); err != nil {
		return err
	}
	o.writeSequence++
	temporary := "." + o.name + "." + strconv.Itoa(os.Getpid()) + "." + strconv.FormatUint(o.writeSequence, 10) + ".tmp"
	file, err := root.OpenFile(temporary, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	defer root.Remove(temporary)
	if runtime.GOOS != "windows" {
		err = file.Chmod(0600)
	}
	if err == nil {
		_, err = file.Write(data)
	}
	if err == nil {
		err = file.Sync()
	}
	if err == nil {
		err = reclaimPrivateFileOwnership(file)
	}
	closeErr := file.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if err = observationTargetSafe(root, o.name); err != nil {
		return err
	}
	return root.Rename(temporary, o.name)
}

func (o *routingLeaseObserver) produce() {
	defer close(o.producerDone)
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-o.stop:
			return
		case <-ticker.C:
			selectMu.Lock()
			if leaseObserver == o {
				queueLeaseObservationLocked()
			}
			selectMu.Unlock()
		}
	}
}

func (o *routingLeaseObserver) runWriter() {
	defer close(o.writerDone)
	defer o.root.Close()
	for snapshot := range o.latest {
		if err := o.write(snapshot); err != nil {
			reason := "file_io"
			if errors.Is(err, errUnsafeObservationPath) {
				reason = "unsafe_path"
			}
			if o.lastFailure == reason {
				continue
			}
			o.lastFailure = reason
			selectMu.Lock()
			if leaseObserver == o {
				// A failed write is observable without recursively scheduling another failed write.
				leaseObservationSequence++
				if len(leaseObservationEvents) == observation.MaxEvents {
					leaseObservationEvents = leaseObservationEvents[1:]
				}
				leaseObservationEvents = append(leaseObservationEvents, observation.Event{Sequence: leaseObservationSequence, AtUnixMS: time.Now().UnixMilli(), UptimeMS: time.Since(leaseObservationStarted).Milliseconds(), Kind: "write_rejected", Reason: reason, State: leaseObservationStateLocked()})
			}
			selectMu.Unlock()
		} else {
			o.lastFailure = ""
		}
	}
}

func stopRoutingLeaseObservationLocked() {
	selectMu.Lock()
	o := leaseObserver
	if o != nil {
		snapshot := leaseObservationSnapshotLocked()
		snapshot.ProducerState = "stopped"
		select {
		case <-o.latest:
		default:
		}
		o.latest <- snapshot
		leaseObserver = nil
	}
	selectMu.Unlock()
	if o == nil {
		return
	}
	close(o.stop)
	<-o.producerDone
	close(o.latest)
	<-o.writerDone
}

func stopRoutingLeaseObservation() {
	leaseObservationControl.Lock()
	defer leaseObservationControl.Unlock()
	stopRoutingLeaseObservationLocked()
}

func configureRoutingLeaseObservation(home string, enabled bool) error {
	leaseObservationControl.Lock()
	defer leaseObservationControl.Unlock()
	stopRoutingLeaseObservationLocked()
	if !enabled {
		return nil
	}
	root, err := openObservationDirectory(home)
	if err != nil {
		return err
	}
	_, role := leaseObservationRole()
	name := "lease-observation-" + role + ".json"
	if err = observationTargetSafe(root, name); err != nil {
		root.Close()
		return err
	}
	info, err := root.Stat(".")
	if err != nil {
		root.Close()
		return err
	}
	o := &routingLeaseObserver{home: home, root: root, directory: info, name: name, latest: make(chan observation.Snapshot, 1), stop: make(chan struct{}), producerDone: make(chan struct{}), writerDone: make(chan struct{})}
	selectMu.Lock()
	leaseObserver = o
	queueLeaseObservationLocked()
	selectMu.Unlock()
	safeGo("routingLeaseObservationWriter", o.runWriter)
	safeGo("routingLeaseObservationHeartbeat", o.produce)
	return nil
}

type observedLeaseSelector struct {
	pickableGroup
	kind string
}

func (s observedLeaseSelector) Set(value string) error {
	if err := s.pickableGroup.Set(value); err != nil {
		recordLeaseObservationLocked("write_rejected", "selection")
		return err
	}
	recordLeaseObservationLocked(s.kind, "selection")
	return nil
}

func (s observedLeaseSelector) ForceSet(value string) {
	s.pickableGroup.ForceSet(value)
	recordLeaseObservationLocked(s.kind, "selection")
}

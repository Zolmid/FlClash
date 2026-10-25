package main

import (
	"bytes"
	"core/observation"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func snapshot(now time.Time) observation.Snapshot {
	return observation.Snapshot{SchemaVersion: 1, Kind: observation.Kind, CoreVersion: "v1.19.32", ProducerPID: 42, Platform: "ios", Role: "ios_extension", SampledAtUnixMS: now.UnixMilli(), ProducerState: "running", State: observation.State{InstanceTag: strings.Repeat("a", 64), ConfigurationGeneration: 3, LeasePresent: true, DeadlineElapsed: true, Groups: []observation.Group{{Index: 0, Mode: "auto", Automatic: "proxy"}}}}
}
func TestReaderLeavesSnapshotAndExpiredSelectorUnchanged(t *testing.T) {
	now := time.Now()
	s := snapshot(now)
	raw, _ := json.Marshal(s)
	file := filepath.Join(t.TempDir(), "observation.json")
	if os.WriteFile(file, raw, 0600) != nil {
		t.Fatal("fixture write")
	}
	r := read(options{file: file, role: "ios_extension", maxAgeSeconds: 5}, now)
	after, _ := os.ReadFile(file)
	if !r.OK || r.DeadlineResult != "not_rejected" || !bytes.Equal(raw, after) {
		t.Fatal("reader changed state or fabricated TTL enforcement")
	}
}
func TestHistoricalSnapshotsAreExplicit(t *testing.T) {
	now := time.Now()
	raw, _ := json.Marshal(snapshot(now.Add(-time.Hour)))
	file := filepath.Join(t.TempDir(), "observation.json")
	_ = os.WriteFile(file, raw, 0600)
	opt := options{file: file, maxAgeSeconds: 5}
	if r := read(opt, now); r.OK || r.Code != "observation_stale" {
		t.Fatal("old snapshot claimed fresh")
	}
	opt.historical = true
	if r := read(opt, now); !r.OK || !r.Historical || r.Code != "observation_history" {
		t.Fatal("historical evidence not labelled")
	}
}
func TestWrongRoleAndPrivateInputsFailWithoutEcho(t *testing.T) {
	file := filepath.Join(t.TempDir(), "PRIVATE.json")
	_ = os.WriteFile(file, []byte(`{"account":"PRIVATE","ip":"203.0.113.1"}`), 0600)
	var out bytes.Buffer
	exit := run(options{file: file, pollMS: 250, maxAgeSeconds: 5}, &out)
	if exit == 0 || strings.Contains(out.String(), "PRIVATE") || strings.Contains(out.String(), "203.0.113") {
		t.Fatal("reader leaked private input")
	}
	raw, _ := json.Marshal(snapshot(time.Now()))
	_ = os.WriteFile(file, raw, 0600)
	if r := read(options{file: file, role: "ios_app", maxAgeSeconds: 5}, time.Now()); r.OK || r.Code != "observation_role_mismatch" {
		t.Fatal("wrong process role accepted")
	}
}

package observation

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func fixture() Snapshot {
	return Snapshot{SchemaVersion: 1, Kind: Kind, CoreVersion: "v1.19.32", ProducerPID: 42, Platform: "windows", Role: "desktop", SampledAtUnixMS: 2000, UptimeMS: 100, ProducerState: "running", State: State{InstanceTag: strings.Repeat("a", 64), ConfigurationGeneration: 2, LeasePresent: true, DeadlineElapsed: true, RemainingMS: -1, Groups: []Group{{Index: 0, Mode: "auto", Automatic: "proxy", ManualTag: strings.Repeat("b", 64)}}}}
}
func TestReadDoesNotTurnExpiredStateIntoRejection(t *testing.T) {
	s := fixture()
	raw, _ := json.Marshal(s)
	got, err := Read(bytes.NewReader(raw))
	if err != nil || got.State.Revoked || got.State.Groups[0].Automatic != "proxy" || got.State.DeadlineResult() != "not_rejected" {
		t.Fatal("passive reader mutated or rejected negative-control state")
	}
}
func TestRejectsAmbiguousOversizedOrPrivateData(t *testing.T) {
	s := fixture()
	raw, _ := json.Marshal(s)
	for _, bad := range []string{`{"kind":"private","kind":"duplicate"}`, string(raw) + " {}", strings.Replace(string(raw), `"core_version":`, `"account":"PRIVATE","core_version":`, 1), strings.Repeat("x", MaxBytes+1)} {
		if _, err := Read(strings.NewReader(bad)); err == nil {
			t.Fatal("invalid diagnostic accepted")
		}
	}
}
func TestDeadlineResultRequiresActualRejectSelection(t *testing.T) {
	s := fixture().State
	s.Groups[0].Automatic = "reject"
	if s.DeadlineResult() != "rejected" {
		t.Fatal("rejection missing")
	}
	s.Groups[0].Automatic = "missing"
	if s.DeadlineResult() != "unverified" {
		t.Fatal("missing topology treated as evidence")
	}
	s.LeasePresent = false
	if s.DeadlineResult() != "not_applicable" {
		t.Fatal("absent lease treated as evidence")
	}
}

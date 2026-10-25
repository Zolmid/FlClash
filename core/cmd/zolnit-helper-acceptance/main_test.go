package main

import (
	"core/observation"
	"encoding/json"
	"strings"
	"testing"
)

func TestSuspensionEvidenceFailsClosed(t *testing.T) {
	tag := strings.Repeat("a", 64)
	state := observation.State{InstanceTag: tag, LeasePresent: true, Groups: []observation.Group{{Index: 0, Mode: "auto", Automatic: "proxy", ManualTag: tag}}}
	before := observation.Snapshot{SchemaVersion: 1, Kind: observation.Kind, CoreVersion: "test", ProducerPID: 123, Platform: "windows", Role: "desktop", SampledAtUnixMS: 1000, UptimeMS: 1000, ProducerState: "running", State: state}
	rejected := state
	rejected.Groups = append([]observation.Group(nil), state.Groups...)
	rejected.Groups[0].Automatic = "reject"
	rejected.Revoked = true
	rejected.DeadlineElapsed = true
	cases := []struct {
		name  string
		alter func(*observed)
		pass  bool
	}{
		{"Core watchdog", func(*observed) {}, true},
		{"frontend query expiry", func(r *observed) { r.Snapshot.Events[0].Kind = "query_expired" }, false},
		{"old watchdog before suspension", func(r *observed) { r.Snapshot.Events[0].AtUnixMS = 999 }, false},
		{"different Core process", func(r *observed) { r.Snapshot.ProducerPID++ }, false},
		{"historical export", func(r *observed) { r.Historical = true }, false},
		{"stale observer result", func(r *observed) { r.OK = false }, false},
		{"manual selection changed", func(r *observed) { r.Snapshot.State.Groups[0].ManualTag = strings.Repeat("b", 64) }, false},
		{"no watchdog event", func(r *observed) { r.Snapshot.Events = nil }, false},
		{"wrong instance", func(r *observed) { r.Snapshot.State.InstanceTag = strings.Repeat("b", 64) }, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			current := rejected
			current.Groups = append([]observation.Group(nil), rejected.Groups...)
			eventState := rejected
			eventState.Groups = append([]observation.Group(nil), rejected.Groups...)
			s := before
			s.State = current
			s.Events = []observation.Event{{Sequence: 1, AtUnixMS: 1100, UptimeMS: 1000, Kind: "watchdog", State: eventState}}
			r := observed{OK: true, Snapshot: s}
			tc.alter(&r)
			data, err := json.Marshal(r)
			if err != nil {
				t.Fatal(err)
			}
			err = checkWatchdog(append(data, '\n'), before, 1000)
			if (err == nil) != tc.pass {
				t.Fatalf("evidence acceptance = %v, want %v (%v)", err == nil, tc.pass, err)
			}
		})
	}
	if checkWatchdog(nil, before, 1000) == nil {
		t.Fatal("empty observer output accepted")
	}
}

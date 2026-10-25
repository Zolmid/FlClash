package observation

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"strings"
)

const (
	Kind      = "zolnit_routing_lease_observation"
	MaxBytes  = 32768
	MaxEvents = 8
	MaxGroups = 16
)

var ErrInvalidSnapshot = errors.New("invalid_observation_snapshot")
var ErrSnapshotTooLarge = errors.New("observation_snapshot_too_large")

type Group struct {
	Index     int    `json:"index"`
	Mode      string `json:"mode"`
	Automatic string `json:"automatic"`
	ManualTag string `json:"manual_tag,omitempty"`
}
type State struct {
	InstanceTag             string  `json:"instance_tag"`
	ConfigurationGeneration int     `json:"configuration_generation"`
	LeasePresent            bool    `json:"lease_present"`
	Revoked                 bool    `json:"revoked"`
	DeadlineElapsed         bool    `json:"deadline_elapsed"`
	RemainingMS             int64   `json:"remaining_ms"`
	Groups                  []Group `json:"groups"`
}
type Event struct {
	Sequence uint64 `json:"sequence"`
	AtUnixMS int64  `json:"at_unix_ms"`
	UptimeMS int64  `json:"uptime_ms"`
	Kind     string `json:"kind"`
	Reason   string `json:"reason,omitempty"`
	State    State  `json:"state"`
}
type Snapshot struct {
	SchemaVersion   int     `json:"schema_version"`
	Kind            string  `json:"kind"`
	CoreVersion     string  `json:"core_version"`
	ProducerPID     int     `json:"producer_pid"`
	Platform        string  `json:"platform"`
	Role            string  `json:"role"`
	SampledAtUnixMS int64   `json:"sampled_at_unix_ms"`
	UptimeMS        int64   `json:"uptime_ms"`
	ProducerState   string  `json:"producer_state"`
	State           State   `json:"state"`
	Events          []Event `json:"events"`
}

func tag(value string) bool {
	if len(value) != 64 || strings.ToLower(value) != value {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}
func token(value string, max int) bool {
	if value == "" || len(value) > max {
		return false
	}
	for _, c := range value {
		if !(c >= 'a' && c <= 'z' || c == '_') {
			return false
		}
	}
	return true
}
func stateValid(s State) bool {
	if !tag(s.InstanceTag) || s.ConfigurationGeneration < 0 || len(s.Groups) > MaxGroups {
		return false
	}
	seen := map[int]bool{}
	for _, g := range s.Groups {
		if g.Index < 0 || g.Index >= MaxGroups || seen[g.Index] {
			return false
		}
		seen[g.Index] = true
		if g.Mode != "auto" && g.Mode != "manual" && g.Mode != "direct" && g.Mode != "other" {
			return false
		}
		if g.Automatic != "reject" && g.Automatic != "proxy" && g.Automatic != "missing" {
			return false
		}
		if g.ManualTag != "" && !tag(g.ManualTag) {
			return false
		}
	}
	return true
}
func (s Snapshot) Validate() error {
	if s.SchemaVersion != 1 || s.Kind != Kind || s.ProducerPID <= 0 || s.SampledAtUnixMS < 0 || s.UptimeMS < 0 || len(s.Events) > MaxEvents || !stateValid(s.State) {
		return ErrInvalidSnapshot
	}
	if s.ProducerState != "running" && s.ProducerState != "stopped" {
		return ErrInvalidSnapshot
	}
	if len(s.CoreVersion) == 0 || len(s.CoreVersion) > 128 {
		return ErrInvalidSnapshot
	}
	for _, c := range s.CoreVersion {
		if c < 33 || c > 126 {
			return ErrInvalidSnapshot
		}
	}
	switch s.Platform {
	case "ios":
		if s.Role != "ios_app" && s.Role != "ios_extension" {
			return ErrInvalidSnapshot
		}
	case "android":
		if s.Role != "android_service" {
			return ErrInvalidSnapshot
		}
	case "darwin", "windows", "linux":
		if s.Role != "desktop" {
			return ErrInvalidSnapshot
		}
	default:
		return ErrInvalidSnapshot
	}
	var previous uint64
	for _, e := range s.Events {
		if e.Sequence <= previous || e.AtUnixMS < 0 || e.UptimeMS < 0 || e.UptimeMS > s.UptimeMS || !token(e.Kind, 40) || (e.Reason != "" && !token(e.Reason, 40)) || !stateValid(e.State) {
			return ErrInvalidSnapshot
		}
		previous = e.Sequence
	}
	return nil
}
func unique(dec *json.Decoder, depth int) bool {
	if depth > 16 {
		return false
	}
	value, err := dec.Token()
	if err != nil {
		return false
	}
	d, ok := value.(json.Delim)
	if !ok {
		return true
	}
	if d == '{' {
		seen := map[string]bool{}
		for dec.More() {
			v, e := dec.Token()
			key, ok := v.(string)
			if e != nil || !ok || seen[key] {
				return false
			}
			seen[key] = true
			if !unique(dec, depth+1) {
				return false
			}
		}
		v, e := dec.Token()
		return e == nil && v == json.Delim('}')
	}
	if d == '[' {
		for dec.More() {
			if !unique(dec, depth+1) {
				return false
			}
		}
		v, e := dec.Token()
		return e == nil && v == json.Delim(']')
	}
	return false
}
func Read(input io.Reader) (Snapshot, error) {
	var s Snapshot
	data, err := io.ReadAll(io.LimitReader(input, MaxBytes+1))
	if err != nil {
		return s, ErrInvalidSnapshot
	}
	if len(data) > MaxBytes {
		return s, ErrSnapshotTooLarge
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	if !unique(dec, 0) {
		return s, ErrInvalidSnapshot
	}
	if _, err = dec.Token(); err != io.EOF {
		return s, ErrInvalidSnapshot
	}
	dec = json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if dec.Decode(&s) != nil {
		return Snapshot{}, ErrInvalidSnapshot
	}
	if err = s.Validate(); err != nil {
		return Snapshot{}, err
	}
	return s, nil
}
func (s State) DeadlineResult() string {
	if !s.LeasePresent || len(s.Groups) == 0 {
		return "not_applicable"
	}
	if !s.DeadlineElapsed && !s.Revoked {
		return "pending"
	}
	unknown := false
	for _, g := range s.Groups {
		if g.Automatic == "proxy" {
			return "not_rejected"
		}
		if g.Automatic == "missing" {
			unknown = true
		}
	}
	if unknown {
		return "unverified"
	}
	return "rejected"
}

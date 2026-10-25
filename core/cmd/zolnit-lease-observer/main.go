package main

import (
	"core/observation"
	"encoding/json"
	"flag"
	"io"
	"os"
	"time"
)

var sourceCommit = "unversioned"

type options struct {
	file, role                          string
	historical                          bool
	watchSeconds, pollMS, maxAgeSeconds int
}
type result struct {
	OK             bool                  `json:"ok"`
	Code           string                `json:"code"`
	ObserverSource string                `json:"observer_source_commit"`
	Historical     bool                  `json:"historical"`
	AgeMS          int64                 `json:"age_ms,omitempty"`
	DeadlineResult string                `json:"deadline_result,omitempty"`
	Snapshot       *observation.Snapshot `json:"snapshot,omitempty"`
}

func read(opt options, now time.Time) result {
	r := result{Code: "observation_file_unavailable", ObserverSource: sourceCommit, Historical: opt.historical}
	infoBefore, err := os.Lstat(opt.file)
	if err != nil || !infoBefore.Mode().IsRegular() {
		return r
	}
	f, err := os.Open(opt.file)
	if err != nil {
		return r
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() || !os.SameFile(infoBefore, info) {
		r.Code = "invalid_observation_snapshot"
		return r
	}
	snapshot, err := observation.Read(f)
	if err != nil {
		r.Code = "invalid_observation_snapshot"
		return r
	}
	if opt.role != "" && snapshot.Role != opt.role {
		r.Code = "observation_role_mismatch"
		return r
	}
	r.Snapshot = &snapshot
	r.AgeMS = now.UnixMilli() - snapshot.SampledAtUnixMS
	r.DeadlineResult = snapshot.State.DeadlineResult()
	if !opt.historical && (r.AgeMS < -2000 || r.AgeMS > int64(opt.maxAgeSeconds)*1000) {
		r.Code = "observation_stale"
		return r
	}
	r.OK = true
	r.Code = "observation_read"
	if opt.historical {
		r.Code = "observation_history"
	}
	return r
}
func fingerprint(r result) string {
	if r.Snapshot == nil {
		return r.Code
	}
	state := r.Snapshot.State
	state.RemainingMS = 0
	var sequence uint64
	if n := len(r.Snapshot.Events); n > 0 {
		sequence = r.Snapshot.Events[n-1].Sequence
	}
	b, _ := json.Marshal(struct {
		Code     string
		PID      int
		Producer string
		State    observation.State
		Sequence uint64
	}{r.Code, r.Snapshot.ProducerPID, r.Snapshot.ProducerState, state, sequence})
	return string(b)
}
func run(opt options, out io.Writer) int {
	if opt.file == "" || opt.watchSeconds < 0 || opt.watchSeconds > 600 || opt.pollMS < 100 || opt.pollMS > 5000 || opt.maxAgeSeconds < 1 || opt.maxAgeSeconds > 60 {
		return 2
	}
	end := time.Now().Add(time.Duration(opt.watchSeconds) * time.Second)
	last := ""
	count := 0
	exit := 1
	for {
		r := read(opt, time.Now())
		current := fingerprint(r)
		if current != last {
			if json.NewEncoder(out).Encode(r) != nil {
				return 1
			}
			last = current
			count++
			if r.OK {
				exit = 0
			} else {
				exit = 1
			}
		}
		if opt.watchSeconds == 0 || !time.Now().Before(end) || count >= 256 {
			return exit
		}
		time.Sleep(time.Duration(opt.pollMS) * time.Millisecond)
	}
}
func main() {
	flags := flag.NewFlagSet("zolnit-lease-observer", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	opt := options{}
	flags.StringVar(&opt.file, "file", "", "Core-owned snapshot file")
	flags.StringVar(&opt.role, "expect-role", "", "desktop, ios_app, ios_extension or android_service")
	flags.BoolVar(&opt.historical, "allow-historical", false, "read an exported snapshot without claiming current freshness")
	flags.IntVar(&opt.watchSeconds, "watch-seconds", 0, "read changes for up to 600 seconds")
	flags.IntVar(&opt.pollMS, "interval-ms", 250, "poll interval from 100 to 5000 milliseconds")
	flags.IntVar(&opt.maxAgeSeconds, "max-age-seconds", 5, "fresh snapshot age from 1 to 60 seconds")
	version := flags.Bool("version", false, "report observer source without accessing files")
	if flags.Parse(os.Args[1:]) != nil || flags.NArg() != 0 {
		_ = json.NewEncoder(os.Stdout).Encode(result{Code: "invalid_arguments", ObserverSource: sourceCommit})
		os.Exit(2)
	}
	if *version {
		_ = json.NewEncoder(os.Stdout).Encode(result{OK: true, Code: "version", ObserverSource: sourceCommit})
		return
	}
	code := run(opt, os.Stdout)
	if code == 2 {
		_ = json.NewEncoder(os.Stdout).Encode(result{Code: "invalid_arguments", ObserverSource: sourceCommit})
	}
	if code != 0 {
		os.Exit(code)
	}
}

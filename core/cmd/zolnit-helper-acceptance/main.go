package main

import (
	"bufio"
	"bytes"
	"core/observation"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"
)

type rpc struct {
	ID        string `json:"id"`
	Method    string `json:"method"`
	Arguments any    `json:"arguments"`
}
type response struct {
	ID     string          `json:"id"`
	Result json.RawMessage `json:"result"`
	Error  any             `json:"error"`
	File   string          `json:"file"`
}

func frameCall(conn io.ReadWriter, call rpc) (json.RawMessage, error) {
	data, err := json.Marshal(call)
	if err != nil {
		return nil, err
	}
	var header [4]byte
	binary.LittleEndian.PutUint32(header[:], uint32(len(data)))
	if _, err = io.Copy(conn, bytes.NewReader(append(header[:], data...))); err != nil {
		return nil, err
	}
	for {
		if _, err = io.ReadFull(conn, header[:]); err != nil {
			return nil, err
		}
		n := binary.LittleEndian.Uint32(header[:])
		if n > 1<<20 {
			return nil, errors.New("oversized Core frame")
		}
		data = make([]byte, n)
		if _, err = io.ReadFull(conn, data); err != nil {
			return nil, err
		}
		var r response
		if err = json.Unmarshal(data, &r); err != nil {
			return nil, err
		}
		if r.ID != call.ID {
			continue
		}
		if r.Error != nil || r.File != "" {
			return nil, errors.New("Core RPC failed or spilled")
		}
		return r.Result, nil
	}
}

type observed struct {
	OK         bool                 `json:"ok"`
	Historical bool                 `json:"historical"`
	Snapshot   observation.Snapshot `json:"snapshot"`
}

func checkWatchdog(data []byte, before observation.Snapshot, haltedAt int64) error {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	found := false
	for scanner.Scan() {
		var r observed
		if err := json.Unmarshal(scanner.Bytes(), &r); err != nil {
			return err
		}
		s := r.Snapshot
		if !r.OK || r.Historical || s.Validate() != nil || s.ProducerState != "running" || s.ProducerPID != before.ProducerPID || s.Platform != "windows" || s.Role != "desktop" || s.State.InstanceTag != before.State.InstanceTag {
			return errors.New("observer identity/freshness failure")
		}
		if len(s.State.Groups) != 1 || s.State.Groups[0].ManualTag != before.State.Groups[0].ManualTag {
			return errors.New("manual choice changed")
		}
		for _, e := range s.Events {
			if e.Kind == "query_expired" {
				return errors.New("query-triggered expiry cannot prove watchdog")
			}
			if e.Kind == "watchdog" && e.AtUnixMS >= haltedAt && e.State.Revoked && e.State.DeadlineElapsed && e.State.DeadlineResult() == "rejected" && len(e.State.Groups) == 1 && e.State.Groups[0].ManualTag == before.State.Groups[0].ManualTag && s.State.DeadlineResult() == "rejected" {
				found = true
			}
		}
	}
	if scanner.Err() != nil {
		return scanner.Err()
	}
	if !found {
		return errors.New("no Core watchdog REJECT while frontend suspended")
	}
	return nil
}

func snapshot(file string, pid int, predicate func(observation.Snapshot) bool) (observation.Snapshot, error) {
	end := time.Now().Add(5 * time.Second)
	for time.Now().Before(end) {
		f, err := os.Open(file)
		if err == nil {
			s, e := observation.Read(f)
			_ = f.Close()
			age := time.Now().UnixMilli() - s.SampledAtUnixMS
			if e == nil && s.ProducerPID == pid && s.ProducerState == "running" && age >= -2000 && age <= 5000 && predicate(s) {
				return s, nil
			}
		}
		time.Sleep(25 * time.Millisecond)
	}
	return observation.Snapshot{}, errors.New("Core passive snapshot timeout")
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

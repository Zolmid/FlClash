package clientbundle

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

// ReplayFloor remains after the credential-bearing package is removed.  A
// revoked serial is therefore a durable tombstone, not an in-memory hint.
type ReplayFloor struct {
	AccountID string `json:"account_id,omitempty"`
	DeviceID  string `json:"device_id,omitempty"`
	Serial    int64  `json:"serial"`
	Digest    string `json:"digest"`
	Revoked   bool   `json:"revoked"`
	Expired   bool   `json:"expired,omitempty"`
}

func LoadReplayFloor(path string) (ReplayFloor, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return ReplayFloor{}, nil
	}
	if err != nil {
		return ReplayFloor{}, err
	}
	var floor ReplayFloor
	if json.Unmarshal(b, &floor) != nil || floor.Serial < 0 {
		return ReplayFloor{}, errors.New("invalid replay floor")
	}
	return floor, nil
}

func SaveReplayFloor(path string, floor ReplayFloor) error {
	if floor.Serial < 0 {
		return errors.New("invalid replay floor")
	}
	b, err := json.Marshal(floor)
	if err != nil {
		return err
	}
	if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	return writeAtomic(filepath.Dir(path), filepath.Base(path), b)
}

func (floor ReplayFloor) Accept(serial int64, digest string, revoked bool) error {
	if serial < 1 || digest == "" {
		return errors.New("invalid signed serial")
	}
	if serial < floor.Serial || (serial == floor.Serial && digest != floor.Digest) {
		return ErrReplay
	}
	if floor.Revoked && serial <= floor.Serial {
		return ErrTombstone
	}
	return nil
}

func writeAtomic(dir, name string, content []byte) error {
	tmp, err := os.CreateTemp(dir, ".zn-subscription-")
	if err != nil {
		return err
	}
	temporary := tmp.Name()
	defer os.Remove(temporary)
	if err = tmp.Chmod(0600); err == nil {
		_, err = tmp.Write(content)
	}
	if err == nil {
		err = tmp.Sync()
	}
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	if err = os.Rename(temporary, filepath.Join(dir, name)); err != nil {
		return err
	}
	syncDir(dir)
	return nil
}

func syncDir(dir string) {
	if handle, err := os.Open(dir); err == nil {
		_ = handle.Sync()
		_ = handle.Close()
	}
}

func readRegular(dir, name string) ([]byte, error) {
	path := filepath.Join(dir, name)
	info, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() || info.Size() > maxInput+4096 {
		return nil, ErrStoreCorrupt
	}
	content, err := os.ReadFile(path)
	if err == nil && !bytes.Equal(content, bytes.TrimSpace(content)) {
		return nil, ErrStoreCorrupt
	}
	return content, err
}

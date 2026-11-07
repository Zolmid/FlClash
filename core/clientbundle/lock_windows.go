//go:build windows

package clientbundle

import (
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows"
)

func lockStore(dir string) (func(), error) {
	file, err := os.OpenFile(filepath.Join(dir, lockFileName), os.O_RDWR|os.O_CREATE, 0600)
	if err != nil {
		return nil, err
	}
	handle := windows.Handle(file.Fd())
	deadline := time.Now().Add(lockWait)
	for {
		overlapped := new(windows.Overlapped)
		err = windows.LockFileEx(handle, windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, overlapped)
		if err == nil {
			return func() {
				_ = windows.UnlockFileEx(handle, 0, 1, 0, overlapped)
				_ = file.Close()
			}, nil
		}
		if time.Now().After(deadline) {
			_ = file.Close()
			return nil, ErrStoreBusy
		}
		time.Sleep(10 * time.Millisecond)
	}
}

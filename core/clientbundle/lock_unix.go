//go:build unix

package clientbundle

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

func lockStore(dir string) (func(), error) {
	file, err := os.OpenFile(filepath.Join(dir, lockFileName), os.O_RDWR|os.O_CREATE|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(lockWait)
	for {
		err = syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return func() {
				_ = syscall.Flock(int(file.Fd()), syscall.LOCK_UN)
				_ = file.Close()
			}, nil
		}
		if !errors.Is(err, syscall.EWOULDBLOCK) && !errors.Is(err, syscall.EINTR) || time.Now().After(deadline) {
			_ = file.Close()
			return nil, ErrStoreBusy
		}
		time.Sleep(10 * time.Millisecond)
	}
}

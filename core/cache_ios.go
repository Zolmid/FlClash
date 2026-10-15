//go:build ios

package core

import (
	"errors"
	"fmt"
	"path/filepath"
	"sync"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/constant/features"
)

var iosCacheInit struct {
	once    sync.Once
	homeDir string
	err     error
}

func initializePlatformCache(homeDir string) error {
	if !filepath.IsAbs(homeDir) {
		return errors.New("iOS core requires an absolute home directory")
	}
	homeDir = filepath.Clean(homeDir)
	iosCacheInit.once.Do(func() {
		iosCacheInit.homeDir = homeDir
		role := "app"
		if features.WithLowMemory {
			role = "ne"
		}
		iosCacheInit.err = withCacheHome(homeDir, role, func() error {
			db := cachefile.Cache().DB
			if db == nil {
				return errors.New("could not open the iOS core cache")
			}
			if filepath.Clean(db.Path()) != filepath.Clean(constant.Path.Cache()) {
				return errors.New("iOS core cache was opened before initialization")
			}
			return nil
		})
	})
	if iosCacheInit.homeDir != homeDir {
		return fmt.Errorf("iOS core cache is already bound to %s", iosCacheInit.homeDir)
	}
	return iosCacheInit.err
}

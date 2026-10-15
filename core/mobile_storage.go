package core

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
)

const iosAppStorageDir = ".ios-app"

// Cache() opens once per process; only its initialization sees the role home.
func withCacheHome(sharedHome, role string, open func() error) error {
	cacheHome := filepath.Join(sharedHome, ".ios-cache", role)
	if err := os.MkdirAll(cacheHome, 0o700); err != nil {
		return err
	}
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(cacheHome)
	defer constant.SetHomeDir(previous)
	return open()
}

func isolateHTTPProviders(raw *config.RawConfig, homeDir string) error {
	for _, group := range []struct {
		directory string
		providers map[string]map[string]any
	}{
		{"proxies", raw.ProxyProvider},
		{"rules", raw.RuleProvider},
	} {
		for name, provider := range group.providers {
			if provider["type"] != "http" {
				continue
			}
			source, _ := provider["path"].(string)
			if source == "" {
				url, _ := provider["url"].(string)
				source = filepath.Join(group.directory, utils.MakeHash([]byte(url)).String())
			}
			if !filepath.IsAbs(source) {
				source = filepath.Join(homeDir, source)
			}
			relative, err := filepath.Rel(homeDir, source)
			if err != nil || !filepath.IsLocal(relative) {
				return fmt.Errorf("provider %s cache path is outside the iOS home directory", name)
			}
			target := filepath.Join(homeDir, iosAppStorageDir, relative)
			if err := seedProviderCache(source, target); err != nil {
				return fmt.Errorf("initialize provider %s cache: %w", name, err)
			}
			provider["path"] = target
		}
	}
	return nil
}

func seedProviderCache(source, target string) error {
	if _, err := os.Stat(target); err == nil {
		return nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	input, err := os.Open(source)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	defer input.Close()
	info, err := input.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
		return err
	}
	output, err := os.CreateTemp(filepath.Dir(target), ".provider-*")
	if err != nil {
		return err
	}
	defer os.Remove(output.Name())
	_, copyErr := io.Copy(output, input)
	if err := output.Close(); copyErr == nil {
		copyErr = err
	}
	if copyErr != nil {
		return copyErr
	}
	if err := os.Chtimes(output.Name(), info.ModTime(), info.ModTime()); err != nil {
		return err
	}
	// Linking publishes a complete copy without replacing a newer app download.
	if err := os.Link(output.Name(), target); err != nil && !errors.Is(err, os.ErrExist) {
		return err
	}
	return nil
}

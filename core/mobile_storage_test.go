package core

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/bbolt"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
)

func TestRoleCachesRemainOpenTogetherAndPersistIndependently(t *testing.T) {
	homeDir := t.TempDir()
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(homeDir)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	var databases []*bbolt.DB
	t.Cleanup(func() {
		for _, db := range databases {
			_ = db.Close()
		}
	})
	for _, role := range []string{"app", "ne"} {
		err := withCacheHome(homeDir, role, func() error {
			db, err := bbolt.Open(constant.Path.Cache(), 0o600, &bbolt.Options{Timeout: 50 * time.Millisecond})
			if err != nil {
				return err
			}
			databases = append(databases, db)
			return db.Update(func(tx *bbolt.Tx) error {
				bucket, err := tx.CreateBucketIfNotExists([]byte("selected"))
				if err != nil {
					return err
				}
				return bucket.Put([]byte("proxy"), []byte(role))
			})
		})
		if err != nil {
			t.Fatalf("initialize %s cache alongside the other role: %v", role, err)
		}
		if constant.Path.HomeDir() != homeDir {
			t.Fatal("cache initialization changed the shared resource home")
		}
	}
	for index, role := range []string{"app", "ne"} {
		db := databases[index]
		path := db.Path()
		if err := db.Close(); err != nil {
			t.Fatal(err)
		}
		reopened, err := bbolt.Open(path, 0o600, &bbolt.Options{Timeout: 50 * time.Millisecond})
		if err != nil {
			t.Fatal(err)
		}
		databases[index] = reopened
		if err := reopened.View(func(tx *bbolt.Tx) error {
			if got := string(tx.Bucket([]byte("selected")).Get([]byte("proxy"))); got != role {
				t.Errorf("%s persisted selection = %q", role, got)
			}
			return nil
		}); err != nil {
			t.Fatal(err)
		}
	}
}

func TestRoleCacheRestoresResourceHomeAfterOpenFailure(t *testing.T) {
	previous := constant.Path.HomeDir()
	failure := errors.New("cache open failed")
	err := withCacheHome(t.TempDir(), "app", func() error { return failure })
	if !errors.Is(err, failure) || constant.Path.HomeDir() != previous {
		t.Fatalf("cache failure = %v, home = %q; want original home %q", err, constant.Path.HomeDir(), previous)
	}
}

func TestHTTPProvidersUseIndependentSeededAppCaches(t *testing.T) {
	homeDir := t.TempDir()
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(homeDir)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	source := filepath.Join(homeDir, "profiles", "providers", "42", "proxies.yaml")
	if err := os.MkdirAll(filepath.Dir(source), 0o700); err != nil {
		t.Fatal(err)
	}
	seed := []byte("proxies:\n  - {name: cached, type: direct}\n")
	if err := os.WriteFile(source, seed, 0o600); err != nil {
		t.Fatal(err)
	}
	modified := time.Now().Add(-time.Hour)
	if err := os.Chtimes(source, modified, modified); err != nil {
		t.Fatal(err)
	}
	raw := config.DefaultRawConfig()
	raw.ProxyProvider = map[string]map[string]any{
		"remote": {
			"type": "http", "url": "https://example.invalid/proxies.yaml",
			"path": "profiles/providers/42/proxies.yaml", "interval": 86400,
		},
		"local": {"type": "file", "path": source},
	}
	raw.RuleProvider = map[string]map[string]any{
		"domains": {"type": "http", "url": "https://example.invalid/rules", "behavior": "domain"},
	}
	if err := isolateHTTPProviders(raw, homeDir); err != nil {
		t.Fatal(err)
	}
	appPath := filepath.Join(homeDir, iosAppStorageDir, "profiles", "providers", "42", "proxies.yaml")
	if raw.ProxyProvider["remote"]["path"] != appPath || raw.ProxyProvider["local"]["path"] != source {
		t.Fatalf("provider paths = %+v", raw.ProxyProvider)
	}
	if _, err := os.Stat(raw.RuleProvider["domains"]["path"].(string)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("an uncached rule provider should remain fetchable: %v", err)
	}
	stat, err := os.Stat(appPath)
	if err != nil || !stat.ModTime().Equal(modified) {
		t.Fatalf("seed did not preserve the cache age: stat=%v, err=%v", stat, err)
	}
	delete(raw.RuleProvider, "domains")
	appConfig, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		for _, p := range appConfig.Providers {
			if closer, ok := p.(io.Closer); ok {
				_ = closer.Close()
			}
		}
	})
	remote := appConfig.Providers["remote"].(*provider.ProxySetProvider)
	if err := remote.Initial(); err != nil {
		t.Fatalf("initialize provider offline from its isolated seed: %v", err)
	}
	if len(remote.Proxies()) != 1 || remote.Proxies()[0].Name() != "cached" {
		t.Fatalf("cached proxies = %+v", remote.Proxies())
	}
	appUpdate := []byte("proxies:\n  - {name: app-update, type: direct}\n")
	if _, _, err := remote.SideUpdate(appUpdate); err != nil {
		t.Fatal(err)
	}
	if shared, err := os.ReadFile(source); err != nil || !bytes.Equal(shared, seed) {
		t.Fatalf("app provider modified the NE cache: content=%q, err=%v", shared, err)
	}
	if err := seedProviderCache(source, appPath); err != nil {
		t.Fatal(err)
	}
	if cached, err := os.ReadFile(appPath); err != nil || !bytes.Equal(cached, appUpdate) {
		t.Fatalf("seeding replaced a newer app download: content=%q, err=%v", cached, err)
	}
}

func TestProviderIsolationRejectsPathsOutsideTheSharedHome(t *testing.T) {
	raw := config.DefaultRawConfig()
	raw.ProxyProvider = map[string]map[string]any{
		"escaped": {"type": "http", "path": "../other/provider.yaml"},
	}
	if err := isolateHTTPProviders(raw, t.TempDir()); err == nil {
		t.Fatal("accepted a provider cache outside the shared home")
	}
}

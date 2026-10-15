package core

import (
	"os"
	"path/filepath"
	"testing"
)

func TestProviderCleanupKeepsOtherProfilesAndBothIOSStores(t *testing.T) {
	home := t.TempDir()
	for _, appStorage := range []bool{false, true} {
		cacheHome := home
		if appStorage {
			cacheHome = filepath.Join(home, iosAppStorageDir)
		}
		for _, profileID := range []string{"42", "43"} {
			path := filepath.Join(cacheHome, "profiles", "providers", profileID)
			if err := os.MkdirAll(path, 0o700); err != nil {
				t.Fatal(err)
			}
		}
		if err := clearProviderEffects(home, 42, appStorage); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(filepath.Join(cacheHome, "profiles", "providers", "42")); !os.IsNotExist(err) {
			t.Fatalf("requested cache still exists: %v", err)
		}
		if _, err := os.Stat(filepath.Join(cacheHome, "profiles", "providers", "43")); err != nil {
			t.Fatalf("another profile was removed: %v", err)
		}
	}
}

func TestProviderCleanupRejectsSymlinkedScopeRoots(t *testing.T) {
	for _, scope := range []string{"profiles", iosAppStorageDir} {
		t.Run(scope, func(t *testing.T) {
			home, outside := t.TempDir(), t.TempDir()
			target := filepath.Join(outside, "providers", "42")
			if scope == iosAppStorageDir {
				target = filepath.Join(outside, "profiles", "providers", "42")
			}
			if err := os.MkdirAll(target, 0o700); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(outside, filepath.Join(home, scope)); err != nil {
				t.Skipf("symlink unavailable: %v", err)
			}
			if err := clearProviderEffects(home, 42, scope == iosAppStorageDir); err == nil {
				t.Fatal("accepted a symlinked provider scope")
			}
			if _, err := os.Stat(target); err != nil {
				t.Fatalf("followed the symlink outside the managed root: %v", err)
			}
		})
	}
}

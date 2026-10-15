//go:build !ios

package core

func initializePlatformCache(homeDir string) error {
	return nil
}

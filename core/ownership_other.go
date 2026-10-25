//go:build !(darwin || linux) || android || ios

package core

import "os"

func initOwnership(homeDir string) {}

func scheduleReclaimOwnership() {}

func reclaimDirOwnership(path string) {}

func reclaimPrivateFileOwnership(file *os.File) error { return nil }

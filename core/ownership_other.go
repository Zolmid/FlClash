//go:build !(darwin || linux) || android || ios

package core

func initOwnership(homeDir string) {}

func scheduleReclaimOwnership() {}

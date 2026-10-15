//go:build ios && cgo && with_low_memory

package main

import "runtime/debug"

func init() {
	debug.SetMemoryLimit(32 * 1024 * 1024)
}

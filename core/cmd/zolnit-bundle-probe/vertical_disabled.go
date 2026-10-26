//go:build !zolnit_acceptance

package main

import (
	"flag"
	"io"
	"time"
)

func addVerticalFlag(_ *flag.FlagSet) *bool { return nil }

func runVerticalMode(_ io.Reader, _ io.Writer, _ string, _ time.Duration) bool { return false }

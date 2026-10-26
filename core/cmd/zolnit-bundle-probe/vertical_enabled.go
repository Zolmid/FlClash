//go:build zolnit_acceptance

package main

import (
	"core"
	"flag"
	"io"
	"time"
)

func addVerticalFlag(flags *flag.FlagSet) *bool {
	return flags.Bool("vertical", false, "run account-2 vertical acceptance using stdin commands")
}

func runVerticalMode(input io.Reader, output io.Writer, source string, timeout time.Duration) bool {
	return core.RunClientBundleAcceptance(input, output, source, timeout)
}

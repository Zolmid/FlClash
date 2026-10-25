//go:build !windows

package main

import "errors"

func run() error { return errors.New("Windows host required; SCM is not exercised by this harness") }

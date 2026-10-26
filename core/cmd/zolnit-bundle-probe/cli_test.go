package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"os"
	"os/exec"
	"slices"
	"testing"
	"time"
)

func TestProbeCLI(t *testing.T) {
	if os.Getenv("ZOLNIT_PROBE_CLI_CHILD") == "1" {
		index := slices.Index(os.Args, "--")
		if index < 0 {
			os.Exit(3)
		}
		os.Args = append([]string{"zolnit-bundle-probe"}, os.Args[index+1:]...)
		main()
		os.Exit(0)
	}
	vertical := addVerticalFlag(flag.NewFlagSet("capability", flag.ContinueOnError)) != nil
	for _, scenario := range []struct {
		name string
		args []string
		exit int
		mode string
	}{
		{"version", []string{"--version"}, 0, "metadata"},
		{"vertical-version", []string{"--vertical", "--version"}, 0, "vertical_metadata"},
		{"other-account", []string{"--vertical", "--account-id", "3"}, 2, ""},
		{"excessive-timeout", []string{"--vertical", "--account-id", "2", "--timeout-seconds", "21"}, 2, ""},
		{"legacy-target", []string{"--vertical", "--account-id", "2", "--target", "PRIVATE_SENTINEL"}, 2, ""},
		{"unknown-flag", []string{"--PRIVATE_SENTINEL"}, 2, ""},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			if scenario.name == "vertical-version" && !vertical {
				scenario.exit, scenario.mode = 2, ""
			}
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			args := append([]string{"-test.run=^TestProbeCLI$", "--"}, scenario.args...)
			command := exec.CommandContext(ctx, os.Args[0], args...)
			command.Env = append(os.Environ(), "ZOLNIT_PROBE_CLI_CHILD=1")
			command.Stdin = bytes.NewBufferString("PRIVATE_SENTINEL\n")
			var stdout, stderr bytes.Buffer
			command.Stdout, command.Stderr = &stdout, &stderr
			err := command.Run()
			exit := 0
			if err != nil {
				failure, ok := err.(*exec.ExitError)
				if !ok {
					t.Fatal("CLI did not terminate within its bound")
				}
				exit = failure.ExitCode()
			}
			if exit != scenario.exit || stderr.Len() != 0 || bytes.Contains(stdout.Bytes(), []byte("PRIVATE_SENTINEL")) {
				t.Fatal("CLI exit or output boundary failed")
			}
			var result report
			if json.Unmarshal(stdout.Bytes(), &result) != nil || result.SourceCommit != sourceCommit || result.CoreVersion == "" {
				t.Fatal("CLI did not emit one version-bound JSON report")
			}
			if exit == 0 {
				if !result.OK || result.Code != "version" || result.Mode != scenario.mode {
					t.Fatal("CLI capability metadata mismatch")
				}
			} else if result.OK || result.Code != "invalid_arguments" {
				t.Fatal("CLI accepted invalid arguments")
			}
		})
	}
}

package main

import (
	"bufio"
	"bytes"
	"context"
	"core/observation"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"
	"unsafe"

	"github.com/Microsoft/go-winio"
	"golang.org/x/sys/windows"
)

type child struct {
	cmd       *exec.Cmd
	input     io.WriteCloser
	output    *json.Decoder
	handle    windows.Handle
	suspended bool
	done      chan error
}

var acceptanceJob windows.Handle

func makeJob() (windows.Handle, error) {
	h, err := windows.CreateJobObject(nil, nil)
	if err != nil {
		return 0, err
	}
	limits := windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION{}
	limits.BasicLimitInformation.LimitFlags = windows.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
	_, err = windows.SetInformationJobObject(h, windows.JobObjectExtendedLimitInformation, uintptr(unsafe.Pointer(&limits)), uint32(unsafe.Sizeof(limits)))
	if err != nil {
		_ = windows.CloseHandle(h)
		return 0, err
	}
	return h, nil
}

func cleanupOwnedJob(job windows.Handle, home string) error {
	type accounting struct {
		TotalUserTime, TotalKernelTime, PeriodUserTime, PeriodKernelTime int64
		PageFaults, TotalProcesses, ActiveProcesses, TerminatedProcesses uint32
	}
	jobErr := windows.TerminateJobObject(job, 0)
	if jobErr == nil {
		deadline := time.Now().Add(5 * time.Second)
		for {
			var info accounting
			jobErr = windows.QueryInformationJobObject(job, windows.JobObjectBasicAccountingInformation, uintptr(unsafe.Pointer(&info)), uint32(unsafe.Sizeof(info)), nil)
			if jobErr != nil || info.ActiveProcesses == 0 {
				break
			}
			if !time.Now().Before(deadline) {
				jobErr = errors.New("owned acceptance Job still has active processes")
				break
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
	closeErr := windows.CloseHandle(job)
	var removeErr error
	if home != "" {
		removeErr = os.RemoveAll(home)
	}
	return errors.Join(jobErr, closeErr, removeErr)
}

func observe(ctx context.Context, executable, file string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, executable, "--file", file, "--expect-role", "desktop", "--watch-seconds", "8", "--interval-ms", "100")
	var output bytes.Buffer
	cmd.Stdout, cmd.Stderr = &output, os.Stderr
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	handle, err := windows.OpenProcess(windows.PROCESS_SET_QUOTA|windows.PROCESS_TERMINATE, false, uint32(cmd.Process.Pid))
	if err == nil {
		err = windows.AssignProcessToJobObject(acceptanceJob, handle)
		_ = windows.CloseHandle(handle)
	}
	if err != nil {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		return nil, err
	}
	err = cmd.Wait()
	return output.Bytes(), err
}

func launch(ctx context.Context, exe string, args ...string) (*child, error) {
	c := &child{cmd: exec.CommandContext(ctx, exe, args...), done: make(chan error, 1)}
	var err error
	c.input, err = c.cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	out, err := c.cmd.StdoutPipe()
	if err != nil {
		_ = c.input.Close()
		return nil, err
	}
	c.output = json.NewDecoder(out)
	c.cmd.Stderr = os.Stderr
	if err = c.cmd.Start(); err != nil {
		_ = c.input.Close()
		_ = out.Close()
		return nil, err
	}
	c.handle, err = windows.OpenProcess(windows.PROCESS_SET_QUOTA|windows.PROCESS_TERMINATE|windows.PROCESS_SUSPEND_RESUME|windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(c.cmd.Process.Pid))
	go func() { c.done <- c.cmd.Wait() }()
	if err != nil {
		_ = c.cmd.Process.Kill()
		<-c.done
		return nil, err
	}
	if err = windows.AssignProcessToJobObject(acceptanceJob, c.handle); err != nil {
		_ = c.cmd.Process.Kill()
		<-c.done
		_ = windows.CloseHandle(c.handle)
		return nil, err
	}
	return c, nil
}
func (c *child) close() {
	if c.suspended {
		_ = c.pause(false)
	}
	_ = c.input.Close()
	select {
	case <-c.done:
	case <-time.After(2 * time.Second):
		_ = c.cmd.Process.Kill()
		<-c.done
	}
	_ = windows.CloseHandle(c.handle)
}
func (c *child) pause(suspend bool) error {
	name := "NtResumeProcess"
	if suspend {
		name = "NtSuspendProcess"
	}
	status, _, _ := windows.NewLazySystemDLL("ntdll.dll").NewProc(name).Call(uintptr(c.handle))
	if status != 0 {
		return fmt.Errorf("%s status %x", name, status)
	}
	c.suspended = suspend
	return nil
}
func (c *child) exchange(request, result any) error {
	if err := json.NewEncoder(c.input).Encode(request); err != nil {
		return err
	}
	return c.output.Decode(result)
}
func (c *child) call(method string, args any) (json.RawMessage, error) {
	var result struct {
		Result  json.RawMessage `json:"result"`
		Failure string          `json:"failure"`
	}
	if err := c.exchange(rpc{ID: method, Method: method, Arguments: args}, &result); err != nil {
		return nil, err
	}
	if result.Failure != "" {
		return nil, errors.New(result.Failure)
	}
	return result.Result, nil
}
func (c *child) helper(operation, pipe, session string) (int, error) {
	request := map[string]any{"operation": operation, "sessionId": session}
	if operation == "start" {
		request["address"] = pipe
	}
	var r struct {
		Status int `json:"status"`
		Body   struct {
			PID     int  `json:"pid"`
			Stopped bool `json:"stopped"`
		} `json:"body"`
	}
	if err := c.exchange(request, &r); err != nil {
		return 0, err
	}
	if r.Status != 200 || (operation == "start" && r.Body.PID <= 0) || (operation == "stop" && !r.Body.Stopped) {
		return 0, errors.New("Hub start/stop rejected")
	}
	return r.Body.PID, nil
}

func frontend(pipe string) error {
	tokenUser, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		return err
	}
	listener, err := winio.ListenPipe(pipe, &winio.PipeConfig{SecurityDescriptor: "D:P(A;;GA;;;" + tokenUser.User.Sid.String() + ")", InputBufferSize: 65536, OutputBufferSize: 65536})
	if err != nil {
		return err
	}
	defer listener.Close()
	if err = json.NewEncoder(os.Stdout).Encode(map[string]bool{"ready": true}); err != nil {
		return err
	}
	conn, err := listener.Accept()
	if err != nil {
		return err
	}
	defer conn.Close()
	decoder := json.NewDecoder(bufio.NewReader(os.Stdin))
	for {
		var request rpc
		if err = decoder.Decode(&request); err == io.EOF {
			return nil
		} else if err != nil {
			return err
		}
		if err = conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
			return err
		}
		result, e := frameCall(conn, request)
		failure := ""
		if e != nil {
			failure = e.Error()
		}
		if err = json.NewEncoder(os.Stdout).Encode(map[string]any{"result": result, "failure": failure}); err != nil {
			return err
		}
	}
}

const syntheticProfile = `mixed-port: 0
port: 0
socks-port: 0
redir-port: 0
tproxy-port: 0
external-controller: ''
external-controller-tls: ''
external-controller-unix: ''
external-controller-pipe: ''
mode: rule
dns: {enable: false, listen: ''}
tun: {enable: false}
ntp: {enable: false, write-to-system: false}
sniffer: {enable: false}
listeners: []
tunnels: []
geo-auto-update: false
profile: {store-selected: false, store-fake-ip: false}
proxies:
  - {name: zn.node.socks5.1, type: socks5, server: 192.0.2.1, port: 9}
  - {name: zn.node.socks5.2, type: socks5, server: 198.51.100.1, port: 9}
proxy-groups:
  - {name: zn.service.ai.auto, type: select, proxies: [REJECT, zn.node.socks5.1]}
  - {name: zn.service.ai.manual, type: select, proxies: [zn.node.socks5.1, zn.node.socks5.2, DIRECT]}
  - {name: zn.service.ai, type: select, proxies: [zn.service.ai.auto, zn.service.ai.manual, DIRECT]}
rules: ['MATCH,REJECT']
`

func setup(f *child, expiry int64) error {
	_, err := f.call("setupConfig", map[string]any{"selected-map": map[string]string{"zn.service.ai": "zn.service.ai.auto"}, "test-url": "", "routing-lease": map[string]any{
		"accountId": "synthetic-account", "accountGeneration": 3, "bundleId": "synthetic-bundle", "configurationDigest": "synthetic-digest", "expiresAt": expiry,
		"services": []any{map[string]any{"groupName": "zn.service.ai", "automaticGroup": "zn.service.ai.auto", "manualGroup": "zn.service.ai.manual", "allowedProxies": []string{"zn.node.socks5.1"}}},
	}})
	return err
}
func guard(f *child) (map[string]any, error) {
	data, err := f.call("getRoutingLease", nil)
	if err != nil {
		return nil, err
	}
	var g map[string]any
	err = json.Unmarshal(data, &g)
	if err == nil && (g["instanceId"] == nil || g["token"] == nil) {
		err = errors.New("guard missing")
	}
	return g, err
}
func choose(f *child, group, node string, g map[string]any) error {
	args := map[string]any{"group-name": group, "proxy-name": node}
	if g != nil {
		args["routing-lease"] = g
	}
	data, err := f.call("changeProxy", args)
	if err != nil {
		return err
	}
	var r struct {
		Message string `json:"message"`
	}
	if err = json.Unmarshal(data, &r); err != nil {
		return err
	}
	if r.Message != "" {
		return errors.New("Core rejected selector write")
	}
	return nil
}
func newFrontend(ctx context.Context, helper *child, exe, home string) (*child, int, error) {
	var nonce [16]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		return nil, 0, err
	}
	session := hex.EncodeToString(nonce[:])
	pipe := `\\.\pipe\ZolNitCore_` + session
	f, err := launch(ctx, exe, "--frontend", pipe)
	if err != nil {
		return nil, 0, err
	}
	ready := struct {
		Ready bool `json:"ready"`
	}{}
	if err = f.output.Decode(&ready); err != nil || !ready.Ready {
		f.close()
		return nil, 0, errors.New("frontend not ready")
	}
	pid, err := helper.helper("start", pipe, session)
	if err != nil {
		f.close()
		return nil, 0, err
	}
	if _, err = f.call("initClash", map[string]any{"home-dir": home, "version": 0, "routing-observation": true}); err != nil {
		f.close()
		return nil, 0, err
	}
	return f, pid, nil
}

func run() (resultErr error) {
	flags := flag.NewFlagSet("zolnit-helper-acceptance", flag.ContinueOnError)
	helperPath := flags.String("helper", "", "isolated Helper binary beside hash-bound Core")
	observer := flags.String("observer", "", "passive observer binary")
	worker := flags.String("frontend", "", "internal private pipe")
	if err := flags.Parse(os.Args[1:]); err != nil {
		return err
	}
	if *worker != "" {
		return frontend(*worker)
	}
	if *helperPath == "" || *observer == "" || flags.NArg() != 0 {
		return errors.New("--helper and --observer required")
	}
	var err error
	acceptanceJob, err = makeJob()
	if err != nil {
		return err
	}
	var home string
	defer func() {
		resultErr = errors.Join(resultErr, cleanupOwnedJob(acceptanceJob, home))
		if resultErr == nil {
			fmt.Println("PASS cleanup: owned Job has zero active processes; temporary Core home removed")
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	home, err = os.MkdirTemp("", "zolnit-helper-acceptance-")
	if err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(home, "config.yaml"), []byte(syntheticProfile), 0600); err != nil {
		return err
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	helper, err := launch(ctx, *helperPath)
	if err != nil {
		return err
	}
	defer helper.close()
	f, pid, err := newFrontend(ctx, helper, exe, home)
	if err != nil {
		return err
	}
	defer f.close()
	if err = setup(f, time.Now().Add(6*time.Second).UnixMilli()); err != nil {
		return err
	}
	if err = choose(f, "zn.service.ai.manual", "zn.node.socks5.2", nil); err != nil {
		return err
	}
	g, err := guard(f)
	if err != nil {
		return err
	}
	if err = choose(f, "zn.service.ai.auto", "zn.node.socks5.1", g); err != nil {
		return err
	}
	file := filepath.Join(home, "diagnostics", "lease-observation-desktop.json")
	before, err := snapshot(file, pid, func(s observation.Snapshot) bool {
		return s.State.LeasePresent && len(s.State.Groups) == 1 && s.State.Groups[0].Automatic == "proxy" && s.State.Groups[0].ManualTag != "" && s.State.RemainingMS > 2000
	})
	if err != nil {
		return err
	}
	if err = f.pause(true); err != nil {
		return err
	}
	haltedAt := time.Now().UnixMilli()
	output, err := observe(ctx, *observer, file)
	if err != nil {
		return errors.New("passive observer execution failed")
	}
	if err = checkWatchdog(output, before, haltedAt); err != nil {
		return err
	}
	fmt.Println("PASS frontend process suspended: actual Core watchdog REJECT; manual selection unchanged")
	if err = f.pause(false); err != nil {
		return err
	}
	expiry := time.Now().Add(30 * time.Second).UnixMilli()
	if err = setup(f, expiry); err != nil {
		return err
	}
	old, err := guard(f)
	if err != nil {
		return err
	}
	coreHandle, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(pid))
	if err != nil {
		return err
	}
	defer windows.CloseHandle(coreHandle)
	if err = helper.cmd.Process.Kill(); err != nil {
		return err
	}
	status, err := windows.WaitForSingleObject(coreHandle, 5000)
	if err != nil || status != windows.WAIT_OBJECT_0 {
		return errors.New("Helper Job did not terminate its Core")
	}
	nextHelper, err := launch(ctx, *helperPath)
	if err != nil {
		return err
	}
	defer nextHelper.close()
	next, nextPID, err := newFrontend(ctx, nextHelper, exe, home)
	if err != nil {
		return err
	}
	defer next.close()
	if err = setup(next, expiry); err != nil {
		return err
	}
	// Match the old generation so only process identity explains stale-guard rejection.
	if err = setup(next, expiry); err != nil {
		return err
	}
	fresh, err := guard(next)
	if err != nil {
		return err
	}
	if fresh["instanceId"] == old["instanceId"] || fresh["configurationGeneration"] != old["configurationGeneration"] || fresh["expiresAt"] != old["expiresAt"] {
		return errors.New("restart guard comparison invalid")
	}
	state, err := snapshot(file, nextPID, func(s observation.Snapshot) bool {
		return s.State.InstanceTag != before.State.InstanceTag && s.State.LeasePresent && len(s.State.Groups) == 1 && s.State.Groups[0].Automatic == "reject"
	})
	if err != nil {
		return err
	}
	if err = choose(next, "zn.service.ai.auto", "zn.node.socks5.1", old); err == nil {
		return errors.New("stale old-process guard accepted")
	}
	_, err = snapshot(file, nextPID, func(s observation.Snapshot) bool {
		if len(s.State.Groups) != 1 || s.State.Groups[0].Automatic != "reject" || s.State.Groups[0].ManualTag != state.State.Groups[0].ManualTag {
			return false
		}
		for _, e := range s.Events {
			if e.Kind == "write_rejected" && e.Reason == "authorization" {
				return true
			}
		}
		return false
	})
	if err != nil {
		return err
	}
	if err = choose(next, "zn.service.ai.auto", "zn.node.socks5.1", fresh); err != nil {
		return err
	}
	_, err = snapshot(file, nextPID, func(s observation.Snapshot) bool {
		return len(s.State.Groups) == 1 && s.State.Groups[0].Automatic == "proxy"
	})
	if err != nil {
		return err
	}
	fmt.Println("PASS isolated Helper restart: Job terminated old Core; new instance rejects old guard and accepts fresh guard")
	fmt.Println("SCM, installed services, production HTTP owner ingress, Flutter UI and real-device suspension remain untested")
	return nil
}

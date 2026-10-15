//go:build ios && cgo

package main

//#include <stdlib.h>
import "C"

import (
	"core"
	"core/tun"
	"encoding/json"
	"sync"
	"unsafe"
)

func main() {}

var (
	listenerUpdateMu sync.Mutex
	eventListenerMu  sync.Mutex
	eventListener    unsafe.Pointer
)

//export invokeMethod
func invokeMethod(callback unsafe.Pointer, params *C.char) {
	core.InvokeMethod(takeCString(params), func(data []byte) {
		defer releaseObject(callback)
		sendResult(callback, data)
	})
}

//export quickSetup
func quickSetup(callback unsafe.Pointer, initParams, setupParams *C.char) {
	initData, setupData := takeCString(initParams), takeCString(setupParams)
	core.QuickSetup(initData, setupData, func(message string) {
		defer releaseObject(callback)
		sendResult(callback, []byte(message))
	})
}

//export startTUN
func startTUN(callback unsafe.Pointer, fd C.int, rawOptions *C.char) bool {
	defer releaseObject(callback)
	data := takeCString(rawOptions)
	var options tun.Options
	if err := json.Unmarshal([]byte(data), &options); err != nil {
		return false
	}
	return core.StartTun(nil, int(fd), options.Stack, options.Address, options.DNS, data)
}

//export setEventListener
func setEventListener(callback unsafe.Pointer) {
	listenerUpdateMu.Lock()
	defer listenerUpdateMu.Unlock()
	eventListenerMu.Lock()
	previous := eventListener
	eventListener = callback
	eventListenerMu.Unlock()
	releaseObject(previous)
	if callback == nil {
		core.SetEventListener(nil)
		return
	}
	core.SetEventListener(func(data []byte) {
		eventListenerMu.Lock()
		listener := retainObject(eventListener)
		eventListenerMu.Unlock()
		if listener == nil {
			return
		}
		defer releaseObject(listener)
		sendResult(listener, data)
	})
}

//export getTraffic
func getTraffic(onlyStatisticsProxy bool) *C.char {
	return C.CString(core.GetTraffic(onlyStatisticsProxy))
}

//export getTotalTraffic
func getTotalTraffic(onlyStatisticsProxy bool) *C.char {
	return C.CString(core.GetTotalTraffic(onlyStatisticsProxy))
}

//export stopTun
func stopTun() {
	core.StopTun()
}

//export startListener
func startListener() {
	core.StartListener()
}

//export stopListener
func stopListener() {
	core.StopListener()
}

//export forceGC
func forceGC() {
	core.ForceGC()
}

//export updateDns
func updateDns(value *C.char) {
	core.UpdateDns(takeCString(value))
}

//export resetNetwork
func resetNetwork() {
	core.ResetNetwork()
}

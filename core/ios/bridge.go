//go:build ios && cgo

package main

//#include "bride.h"
import "C"

import (
	"core"
	"unsafe"
)

func init() {
	core.SetMemoryFootprintReader(func() uint64 { return uint64(C.flclash_physical_footprint()) })
}

func takeCString(value *C.char) string {
	defer C.free_string(value)
	return C.GoString(value)
}

func sendResult(callback unsafe.Pointer, data []byte) {
	value := C.CString(string(data))
	defer C.free(unsafe.Pointer(value))
	C.result(callback, value)
}

func releaseObject(callback unsafe.Pointer) {
	C.release_object(callback)
}

func retainObject(callback unsafe.Pointer) unsafe.Pointer {
	return C.retain_object(callback)
}

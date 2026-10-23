package com.zolmid.zolnit.plugins

internal const val INSTALL_PERMISSION_REQUEST_CODE = 1006
internal const val BATTERY_OPTIMIZATION_REQUEST_CODE = 1005

internal fun consumeActivityResult(requestCode: Int, expectedCode: Int, resolve: () -> Unit): Boolean {
    if (requestCode != expectedCode) {
        return false
    }
    resolve()
    return true
}

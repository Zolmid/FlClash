package com.zolmid.zolnit.service

internal fun Array<String>?.unambiguousPackageName(): String {
    val packages = this ?: return ""
    return packages.singleOrNull()?.takeIf { it.isNotEmpty() }.orEmpty()
}

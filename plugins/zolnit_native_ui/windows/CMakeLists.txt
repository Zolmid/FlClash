cmake_minimum_required(VERSION 3.21)
project(zolnit_native_ui LANGUAGES CXX)

set(PLUGIN_NAME "zolnit_native_ui_plugin")
set(ZOLNIT_WINAPPSDK_VERSION "1.7.250401001" CACHE STRING
    "Pinned Microsoft.WindowsAppSDK NuGet version")
set(ZOLNIT_WEBVIEW2_WINMD "" CACHE FILEPATH
    "Microsoft.Web.WebView2.Core.winmd (WebView2 1.0.2903.40) referenced while generating the Microsoft.UI.Xaml projection")

find_program(POWERSHELL_EXECUTABLE powershell REQUIRED)
set(ZOLNIT_WINAPPSDK_CACHE "${CMAKE_BINARY_DIR}/zolnit_native_ui_winappsdk")
execute_process(
  COMMAND "${POWERSHELL_EXECUTABLE}" -NoProfile -ExecutionPolicy Bypass -File
    "${CMAKE_CURRENT_SOURCE_DIR}/scripts/restore-winappsdk.ps1"
    -CacheDir "${ZOLNIT_WINAPPSDK_CACHE}"
    -WebView2Winmd "${ZOLNIT_WEBVIEW2_WINMD}"
  RESULT_VARIABLE ZOLNIT_WINAPPSDK_RESTORE_RESULT
  OUTPUT_VARIABLE ZOLNIT_WINAPPSDK_RESTORE_OUTPUT
  ERROR_VARIABLE ZOLNIT_WINAPPSDK_RESTORE_ERROR)
if(NOT ZOLNIT_WINAPPSDK_RESTORE_RESULT EQUAL 0)
  message(FATAL_ERROR "ZolNit WinUI dependency restore failed: ${ZOLNIT_WINAPPSDK_RESTORE_ERROR}")
endif()
string(REGEX MATCH "ZOLNIT_WINDOWS_APP_SDK_DIR=([^\r\n]+)" _ "${ZOLNIT_WINAPPSDK_RESTORE_OUTPUT}")
set(ZOLNIT_WINDOWS_APP_SDK_DIR "${CMAKE_MATCH_1}")
string(REGEX MATCH "ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE=([^\r\n]+)" _ "${ZOLNIT_WINAPPSDK_RESTORE_OUTPUT}")
set(ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE "${CMAKE_MATCH_1}")

if(NOT EXISTS "${ZOLNIT_WINDOWS_APP_SDK_DIR}/lib/uap10.0/Microsoft.UI.Xaml.winmd")
  message(FATAL_ERROR "${ZOLNIT_WINDOWS_APP_SDK_DIR} is not a usable Microsoft.WindowsAppSDK ${ZOLNIT_WINAPPSDK_VERSION} package.")
endif()
if(NOT EXISTS "${ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE}/winrt/Microsoft.UI.Xaml.h")
  message(FATAL_ERROR
    "ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE must point to C++/WinRT projections generated "
    "from Microsoft.UI.Xaml.winmd by the Microsoft.Windows.SDK.BuildTools cppwinrt tool.")
endif()

if(CMAKE_VS_PLATFORM_NAME STREQUAL "ARM64" OR
   CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64" OR
   CMAKE_SYSTEM_PROCESSOR MATCHES "^[Aa][Rr][Mm]64$")
  message(FATAL_ERROR "ZolNit WinUI island currently supports Flutter Windows x64 only; ARM64 must use the Flutter surface until its WinAppSDK target is added.")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(ZOLNIT_WINAPPSDK_ARCH x64)
else()
  message(FATAL_ERROR "ZolNit WinUI island currently supports x64 only; x86 is unsupported.")
endif()

set(ZOLNIT_WINAPPSDK_LIB "${ZOLNIT_WINDOWS_APP_SDK_DIR}/lib/win10-${ZOLNIT_WINAPPSDK_ARCH}")
set(ZOLNIT_WINAPPSDK_DISPATCHING_LIB "${ZOLNIT_WINDOWS_APP_SDK_DIR}/lib/native/win10-${ZOLNIT_WINAPPSDK_ARCH}/Microsoft.UI.Dispatching.lib")
if(NOT EXISTS "${ZOLNIT_WINAPPSDK_LIB}/Microsoft.WindowsAppRuntime.lib" OR
   NOT EXISTS "${ZOLNIT_WINAPPSDK_LIB}/Microsoft.WindowsAppRuntime.Bootstrap.lib" OR
   NOT EXISTS "${ZOLNIT_WINAPPSDK_DISPATCHING_LIB}" OR
   NOT EXISTS "${ZOLNIT_WINDOWS_APP_SDK_DIR}/runtimes/win-${ZOLNIT_WINAPPSDK_ARCH}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll")
  message(FATAL_ERROR "Windows App SDK libraries for ${ZOLNIT_WINAPPSDK_ARCH} were not found in ${ZOLNIT_WINDOWS_APP_SDK_DIR}.")
endif()

add_library(${PLUGIN_NAME} SHARED
  "include/zolnit_native_ui/zolnit_native_ui_plugin_c_api.h"
  "zolnit_native_ui_plugin_c_api.cpp"
  "zolnit_native_ui_plugin.cpp"
  "zolnit_native_ui_plugin.h"
  "winui_surface.cpp"
  "winui_surface.h"
)

apply_standard_settings(${PLUGIN_NAME})
# C++/WinRT requires exceptions; the Flutter standard settings define
# _HAS_EXCEPTIONS=0, so drop that definition for this target only.
get_target_property(ZOLNIT_PLUGIN_DEFS ${PLUGIN_NAME} COMPILE_DEFINITIONS)
if(ZOLNIT_PLUGIN_DEFS)
  list(REMOVE_ITEM ZOLNIT_PLUGIN_DEFS "_HAS_EXCEPTIONS=0")
  set_property(TARGET ${PLUGIN_NAME} PROPERTY COMPILE_DEFINITIONS "${ZOLNIT_PLUGIN_DEFS}")
endif()
target_compile_options(${PLUGIN_NAME} PRIVATE /permissive- /bigobj)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL WINRT_LEAN_AND_MEAN NOMINMAX)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${ZOLNIT_WINDOWS_APP_SDK_DIR}/include"
  "${ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE}"
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter flutter_wrapper_plugin
  "${ZOLNIT_WINAPPSDK_LIB}/Microsoft.WindowsAppRuntime.lib"
  "${ZOLNIT_WINAPPSDK_LIB}/Microsoft.WindowsAppRuntime.Bootstrap.lib"
  "${ZOLNIT_WINAPPSDK_DISPATCHING_LIB}"
  windowsapp ole32)

# The island uses the existing brand artwork; the application bundle retains the
# authoritative asset and this only copies it next to the plugin DLL at build time.
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/assets/images"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_SOURCE_DIR}/../assets/images/zolnit-horizontal-light.png"
    "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/assets/images/zolnit-horizontal-light.png"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_SOURCE_DIR}/../assets/images/zolnit-horizontal-dark.png"
    "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/assets/images/zolnit-horizontal-dark.png")

set(zolnit_native_ui_bundled_libraries
  "${ZOLNIT_WINDOWS_APP_SDK_DIR}/runtimes/win-${ZOLNIT_WINAPPSDK_ARCH}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll"
  PARENT_SCOPE)

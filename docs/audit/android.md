# Patched Android 原生整合审计

## 范围和边界

比较共同祖先 `7c61c90ac20493b474d19c75ec96262b478b4b88` 到 Patched `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`，枚举 `android/**` 的全部 **23 个**来源提交。主线输入为 `origin/main` 的 `f2112fc4`，保留 iOS 移植基线 `3222b8d609caaf74c28f61712c8d654e4937eed9`。

本轮实现确认缺失的桌面 Widget、Quick Settings 展示与收起偏好、活动 VPN 参数快照、通知网速开关和 APK 安装通道。保持主线 gomobile、`ServiceStateMachine` 最新意图仲裁、`ServiceRuntime` 实际服务状态、Dart `commandRevision`、BootGuard 和现有权限/回调保护；没有移入 Patched 的旧 Android Cgo/CMake 桥接。

## 来源与处理结果

| 精确来源提交 | 处理与理由 | 证据路径 |
| --- | --- | --- |
| `4d3ce623c86a2ff84046597c21961d0cee492e5d` | **迁入有效原生差异**：通知网速开关和 Android back callback opt-in；关闭网速时不轮询，亮屏/解锁保留主线刷新修复。**保留主线替代**：不移入旧 Cgo 桥接、不删除动态 `stopText`、Crashlytics 和主线回调保护。 | `NotificationModule.kt`、`NotificationParams.kt`、`models/State.kt`、`AndroidManifest.xml`；gomobile 仍在 `android/core/` |
| `50730d01baf27303fad5d7d8f8bcca862f71f990` | **本轮迁入**：`collapseQuickSettingsPanel` 默认 true。true 仍通过 QuickActionActivity 收起面板，false 在原 service owner 上请求 toggle。 | `android/app/src/main/kotlin/com/follow/clash/TileService.kt`、`models/State.kt` |
| `f187acf285f04e9855ec83e143b1da89e07b81b8` | **本轮迁入**：Android 10+ tile subtitle 展示运行中的配置名；SharedPreferences 监听使名称随状态更新。旧系统保留兼容路径。 | `TileService.kt`、`TilePresentation.kt` |
| `b03877df6e1ca47f3050a42414b4fd1dedfdf4a8` | **由主线测试替代并扩展**：保留主线 NotificationParams 参数顺序/stopText，补网络速度偏好实际传递测试，不复制已经不对应主线模型的期望。 | `android/tests/app/ServiceStateMachineTest.kt`、`android/tests/service/ServiceConfigTest.kt` |
| `864826aea7074069da58058e466f68285b3dbca1` | **本轮迁入**：面板保持打开时隐藏 start/stop 过渡 toast；错误提示仍保留，操作继续经同一状态机。 | `ServiceStateMachine.handleStopAction/setupCore`、对应 JVM 测试 |
| `68ae229833b42b63d67bcb109e087d16d791bdc1` | **主线已有有效传递路径**：`congestionController` 随 VpnOptions 经 `tunOptions` 进入 Go，不改变主线默认栈或另加 global owner。 | `android/service/src/main/java/com/follow/clash/service/models/VpnOptions.kt`、`android/tests/service/VpnOptionsTest.kt` |
| `f713793ae8bed112a8b30a084940beb31cb71ed8` | **主线已有/保留**：设备睡眠不会停启 Core；当前 ServiceModules 没有 SuspendModule。通知屏幕策略只影响展示轮询。 | `android/service/src/main/java/com/follow/clash/service/modules/ServiceModules.kt`、`NotificationModule.kt` |
| `0d764e8b8fddcfd35860e6b6dd8e255d777b5deb` | **拒绝品牌/包名迁移**：保留 `com.follow.clash`、debug `.dev`、本地签名配置和 method-channel。避免改变持久化目录、VPN 身份、权限名和升级签名关系。 | `android/app/build.gradle.kts`、`common/Components.kt`、`AndroidManifest.xml` |
| `05e0f44ccd0c567a0150cc70c2fbbbe398f8c854` | **保留主线图标生成源**：不单独替换 launcher/tray 的导出资源，避免与 `assets_source/images/icon/` 和 `tool/generate_status_icons.dart` 的主线来源失配。新增 Widget 专属图标单独迁入。 | `android/app/src/main/res/drawable/ic_widget_logo.xml`；主线 launcher 资源保持原样 |
| `907cd0117aa237be8387c77aa6fd4c06bb20c7dc` | **拒绝删除主线崩溃恢复**：BootGuard 的启动阶段/退出原因判定仍是当前主线明确的可靠性行为，不因 fork 删除它而移除。 | `lib/common/boot_guard.dart`、`android/common/.../GlobalState.kt`、`android/app/.../plugins/AppPlugin.kt` |
| `2d057f209b1172ef5758aa3976f20c9b604f1edf` | **保留主线替代策略**：本仓库的本地网络权限拒绝路径实际为 system/mixed → **gvisor**，与外部描述的 → mips 不同。根任务确认保持现有策略；用 requested/actual 分离避免合法 fallback 反复触发重启提示。没有只为匹配文案更改内核路径。 | `ServiceStateMachine.withLocalNetworkFallback`、`ServiceRuntime`、requested/actual JVM 回归 |
| `65c15c871636dd78544cc33ab85e9f375c587a3f` | **由构建审计处理依赖；本模块不覆盖**：保留当前 SDK/NDK/AGP/Kotlin 与 gomobile 构建关系，不把 fork 的旧桥接和 pin 当作 UI 功能前提。 | `android/settings.gradle.kts`、`android/gradle/libs.versions.toml`、`android/core/build.gradle.kts` |
| `d4369bc5b41a5b8f0af5976eac3f19c558031852` | **保留主线生成图标**：同上述图标源约束；本轮 Widget 配色可由 Dart 主题覆盖，不重写现有 launcher。 | `StatusWidgetProvider.palette`、`models/WidgetTheme`、主线 `assets_source/images/icon/` |
| `aaf0755da58010b210b23627cfc3134819928d74` | **保留主线生成图标**：不把 Android 单平台导出 PNG/WebP 替换成另一来源版本；新增 Widget 资源完整纳入当前工程。 | `android/app/src/main/res/drawable/widget_*`、`res/layout/status_widget*` |
| `323f678d2f4fed3aa08a409cdfbb2e06a32e95b0` | **迁入本轮原生控件所需翻译**：Widget/连接状态覆盖 en、简中、繁中、日、俄；不删除主线从 Dart 传入的服务提示。全 app 语言扩展由 Dart 审计处理。 | `android/app/src/main/res/values*/strings.xml`、`android/service/src/main/res/values*/strings.xml` |
| `697755c953a3a7f56c7dba04ef979ee0aa4d49f3` | **本轮迁入并强化**：成功启动后在既有 ServiceRuntime 保存 actual 与 requested 两份参数；同一个 runtime 消失时一起清空。新增两个只读方法，不新增 active 标志或 commandCount。 | `ServiceController.kt`、`ServiceStateHost.kt`、`ServiceStateMachine.kt`、`plugins/ServicePlugin.kt` |
| `10332be8866854065c407cb26b3c05fd96ae1545` | **本轮迁入**：`showQuickSettingsProfileName` 默认 true，关闭后使用本地化连接状态；空名称/过渡状态不冒充已连接配置。 | `TilePresentation.kt`、`TileService.kt`、`models/State.kt`、`TilePresentationTest.kt` |
| `1de91ebbfce8013bced5e99426d0b227aa82cb9f` | **本轮原生 APK 通道**：保留 PackageInstaller 用户确认及安装包身份边界；仅处理 App 私有更新 staging 的真实 APK，包名、签名、版本匹配当前应用。不会把任意 URI 或任意路径交给外部安装器。 | `plugins/AppPlugin.kt`、`ApkInstaller.kt`、`ApkInstallPolicy.kt`、`AndroidManifest.xml` |
| `1cad08ba10c99959b835cdf1286453232d1e4e53` | **主线已有且更严格**：运行状态由实际 ServiceRuntime、最新 intent 和进行中 transition 推导；保留 commandRevision、最新意图、异常回收和服务丢失仲裁。 | `ServiceStateMachine.publish`、`ServiceController.runtime`、`RunIntentArbiter`、现有 JVM 生命周期测试 |
| `95a06882d436f4433b8e01a8c2f623ded49e65e1` | **主线已有**：START/STOP/TOGGLE QuickActionActivity、重复 intent、shortcut 使用上报仍在。Widget 复用这些入口，没有绕过 ServiceState。 | `QuickActionActivity.kt`、`common/Enums.kt`、`AndroidManifest.xml` |
| `3814b935fa5de23e72e744b367b2f77ac55d8aec` | **主线已有**：VPN 地址为 `198.18.0.1/30`、DNS `198.18.0.2`，不再占用普通 LAN 地址段。 | `android/service/src/main/java/com/follow/clash/service/VpnService.kt` companion constants |
| `93c7145b9c7bf42db5037837bb3a5a4144666d25` | **主线已有/保留**：BatteryPlugin 的实时 allowlist/Xiaomi 状态流与 PendingCallback 生命周期保护保留，不重复移植旧单回调代码。Wi-Fi 背景定位仍由插件权限 owner 处理。 | `plugins/BatteryPlugin.kt`、`MainActivity.kt`、`plugins/wifi_ssid/android/` |
| `3ac6f36dc30ba0b6d0c53ab9eadbcbfe777d9bc5` | **本轮迁入**：StatusWidgetProvider、compact/row/square RemoteViews、主题 ARGB 色值、profile/status、VPN toggle、偏好和 runState 监听、系统主题刷新、manifest provider metadata。 | `StatusWidgetProvider.kt`、`StatusWidgetLayout.kt`、`FlClashApplication.kt`、`res/layout/`、`res/drawable/`、`res/xml/status_widget_info.xml` |

## 方法与生命周期契约

- `$packageName/service` 的 `start`、`stop` 参数仍是 Dart 传入的 commandRevision；native 只保存并回报该 revision，未增加独立递增计数。
- `getActiveVpnOptions` 返回成功启动时实际使用的完整 VpnOptions JSON String，未运行为 null；它可用于诊断实际的权限 fallback。
- `getRequestedVpnOptions` 返回同一 run 当时请求的完整 JSON String，未运行为 null。Android 重启提示以它与当前 `.effective` 比较；修改偏好不会篡改已经启动的快照。iOS 仍使用真实 active options。
- requested/actual 均是同一个 ServiceRuntime 的字段。读取经过 ServiceStateMachine 的 transition 锁，停止、启动失败和绑定丢失仍走既有 owner；没有第二套运行状态。
- profile `disableIcmpForwarding` 传入 Android `tunOptions` 的 `disable-icmp-forwarding`。未添加 Android recvmsg_x/sendmsg_x 假能力；未添加 sing-tun 不读取的 endpoint-independent NAT 设置或 global Tun owner。
- `$packageName/app` 的 `installApk` 参数为 `{'path': path}`，返回 `started`、`permissionDenied` 或 `failed`；`started` 表示已交给 PackageInstaller，最终安装仍由系统确认和校验。
- APK 必须是 `Context.cacheDir/app-updates/<tag>-<sha256>/<apk>` 内可读、非空的真实 `.apk` 文件，与 Dart 的隔离下载目录一致。只允许一层 release 目录（合法版本 tag 加 64 位小写摘要）；拒绝 staging/release/file symlink、任意 URI、外部路径和更深目录。要求 packageName 与当前应用一致、versionCode 严格增加、签名集合相同，或 PackageManager 解析的单证书历史包含当前与新证书。请求未知来源授权之前和提交安装之前分别检查，使用指定当前包名的 PackageInstaller session，结果广播 receiver 不导出。

## TV 与主线保护

MainActivity 与 Patched tip 在标识归一后相同，均将输入/遥控交给 FlutterActivity，没有额外的 Android TV IME patch 可搬。补上参考的 `enableOnBackInvokedCallback=true`，保留主线 `flutter_deeplinking_enabled=false`，不加入会截断 Flutter 焦点/返回处理的 native key interception。TV 的焦点边界、IME、遥控布局和 AppBar 行为由 Dart/UI 审计覆盖。

Widget 和 tile 的点击都请求既有 ServiceState/QuickActionActivity；不直接启停 VpnService、不绕过权限请求，不把状态观察读成用户意图。主线 `gomobile bind`、callback error 处理、实际 UID/包名解析、USER_PRESENT 通知重发、BootGuard、广播 lease 的 exactly-once finish 均保持。

## 验证与实际限制

本环境没有 Android SDK/NDK、sdkmanager/adb 或 Gradle wrapper，因此没有声称完成 Android 模块编译、APK 生成、模拟器或设备验收。

使用匹配工程 pin 的 Kotlin **2.4.20**、Coroutines **1.11.0**、Gson **2.14.0**、JUnit **4.13.2**，在 JDK 21 上编译目标 JVM 17，**117 项测试通过**。独立 scratch harness 使用生产纯 Kotlin 文件、原 ServiceStateHost 的纯接口/数据声明和现有 fake host 测试；未改仓库 build/codegen 设置。验证覆盖共享 JSON 默认值与 unsigned ARGB、tile 展示、Widget 布局、所有主线 ServiceStateMachine 用例、真实/请求 fallback 快照、配置变化与停止/失败清空、VPN option envelope、RunIntentArbiter，以及 APK release staging/目录与文件软链接/空文件/包名/版本/签名轮换和多签名策略。

静态检查解析全部新增 XML、核对 Widget 的 R 资源绑定、三类布局、receiver export/metadata 和源码空白。Launcher 小组件尺寸、Android 各版本 tile 面板交互、ROM 锁屏通知、安装授权/系统确认/最终验签以及 TV 遥控/IME 仍需真实 Android 环境验证；纯 JVM 和源检查不能替代这些系统行为。

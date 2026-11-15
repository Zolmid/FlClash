# ZolNit 平台契约

本文列出五个平台的身份、原生视图、深链、权限、存储隔离和升级约束。依据为 `main` 基线 `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` 的源码阅读（2026-11-15）。值只来自仓库源码或控制台文档，不包含密钥、UDID、账号或签名材料。“源码确认”指可在文件中看到；“推断”指由平台 API 行为推出、未在设备上验证；“未核对”指本次未读取。

## 1. 身份（debug 与 release）

| 平台 | release 身份 | debug 身份 | 来源 | 状态 |
|---|---|---|---|---|
| Android | `com.zolmid.zolnit` | `com.zolmid.zolnit.debug`（`applicationIdSuffix ".debug"`） | [android/app/build.gradle.kts](../../android/app/build.gradle.kts) 第 19、29、56 行 | 源码确认 |
| macOS | `com.zolmid.zolnit`（[AppInfo.xcconfig](../../macos/Runner/Configs/AppInfo.xcconfig)） | **`com.zolmid.zolnit.debug`**，由 Runner 目标的 Debug 配置覆盖（[project.pbxproj](../../macos/Runner.xcodeproj/project.pbxproj) 第 778 行） | 两处 | 源码确认：只读 AppInfo.xcconfig 会漏掉覆盖 |
| iOS | `$(APP_BUNDLE_ID)`，由 [setup.dart](../../setup.dart) 与构建参数写入 | Widget、NECore、RunnerTests 各追加后缀（`.Widget`、`.NECore`、`.RunnerTests`） | [project.pbxproj](../../ios/Runner.xcodeproj/project.pbxproj) | 源码确认，具体 release 值由构建参数决定 |
| Windows | 产品名 ZolNit，`ZolNit.exe` | AUMID 由 [main.cpp](../../windows/runner/main.cpp) 第 19–23 行的 `SetCurrentProcessExplicitAppUserModelID` 设置：条件编译 `#ifdef _DEBUG` 为真时写 `com.zolmid.zolnit.debug`，否则写 `com.zolmid.zolnit`（纠正：条件已核对，取决于构建的 `_DEBUG` 宏，不是运行时判断） | [Runner.rc](../../windows/runner/Runner.rc)，[main.cpp](../../windows/runner/main.cpp) | 源码确认 |
| Linux | `APPLICATION_ID` `com.zolmid.zolnit`，二进制 `ZolNit` | `com.zolmid.zolnit.debug` | [linux/CMakeLists.txt](../../linux/CMakeLists.txt) 第 7–12 行 | 源码确认 |

Dart 侧的 `packageName` 来自 `PackageInfo`，在 iOS 上用于拼接 App Group 名称。

## 2. 数据目录与 debug 隔离

- 数据路径入口：[lib/common/path.dart](../../lib/common/path.dart) 的 `_resolveDataDirectory`。非 iOS 平台直接返回 `supportDirectory()`，即 `getApplicationSupportDirectory`。
- iOS：先读取 `PackageInfo.packageName`，再用 `group.<packageName>` 调用 `PathProviderFoundation().getContainerPath`。容器为空会抛出 `StateError`，不回退到沙盒目录。`migrateIOSDataDirectory` 把旧的 support 目录递归复制到 App Group 容器，源与目标相同则直接返回。
- Android 的 application ID 区分应用沙盒。macOS 的锁定 `path_provider_foundation` 2.6.0 会在 Application Support/Cache 下追加 `NSBundle.main.bundleIdentifier`，因此通常按 debug/release ID 分开应用数据；这不是钥匙串、特权服务或网络隔离证明。
- Linux 的锁定 `path_provider_linux` 2.2.2 优先使用 XDG 数据目录下的 application ID；若该目录不存在但旧版“可执行文件名”目录存在，会复用旧目录。读不到 application ID 时也回退到可执行文件名。因此 `.debug` ID 不能保证已有安装之间的数据隔离。启动前应在指定测试环境核对实际解析路径，不能主动删除旧目录来制造隔离。
- Windows 的锁定 `path_provider_windows` 2.3.0 用 RoamingAppData 加资源中的 CompanyName/ProductName；当前 `Runner.rc` 两种构建均为 Zolmid/ZolNit。AUMID 的 `.debug` 不改变这个路径，不应假定数据隔离。上述插件源码已按 pubspec.lock 版本静态核对，未执行真实用户数据访问。

## 3. 安全存储与钥匙串

- 登录令牌在 [providers/zolnit_vault.dart](../../lib/providers/zolnit_vault.dart) 中由 `FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false))` 保存，键为 `zolnit.session.authorization.v1`。`zolnit_native_renewal.dart` 使用同样的 macOS 选项。
- 源码没有显式设置 `accessGroup` 或 `service`。因此两个构建之间的钥匙串隔离取决于插件的默认服务名与 bundle ID，这一点**未核对**，不能仅凭源码承诺 debug 与 release 的令牌互不可见。
- d0 原始源码中，Runner 声明自身 `keychain-access-groups`，NECore/Widget 源文件没有该条目。**最终签名权限不能只看这些源文件**：Apple 工具 `97f29774` 的 [source_preparation.py](https://github.com/Zolmid/FlClash/blob/97f297743718b6d46272d244ad375b5ca903f499/tool/apple_distribution/source_preparation.py) 为 Runner/NECore 加入共享 renewal 组，并写入 `ZolNitRenewalKeychainAccessGroup`、`ZolNitDistribution`、`ZolNitRenewalWhileLocked`。`projected_target_entitlements` 给 app 保留自身组及 renewal 组，给 necore renewal 组，不给 Widget 该组；profile 和签名包仍须通过工具校验。
- [ClientBundleRenewalConfiguration.swift](../../ios/Shared/ClientBundleRenewalConfiguration.swift) 拒绝未展开的配置及 Widget/observer 目标；[ClientBundleKeychainStore.swift](../../ios/Shared/ClientBundleKeychainStore.swift) 用明确 access group、service `com.zolmid.zolnit.renewal.authorization.v1` 和 session epoch 保存受绑定的 authorization/device 信息，不使用 App Group 明文文件保存凭据。锁屏策略在 `whenUnlockedThisDeviceOnly` 与 `afterFirstUnlockThisDeviceOnly` 间由已校验配置选择。状态/epoch 另用 App Group。Flutter 的会话键和 renewal journal 是不同存储用途，排障不能随意互删。
- macOS Runner 的 DebugProfile/Release entitlement 文件未声明 keychain-access-groups 或 App Group；这只说明源码声明，不证明默认安全存储跨构建隔离，实际签名权限还须从受验包核对。

## 4. App Group、扩展与 IPC

| 组件 | 标识 | 来源 |
|---|---|---|
| iOS App Group | `group.$(APP_BUNDLE_ID)`，Runner、NECore、Widget 一致 | [Runner.entitlements](../../ios/Runner/Runner.entitlements)，[NECore.entitlements](../../ios/NECore/NECore.entitlements)，[Widget.entitlements](../../ios/Widget/Widget.entitlements) |
| NECore 扩展 | `$(APP_BUNDLE_ID).NECore` | [project.pbxproj](../../ios/Runner.xcodeproj/project.pbxproj) 第 759、805、849 行 |
| iOS 共享状态 | [PacketTunnelSharedStateStore.swift](../../ios/NECore/PacketTunnelSharedStateStore.swift) | App Group UserDefaults 的 sharedState/setupParams/runTime/activeVpnOptions；缺失 setupParams 回退共享快照，Core home 指向 App Group |
| Windows Helper 服务 | `ZolNitHelperService`（[constant.dart](../../lib/common/constant.dart) 第 13 行），可执行文件名 `ZolNitHelperService.exe` | 源码确认 |
| Windows Helper 工程 | [services/helper/](../../services/helper/) | 源码确认 |
| Linux Helper | 可执行文件仍由 appHelperService 命名；服务名 `zolnit-helper`，unit `/etc/systemd/system/zolnit-helper.service`，socket `/run/zolnit/helper.sock`，模式 0660；所属 UID/GID 与 peer 访问另校验 | [linux.rs](../../services/helper/src/service/linux.rs)，安装/卸载会操作 systemd，不能由 SAFE_MODE UI 单测代验 |
| Windows Helper 的 SCM 边界 | 应用经 readiness 检查和 `runas install --owner-pid` 发起提权安装；安装程序调用 SCM 注册/启动。`service_dispatcher::start` 是运行时连接 SCM 分发控制事件；已有 Helper 通过 loopback 动态 TCP/HTTP 接请求，注册表发现端口，连接进程 SID 校验所有者，不能由 UI 状态冒充宿主结果 | [system.dart](../../lib/common/system.dart)、[windows.rs](../../services/helper/src/service/windows.rs) |
| Windows 进程身份（AUMID） | `SetCurrentProcessExplicitAppUserModelID`：`_DEBUG` 构建为 `com.zolmid.zolnit.debug`，release 为 `com.zolmid.zolnit`（与第 1 节表格一致，这里是运行时设置点，不是资源声明） | [main.cpp](../../windows/runner/main.cpp) 第 19–23 行 |
| 桌面 Core IPC（与 Helper HTTP 分开） | Unix domain socket（macOS、Linux）与命名管道（Windows），见 [architecture.md](../../.agents/architecture.md) | 原有机制，ZolNit 未改动 |

## 5. 原生视图：已实现但未挂载

ZolNit 的原生视图组件已经存在，但当前 `ZolnitHomePage` 生产路径使用共享 Flutter 页面，未挂载 `ZolnitNativeHome`。以下事实分别来自源码：

- Dart 层：[plugins/zolnit_native_ui/lib/src/surface.dart](../../plugins/zolnit_native_ui/lib/src/surface.dart) 的 `ZolnitNativeSurface` 按平台选择 `AndroidView`、`UiKitView`、`AppKitView` 或 Windows 的 `_WindowsSurface`。其他平台返回 `SizedBox.shrink()`。
- 通道与视图类型：[protocol.dart](../../plugins/zolnit_native_ui/lib/src/protocol.dart) 定义 `com.zolmid.zolnit/native-ui`、视图类型 `com.zolmid.zolnit/native-home`、快照版本 `nativeUiSchemaVersion = 1`。
- Android：[ZolnitNativeUiPlugin.kt](../../plugins/zolnit_native_ui/android/src/main/kotlin/com/zolmid/zolnit/nativeui/ZolnitNativeUiPlugin.kt) 第 20 行注册 `NativeHomeViewFactory`；[NativeHomePlatformView.kt](../../plugins/zolnit_native_ui/android/src/main/kotlin/com/zolmid/zolnit/nativeui/NativeHomePlatformView.kt)（约 643 行）用 `ComposeView` 渲染 Compose 界面，快照由 `NativeUiProtocol.kt` 解析。
- Apple：[ZolnitNativeUiPlugin.swift](../../plugins/zolnit_native_ui/darwin/Sources/ZolnitNativeUiPlugin/ZolnitNativeUiPlugin.swift) 的 `NativeHomePlatformView` 在 iOS 上返回 `hostingController.view`（SwiftUI），在 macOS 上是 `NSView`（AppKit 宿主）。核心逻辑在 [NativeUiContract.swift](../../plugins/zolnit_native_ui/darwin/Sources/ZolnitNativeUiCore/NativeUiContract.swift)（约 1120 行）。
- Windows：[winui_surface.cpp](../../plugins/zolnit_native_ui/windows/winui_surface.cpp)（约 884 行）与 [zolnit_native_ui_plugin.cpp](../../plugins/zolnit_native_ui/windows/zolnit_native_ui_plugin.cpp)，通过 C API 导出给 Flutter 注册。
- 原生命令回到 Dart：[native_home.dart](../../lib/views/zolnit/native_home.dart) 的 `_command` 对 `accountGeneration` 做代际校验，过期返回 `stale_account`；安全模式返回 `safe_mode`；未登录返回 `unauthenticated`。
- 门控：`static const _enabled = bool.fromEnvironment('ZOLNIT_NATIVE_UI')`（[native_home.dart](../../lib/views/zolnit/native_home.dart) 第 49 行）。只有为真且平台受支持时才创建 `NativeUiBridge`，并调用 `isAvailable`。
- 回退：`isAvailable` 为假时，`ZolnitNativeHome` 显示 `zolnitConnectionPageUnavailable` 文案与重试按钮，而不是原生视图。门控为假时，widget 不创建桥接，但它本身也不在生产路由中。
- 挂载状态：在 `lib/` 中只找到 `ZolnitNativeHome` 的定义；唯一的构造调用在 [test/views/zolnit/native_home_test.dart](../../test/views/zolnit/native_home_test.dart) 第 108 行。[home_test.dart](../../test/views/zolnit/home_test.dart) 第 487 行断言 `find.byType(ZolnitNativeHome)` 为空。因此**当前已检查的生产首页路径不挂载该视图**；编译开关为真本身不会新增挂载点。这不是仅凭 grep 认定整个原生插件可删。
- CI：[cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 110–113、220–231、304 行把选择器输出 `native_ui` 传为 `ZOLNIT_NATIVE_UI` 与 `ZOLNIT_CLIENT_BUNDLE`。第 222 行在 macOS 安全预览中运行 `native_home_test.dart`。这证明编译与该测试路径，不证明生产界面。
- 合同文件：[native_ui/contract.v1.json](../../native_ui/contract.v1.json) 可用作人工对照。此次没有确认由它生成各平台实现的自动化链路；不能从一次字面量搜索推断所有动态/工具消费者不存在。维护时同时核对 Dart/Swift/Kotlin/C++ 协议与测试。

## 6. 深链与 URL scheme

| 平台 | 声明位置 | scheme 或路由 |
|---|---|---|
| Android | [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml) 第 77、85 行 | `zolnit`；`zolnit://safepay` 单独声明 host |
| iOS | [Info.plist](../../ios/Runner/Info.plist) 第 40–43 行 `CFBundleURLSchemes` | `zolnit` |
| macOS | [Info.plist](../../macos/Runner/Info.plist) 第 38 行 | `zolnit` |
| Linux | `Window.init` → `Protocol.registerLinux`；启动参数交给 LinkManager | 非 SAFE_MODE 写入当前用户 XDG desktop entry 并注册 `zolnit`；Debug desktop ID 带 `.debug` |
| Windows | `lib/common/window.dart` → `Protocol.register` | 非 SAFE_MODE 启动向 HKCU 的 `Software\Classes\zolnit` 注册当前可执行文件；安装器按归属清理 |

系统注册仅包含 `registeredProtocolSchemes=[zolnit]`；解析器兼容列表更宽，不能把两者混为系统已注册的 scheme。路由在 [lib/common/link.dart](../../lib/common/link.dart) 中识别，且列表来自 [lib/common/protocol.dart](../../lib/common/protocol.dart) 第 8 行：`clash`、`clashmeta`、`mihomo`、`flclash`、`zolnit`。

- `zolnit://safepay`：`isPaymentReturnLink`。回调在 [application.dart](../../lib/application.dart) 第 134 行刷新付款状态，不授予权益。
- `zolnit://auth/register#fragment`：`isRegistrationReturnLink`，要求 host 为 `auth`、路径为 `/register`、查询串为空、片段非空。回调在 [application.dart](../../lib/application.dart) 第 139 行调用 `zolnitRegistrationProvider.accept(uri)`。
- 旧版安装配置：任何受支持 scheme 的 `install-config?url=...` 由 `_installConfigUrl` 解析，回调弹出确认框，随后调用 `addProfileFromLink`。
- 直接 URL 与分享链接：`text.isUrl` 或 `text.isShareLink` 的字符串在 `profileUrlFromQrCodes` 中直接被接受。
- 网页单点登录（SSO）：[web_session.dart](../../packages/zolnit_client/lib/src/web_session.dart) 经 `authorizeWebSession` 获取一次性码并打开第一方 landing 页；此链路在浏览器完成，不依赖 `link.dart` 的 App 回跳。原生通道/Windows 临时浏览器、取消及无凭据 fallback 见架构第 3.13 节。

## 7. 权限与系统入口

- Android 安装 APK：`REQUEST_INSTALL_PACKAGES` 声明于 [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml) 第 31 行。[ApkInstaller.kt](../../android/app/src/main/kotlin/com/zolmid/zolnit/ApkInstaller.kt) 第 136 行检查 `canRequestPackageInstalls()`。[AppPlugin.kt](../../android/app/src/main/kotlin/com/zolmid/zolnit/plugins/AppPlugin.kt) 中的 `installPermissionCallback` 处理权限请求与设置页返回。UI 测试见 [update_test.dart](../../test/views/zolnit/update_test.dart) 的 `install permission offers later and explicit authorization` 与 `already granted install permission does not open a prompt`。
- Android 系统入口：Manifest 中声明了 `${applicationId}.action.START`、`.action.STOP`、`.action.TOGGLE`、`.intent.action.VPN_REVOKED`、`.intent.action.VPN_START_REQUESTED`、快速设置磁贴 `TOGGLEABLE_TILE`，以及应用小部件 provider。这些是 Android 的系统入口，都必须通过 `ServiceState` 裁决。
- iOS 快捷操作：[ShortcutProvider.swift](../../ios/Runner/ShortcutProvider.swift) 定义 `StartVPNIntent`、`StopVPNIntent`、`ToggleVPNIntent` 的 `AppShortcut`。这些 intent 的实现位于 Shared，调用 `NEHelper`；Widget 也使用 Shared 路径，不能将其等同于 Runner 的 `TunnelCoordinator`。本树中跨进程 start/stop 竞态及独立候选状态见 [架构](architecture.md) 和 [验证基线](verification-baseline.md)。

## 8. 支付渠道与分发

| 平台 | `ZOLNIT_DISTRIBUTION` 为空时 | `ZOLNIT_DISTRIBUTION=direct` 时 | 来源 |
|---|---|---|---|
| iOS | `appleAppStore`：允许 StoreKit IAP，不允许 Stripe | `direct`：允许 Stripe，不允许 IAP | [policy.dart](../../packages/zolnit_client/lib/src/policy.dart) |
| macOS | `appleAppStore` | `direct` | 同上 |
| Android | `direct` | `direct` | 同上 |
| Windows、Linux | `direct` | `direct` | 同上 |

- `allowStripe` 仅在 `direct` 为真。`allowAndroidSdk` 仅在 Android 上且 `allowStripe` 为真时为真，并要求能力列表包含 `payment_sheet`。
- `allowAppleIap` 仅在 iOS 或 macOS 上且为 `appleAppStore` 时为真。
- CI 中 `ZOLNIT_DISTRIBUTION` 仅在 `client_branch` 为真时设为 `direct`（[cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 110 行）。因此，一次没有 client_branch 的 iOS 构建会使用 App Store 渠道。
- 微信：`ZOLNIT_WECHAT_APP_ID` 默认为空，此时返回 `sdk_unavailable`（[platform_payments.dart](../../packages/zolnit_client/lib/src/platform_payments.dart)）。**按用户决定，移动端微信保持禁用**。存在桥接代码不等于已启用。
- 不得把 `allowStripe` 写成 iOS 的常规路径，也不得写成 macOS 永不使用 IAP。两者都取决于 `ZOLNIT_DISTRIBUTION`。

## 9. 更新与安装身份

- 网站清单：[app_update.dart](../../lib/common/app_update.dart) 的 `parseWebsiteReleases` 要求 `schema_version == 1`、`app_id == 'com.zolmid.zolnit'`、`updates_enabled` 为布尔值，并拒绝未知顶层字段。最多接受 30 个版本。
- GitHub 发布：`ReleaseManifest.fromGitHubRelease` 只接受带 `sha256:` 摘要的资产。
- 公开清单的当前观察值（控制台 [验证基线](verification-baseline.md)）：`app_id` 为 `com.zolmid.zolnit`，`updates_enabled` 为真，唯一列出的版本为 1.1.9，8 个资产。
- 安装身份：Android 安装前需要 `REQUEST_INSTALL_PACKAGES`；其他平台的安装身份检查未在本次核对。

## 10. 升级兼容

- 身份不变：相同 application ID/bundle ID 是覆盖升级的重要前提，还须匹配平台签名、版本及数据迁移契约；不能仅凭名字相同保证升级成功。
- 身份改变：按独立身份/迁移任务处理，不承诺旧数据自动跟随；已有共享服务、显式 App Group 或旧路径兼容也需单独调查。
- 数据库：Drift schema 为 21（[database.dart](../../lib/database/database.dart) 第 53 行），升级逻辑按版本分段，详见 [testing-and-debugging.md](testing-and-debugging.md) 第 4 节。
- 旧 Clash 配置仍由 [link.dart](../../lib/common/link.dart) 的 install-config 路由接受。

## 11. 历史上已知的平台缺口

以下缺口来自控制台交接记录，不是本次新增的：Windows 登录诊断已暂停；iOS 的 VPN 锁屏、恢复和网络切换在 1.1.9 上需要复测；Android 支付返回未在真机验收。所有这些都属于历史状态，本文不声明已解决。

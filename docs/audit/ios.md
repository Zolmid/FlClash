# Patched iOS 原生整合审计

## 比较范围与结论

- 主线输入：`origin/main` 的 `f2112fc4`；本轮保留的 iOS 移植输入：`3222b8d609caaf74c28f61712c8d654e4937eed9`。
- Patched 输入：`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`；真实共同祖先：`7c61c90ac20493b474d19c75ec96262b478b4b88`。
- 审计对象：`ios/**`、`plugins/wifi_ssid/ios/**`，以及会影响这些原生接口的 Dart/Core 交界。
- 使用 `git log --reverse <base>..<patched-tip> -- ios plugins/wifi_ssid/ios` 枚举全部 **21 个**相关提交，再用最终树逐文件比较确认实际结果。不能以提交未被 cherry-pick 判断功能缺失。

最终原生工程已覆盖 Patched tip 的全部 iOS 功能。Tunnel manager/coordinator、NE 网络配置、Widget、启动资源、权限声明、本地化和插件 SPM manifest 没有未迁入的最终功能差异。本轮保留既有安全模式、状态事件积压保护、主线 Core 协议适配和写请求路由一致性；没有用参考旧实现覆盖它们。

## 全部相关来源提交与处理

| 精确来源提交 | 内容与处理 | 当前证据路径 |
| --- | --- | --- |
| `e6d0712eefb54ed32e03a335a5ae9d6da0a527c4` | **已迁入并适配**：iOS Runner、NECore packet tunnel、App/NE 双 Core 桥接、App Group、控制中心 Widget/AppIntents、Wi-Fi 插件和原生生命周期。采用 `com.follow.clash`；保留后续 SPM 结构，未恢复初版 Podfile 和生成的 Podfile.lock。 | `ios/Runner/AppDelegate.swift`、`ios/Runner/ServiceChannel.swift`、`ios/Runner/Tunnel/`、`ios/NECore/`、`ios/Shared/`、`ios/Widget/`、`plugins/wifi_ssid/ios/` |
| `6a85072ee40250d5e05aa7fd3e036904af313346` | **已由后续结构替代**：NECore 不依赖 Flutter。未恢复已经被 SPM 提交删除的 `Flutter/NECore.xcconfig`；NECore 仅链接 low-memory Go archive、系统框架和纯原生 Shared 静态库。 | `ios/Runner.xcodeproj/project.pbxproj` 的 NECore Frameworks、`ios/NECore/NECoreBridge.m` |
| `5d80e40801ebeea81d7b79c40a7758fde39bd5dd` | **已迁入最终构建配置**：项目修正包含在最终 PBX 树中；没有回滚后续 SPM 和本地签名参数化。 | `ios/Runner.xcodeproj/project.pbxproj` |
| `446f2159ded1f3c72d2791c524577747ee955fee` | **已迁入**：本地 `FlutterGeneratedPluginSwiftPackage`、Flutter framework prepare、Wi-Fi Swift package。参考删除的固定 Podfile/lock 继续保持删除；macOS Flutter 工具会按实际依赖自动补 CocoaPods fallback。 | `ios/Runner.xcodeproj/project.pbxproj`、`ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`、`plugins/wifi_ssid/ios/wifi_ssid/Package.swift` |
| `7526372c6a68696dac4927a6ee6ac1d220a5a26e` | **原生已迁入**：`recvMsgX`、`sendMsgX` 解码并传给 Core TUN；缺省值保留。Dart 设置和平台开关由对应审计负责，不替换原生接口。 | `ios/NECore/PacketTunnelSharedStateStore.swift`、`ios/NECore/PacketTunnelProvider.swift` |
| `fff98bb70a41a5d9af44c1137eab8d31ee5f3479` | **已迁入**：回到前台只刷新状态，不把观察结果解释为重新启动意图。 | `ios/Runner/Tunnel/TunnelController.swift` 的 `startObserving`、`TunnelCoordinator.requestStatusRefresh` |
| `68ae229833b42b63d67bcb109e087d16d791bdc1` | **原生已迁入**：拥塞控制器选项解码并通过 `CoreTunOptions` 传递；不把具体栈名称或默认值硬编码在 native。 | `ios/NECore/PacketTunnelSharedStateStore.swift`、`ios/NECore/PacketTunnelProvider.swift` |
| `f713793ae8bed112a8b30a084940beb31cb71ed8` | **原生已迁入**：PacketTunnel 不因设备睡眠调用停止/重启 Core；TUN 完整选项通过桥接传递。Go/Android 部分不在本文件所有权范围。 | `ios/NECore/NECoreBridge.h`、`ios/NECore/NECoreBridge.m`、`ios/NECore/PacketTunnelProvider.swift` |
| `0d764e8b8fddcfd35860e6b6dd8e255d777b5deb` | **拒绝标识迁移，保留技术结构**：`cc.chenx.flclash` 是另一发行身份，会改变 App Group、VPN extension、持久化目录和 method-channel；本项目保留 `com.follow.clash`，自定义 bundle/team 由本地生成配置传入，不写个人签名团队。 | `ios/Flutter/Debug.xcconfig`、`ios/Flutter/Release.xcconfig`、`ios/Runner/ServiceChannel.swift`、三份 entitlements |
| `05e0f44ccd0c567a0150cc70c2fbbbe398f8c854` | **已迁入最终资源**：AppIcon 改用 SVG 与 Icon Composer 目录；未恢复被删除的旧 PNG。 | `ios/Runner/AppIcon.icon/` |
| `3b6d1579cafcbb8865a4c2b7a376dae1b17c8b68` | **原生已迁入**：发布 `pending/connected/disconnected`，让网络检测等待实际 tunnel readiness。Dart 的 readiness 使用在对应审计中核对。 | `ios/Runner/ServiceChannel.swift`、`ios/Runner/Tunnel/TunnelCoordinator.swift` 的 `publishConnectionState` |
| `354bea5e7397f1195247cd1b9ae5d6d2a94a1269` | **已迁入**：状态观察经 `syncRunningState` 同步，不回放 start/stop；on-demand preferences 更新归串行 coordinator。 | `ios/Runner/ServiceChannel.swift`、`ios/Runner/Tunnel/TunnelCoordinator.swift`、`ios/Runner/Tunnel/TunnelManagerStore.swift` |
| `d4369bc5b41a5b8f0af5976eac3f19c558031852` | **已迁入最终资源**：蓝色图标调色；对应 SVG 与 Patched tip 一致。 | `ios/Runner/AppIcon.icon/Assets/icon.svg` |
| `aaf0755da58010b210b23627cfc3134819928d74` | **已迁入最终资源**：统一启动图与 app icon，改用 `LaunchLogo`。唯一未保留文件为说明引用缺失脚本的模板 README；它不是运行资源，也不是构建输入。 | `ios/Runner/Assets.xcassets/LaunchLogo.imageset/`、`ios/Runner/Base.lproj/LaunchScreen.storyboard` |
| `323f678d2f4fed3aa08a409cdfbb2e06a32e95b0` | **原生已迁入**：`zh-Hant` 声明和 Runner/Widget 的繁体中文 string catalogs。 | `ios/Runner/Info.plist`、`ios/Runner/InfoPlist.xcstrings`、`ios/Runner/Localizable.xcstrings`、`ios/Widget/Localizable.xcstrings` |
| `697755c953a3a7f56c7dba04ef979ee0aa4d49f3` | **原生已迁入并兼容主线模型**：保存启动时原始 VPN options，`getActiveVpnOptions` 返回完整快照；重启提示可比较实际正在运行的配置。另兼容主线 `dnsHijacking` 字段并把 MTU ≤ 0 归一至 9000。 | `ios/NECore/PacketTunnelSharedStateStore.swift`、`ios/NECore/PacketTunnelProvider.swift`、`ios/Runner/Storage/SharedStateStore.swift`、`ios/Runner/ServiceChannel.swift` |
| `bae8dd9b01456acd8f450bd0c53e1d5a5b6e23b3` | **已迁入**：启动/停止请求用 generation 维持最新意图；unknown/intermediate NE 状态不伪装成 stopped；并发 manager load 与 preference stale retry 仍由单一 native owner 处理。 | `ios/Runner/Tunnel/TunnelCoordinator.swift`、`TunnelManagerStore.swift`、`TunnelTypes.swift`、`ios/Runner/ServiceChannel.swift` |
| `10332be8866854065c407cb26b3c05fd96ae1545` | **原生已迁入**：控制中心名称遵守 `showQuickSettingsProfileName`，相关显示状态变化才 reload control。Dart 字段由对应审计交付。 | `ios/Runner/Storage/SharedStateStore.swift`、`ios/Widget/WidgetControl.swift` |
| `95a06882d436f4433b8e01a8c2f623ded49e65e1` | **已迁入并强化**：桌面 start/stop/toggle 快捷操作、冷启动意图折叠；当前移植在 Flutter 初始化并明确 safe-mode 后才执行积压操作。 | `ios/Runner/Info.plist`、`ios/Runner/InfoPlist.xcstrings`、`ios/Runner/SceneDelegate.swift`、`ios/Runner/ServiceChannel.swift` |
| `3814b935fa5de23e72e744b367b2f77ac55d8aec` | **已迁入**：IPv4 使用基准测试网段 `198.18.0.0/15` 内的 `198.18.0.1/30` 和 `198.18.0.2` DNS；与 Android 的地址设计保持兼容。 | `ios/NECore/PacketTunnelNetworkConfiguration.swift` |
| `3ac6f36dc30ba0b6d0c53ab9eadbcbfe777d9bc5` | **原生已迁入**：桌面状态 Widget、profile 名称、VPN toggle、主题与 AppLogo；NE 生命周期及共享展示状态变化触发 reload。保留本移植修正：`SetValueIntent` 按 SDK 要求标记 iOS 18。 | `ios/Widget/WidgetStatus.swift`、`WidgetSharedState.swift`、`WidgetBundle.swift`、`ios/Shared/Intent.swift`、`ios/Runner/Storage/SharedStateStore.swift` |

## 明确保留的移植强化

1. **安全模式在原生 owner 检查**：`ServiceChannel` 初始化接收 bool，快捷操作等待初始化；AppIntent、service start/stop、NE start 和 on-demand preference 写入均检查共享标记。Patched 的无保护入口不覆盖这些行为。
2. **状态事件与日志分开承压**：`ios/Shared/CoreEventBacklog.swift` 对 `loaded` 按 provider、`geoUpdate` 按 type、`routeChanged` 按快照合并；状态与 transient 有各自容量上限，旧文件 ACK 不删除新代。`NECoreEventQueue` 用锁统一 callback/恢复路径。拒绝回退至 Patched 的十文件统一裁剪和全量暂停。
3. **主线 Core 协议**：`CoreNotificationCoordinator` 使用 `startLog/stopLog/watchRoute(bool)`，替代参考旧 `*Notify` 方法。route watcher 随 App/NE 迁移；不恢复不存在于主线的 request-notify 协议。
4. **实际 Core 写一致性**：`CoreMessageRouter` 的 NE transport 错误保留错误 envelope/id，不回退备用 App Core；否则 proxy/provider/connection 修改可返回假成功。App-only 工具方法仍显式路由 App，稳定断开后普通方法自然路由 App。
5. **主线非运行 App Core 不监听网络**：App `updateConfig` 的 external-controller 始终清空；Go 层处理共享配置中的其他 listener/controller gate，不改共享 YAML。原生和 Go 职责不倒退成前台/后台两个并行网络 owner。
6. **Wi-Fi 插件懒初始化和并发 permission replies**：保留 `WifiSsidPlugin` 的 lazy CLLocationManager、请求数组、未确定状态不提前完成、未授权不读取 SSID、回调回到主队列。拒绝恢复参考的单 pending reply 和注册时主动接触 locationd。
7. **构建与身份**：保留 GeneratedBundleConfig 的 ignore 规则、RunnerTests 的可覆盖 bundle ID、Shared 对 NECore/测试目标的链接；不引入 `cc.chenx.flclash` 或个人 development team。

## 交界与验证

原生已有 `includeAllNetworks/excludeLocalNetworks/excludeAPNs/excludeCellularServices/enforceRoutes/excludeDeviceCommunication`、ICMP、拥塞控制器、Darwin msgx、SSID/on-demand、Widget 主题和 profile-name 的接收与执行路径。基线 `endpointIndependentNat` raw 字段只保留协议兼容；当前 sing-tun 不读取它，不能宣称生效或为它新增设置。有效字段由 Dart 设置公开和传入的整合由对应审计负责；没有重复实现另一套模型。

本轮跨域整合新增 `43964ff168f66bbc315fab0be22a384e89397902` 的 Age key 工具时，已把 `generateAgeKeyPair` 和 `convertAgeSecretKeyToPublicKey` 加入 `CoreMessageRouter.AppCoreMethod`，避免连接 VPN 后把纯密钥工具操作送进 NE 的受限内存进程。`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` 的 `getCoreVersion` 保留默认 active-Core 路由。最终保留原核 8380 后，依赖新内核的 Overlay runtime API 已撤出产品。RunnerTests 用 sender seam 验证 VPN 已连接时两项 Age 工具走 App、版本查询仍走 NE。

构建、Rust、Go TUN/缓存与 UI-only 的相关提交不伪记为本文件完成：例如 `9d8b8ea0c2fa15009d88b39b53aee4d519b95ddf`（Rust libc/backtrace）、`9c65454dcf82b47a26ab3e61a16b576081710550`（Rust framework alignment）、`5f6e0fb022bd5646c19b51e9afc3ae0b5406074c`（system stack）、`32ca96eb5c8af04108b5dc73fd264d5cce785695`（栈选择）和 `a84e571099fe1392b55e051ab76d892ff7f9e0a6`（内存详情）。它们已通知对应所有者跨域核对。

本轮窄验证：解析 plist/entitlements/xcsettings、JSON/string catalogs 和 XML 资源；检查 PBX 对象引用/目标 build phase/源文件路径；比较 Patched 最终资源树及 native protocol 路由表。既有 `ios/RunnerTests/RunnerTests.swift` 覆盖冷启动意图折叠、route subscription 迁移、NE 错误不假成功、有界状态积压和旧代 ACK。

当前执行环境为 Linux，缺少 Xcode、Apple SDK 与 swiftc；上述 XCTest、实际链接、签名、PacketTunnel 生命周期、SSID 权限、后台、Widget 和真实设备网络行为未在此环境执行。参考工程使用 Icon Composer 和 iOS 26 API，实际构建要求 Xcode 26+；应用/NE 最低 iOS 15，Widget 最低 iOS 18。静态检查不等价于实际 IPA 或 VPN 运行验证。

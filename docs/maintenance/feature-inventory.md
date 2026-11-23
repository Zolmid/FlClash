# ZolNit 功能清单

本清单按能力记录实际的入口、状态所有者、存储、后台行为、平台和测试链。它记录的是“在源码中可见”的路径，不是对每条路径都已证明会被执行。证据状态使用四个词区分：**存在**（代码在仓库中）、**可达**（生产路由或启动路径能调用到）、**启用**（门控或平台条件为真）、**验证**（有测试或设备证据）。

处置一栏只用于保守的产品决定：`keep`（保留）、`isolate`（隔离但保留）、`unknown`（未核对）。本次没有批准任何退役，也没有把“没有直接引用”当作死代码证明。

初始基线为 `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6`，收件箱协调补充到 `7fd40a7a4777047b554a786ea4085ec1d62a0240`；依据为 2026-11-15 的源码与明确验证记录。

| 能力 | 入口（UI / 非 UI） | 状态所有者与存储 | 后台与平台 | 测试 | 证据状态 | 处置 |
|---|---|---|---|---|---|---|
| 登录 | [auth.dart](../../lib/views/zolnit/auth.dart)；启动恢复 | `ZolnitSessionController`；安全存储 | 全平台 | `test/views/zolnit/auth_test.dart`，`auth_restore_test.dart` | 存在、可达、验证（widget） | keep |
| 注册返回 | `zolnit://auth/register`（[link.dart](../../lib/common/link.dart)）→ [application.dart](../../lib/application.dart) 第 139 行 | [providers/zolnit_registration.dart](../../lib/providers/zolnit_registration.dart) `accept` | 全平台 | `test/views/zolnit/auth_test.dart` 的 PKCE callback 与 `test/common/link_test.dart` | 存在、可达、已有单元测试 | keep |
| 网页单点登录 | [web_session.dart](../../packages/zolnit_client/lib/src/web_session.dart)；[providers/zolnit_web_session.dart](../../lib/providers/zolnit_web_session.dart) | `ZolnitWebSessionCoordinator`；一次性授权码和浏览器短期会话 | 第一方 landing 页；账号变化关闭浏览器，失败用无凭据 fallback | 包内 `web_session_coordinator_test.dart` | 存在、首页/更新入口可达；不需要 App 深链返回 | keep |
| 会话安全存储 | 登录与退出 | `session_vault.dart`；钥匙串（插件默认服务名） | 平台钥匙串 | `test/providers/zolnit_vault_test.dart` | 存在、可达、验证（单元） | keep |
| 订阅 bundle 同步 | 启动与同步动作 | `zolnitSyncCurrentClientBundleProvider`；Drift profile | 自动同步由 `ZOLNIT_CLIENT_BUNDLE` 控制；全平台 | `test/providers/zolnit_bundle_test.dart`，`zolnit_profile_test.dart` | 存在、启用取决于编译参数、验证（单元） | keep |
| 签名订阅 v2 与撤销 | bundle 同步的内部路径 | `SignedSubscriptionVerifier`；随 Core 打包的 trust 资源 | 全平台 | `packages/zolnit_client/test/signed_subscription_test.dart` | 存在、可达、验证（单元） | keep |
| 路由与探测 | [routing 页面与节点](../../lib/views/zolnit/nodes.dart)；`ZolnitRouting` | `ZolnitRouting`；内存 | 探测 30 秒或 60 秒；前台恢复 | `test/providers/zolnit_routing_test.dart` | 存在、可达、验证（单元） | keep |
| 返回路由（分派绑定） | Core 分组绑定 | [common/zolnit_return_route.dart](../../lib/common/zolnit_return_route.dart)；Go 的 `core/clientbundle/return_route.go` | 随 Core | `test/common/zolnit_return_route_test.dart` | 存在、可达、验证（单元） | keep |
| 实时消息 | 首页消息入口 | `ZolnitRealtimeChannel`管传输，`ZolnitInboxCoordinator`管快照/撤回/未读/重试，偏好store串行持久化；WS 不健康时经 `XboardClient._preferLive` 落回 HTTP（[architecture.md](architecture.md) 3.4 节） | WebSocket；退避基准上限 180 秒，另加抖动 | `test/views/zolnit/realtime_withdraw_test.dart`，`realtime_home_test.dart` | 存在、可达、验证（widget） | keep |
| 套餐与订单 | [plans.dart](../../lib/views/zolnit/plans.dart)，[orders.dart](../../packages/zolnit_client/lib/src/orders.dart) | 订单查询 | 全平台 | `test/views/zolnit/plans_test.dart` | 存在、可达、验证（widget） | keep |
| 收银台（Hosted） | [cashier.dart](../../lib/views/zolnit/cashier.dart) | `CheckoutController` | 系统浏览器；direct 渠道 | `test/views/zolnit/cashier_test.dart` | 存在、启用需 `allowStripe`、验证（widget） | keep |
| 连续包月 | 套餐页的续费选项 | [billing_api.dart](../../packages/zolnit_client/lib/src/billing_api.dart)；同意条款仅在进程内 | direct 渠道 | 包内 `renewal_state_test.dart` | 存在、启用需 direct、验证（单元） | keep |
| Apple 内购 | [apple_plans.dart](../../lib/views/zolnit/apple_plans.dart)；[providers/zolnit_apple.dart](../../lib/providers/zolnit_apple.dart) | `ApplePurchaseController`；StoreKit 保留未完成交易 | iOS 与 macOS 的 `appleAppStore` 渠道；默认为 iOS 与 macOS 的渠道 | `test/views/zolnit/apple_plans_test.dart` | 存在、默认启用于 iOS 与 macOS、StoreKit 未设备验证 | keep |
| 原生 Stripe（Android） | `platform_payments.dart` | 无 | Android；`payment_sheet` 能力 | 包内测试未在本次核对 | 存在、启用需 Android 与 direct | isolate |
| 微信支付（移动端） | `platform_payments.dart` | 无 | `ZOLNIT_WECHAT_APP_ID` 为空时返回 `sdk_unavailable` | 未在本次核对 | 存在、**禁用（用户决定）**，不得视为已启用 | isolate |
| 礼品卡 | [rewards.dart](../../lib/views/zolnit/rewards.dart) | `ZolnitGiftCardAttempt`；偏好存储 | 全平台 | `test/views/zolnit/rewards_recovery_test.dart`，`rewards_test.dart` | 存在、可达、验证（widget） | keep |
| 邀请 | [invite.dart](../../lib/views/zolnit/invite.dart)；[invite.dart](../../packages/zolnit_client/lib/src/invite.dart) | 邀请页面 | 生成邀请码为网络写操作 | `test/views/zolnit/invite_test.dart` | 存在、可达、验证（widget） | keep |
| 推荐优惠 | [plans.dart](../../lib/views/zolnit/plans.dart) 的 `_loadReferralOffers` | 客户端 `referralOffer` | 全平台 | 未在本次核对 | 存在、可达 | keep |
| 账户与密码 | [account.dart](../../lib/views/zolnit/account.dart)，[password.dart](../../lib/views/zolnit/password.dart) | 账户快照 | 全平台；写操作需要明确确认 | `test/views/zolnit/account_test.dart` | 存在、可达、验证（widget） | keep |
| 工单（支持） | [help.dart](../../lib/views/zolnit/help.dart)；包内 [support.dart](../../packages/zolnit_client/lib/src/support.dart) | 包内客户端 | 网络写操作 | `test/views/zolnit/help_test.dart`；包内 support 测试 | 首页 `_openHelp` 可达；支持工单列表/创建/回复/详情 | keep |
| 独立每日流量明细 | 包内 [traffic.dart](../../packages/zolnit_client/lib/src/traffic.dart) 的 `ZolnitTrafficClient.log` | API 数据模型 | 网络读取 | `packages/zolnit_client/test/traffic_test.dart` | 包能力存在，检查的生产视图未见独立明细页；`views/zolnit/data.dart` 是格式化/错误文案工具，不是流量页面 | keep（保留包能力） |
| 节点与节点组 | [nodes.dart](../../lib/views/zolnit/nodes.dart)，[node_groups.dart](../../lib/views/zolnit/node_groups.dart) | Core 选择器 | 切换需 Core 已连接且非安全模式 | `test/views/zolnit/nodes_test.dart`，`node_groups_test.dart` | 存在、可达、验证（widget） | keep |
| 公告 | 首页 `_openNotices` → [showZolnitNotices](../../lib/views/zolnit/notices.dart) | session noticeList + 账号作用域 inbox/canonicalNotices | 代际/修订失效时关闭弹窗；已读可经 WS 或 HTTP 写入 | `test/views/zolnit/realtime_home_test.dart`、`realtime_withdraw_test.dart` | 存在、可达；弹窗和撤回有 widget 测试 | keep |
| 更新与安装 | [update.dart](../../lib/views/zolnit/update.dart)；[app_update.dart](../../lib/common/app_update.dart)；Android `ApkInstaller.kt` | 更新状态 | Android 安装需 `REQUEST_INSTALL_PACKAGES` | `test/views/zolnit/update_test.dart` | 存在、可达、验证（widget）；下载与安装未在本次执行 | keep |
| 深链：支付返回 | `zolnit://safepay`（[link.dart](../../lib/common/link.dart)）→ [application.dart](../../lib/application.dart) 第 134 行 | `session.refreshPayment()` | Android 与 iOS 与 macOS 的 scheme | 未在本次按名称核对 | 存在、可达、支付返回未真机验证 | keep |
| 深链：旧版安装配置 | `install-config?url=`（[link.dart](../../lib/common/link.dart)） | `addProfileFromLink` | 全协议列表 | 未在本次按名称核对 | 存在、可达 | keep |
| 原生首页 | [native_home.dart](../../lib/views/zolnit/native_home.dart)；插件 | 原生快照 | 门控 `ZOLNIT_NATIVE_UI`；**无生产挂载** | `test/views/zolnit/native_home_test.dart` | 存在、**不可达**、验证（widget，测试构造） | unknown |
| Android 系统入口（磁贴、小部件、Intent） | [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)；[plugins/tile.dart](../../lib/plugins/tile.dart) | `ServiceState` | Android | `android/tests/app/ServiceStateMachineTest.kt` | 存在、可达、验证（Kotlin 单元，运行方式未核对） | keep |
| iOS 快捷操作与 Widget | [ShortcutProvider.swift](../../ios/Runner/ShortcutProvider.swift)；Widget 目标 | `TunnelCoordinator` | iOS 18 Widget | 未在本次核对 | 存在，设备验证缺失 | keep |
| 桌面托盘 | [common/tray.dart](../../lib/common/tray.dart) | 托盘状态 | 桌面 | `test/common/tray_lifecycle_test.dart` | 存在、可达、验证（单元） | keep |
| 启动守护 | [boot_guard.dart](../../lib/common/boot_guard.dart)，[boot_record.dart](../../lib/common/boot_record.dart)；落地于 [bootstrap.dart](../../lib/bootstrap.dart) | `BootGuard`；偏好存储的 `BootRecord` | 仅 Android；影响启动流程与自动连接 | `test/common/boot_guard_test.dart`，`boot_record_test.dart`（见 [testing-and-debugging.md](testing-and-debugging.md) R11） | 存在、可达、验证（单元） | keep |
| 自动更新配置定时器 | [profile_auto_updater.dart](../../lib/common/profile_auto_updater.dart) | `ProfileAutoUpdater`；每个 profile 的最近成功/尝试时间 | 单次串行更新；失败也记尝试时间，避免循环；dispose 取消定时器 | `test/common/profile_auto_updater_test.dart` | 存在、可达，已有失败/重调度测试 | keep |
| 备份与恢复 | [backup.dart](../../lib/common/backup.dart) | 归档文件（zip：配置 JSON、Drift 快照、profile/脚本/非远程 provider） | 全平台 | `test/common/backup_task_test.dart`（见 [testing-and-debugging.md](testing-and-debugging.md) R9） | 存在、可达、验证（单元） | keep |
| 旧版 Clash 导入 | [protocol.dart](../../lib/common/protocol.dart) 的协议列表；[link.dart](../../lib/common/link.dart) | profile | 全平台 | 未在本次核对 | 存在、可达 | keep |

## 未扫描的范围

本清单没有穷尽调用图。以下部分在本次没有逐行核对：`lib/views/config/` 下的设置页面、`lib/views/dashboard/`、`lib/manager/`、`lib/providers/state/` 中的系统状态、`lib/plugins/battery.dart` 与 `lib/plugins/app.dart`、Android `ServicePlugin` 与 `ServiceController` 的全部调用者、iOS Widget 的全部系统运行情景、Windows 原生视图的设备运行路径。新增或退役任何能力前，都要先在这些区域中补充扫描。

服务路由手动组保留账号授权的全部节点及 DIRECT；服务面板只展示当前 Core 手动组中仍存在的授权节点，并持久化明确选择。自动组仅使用签名资格（含 operator_allowlist 的出站指纹匹配）与当前服务探测；普通延迟测试不产生服务资格。当前线路沿 Core 的实际选择链解析，循环或缺失成员视为未知；没有当前服务探测通过的自动线路时显示未验证说明，不由普通测速推断全部失败。五平台皮肤、24 条授权/4 条 US/JP 资格形态与迟到响应由 `test/views/zolnit/bundle_routing_test.dart`、`test/common/zolnit_routing_test.dart`、`core/client_bundle_routing_test.go` 覆盖；这些是离线测试，不代表设备验收。

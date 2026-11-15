# ZolNit 测试与排障

本文提供可执行的诊断步骤。每条步骤都标明输入、错误码、日志位置、函数或命令、预期观察、停止条件和升级路径。依据为 `main` 基线 `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` 的源码阅读（2026-11-15）；本文新增的文档工作未重新运行这些应用测试。已有执行结果单独见 [验证基线](verification-baseline.md)。

所有命令默认只读或只运行本地单元测试。不使用真实账号、真实支付或真实网络请求。需要真实环境的步骤单独标注“仅在授权后执行”。

## 1. 证据等级与历史证据

| 等级 | 含义 | 本仓库已有的证据来源 |
|---|---|---|
| V0 | 静态分析、格式、生成一致性 | CI 的 `flutter analyze`、`dart format`、`dart analyze`（[build.yaml](../../.github/workflows/build.yaml)） |
| V1 | 纯逻辑与契约测试 | 第 3 节列出的测试文件与测试名 |
| V2 | 平台编译、打包元数据 | CI hosted 构建（D0 阶段，全部平台已通过编译与打包） |
| V3 | 指定设备的安装、运行、原生场景 | 控制台记录的 1.1.9 历史验收：Linux 隔离更新、iOS 注册设备 OTA、Windows 登录诊断已暂停；APK 验签本身归入构建/签名证据，不算 V3 |
| V4 | 签名、公证、正式渠道发布后的校验 | 1.1.9 的正式发布与公开清单校验（控制台记录，[验证基线](verification-baseline.md)） |

表中 1.1.9 的 V3/V4 历史证据不能认证新主线；D0 的 V0/V1/V2 有独立 CI/本地结果，详见验证基线。新的 D0 开发构建（hosted CI）只证明编译与打包路径。本文的 doc-only 工作不产生 V1 以上的运行证据。因此 V4 证据已存在于历史 1.1.9 发布中，不应写成“不存在”。

## 2. 诊断通用流程

1. 记录版本：`git -C <checkout> rev-parse HEAD`，并记录 `flutter --version`。
2. 复现分层：先在 V1 单元测试中复现，再考虑设备。
3. 只改变一个变量。
4. 日志脱敏后保存：不记录令牌、支付 secret、原始深链 URL。
5. 停止条件出现时停止，升级给对应的所有者。

Flutter 界面日志：`CommonPrint.log`（[print.dart](../../lib/common/print.dart)）只做两件事——`debugPrint` 和（容器已挂载时）把一条 `Log` 追加进 `logsProvider` 持有的 `FixedList<Log>`。这是**纯内存**的环形缓冲，容量 `maxLogsLength`，这条 Flutter 日志链不持续落盘；显式导出时：[providers/app.dart](../../lib/providers/app.dart) 的 `Logs.exportLogs()` 把 `encodeLogsTask(value.list)` 的结果写到 `appPath.tempFilePath`（临时目录），再调用 `picker.saveFileWithPath(logFileName, tempFilePath)` 让用户选择最终落盘位置；导出文件名由 [path.dart](../../lib/common/path.dart) 第 220 行的 `logFileName` 生成，格式为 `${appName}_${DateTime.now().show}.log`。因此获取这份 Flutter 日志应使用应用内导出，不能假设固定目录里有它的历史文件；进程重启或崩溃会丢失尚未导出的内存日志。深链接收日志只写 `onAppLink received`，不写 URL（[link.dart](../../lib/common/link.dart)）。原生日志另行处理，例如 iOS NECore 的 `NECoreBridge.m` 使用 `os_log`，`PacketTunnelProvider.swift` 使用系统 Logger；这不属于 Flutter 缓冲区。构建钩子日志见 `.agents/commands.md` 的 hook.log 路径。

## 3. 诊断配方

### R1 登录恢复与账户切换

- 输入：已保存的登录令牌；安全存储键 `zolnit.session.authorization.v1`。
- 错误码：`storage_unavailable`（安全存储读写失败）、`unauthenticated`（401，或账户身份查询中明确的会话失效 403；普通未知 403 不登出）、`superseded`（同步被更新的请求取代）。
- 函数：`ZolnitSessionController`、`SecureZolnitSessionVault.deleteAuthorization`、`zolnitSyncCurrentClientBundleProvider`。
- 命令（V1）：`dart run tool/test.dart test/providers/zolnit_vault_test.dart test/views/zolnit/auth_restore_test.dart test/providers/zolnit_profile_test.dart`
- 测试名：`test/providers/zolnit_vault_test.dart` 中的 `native retirement starts even while credential deletion waits`；`test/views/zolnit/auth_restore_test.dart` 中的 `pending automatic restore cannot disable sign-in`；`test/providers/zolnit_profile_test.dart` 中的 `logout during validation cannot publish a late profile`。
- 预期：三个文件全部通过。
- 停止条件：令牌有效但 `storage_unavailable` 反复出现。此时不要清空安全存储；记录平台、钥匙串状态与代际号，升级给客户端所有者。
- 授权后的真实环境检查：不属于默认步骤。

### R2 签名订阅 v2、bundle 对象与撤销

- 输入：订阅信封 JSON（`kind` 为 `bundle`、`revoked` 或 `state`）；随 Core 打包的 trust 资源。
- 错误码：`invalid_signed_subscription`、`invalid_client_bundle`、`client_bundle_expired`、`client_bundle_binding_mismatch`、`invalid_client_context`。
- 函数：`SignedSubscriptionVerifier.fromTrustJson`、`ZolnitClientBundle.parse`（`_timestamp` 解析过期时间）。
- 命令（V1，包内）：`cd packages/zolnit_client && flutter test test/signed_subscription_test.dart`
- 测试名：`production empty trust map and tampering fail closed`；`v2 capability never gates legacy or third-party subscriptions`；`state is verified but never projects credentials`；`production trust asset format yields pins only when populated`。
- 预期：全部通过。空 trust map 与篡改的信封必须失败关闭。
- 停止条件：需要启用签名订阅 v2 的构建却缺少预期 trust pins。核对 capability、资源打包和发布配置；空 map 会使 v2 校验失败关闭，但不能据此把 legacy/第三方订阅也禁用，更不能绕过签名校验。
- bundle 过期与撤销：过期的 bundle 不写入 profile，撤销信封不作为 `bundle` 处理。相关 Dart 测试见 [test/providers/zolnit_bundle_test.dart](../../test/providers/zolnit_bundle_test.dart)，测试名以文件内 `test(` 的描述为准，本次未逐个列出。

### R3 路由与返回路由

- 输入：一份 Core 分组配置（`proxy-groups`）与 bundle 的路由段。
- 错误码与状态：`AI 自动` 与 `AI 手动` 分组的 `proxies`；`REJECT` 表示被阻断。
- 函数：`ZolnitReturnRoute.resolve`、`ZolnitRouting`、`RoutingProbeScheduler`。
- 命令（V1）：`dart run tool/test.dart test/common/zolnit_return_route_test.dart test/common/zolnit_routing_test.dart test/providers/zolnit_routing_test.dart`
- 测试名：`test/common/zolnit_return_route_test.dart` 的 `explicit dispatch bindings start local and observe both Core parents`；`test/providers/zolnit_routing_test.dart` 的 `a changed configuration does not inherit the prior lease`；`test/common/zolnit_routing_test.dart` 的 `ordinary server selection is independent of AI automatic groups` 的同文件用例。
- 包内探测：`packages/zolnit_client/test/routing_http_health_test.dart`。
- Go 侧（CI 同样运行）：`cd core && CGO_ENABLED=0 go test -count=1 ./clientbundle`。
- 预期：通过。
- 说明：**`test/common/zolnit_return_route_test.dart` 测的是分派绑定与 Core 分组，不是支付返回。** 支付返回见 R6。
- 停止条件：Dart 与 Go 的返回路由结果不一致。两端都要修，不能只改一端。

### R4 实时通道：WebSocket 与重连

- 输入：票据响应、`wss` 连接结果、服务端的 `hello`、`resync` 与 `ping/pong`。
- 错误：`FormatException`（生产 origin 不是 `https://link.zolmid.com`，或票据的 subject 与作用域不一致，消息为 `realtime subject`）。
- 超时：打开阶段 20 秒；发送 hello 后等待 ready 30 秒；ready/pulse 后默认 150 秒存活期限；RPC 默认 8 秒；ping 每 35 秒；resync/事件回调 22 秒；连接 12 秒；HttpClient 8 秒。
- 退避：`_attempt` 上限 8，延迟 `min(180, 2^attempt)` 秒乘 0.75–1.25 的抖动。
- 函数：`ZolnitRealtimeChannel._open`、`_fail`、`_connect`（[realtime.dart](../../packages/zolnit_client/lib/src/realtime.dart)）。
- 命令（V1）：`dart run tool/test.dart test/views/zolnit/realtime_withdraw_test.dart test/views/zolnit/realtime_home_test.dart`
- 包内实时测试未在本次列出测试名。先运行 `rg -l -i realtime packages/zolnit_client/test` 找到文件，再读取其中的测试名。
- WS→HTTP 回退：`realtimeInbox` 用 `_preferLive('inbox.list', ...)`，失败后的 REST 路径是 `GET /api/v1/zolnit/client/realtime/inbox`；它真实存在。已读写入由 `home._markRead` 先尝试 WS 的 `inbox.read`，重核代际后才可使用 `POST /api/v1/zolnit/client/realtime/read`。其他读取方法的 fallback 见架构 3.4。`unsupported` 只影响当前协商方法集合，后续 ready 可恢复，不是永久禁用。
- 包内确定性测试入口：`packages/zolnit_client/test/realtime_reads_test.dart`、`realtime_test.dart`；读源码确认各测试所断言的代际、回退、重连和协商条件，不只运行页面测试。
- 预期：`liveReads` 不可用（未附加、代际不符、`supports` 为假、或 `read` 超时返回 null）时，上述方法按合同落到 HTTP；HTTP 自身仍可能报业务/网络错误。若等待 WS 时账号代际已变化，`_preferLive` 抛 `superseded`，不得继续用旧账户结果或伪造成功。
- 复现建议：构造一个假的 `ZolnitLiveReads`，让 `supports` 返回 false 或 `read` 返回 null，断言调用方确实走了传入的 `http()` 回调；或者让 `ZolnitRealtimeChannel` 始终不建立连接，确认 `liveReads` 一直为 null。
- 停止条件：持续无法建立连接时记录 `_attempt`、失败阶段与脱敏票据状态。退避基准上限 180 秒还要乘抖动，单次等待可接近 225 秒；“超过 3 分钟”本身不是代码违约或卡死证明。
- 仅在授权后：连接真实 `link.zolmid.com`。

### R5 礼品卡兑换与幂等

- 输入：兑换码（不记录原文）。
- 错误码：`invalid_idempotency_key`（键不匹配 `^[A-Za-z0-9_-]{8,128}$`）。
- 函数：`ZolnitGiftCardAttempt`，偏好存储的 `write(cardHash, requestId)` 与 `remove(cardHash, requestId)`，兑换接口 `redeem(code, idempotencyKey)`（[rewards.dart](../../packages/zolnit_client/lib/src/rewards.dart)）。
- 命令（V1）：`dart run tool/test.dart test/views/zolnit/rewards_recovery_test.dart test/views/zolnit/rewards_test.dart`
- 测试名：`test/views/zolnit/rewards_recovery_test.dart` 的 `test(` 用例（描述见文件）。
- 预期：同一卡的未完成请求在重启后复用同一请求 ID；成功后移除记录。
- 停止条件：同一兑换码两次成功兑换。这是服务端幂等失败的信号，记录两个请求 ID 的时间差，升级给奖励接口所有者。

### R6 支付与权益确认

- 输入：订单号（`tradeNo`）与订单状态。
- 状态：`1` 为开通中，`3` 为完成，`4` 为折抵。只有 `3` 才显示完成。
- 错误码：`payment_status_unknown`（超时、408 或 5xx）、`invalid_order_status`、`pending_order`、`quote_expired`、`checkout_exists`、`checkout_processing`、`rate_limited`。
- 函数：`CheckoutController`（[checkout.dart](../../packages/zolnit_client/lib/src/checkout.dart)）、`poll(interval, attempts)`（默认 3 秒、40 次）、`refreshPayment`（[application.dart](../../lib/application.dart) 第 134 行附近的回调）。
- 命令（V1）：`dart run tool/test.dart test/views/zolnit/cashier_test.dart test/views/zolnit/plans_test.dart`
- 测试名：`test/views/zolnit/cashier_test.dart` 的 `awaiting payment keeps retry and cancellation available`，以及 `terminal order $status removes payment controls`（参数化）。
- 预期：未完成的订单保留重试与取消，终止状态移除付款控件。
- 停止条件：订单显示完成但服务端状态不是 3。不要从客户端授予权益；升级给支付所有者。
- 支付返回：`zolnit://safepay` 只触发 `refreshPayment`，不授予权益。
- 仅在授权后：任何真实扣款、真实收银台或真实 SDK 回跳。默认不执行。

### R7 原生界面命令与生命周期

- 输入：原生侧的 `performCommand`，携带 `accountGeneration`、`id` 与 `action`。
- 拒绝码（来自 [native_home.dart](../../lib/views/zolnit/native_home.dart)）：`stale_account`、`safe_mode`、`unauthenticated`、`unavailable`、`failed`。
- 函数：`ZolnitNativeHome._command`、`_checkAvailability`、`NativeUiBridge.dispose`。
- 门控：`ZOLNIT_NATIVE_UI`。
- 命令（V1，门控为真）：`flutter test test/views/zolnit/native_home_test.dart --dart-define=ZOLNIT_NATIVE_UI=true`（CI 在 macOS 安全预览中以 `--dart-define=SAFE_MODE=true` 运行，见 [cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 222 行）。
- 测试：`test/views/zolnit/native_home_test.dart` 中的 `testWidgets` 用例，名称以文件为准。
- 预期：过期代际的命令被拒绝；安全模式不接受连接命令。
- 当前限制：生产首页不挂载 `ZolnitNativeHome`。这是源码观察（见 [platform-contracts.md](platform-contracts.md) 第 5 节）。不要为了验证而临时挂载，升级给界面所有者。
- 原生层：Android 的 `NativeHomePlatformView.kt` 与 iOS/macOS 的 `ZolnitNativeUiPlugin.swift` 没有在本次运行。

### R8 更新与安装

- 输入：网站清单 JSON 或 GitHub 发布 JSON。
- 错误：`FormatException` 的消息 `Unsupported website update metadata`（`app_id` 不符或未知字段）、`Too many website releases`（超过 30 个）、`Unsupported release manifest`、`Unsupported GitHub release`。
- 函数：`parseWebsiteReleases`、`ReleaseManifest.fromGitHubRelease`（[app_update.dart](../../lib/common/app_update.dart)）。
- 命令（V1）：`dart run tool/test.dart test/views/zolnit/update_test.dart`
- 测试名：`test/views/zolnit/update_test.dart` 的 `ordinary launches and the running version say nothing`、`each update state names what the user can do`、`Android installs once however often it is tapped`、`install permission offers later and explicit authorization`、`a failed update offers the website download`。
- 预期：通过。
- 停止条件：清单中 `app_id` 不是 `com.zolmid.zolnit`。不要修改常量绕过；这是身份契约，升级给发布所有者。
- 本次未执行真实安装。读取已授权的公开候选/摘要不需重复批准；运行安装器、写入真实用户数据或改变系统网络须有明确测试范围。

### R9 旧数据、schema 21、备份与迁移中断

- 输入：旧版本的 Drift 数据库文件、旧版备份归档、未知字段。
- 机制：`lib/database/database.dart` 的 `schemaVersion` 为 21（第 53 行），`onUpgrade` 按 `from < 2`、`from < 3`…`from < 20` 分段迁移（第 65 行起）。
- 备份：`backupTask`、`restoreTask`、`writeBackupArchive`、`readBackupArchive`（[backup.dart](../../lib/common/backup.dart)）。
- 命令（V1）：`dart run tool/test.dart test/common/backup_task_test.dart test/database/migration_v1_to_v2_test.dart`
- 测试名：`test/common/backup_task_test.dart` 的 `the archive carries the database, the config and only the listed files`、`restoring returns the rows and stages the files`、`a version 0 archive goes through the legacy migration`、`an archive without a config document is rejected`、`a file that is not a zip archive is rejected`、`a config from a newer data version is rejected`、`a database from a newer schema is rejected`、`an archive without a database yields just the config`。
- 路径穿越：`_stagedEntryPath` 拒绝 `../` 开头、规整后等于 `..`、或规整后是绝对路径的归档条目名；可以构造一个条目名为 `../evil` 的归档验证 `readBackupArchive` 直接跳过该条目而不是写出到 `stagingDirPath` 之外。
- 预期：升级路径通过；未知字段是否保留应由对应模型/迁移测试逐项证明，本章不把这个目标冒充所有字段已实测；比当前 `Migration.currentVersion` 或数据库 `schemaVersion`（21）更新的归档被拒绝，不尝试部分导入。
- 停止条件：迁移中断后再次启动时数据丢失。立即停止写入，保留数据库文件副本，升级给数据库所有者。不要删除旧库。

### R10 Windows 登录（历史暂停）

- 状态：控制台记录的 Windows 登录诊断已暂停，没有可用的复现步骤。
- 本章没有为该历史登录故障确认专门复现测试。Windows Helper 的测试命令见 [development.md](development.md) 第 7 节，其中 `--features windows-service` 只能在 Windows 上运行。
- 停止条件：没有新的复现信息时，不得声称已修复。

### R11 启动守护与崩溃恢复

- 输入：`BootRecord`（`stage`、`profileId`、`startedAt`、`failureCount`、`lastFailedProfileId`、`handledExitAt`）与 `AppExitInfo`（`reason`、`timestamp`）。
- 函数：`resolveBootDecision`（纯函数，[boot_record.dart](../../lib/common/boot_record.dart)）、`BootGuard.evaluate/markRunning/markClosed`（[boot_guard.dart](../../lib/common/boot_guard.dart)）。
- 判定要点：只有记录停在 `stage == starting` 才可能判定异常；能匹配到更晚的 `AppExitInfo` 且 `reason.isExternalStop` 为真时不计入失败；否则失败计数加一，达到 `crashRecoveryClearThreshold = 2` 且存在 `profileId` 时 `recovery = clearProfile`，未达阈值时 `recovery = skipAutoSetup`。
- 落地位置：[bootstrap.dart](../../lib/bootstrap.dart) 的 `_initData`（求值并在 `clearProfile` 时清空 `currentProfileId`）与 `_initApp`（`isDegraded` 时跳过自动连接，随后统一调用 `markRunning`）；正常退出由 [providers/actions/system.dart](../../lib/providers/actions/system.dart) 调用 `markClosed`。
- 平台范围：仅 Android（`_supported` 默认 `system.isAndroid`）；其他平台的三个方法直接返回，不读写记录。
- 命令（V1）：`dart run tool/test.dart test/common/boot_guard_test.dart test/common/boot_record_test.dart`
- 测试名：`an interrupted launch is carried into the next boot record`、`clearing the profile also drops it from the new boot record`、`a consumed exit timestamp is remembered across launches`、`a completed launch resets the failure count`、`a degraded launch keeps its failure count until a clean run`、`a clean exit closes the record and clears the failure count`、`markRunning and markClosed do nothing without a record`、`an unsupported platform never reads, writes or recovers`（均在 `test/common/boot_guard_test.dart`）。
- 预期：连续两次异常退出（且不是外部主动停止）后，第二次启动清空 `currentProfileId`，不自动重连上次失败的 profile；一次正常退出把失败计数清零。
- 停止条件：启动实际已完成，但下次读取仍反复得到 `stage=starting`。先核对 `markRunning` 是否成功落盘以及退出时的 `markClosed`；仅缺少 markClosed 不代表异常，因为记录为 running 时不会计为未完成启动。继续检查 [providers/actions/system.dart](../../lib/providers/actions/system.dart) 的清理代码，记录平台与退出方式，升级给生命周期所有者，不要绕过阈值直接清空用户 profile。

## 4. 日志与脱敏

- 不记录登录令牌、订阅令牌、支付 client secret、兑换码原文与原始深链 URL。
- 日志中只保留时间、版本、错误码与事件名。
- 命令行参数、shell 历史与进程列表可能泄露令牌。需要传递敏感值时使用标准输入或受限文件，不拼入命令字符串。
- 发给他人的日志需要先经过上述检查。

## 5. 必测场景与现有测试的对应

| 类别 | 场景 | 现有入口 |
|---|---|---|
| 正常 | 登录、订阅同步、节点切换、订单查看 | `test/views/zolnit/account_test.dart`、`test/views/zolnit/nodes_test.dart` |
| 失败 | 服务端非 2xx、超长或含控制字符的错误消息 | `packages/zolnit_client/test/http_client_io_test.dart` |
| 离线 | 网络中断后保留会话，恢复后重试 | `test/views/zolnit/auth_test.dart`，R1 |
| 无效数据 | 畸形 bundle、缺失签名字段、未知 `kind` | `packages/zolnit_client/test/producer_bundle_contract_test.dart`，R2 |
| 快速意图 | 重复付款点击、连续切换节点 | `test/views/zolnit/interaction_feedback_test.dart` |
| 生命周期 | 后台、回前台、支付页面 dispose | `test/views/zolnit/ios_resume_test.dart`，R6 |
| 升级 | 旧配置导入、旧版本会话 | `test/common/zolnit_main_group_test.dart`，R9 |
| 崩溃恢复 | 连续异常退出后清空旧 profile，正常退出清零计数 | `test/common/boot_guard_test.dart`，R11 |
| 备份恢复 | 归档版本/schema 超前被拒绝；路径穿越条目被跳过 | `test/common/backup_task_test.dart`，R9 |

## 6. 已知缺口

- 真机 VPN、系统 TUN、真实线路需要设备测试。本次没有这类证据。
- 微信支付保持禁用，不测试微信路径。
- TestFlight 上的演示账号被拒绝一事没有重新提交。
- iOS 的 VPN 锁屏、恢复与网络切换在 1.1.9 上需要复测（控制台记录）。
- Android 支付返回的真机验收仍未完成。
- 原生界面没有挂载，因此没有生产环境的原生界面证据。

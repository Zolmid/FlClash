# 整合交叉审查

审查输入：`codex/patched-integration` 当前工作区、主线 `f2112fc4`、iOS 移植基线 `3222b8d609caaf74c28f61712c8d654e4937eed9`。内核子模块实际仍为原有 `8380d0e7462f061a964323e9bf3129a236fcc5d5`；本次核查没有修改他人领域源码，没有运行根 Flutter/codegen 或提交。

## 发现与处置

| 问题 | 影响与证据 | 处置状态 |
| --- | --- | --- |
| Android 更新 staging 接口不一致 | Dart `AppInstaller._download` 使用 `cache/app-updates/<tag>-<sha256>/<apk>`；原生策略之前只接受 staging 直属 APK，所有正常下载都会返回 failed。 | **已在原生领域修复**：`ApkInstallPolicy.stagedApk` 允许唯一一层符合 tag+完整小写 SHA256 格式的 release 目录，仍要求 canonical 位于私有 cache staging 内；拒绝 staging/release/file 的 symlink、任意 URI、外部路径和额外子目录。包名/严格升版/签名校验与 PackageInstaller 不变。增加合法实际目录、非法目录/hash、内外部软链和别名 staging 回归，原生纯 JVM **117 项通过**。 |
| Linux 包更新失败恢复覆盖新停止意图 | `CommonAction.installPackageUpdate` 原来只在进入 recovery 之前检查 latest run/restart。`recoverPackageCore` 等待 `startCore()` 时若用户停止，随后仍用旧 `wasRunning` 执行 `setRunning(true)`。 | **已交 Dart owner 并核查修复源码**：`CoreAction.startCore` 返回是否真正 applied；`recoverPackageCore` 在 await 后重新核查 run request 身份、restart revision、本地运行意图、connected 状态。`test/providers/common_action_test.dart` 新增 blocked Core recovery 期间发 stop 的行为回归。根测试由 root 执行，本审查没有声称已运行该 Flutter 测试。 |
| 自动调度器漏接手动失败时间 | `ProfilesAction` 已保存 `_lastUpdateAttempts`，`ProfileAutoUpdater._due` 也支持 `lastAttempt`，但 `ApplicationState.initState` 实例化时未传 getter。生产失败手动刷新因此不会把下一次自动尝试延后，单独 helper 测试的注入掩盖了接线缺失。 | **已复核修复源码**：`ApplicationState.initState` 现已传 `lastAttempt: (id) => ref.read(profilesActionProvider.notifier).lastUpdateAttempt(id)`；生产调度器使用与手动刷新同一份 attempt 状态。 |

## 协议与保留范围

用源码解析比对 `lib/core/method.dart` 的枚举与 `core/protocol.go` 的字符串常量：**各 53 个且集合完全相等**。iOS `AppCoreMethod` 全部属于该集合。`core/method.go` 对新增的 `getCoreVersion`、`getMemory`、`getGoroutineCount`、`getRules`、`setRuleDisabled`、`queryDns`、两个 Age 工具均有 handler；`updateDns` 仍由平台实现注册，crash/message 保留原协议用途。

- `getRules`/`setRuleDisabled` 的 index/type/payload/disabled、统计字段及时间戳与 Dart model/interface 对应；set 操作使用当前 config 锁并校验 rule 身份。
- `queryDns` 的 domain/type 输入与现有 DnsQuery 输出一致，使用原 8380 resolver 的手动查询和现有 DNS tracing；没有第二层 JSON 字符串。新旧批量/单事件仍通过 `coreEventsFromData` 逐项解析与隔离失败。
- 内存旧 `getMemoryStats` 字段保留，新 `getMemory` 复用同一快照，符合 Dart 对象类型；CoreVersion 读取 active Core。Age 返回 secret-key/public-key 或 public-key 字符串，iOS 显式路由到 App；运行规则/DNS/版本/内存查询仍随 active route 进入 NE。
- 生产 `lib/`、共享 Go 桥及 iOS 没有 queryRule、nodeTraffic、Overlay network 方法/模型/页面、独立 DNSMode override 或 mmap 开关残留。`DnsMode` 仍用于主线正常的 DNS enhanced-mode 配置和连接元数据，Flutter `Overlay` 仍是普通 UI API；这些不是被撤功能。

## 状态与所有权保护

直接与 `f2112fc4` 比对，以下文件无改动：`core/message.go`、`lib/core/desktop/lifecycle.dart`、`lib/core/desktop/helper_client.dart`、`lib/core/desktop/launcher.dart`、`services/helper/**`、`android/common/.../RunIntentArbiter.kt`。因此 state/priority/bulk 三类队列、16 ms/32 消息批处理、bulk 公平机会、Helper 身份验证、session/lease/PID 归属和未确认退出保护仍保留。RPC 大帧解析新增串行 future 链，断开后提升 generation，隔离旧帧；没有新增进程 owner。

Android `ServicePlugin.start/stop` 仍读取 Dart 传入的 commandRevision，stopped 仍只在最新 stop 意图下回报该值；新增 actual/requested 参数只是原 `ServiceRuntime` 的字段，不是另一组运行标志。actual 保留真正的 gvisor 权限回退，requested 用于 `.effective` 重启比较，停止/失败/失联共用 runtime 清理。

iOS `CoreMessageRouter.sendRoutedCoreMessage` 仅调用选定 route，没有 NE 失败后改投 App 的 catch。`RunnerTests.testProviderFailureDoesNotAcknowledgeWritesFromTheAppCore` 覆盖 changeProxy、连接关闭、provider update 和内存读取失败；断开稳定状态自然改选 App。`Shared/CoreEventBacklog` 的 loaded/geoUpdate/routeChanged 独立有界保留和 generation ACK 仍在，NE wrapper 仍用同一 NSLock；没有改回 transient overflow 丢状态的逻辑。

## ProfileAutoUpdater 与更新生命周期

`ProfileAutoUpdater` 用单 timer、running guard、每 profile 的成功/失败时间和当前配置重新计算 due；启动过期配置只尝试一次，失败后等待完整 interval，resume 只做 catch-up，dispose 取消 timer。`ProfilesAction.updateProfile` 用每 profile 的同一 Future 让手动/自动刷新 singleflight；完成/失败释放 map 并记录 attempt；加载键通过 finally 按 token 结束。已存在的 focused tests 覆盖 singleflight、失败记录、间隔编辑、手动成功/失败延后、resume 和 dispose；生产 getter 接线缺失单独列为发现。

更新下载通过 `.part`、声明大小上限、SHA256 校验后 rename；取消在请求、重试等待、流读取、验证和 publish 前检查，进度 dialog 在 pop 前携带 outcome，AppInstaller/client 的 busy 标志在 finally 清除。Linux package 安装先等 Core stop 的确认结果，再检查 run request/restart revision；superseded 不执行安装。安装失败/取消才恢复且必须是同一意图；恢复 await 后的遗漏已经交 owner 修复。helper/core 仍由原 lifecycle lease 管理，没有用服务名强杀或另起宿主状态机。

## 验证限制

本次做了源码集合核对、调用链/数据形状和并发分支审查、基线 diff 比较、原生 staging 窄 JVM 回归；iOS 工程静态检查确认 153 PBX 对象/5 targets 和 plist/JSON/XML 引用有效。没有 Android SDK/Xcode，因此 Android 系统安装授权/最终验签、Widget/Tile 真机行为和 iOS 编译/NE XCTest 未执行。根 Flutter/analyze/codegen、Dart focused tests 与 Go 测试由对应 owner/root 统一执行；审查不以它们尚未运行来推断通过。

最终新增 `test/views/runtime_rules_test.dart`，复用现有 TestApp、MockCore 和 provider overrides，覆盖真实 RulesView 的 runtime 规则/统计/added 来源标签、成功禁用后的旧会话 mutation 隔离，以及断开时清空/禁操作和迟到 refresh 不恢复旧控件。没有改生产 UI、模型或扩大功能；该文件交由 root 统一运行，不计入上述原生 117 项 JVM 测试。

## 后续 UI 批次交叉审查

本节审查基线为 `88476f4641da39e1dd24c84f065aa06054ab2200`，覆盖网格键盘编辑、
原始 YAML 创建、运行时卡片、输入与 TV 焦点及原生语言资源。根任务统一执行门禁，结果见
[验证记录](validation.md)。只读结构复核未发现尚未解决的责任边界或重复 owner 问题。

- `SuperGrid` 持有本地重排预览和焦点资源，只向既有 dashboard settings 提交最终变更；
  `Grid`/`MotionGrid` 只负责布局、绘制和退出动画。`CardPressOverride` 保持正常与编辑状态的
  wrapper/子树结构稳定，防止保留中的 PageView 瞬时挂到同一 PageController 两次。
- `BackLayerScope` 仍拥有编辑返回层；持起取消只恢复同一层。Flutter 在 onRemove 中暂时将 route
  标记为 popping，不能以该瞬间的 isActive 判断是否可重挂。取消、退出编辑、返回路由的顺序有回归覆盖。
- TV 弹窗使用自己的 `PopScope` 释放输入焦点，不增加会吞掉显式提交结果的 LocalHistoryEntry；
  模态遍历边界仅临时修改，始终在 finally 恢复。叠层弹窗不会释放其他弹窗的焦点。
- 原始 YAML 草稿直到严格校验及文件保存成功后才进入原 profile store；typed custom 继续使用自己的
  编辑器，两者共享既有 origin 导航规则。异步文件/弹窗测试等待真实完成条件，保留失败重试和返回断言。
- 内存类别与 returned-heap 切换仅影响 Go 分类图，不改变 RSS、Android 进程分摊或 iOS footprint。
  协程数采用 active Core 语义；iOS NE 失败仍传播错误，不回退 App。
- 安装器配置用 `setup.dart` 固定的真实 provider/Liquid 验证，纠正被忽略的 publisher 字段；
  作者和支持链接保留上游，更新链接独立指向 Zolmid。静态或模板验证不冒充 ISCC/Xcode 编译。

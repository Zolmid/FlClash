# 独立 review 后的定向修复

基线为 `b9af3521528a49a9edd98dd8be27b065324dbb11`。外层已 fetch 并核验该 SHA 的
[标准 CI 38724531295](https://github.com/Zolmid/FlClash/actions/runs/38724531295) 与
[Cloud all/project 38724531398](https://github.com/Zolmid/FlClash/actions/runs/38724531398)
全部成功。以下只修复后续源码 review 的八项阻断及直接相关验证，不重做功能移植。

| 项目 | 修复与保留边界 | 回归证据 |
| --- | --- | --- |
| 1. 运行时规则配置身份 | `getRules` 在 `configMu` 内返回规则快照和 `crypto/rand.Text` token，set 必带原 token 并在同锁内核对，再核对 index/type/payload。实际 apply（包括生效的默认 fallback）、规则列表替换和 Core 重建使旧 token 失效。随机 token 避免 App/NE 各自整数代际碰撞；不改子模块。 | Go 的同配置允许、跨配置完全相同 DOMAIN/MATCH 拒绝、跨 Core 实例拒绝；Dart 协议和热 apply 迟到读写测试。 |
| 2. Windows 自启卸载清理 | 确认卸载后、停进程前调用同安装的早期清理入口；优先由核实可执行路径的原用户实例执行，否则仅当前 token SID。Task Scheduler COM 精确验证 Source、SID、安装 hash/路径、单 Exec/LogonTrigger、空参数及 InteractiveToken/LeastPrivilege 后删除唯一任务。不会按前缀删除或改变 UIPI/权限。 | 8 项可移植归属断言；Windows Cloud 编译真实 COM 并增加路径 hash 一致性断言。详细跨管理员限制见 [自启审计](windows-autostart.md)。 |
| 3. Android 启动状态与请求码 | engine scope 在 Main collect 既有 `ServiceState.runState` 并发送 tunnelState，detach 取消；connected 后重读 actual/requested，记录 actual，以 requested `.effective` 比较，保留 gvisor fallback 与 Dart commandRevision。安装权限使用 1006，Battery 保持 1005。 | 真实 Service MethodChannel 覆盖 null→connected 时 desired 已改变、权限 fallback 不误报；4 项 Kotlin 回归覆盖状态、detach/reattach 和两真实 listener 共用的回调分派。 |
| 4. Linux 托盘程序勾选 | 程序 set_active 期间仅 block/unblock 本插件的 activate handler，保留其他 GTK/DBusMenu 通知。 | 有效 active_plugin、真实 FlMethodChannel 与可观测 messenger：程序 A→B 零选择事件，外部 GTK 通知和 DBusMenu checked 正常，用户点击一次仅一条事件；移除修复的 scratch 对照确实失败。 |
| 5. 配置刷新队列 | 纯刷新只传 id，join 该 id 最新队尾；只有显式来源编辑可以排新 URL/key。EditProfileView 保存在关页前登记来源意图。列表、详情、托盘和调度器均用 id；保留 lastAttempt、single-flight、启动恢复与 resourcesAction。 | 自动 A→真实 EditProfileView 保存 B 并关闭→旧列表 A 刷新，只请求 A、B，最终保留 B 的 URL/key；旧 A 成功和失败都覆盖。 |
| 6. iOS 规则路由切换 | UI 监听 tunnelState、coreStatus、profile 和本控制器配置操作；变化取消 debounce、提升会话/刷新代际，pending/apply 期间停读写。失效时立即移除旧列表，避免退出动画保留旧开关；忽略迟到 App/NE 返回。无新队列或事件类型，无 NE 失败回退。 | App→NE pending 迟到读与待提交编辑、NE→App 迟到写、connected 热 apply 以及重叠/失败配置操作回归。 |
| 7. 隐藏的 idle interval | 关闭失焦降频时保留提交时 provider 的原 interval；仅启用时验证、解析正整数。 | 9 项真实 GeneralView 弹窗测试：空值、非数字、0/-1、关闭提交、启用校验与修正、保留最新值。 |
| 8. macOS 微架构参数 | setup 限制 x64-v1/v2/v3（及 amd64 别名）只在 Windows/Linux 使用。macOS 保留 x64/arm64，与更新器允许值一致，不新增 Mac 微架构支持。 | setup 参数拒绝/基线接受，以及 macOS 两 ABI 对应 updater 目标测试。 |

规则、配置队列、VPN manager、间隔弹窗、协议和构建参数共 12 个 Flutter 定向 suite，
最终 **206 项全部通过**，`flutter analyze --no-fatal-infos` 无问题。
模型/provider 修改经 build_runner 正常生成，不手改生成文件。
首轮回归发现并修正旧规则子树退出动画问题；新增页面夹具的目录 Future 在普通 setUpAll 预热，
避免 FakeAsync 首次初始化影响后续文件测试；保留原断言并清理既有 Loading 最短展示 timer。

## Windows 安装器的真实编译门禁

原 provider 测试只用空 ISCC 文件渲染 Liquid，不能证明 Pascal/ISL 编译成功。
Cloud Windows 的 Compile desktop 后新增 compile-only 步骤，进入现有独立验证包执行：

```bash
dart pub get --enforce-lockfile
dart run bin/compile_installer.dart
```

入口使用已固定的 provider `AppPackageMakerExe.configLoader.load` / `maker.make`，自行切到仓库根，
读取 `build/windows/x64/runner/Release` 与 `FlClash.exe`，输出目录仍为 `dist`，由执行器现有
Inno Setup 6 实际编译。不会调用 Flutter build、运行安装器、发布 Release 或修改 guard。
本次唯一 lease 决定 artifact 名；确认输出不存在后才取得归属，成功/失败均仅清本次 EXE、ISS、staging
与 lease，保留原 bundle 和其他 dist 文件，避免 SHA256SUMS 枚举到验证目录。

独立包分析与 **5 项测试通过**：2 项真实固定 provider 渲染、3 项真实 config loader/自有输出清理契约。
后者只 mock maker 输出，不冒充本机 ISCC 成功。Windows native CTest 也在 Cloud job 明确 configure、build、run。
actionlint 与 **17 种事件/inputs 场景**检查通过，自动 all/project、手动入口、只读 contents 和未签名 IPA 保持原样。

## 其余针对性验证与限制

- Go：普通及 `with_low_memory` 规则定向测试、host vet、Android arm64 vet 通过。
- Android：新增 Kotlin 编译/JUnit **4 项通过**；不是完整 Android SDK 编译。
- Linux tray：GTK/Xvfb native CTest **1/1 通过**；独立插件分析和 **64 passed / 1 skipped**。
- Windows 任务清理：可移植 native CTest **8/8 通过**；本机未编译/运行 Windows COM 或 ISCC。
- 默认 comment-density、格式、whitespace 与文档链接按原规则检查，未降低门槛。

原 core `8380d0e7462f061a964323e9bf3129a236fcc5d5`、上游子模块地址、依赖锁、helper 鉴权和发布 guard
保持不变。main 仍等该 fixup SHA 的独立 review 与完整平台门禁后再合并。真实 Windows UAC/跨账户清理、
Android 权限与 engine 生命周期、GNOME/KDE 会话、签名 iOS VPN 和 App↔NE 设备行为仍需对应平台验证。

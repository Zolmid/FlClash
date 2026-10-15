# Patched 逐项整合审计

## 固定源码与审计方法

| 对象 | 精确提交 |
| --- | --- |
| 本轮开始时的 `origin/main` | `f2112fc4ad202bbe597e6728acaef7700eeb58a5` |
| 保留的 `codex/ios-support` 基线 | `3222b8d609caaf74c28f61712c8d654e4937eed9` |
| `chenx-dust/FlClash-Patched` 固定参考 | `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` |
| 真实应用共同祖先 | `7c61c90ac20493b474d19c75ec96262b478b4b88` |
| 最终保留的 core gitlink | `8380d0e7462f061a964323e9bf3129a236fcc5d5` |

整合前，main 与 Patched 独有提交分别为 **35 / 281**；iOS 基线与 Patched 为 **37 / 281**。
iOS 基线至 Patched 的树差异涉及 **1325 个路径、94333 行新增、207169 行删除**；
共同祖先至 Patched 涉及 **931 个路径**。这些数字描述本轮开始时的源码差异，不是净新增功能数，
也不是本分支最终变更量。完整可查清单：

- [281 个来源提交、作者与审查领域](audit/source-commits.tsv)
- [共同祖先至 Patched 的文件清单](audit/source-files.tsv)
- [iOS 基线至 Patched 的最终树差异](audit/baseline-tree-diff.tsv)

审计同时检查历史提交和两端最终实现，不整树替换、不批量 cherry-pick。修复后来已被撤回、主线已有
或被较新架构替代的差异，均不当作本轮净新增。来源仍为 Patched 与其保留的上游作者；领域报告列出
精确来源 SHA、目标文件和取舍依据。品牌、应用 ID、更新发布来源与现有安全边界按主项目保留。

本轮开发分支为 `codex/patched-integration`。首批可审查提交为 `0713ff79`（proxy/统一构建）和
`11406fa0`（持久化 old+pending ownership 与实际 C++ 状态测试）；后续功能在同分支分批整合。
`88476f4641da39e1dd24c84f065aa06054ab2200` 是首个完整应用层检查点，后续 UI 批次在它之上补齐。
`main` 在外层独立 review 与同 SHA 全平台验证前不合入。

## 已整合的应用层增量

以下能力已经在整合分支实现；验证范围以本报告末尾、领域记录和同 SHA 云构建结果为准。

| 功能 | 实际实现及保留边界 | 来源 / 详细审计 |
| --- | --- | --- |
| Android 多尺寸 Widget | compact/row/square RemoteViews、配置名、VPN toggle、主题与状态观察；命令仍由现有 ServiceState 仲裁 | `3ac6f36d`；[Android](audit/android.md) |
| Quick Settings | 可选收起面板、可选配置名、保留面板时不发过渡 toast；保留错误反馈 | `50730d01`、`f187acf2`、`10332be8`、`864826ae`；[Android](audit/android.md) |
| 活动 VPN 参数 | requested/actual 由既有 ServiceRuntime 持有，使用 `.effective` 比较；保留 Dart commandRevision。主线实际权限 fallback 是 gvisor，保留它并避免反复提示重启 | `697755c9`；[Android](audit/android.md)、[Dart](audit/dart-domain.md) |
| 桌面托盘 | 代理/配置选择、解析别名后的延迟批量刷新、Mac/Windows 延迟建菜单、Windows 测速保持菜单、Linux 完整 DBusMenu 导出和 SVG、Wayland 时间/token 沿现有窗口队列透传 | `7a26ddcf`、`dfcd6e8e`、`72b5e22d`、`834f3f25`、`38b8e3d9` 等；[托盘](audit/desktop-tray.md) |
| Windows 代理归属 | 持久化旧目标+待应用目标；全部连接成功才收敛；失败/中断后仍可精确回收。查询失败/仍有监听不清理，原用户实例可响应卸载释放请求 | `bd7da00c`；独立 `plugins/proxy/test/native` 状态测试与 Windows cloud job |
| Windows IPv6 / KDE | IPv6 CIDR、zone 和已带括号地址规范化，去重并保留 `<local>`；KDE 设 `ReversedException=false` | `9d8c15a2`、`3e88f3b2`；proxy 插件测试 |
| WebDAV 多备份 | 可配目录/文件名模板、备份浏览/选择/删除；保留主线 staging 恢复和回滚。collection 与 basename 在各入口校验，file/collection/unknown 三态；unknown 未确认不得 DELETE，跨目标重定向拒绝 | `23dc94a2`；[Dart](audit/dart-domain.md) |
| 更新来源与 SemVer | `repository=Zolmid/FlClash`，致谢独立 `upstreamRepository`；支持预发布排序，避免装回上游包；未发布版本正常无更新 | `1de91ebb`、`197967cf`；[更新器](audit/updater.md) |
| 下载校验与安装交接 | 独立严格 TLS、受约束的官方 release 元数据、唯一目标、私有 tag/hash staging、`.part` 校验后 promotion、大小上界、取消/断点续传；Windows PID+nonce/超时、Mac 唯一 bundle/架构与恢复副本、Android 包身份与系统确认、Linux 提权后私有复制再 hash | `1de91ebb`；[更新器](audit/updater.md)、[构建](audit/dependencies-build.md) |
| 每配置自动更新 | 基于最新 lastUpdateDate/lastAttempt 到期，手动/自动同 profile single-flight；删除旧 bootstrap 重复调用，保留 resourcesAction.autoUpdate 启动与周期 | `eaf120ed`；[Dart](audit/dart-domain.md) |
| 运行时规则 | 直接使用原核已有 RuleWrapper 列表、统计与 SetDisabled；展示新增规则来源，按现有配置 owner 应用更新，禁用时失效路由缓存 | `2502ef35`、`0f0511ac`；[Core](audit/core.md)、[产品 UI](audit/product-ui.md) |
| 手动 DNS | 使用现核 DNS trace/QueryRecord/Initiator，查询类型选择、内联结果与错误展示 | `03d79e3d`、`fa13ab5c`；[Core](audit/core.md) |
| AGE / 内存 / core 版本 | 原核现有 AGE 能力的应用工具、Go 内存分项/协程数、iOS footprint、移动端 core 状态与实际 bundled 版本；不伪造节点累计统计 | `0dff1719`、`e16e4c6a`、`a84e5710`、`7ea4597c`；[Core](audit/core.md) |
| 精准连接关闭 | 按选择组和旧节点只关闭受影响连接，同一节点重选仍执行用户意图；不以全局 closeConnections 冒充精准行为 | `e36bbc9f`、`eddc23ee`；[Core](audit/core.md)、[Dart](audit/dart-domain.md) |
| 繁中 / TV / 编辑器 | 繁中与 native 控件翻译、TV 手动模式/焦点/IME 返回、记录筛选、链条折叠、搜索开关/动画/行高/mobile 返回；保留主线新布局、AppGlyphs、superellipse、clash_schema/relaxed_yaml | `323f678d`、`df67e126`、`1756a65c` 等；[产品 UI](audit/product-ui.md) |
| 仪表盘键盘编辑 | 聚焦增删、确认持起、方向键预览换位、确认一次提交、Back 取消后再退出编辑；保留 keyed MotionGrid、指针拖动和卡片状态 | `160bd35a`、`438353c4`、`998317cb`、`caf3a069`；[键盘编辑](audit/dashboard-keyboard.md) |
| 原始 YAML 新建 | 独立文件配置草稿、命名后打开原编辑器、严格 core 校验成功才保存和入库；保留 typed custom 与导入路径 | `6af97066`；[配置创建](audit/profile-creation.md) |
| 协程与内存明细 | 可选协程卡片、Go 内存分类和 returned heap 百分比切换；不改变 RSS、Android 进程归属或 iOS footprint 总量 | `5d3ba8b4`、`e16e4c6a`、`f9a47b8a`；[运行时 UI](audit/runtime-ui.md) |
| 粘贴与输入焦点 | 显式 URL 粘贴、WebDAV URL 键盘、新建名称自动聚焦；TV 弹窗先释放本地输入焦点再返回，模态遍历不逃逸 | `dec59305`、`d6a032d8`、`38d6e1c8`、`e65a054b`、`dd1fcfba`；[输入交互](audit/dialog-inputs.md) |
| 原生繁中资源 | Android 通知渠道、macOS 字符串目录和安装器语言；真实固定 provider 渲染验证，同时纠正 publisher 字段并分离作者与更新地址 | `323f678d`；[原生语言](audit/native-localization.md) |
| Windows 自启 | 当前用户及安装专属 scheduled task，InteractiveToken/LeastPrivilege，不提权；普通自启与 task 迁移失败保留有效方式，保留 debug/SAFE_MODE 门与串行收敛 | `8012efc6`；[自启](audit/windows-autostart.md) |
| 构建适配 | macOS Rust strip=none、Windows libclang/PATH、当前 NDK 的 API triple、APP_ARCH/GOAMD64 缓存与失败恢复；保留较新工具链 | `ab86dadb`、`4512b1d7`、`38f781a7`；[构建](audit/dependencies-build.md) |
| 统一主项目云构建 | main/整合分支 push 自动 all/project；iOS 分支仍 ios/project；手动入口全部选项保留，Patched 仅固定参考 | [云构建说明](cloud-build.md) |

上述后续 UI 批次补齐首个应用层检查点遗漏的净增量。完整取舍仍逐项保留在
[146 项产品 UI 来源矩阵](audit/product-ui.md)，包括由主线现有组件替代的表现设计，
不能把这些应用层能力归入“因内核维护成本延后”。

## 主线已有或由较新架构替代

- core 模块拆分、gomobile、三层事件队列、serviceCheck/probe/share-link；不迁回旧 Cgo/JNI 和旧事件分发。
- helper Windows SID/Linux uid 鉴权、动态端口、子进程回收和 desktop CoreProcessLease；不迁 Patched 删除 owner/peer 的实现。
- Android ServiceState、commandRevision、BootGuard、launcher shortcuts、一步权限、空 DNS 回退、Doze 不暂停；不引入独立 native commandCount。
- iOS TunnelCoordinator/ManagerStore、Widget/快捷操作、安全模式、NE 状态保留、禁止 NE 失败回退 App。原核已生成 IPA，新增 fork 不是 iOS 必要条件。
- 主线窗口插件、跨 DPI 几何恢复、XInitThreads/窗口图标、Linux sudo fallback；不恢复旧 window_manager 依赖。
- KDE HTTPS=http 和 DBus 通知、主线 `<local>`、NTP 逐键覆写/mips/禁止移动端写时钟/iOS 32MiB 限制。
- 主线 profile schema、relaxed YAML、自定义配置编辑与备份恢复 staging；不以 Patched 较旧依赖或 UI 整树替换。
- 保留现有 Flutter/Go/Rust/NDK pin 和覆盖率门槛。没有功能必需的新 API 时，不因版本号不同升级依赖。

## 依赖改内核而延后

维护策略以[上游同步说明](upstream-maintenance.md)为准：优先同步 `chen08209/FlClash`，由它带入已验证
core 版本；我们维护应用/平台差异，不独立追逐 mihomo/Clash.Meta 新特性。

| 能力 | 准确缺口与本轮取舍 |
| --- | --- |
| 高级规则实际匹配 | ResolveMetadata 当前私有；静态规则模拟不能等价处理 PASS/rematch/process/DNS。因维护成本不引入，优先上游公开接口。 |
| 精确节点累计流量 | 现有活动连接快照会漏已关闭连接/fast path；需要 outbound 自持计数。无假等价 UI。 |
| Overlay 状态与控制 | 需要导出 Tailscale/ZeroTier/EasyTier 实例和状态接口；不只搬页面。 |
| 系统 DNSMode | 原 RawTun/LC.Tun/sing-tun 没有完整 plumbing；不添加无效开关。候选 sing 依赖升级已经撤回。 |
| mmap geodata | 新格式、映射生命周期、原子替换、失效和安全路径清理需核心维护；完整探索保存，本轮不接入。 |
| AnyTLS idleSlots/低内存 loader | 需要完整插入/复用/过期/关闭回收和构建约束；不只摘修复，不把现有 GC 描述成等价。 |
| iOS system-stack forwarder / Android loopback | 要改内核行为；保留当前经过构建的基线，待上游或真机可靠性证据再单独论证。 |

`endpoint-independent-nat` 在当前 sing-tun 不读取，不增加无效 UI/全局字段；
`disable-icmp-forwarding` 已有 ProfileTun/TunOverrideKey owner，只沿 profile apply，不形成双重所有者。
recvmsgx/sendmsgx 仅按原核实际 Darwin 能力接入，保留 sendmsgx 默认 false。

未接入探索完整保存于 `/workspace/patched-core-deferred/`、`/workspace/patched-ui-deferred/` 与 Dart 隔离资料。
核心保存基线为 `8380d0e7462f061a964323e9bf3129a236fcc5d5`，本地保存 head 为
`199f4e6d30f5603bc1cc9cd658b16b00fd2557f5`，bundle 已验证，未 push。生产 gitlink、原上游路径和依赖锁均不变。
详细清单和 SHA256 见隔离目录 README 与 [Core 审计](audit/core.md)。这不是“待接入的最小核心扩展”。

## 发布与安全边界

本轮不修改 main，不 force push，不新增 credentials、不更改网络限制或扩大 Actions permissions。
cloud-build 只读 contents、保留未签名 IPA/开发 artifact，不发布正式 Release。
`build.yaml` 原有上游 release guard 和 Telegram/Homebrew 外部动作不放开；正式 updater manifest 与 cloud artifacts 分开。
SHA256 来自同一发布源，只证明传输/包一致性，不是独立签名认证。

## 验证与设备限制

首个完整应用层检查点 `88476f46` 的全量结果为 **4252 passed / 2 skipped，覆盖率 86.37%**。
本批格式、分析和生成完成；全量运行得到 **4313 passed / 2 skipped / 1 个新增测试夹具失败**，
仅修正该夹具的尺寸 provider 后，整个受影响 suite **16 项通过**，生产代码保持全量检查时的版本。
本批覆盖率 **86.52%**，全部既有分组门槛保留并通过。提交前本地 `dart run tool/changelog.dart verify`
通过；交接 SHA 提交后复跑该 main/tag 专有检查并报告。完整执行记录与证据范围见
[验证记录](audit/validation.md)。
只有同一整合 SHA 的全平台云构建完成并经外层独立 review 后才合入 main。

历史基线 `3222b8d` 已由外层核验 iOS 自动构建 `38703895573` 和全部 9 项 CI `38703895671` 成功：
4069 tests passed / 6 skipped，覆盖率 88.13%。更早 `2c8c9f8fdba0749832f221431af7cad85ac9a4ed`
在 Xcode Release 成功生成未签名 IPA。这些结果不替代本轮整合 SHA 的验证。

本地 Linux 无 Android SDK、Xcode、Windows 原生会话；JVM/Go portable vet、C++ 状态测试、静态 plist/PBX 检查
不能代替对应平台编译。签名真机 VPN、锁屏/后台/低内存/网络切换、权限拒绝、Widget/QS、UAC/安装器、
实际系统代理/RAS、各桌面菜单与 Wayland 激活仍须设备/会话验证。未签名 IPA 生成成功不等于上述行为通过。

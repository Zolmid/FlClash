# Patched 逐项整合审计

## 固定源码与方法

- 主线基线：`f2112fc4ad202bbe597e6728acaef7700eeb58a5`（`origin/main`）。
- 已验证 iOS 基线：`3222b8d609caaf74c28f61712c8d654e4937eed9`，保留于 `codex/ios-support`。
- Patched：[`chenx-dust/FlClash-Patched`](https://github.com/chenx-dust/FlClash-Patched)，固定 `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`。
- 真实共同祖先：`7c61c90ac20493b474d19c75ec96262b478b4b88`。
- `origin/main` 与 Patched 独有提交分别为 35 / 281；iOS 基线与 Patched 为 37 / 281。
- iOS 基线至 Patched 的文件树差异涉及 1325 个路径，94333 行新增、207169 行删除；共同祖先至 Patched 涉及 931 个路径。

以上是本轮整合前的精确 Git 差异，不把已经覆盖的功能计作净新增。
审计同时检查共同祖先后的提交及两端最终实现，不 cherry-pick 全部历史，不整树覆盖。
本次整合分支是 `codex/patched-integration`；`main` 在外层独立 review 前保持原状。

## 第一批可审查内容

| 类别 | 取舍 | 依据与实现 |
| --- | --- | --- |
| Windows stale system proxy | 迁入并收紧 | 参考 `bd7da00c`；仅清理 HKCU 中记录为本项目设置、与当前系统代理完全相同且 IPv4/IPv6 均无监听的地址；查询失败视为仍在使用。记录写入失败拒绝修改代理，避免产生无所有权记录的修改。 |
| Windows IPv6 bypass | 迁入并保留主线语义 | 参考 `9d8c15a2`；支持 IPv6 CIDR、去除 zone，兼容已带括号的地址，去重，保留主线 `<local>`。 |
| KDE bypass | 迁入净增量 | `ReversedException=false` 防止旧的反向例外配置将 bypass 含义倒置；HTTPS 使用 HTTP transport、DBus KIO 刷新已由主线实现，保留。 |
| 统一构建 | 适配主项目 | main 和整合分支 push 自动 `all/project`，iOS 分支维持 `ios/project`；保留手动全部选项、只读 contents 权限、未签名 IPA、固定 Patched 对照和现有 CI/覆盖率门槛。 |

第一批配置经 actionlint 及事件/参数组合检查；proxy Dart 插件 27 项测试通过。
Windows 原生注册表、系统代理与多连接清理仍须 Windows 执行器/真实会话验证；本地 Linux 未声称已验证 Windows API。

## 保留的主线保证

保留 core 模块拆分/gomobile、三层事件队列、serviceCheck/probe/share-link、desktop CoreProcessLease、
Android ServiceState 与 Dart commandRevision、helper 的 Windows SID/Linux uid 对端鉴权。
保留主线较新的 UI/窗口插件、clash_schema/relaxed_yaml 与已有备份 staging/回滚。
iOS 保留 TunnelCoordinator/ManagerStore、Widget/快捷操作、安全模式、NE 状态事件保留及禁止 NE 失败回退 App。

当前 sing-tun 不读取 endpoint-independent-nat，不新增无效 UI 或全局字段；
disable-icmp-forwarding 已由 ProfileTun/TunOverrideKey 在 profile apply 时控制，不增加第二所有者。
recvmsgx/sendmsgx 按实际平台能力核实。

## 后续批次

Android 小组件/Quick Settings/实际 VPN 快照、托盘交互、WebDAV 多备份、严格更新器、运行时规则/DNS、
每配置自动更新、繁中、TV/编辑器增量与最小核心扩展仍在本分支工作区整合。
尚未提交的功能不包含在第一批检查点，也不借用 iOS 基线测试结果证明通过。
每个领域的最终取舍与设备验证限制将在后续提交补入本报告和 `docs/audit/`。

## 已有独立验证

外层已核验 iOS 基线 `3222b8d` 的自动构建 `38703895573` 和全部 9 项 CI `38703895671` 成功，
4069 tests passed / 6 skipped，覆盖率 88.13%。
先前 `2c8c9f8fdba0749832f221431af7cad85ac9a4ed` 已在 Xcode Release 生成未签名 IPA；
这不代表签名真机 VPN 或后台运行已经验证。

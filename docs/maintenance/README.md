# ZolNit APP 开发维护手册

本手册面向接手 ZolNit 的开发、测试、发布和运维人员。它说明如何从准确源码开始工作、沿既有状态所有者修改功能、选择验证层级，以及在失败时恢复。它不代替仓库的 [AGENTS.md](../../AGENTS.md) 和 [.agents/rules.md](../../.agents/rules.md)。

业务源码核对基线为 **d0af9d83c4f37199caceb436b3c3ae66cdb36cd6**，观察日期为 **2026-11-15**。A1 时该提交已进入 `Zolmid/FlClash:main`（当前引用执行前须重查）；公开客户端仍为 **1.1.9**，其标签实际指向 `bfb49ed8a41a9b531a64783f9407959085e4444e`。文档提交与应用源码验收基线应分别记录，不能把后来只改文档的 HEAD 当成已重新构建的 App。

C 增量已经在本地集成收件箱协调、正式 tag 标准检查观察复用及 iOS 意图生命周期修复；代码基线 `c6065db408821257fa2f3687ed4354613df224b6`，版本准备为 `1.1.10+2026111501`。各层实际验证与来源见 [verification-baseline.md](verification-baseline.md)，公开发行状态仍单独记录。

## 阅读顺序

| 你要做的事 | 先读 | 接着读 |
|---|---|---|
| 第一次接手、准备工作区 | [开发流程](development.md) | [操作边界与交接](operations-and-handoff.md) |
| 理解业务和状态流 | [架构与状态所有权](architecture.md) | [功能与入口清单](feature-inventory.md) |
| 改 Android、Apple、Windows 或 Linux | [平台契约](platform-contracts.md) | [测试和排障](testing-and-debugging.md) |
| 改 CI、生成候选或正式发布 | [CI、发布与恢复](ci-release-and-recovery.md) | [已验证基线](verification-baseline.md) |
| 同步上游、整理分支 | [分支与上游维护](branch-and-upstream.md) | [手册要求对账](runbook-compliance.md) |
| 设计真机验收窗口 | [设备验收执行单](device-validation.md) | 平台契约及对应原生测试 |

已有深入说明仍是有效入口：[架构参考](../../.agents/architecture.md)、[设置生效方式](../../.agents/setting-changes.md)、[命令目录](../../.agents/commands.md)、[版本相关兼容处理](../../.agents/flutter-upgrade.md)、[Core/平台开发规则](../../.agents/skills/core-platform/SKILL.md)。本手册补充 ZolNit 产品与实际运维连接，避免复制这些参考文件后形成两套容易漂移的规则。

## 四个不可混淆的基线

| 对象 | 准确值 | 用途 |
|---|---|---|
| A1 时主线业务源码 | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | 历史观察值；新任务先重查引用 |
| 已公开 1.1.9 源码 | `bfb49ed8a41a9b531a64783f9407959085e4444e` | 还原已发布版本、升级和问题对照 |
| 独立 Apple 工具源码 | `97f297743718b6d46272d244ad375b5ca903f499` | Apple 分发工具、环境与调度 pin；不是 App SHA |
| Core gitlink | `8380d0e7462f061a964323e9bf3129a236fcc5d5` | `core/Clash.Meta`，原上游 FlClash 分支 |

这些值是有时间边界的观察，不是未来永久不变的常量。开始新任务时核对实际 refs；若输入变动，应建立一次明确的基线更新，不能悄悄跟随 remote tip。GitHub Release 的 `target_commitish=main` 不能代替 tag 解引用后的 commit。

## 开工前的五步

1. 读当前任务授权、仓库指令和相关模块文档。把“有源码”“曾测试”“现在可用”“允许执行”分开。
2. 核对准确 HEAD、staged/unstaged/untracked、worktree 与他人正在使用的路径。不要自动 stash、reset 或 clean。
3. 为本任务建立独立分支和工作树，固定基线。共享接口、生成配置、锁文件和发布脚本保持唯一写入者。
4. 先运行与改动直接相关的安全基线检查，再做最小变更。确认测试命令是否会触发 Go/Rust 构建、原生服务、网络、签名或上传。
5. 用真实 diff 和可重复验证接收结果。记录被测 SHA/工作树摘要、命令、环境、结果与未验证范围，再合入受控集成分支。

下面仅示范只读检查；先把路径替换为实际仓库，不要复制某次任务工作树路径作为长期配置：

```sh
ZOLNIT_REPO=/absolute/path/to/FlClash
git -C "$ZOLNIT_REPO" rev-parse HEAD
git -C "$ZOLNIT_REPO" status --short --branch
git -C "$ZOLNIT_REPO" worktree list --porcelain
git -C "$ZOLNIT_REPO" ls-tree HEAD core/Clash.Meta
git -C "$ZOLNIT_REPO" remote
```

这里仅列远端名称。核对地址时不要把携带凭据的错误 remote URL 输出到聊天或公开日志；正常远端通过既有凭据辅助程序认证，而不是在 URL 中携带 token。

## 一次改动如何选入口

| 变更类型 | 负责层 | 最小验收方向 |
|---|---|---|
| 账号、订单、套餐、礼品卡等协议行为 | `packages/zolnit_client`；App 适配在 `lib/providers/zolnit_*` | 协议、代际、幂等、失败与存储契约 |
| 页面、交互、展示状态 | `lib/views/zolnit`；原生展示走 `native_ui` 及对应插件 | widget/原生快照合同、取消和迟到响应 |
| 启停、重启、进程和系统 VPN | Android `ServiceState`、iOS `TunnelCoordinator`、桌面 lifecycle | 最新意图、资源所有权、失败收敛及平台验收 |
| 配置、旧数据、持久化 | 已有 profile/bundle/vault/database 所有者 | 旧数据读取、未知字段、顺序、迁移幂等和中断 |
| CI 和构建参数 | 工作流与 `tool/ci` 的选择器 | 事件真值表、实际检查执行、权限和产物来源 |
| 发行与恢复 | 既有 `tool/client_release`、独立 Apple 工具链 | 精确签名字节、receipt、checkpoint、幂等及授权 |

不要为了分层给每个类型再包一层。已有状态机或控制器正确时保留它；新边界必须减少具体耦合，并说明谁拥有状态、谁只能请求或订阅。

## 产品和上游的关系

本仓库保留 FlClash 上游结构与许可，自有产品逻辑集中在 ZolNit 包、视图、适配器和原生展示/宿主扩展。根 README 中保留的上游下载、包名或通用使用例子，不是 ZolNit 当前产品身份的权威来源。

隐藏通用配置入口不等于配置解析、合成、存储、托盘或后台更新已经消失。任何功能退役都要覆盖 UI 和非 UI 入口、独占实现、共享能力、旧配置、后台注册、各平台权限及恢复路径；没有明确退役决定时先保留。

## 验收边界

- V0/V1 证明被覆盖的源码与契约，不能证明设备上的 VPN/TUN。
- 开发构建、debug/unsigned/ad-hoc 产物不能当成正式可分发包。
- CI 必须核对 job/step 实际执行；workflow 总体绿色不能掩盖被跳过的必需检查。
- 真实用户数据、宿主网络、发行签名、公证、正式 tag、更新渠道及不可逆操作，需要准确任务授权。
- 当前真机部分按用户决定另列待执行；不能用文档、模拟器记录或已有 1.1.9 历史证据给新候选补一个 PASS。

## 文档维护方法

修改行为时同步更新负责章节及对应可执行测试。更新“当前值”时给出完整 SHA、版本和观察时间，保留历史证明的适用范围。链接和命令要在代码评审中核对；只有静态检查过的命令应明确写“未执行”，危险示例不应出现在默认快速启动流程中。

后续读者若发现文档与源码冲突，应以当前适用源码和任务授权为准，记录冲突并修正文档，而不是升级 SDK、关闭校验或移动标签来迎合旧说明。

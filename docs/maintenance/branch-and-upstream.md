# 分支、归档与上游维护

重构完成时，`main` 快进至 `a4c9577e2b9a218917b35420a26512f82e016c5c`。其后的正式标签 `v1.1.10` 指向 `09de8037c81bc25e40ff4b0dea00c5ad5b23b4ed`。下表保留 2026-11-15 的分支快照，用于追溯和恢复。新任务开始时请解析当时的远端引用。图上独有提交、补丁等价、当前行为和外部消费者是四种不同证据。

## 1. 远端分支和 PR

| 分支 | 完整 SHA | 维护角色 |
|---|---|---|
| `main` | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | A1 完成时的主线提交 |
| `codex/refactor-local-20261115` | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | A1 受验候选，保存来源 |
| `codex/apple-distribution-prep` | `97f297743718b6d46272d244ad375b5ca903f499` | 仍被 environment、dispatcher 和 tools pin 使用，保留独立 |
| `codex/ci-node24` | `c8b881218775138a3d37c9ced97aab16b01e6d3c` | Node actions 更新的历史分支，见下文差异 |
| `codex/ios-native-update` | `bfb49ed8a41a9b531a64783f9407959085e4444e` | 已发布 1.1.9 对应源码，也是 main 祖先 |
| `codex/ios-support` | `3222b8d609caaf74c28f61712c8d654e4937eed9` | 历史祖先；Cloud push 对该分支有仅 iOS 条件 |
| `codex/migration-package-20261021` | `d45b9d09e08a9f10f4e2e6f6908774ce8b861842` | 无共同祖先的归档引用，内容和消费者未判定 |
| `codex/mobile-pay-fix` | `a8ebedc65f4d6ade0286f25c0184db33a377f1cd` | main 祖先，历史产品修复 |
| `codex/native-client-shared` | `ed8f1f00c2ceb04c292d5a577b5b46e08ab9ba7c` | 仍被公证验证和 Windows Helper 特定门禁引用 |
| `codex/patched-integration` | `c651e44b4f48994a57f748957718c9bdf08be75a` | A1 以前的 main，也是当前祖先 |
| `codex/release-1.1.8` | `bf4852f35d39fd14f5e4a27a42341540725b3461` | 已发布历史版本来源，当前祖先 |
| `codex/upstream-0.9.1` | `08d3053745c1e853aea25b62a617a2a64c8fc17a` | 当前祖先，PR #3 的 base |
| `codex/zolnit-client` | `ec9339f9f9617e6238f529aa1e5bf32d4e2bca9e` | 两项图上独有工作已有对应去向，PR #3 已于 2026-11-16 关闭 |

[PR #1](https://github.com/Zolmid/FlClash/pull/1) 已合并；[PR #2](https://github.com/Zolmid/FlClash/pull/2) 随 main 快进后的可达关系被 GitHub 标为 MERGED；[PR #3](https://github.com/Zolmid/FlClash/pull/3) 已于 2026-11-16 关闭，未合并，base/head 未改。2026-11-16 状态：`codex/mobile-pay-fix`、`codex/release-1.1.8`、`codex/ci-node24`、`codex/ios-native-update` 已按精确 SHA 删除并逐项回读为 404；表中其余行保持观察时的记录。2026-11-16 起未重命名其他分支，也未移动正式 tag。

核对命令（只读，不会触发 workflow）：

```sh
gh api repos/Zolmid/FlClash/branches --paginate
gh pr list -R Zolmid/FlClash --state all --limit 100
# REPO 由维护者设为当前实际客户端仓库路径；不要指向总项目根目录。
git -C "$REPO" worktree list --porcelain
git -C "$REPO" status --short
git -C "$REPO" rev-parse HEAD
git -C "$REPO" for-each-ref --format='%(refname) %(objectname)' refs/heads refs/archive
```

`main` 指向开发源码不代表公开 App 已更新。正式 v1.1.10 的 tag 解引用到 `09de8037c81bc25e40ff4b0dea00c5ad5b23b4ed`；历史 v1.1.9 指向 `bfb49ed8a41a9b531a64783f9407959085e4444e`；GitHub Release 的 `target_commitish` 不是选择基线的依据。

## 2. 图上独有工作的实际去向

初始审计的比较基线是 `bfb49ed8`，不能将该时点的 ahead/behind 数字当成 d0af9d83 的数字。当前判断应同时看 `merge-base`、`rev-list --left-right --count`、`cherry`/patch-id 与最终源码；GitHub compare 若截断文件，需要继续读取目标提交/本地对象。

### `codex/zolnit-client`

共同祖先为 `66841b033fab59fc529561f71c689f42ce3d4428`，图上有两个独有 fixup。主控读取了两个完整本地提交 diff，并与当前源码核对：

| 提交 | 原改动 | 当前对应与判定 |
|---|---|---|
| `b57656f97478bef60e5bc4ac5f001013fa5eff36` | 侧栏 `StackFit.expand`、七种 workspace 翻译及生成输出、侧栏测试 | `lib/views/zolnit/shell.dart` 保留 `StackFit.expand`；七种 ARB 值及生成文本仍对应。当前测试已演进为自适应导航对齐、品牌标题测试。**修复已吸收，UI/测试后续演进；不是整个提交逐字节等价** |
| `ec9339f9f9617e6238f529aa1e5bf32d4e2bca9e` | 将所有 403 登出收窄到 `/api/v1/user/info`，补错误分类测试和 README | 当前 `XboardClient._failure` 进一步要求账户响应具有明确失效语义；普通权限拒绝保持凭据。**旧修复意图已被后续实现取代并细化**，不是旧条件/测试名原样保留 |

第一项旧测试要求显示“我的空间”；当前 `sidebar_test.dart` 要求品牌组件，不能仅凭测试文件存在便声称旧界面完全未变。七种 `zolnitWorkspace` 词条在 ARB 与生成消息中仍保留，但不据此认定它们仍是现行侧栏标题。

第二项当前条件是 `401 || (403 && path == '/api/v1/user/info' && _isExpiredAccountResponse(bodyBytes))`。`_isExpiredAccountResponse` 校验结构化失效 code 或明确的过期消息，未知 HTML/403 不使登录失效。对应当前测试包括 `explicit authentication failures never expose the server text`、`foreign account 403 responses preserve the credential`、`subscription and order permission failures do not invalidate authentication`。插件错误另走消息映射；不能把旧的 `plugin 403 keeps...` 测试名写成当前仍存在。

[API 源码](../../packages/zolnit_client/lib/src/api.dart)、[API 错误测试](../../packages/zolnit_client/test/api_errors_test.dart)、[当前侧栏测试](../../test/views/zolnit/sidebar_test.dart) 是维护入口。这里完成了两个 fixup 的源码去向判断，没有再次实测其全部运行行为；既有标准 CI 与新设备验收分别取证。

这两项没有发现需要重新移植的遗失修复。PR #3、工作流历史分支条件与外部消费者仍须先处理，不能因为内容已吸收就直接删分支。

### `codex/ci-node24`

独有 action 升级已完整进入产品历史 `bf4852f35d39fd14f5e4a27a42341540725b3461`。直接比较 `c8b88121` 与该提交的全部 workflow 树，差别仅为产品后来增加的五行测试注解屏蔽；屏蔽不是 c8 遗失的内容。d0 再把 Node 单文件测试改成 glob 并提取选择器。该分支的独有工作已被吸收/后续细化，无需产品负责人替可核对的技术等价性作决定。

c8 不是main祖先，删除前应保留完整可恢复的Git历史；本次已有本地archive ref及经过 `git bundle verify` 的独立bundle。该备份不包含WIP、LFS内容、子模块对象或外部产物。已知消费者调查支持把它与mobile-pay-fix等历史分支列入精确删除审批候选；2026-11-16 已按批准删除；恢复依据为本地 archive ref 与 bundle 记录。公开tag指向同一commit不构成必须保留开发分支名的技术依赖，tag本身保持不可变。

### Apple 工具分叉与本地历史 refs

Apple 工具代码、队列与 environment pin 具有独立生命周期，不能整分支 merge 后宣布迁移完成。初始审计对 Linux tray 补丁得到 cherry 等价证据；其余签名工具继续单独维护。

本地 `codex/client-ios-resume`、`client-web-session`、`macos-notarization-prep` 的 cherry-mark 是抽样补丁等价证据，不能代替完整行为验收。其他 local/origin refs 未证明消费者迁移前继续保留。无共同祖先的迁移归档只登记 tree/元数据，未展开可能含私有资料的分卷；不得自动 unrelated-histories 合并。

## 3. 归档与删除协议

总项目控制工作已为观察到的 13 个远端分支建立本地 `refs/archive/runbook-20261115/...` 快照，保留完整 SHA；这些是本地 Git refs，不是服务器备份，也不包含未提交 WIP、LFS 内容、子模块对象、签名材料或外部 artifact。独立新克隆不保证带有这些 refs。

归档前逐支记录：精确 ref/SHA、独有工作去向、open PR、workflow/dispatcher/人工消费者、活动任务、签名/公证恢复用途、恢复负责人。可读取：

```sh
rg -n 'codex/zolnit-client|codex/apple-distribution-prep|codex/native-client-shared' "$REPO/.github/workflows" "$REPO/tool"
git -C "$REPO" for-each-ref --format='%(refname) %(objectname)' refs/archive/runbook-20261115
```

源码 grep 只是消费者调查的一部分，不证明外部没有引用。除 2026-11-16 已按批准删除的四个历史分支外，其余远端分支仍保留：Apple/native 分支仍有已知职责，PR #3 已关闭，相关 head/base 分支保留，归档分卷及部分本地 refs 的消费者不明。远端删除并非上线前置。

若后续确需删除，批准包必须列出精确 ref 和当时 SHA、已迁移消费者、保留快照、恢复命令及不可恢复范围；执行前重读 ref，发现漂移即停止。禁止通配删除、prune、移动正式 tag 或强推共享历史。关闭 PR 也是单独远程写入，不能由文档中的 COVERED 自动触发。

## 4. 已完成的真实上游演练

真实上游为 `chen08209/FlClash`。2026-11-15 观察到的 upstream main 为 `be84736605527034689c95bf27828ff27d912c5e`（v0.9.3），未采用整版。

演练选择真实提交 `63aaf6d8cfc501f57b0da53603a35a7f85a990ec`，父提交 `b7df45838e2f1bbf6fda1acaeb6b43df1147094f`。完整补丁预检在 `access.dart` 智能选择相关代码和测试导入处冲突，原因涉及本地 UI/l10n 假设差异。最终只移植保存列表的一个行为 hunk：保存当前排序并保留隐藏的系统、无网络、已卸载条目，适配三处本地调用方。

演练分支 `codex/refactor-upstream-rehearsal-20261115` 的 base 为 `0401fc6a9d2bc250257c942cb985fbc4526058dc`，head 为 `7bfc4a4630c8e1cd15087fba715717472963badc`；涉及 `lib/views/access.dart` 和 `test/views/access_test.dart`，18 行新增、27 行删除。旧源码配新期望得到 FAIL，移植后 20 项 access 测试及全量分析 PASS。Core 和最终 pubspec 保持原值。

这证明一次有边界的移植闭环，不证明整版 0.9.3 或整个 63aaf6d8 已同步。该行为变化仍停留在演练分支，未进入产品 main；采纳前应在当时新主线上独立评审和验收。

## 5. 后续上游更新操作流程

1. 在隔离工作树固定真实上游 SHA、父提交和本地主线 SHA；读取实际 diff，不以分支名或最新日期代替来源。
2. 将行为修复、UI/l10n、构建工具与 Core/SDK 变化分开。保留上游共享区结构，产品扩展通过最小适配连接；不要为了追版本整体覆盖自有逻辑。
3. 对保存的准确 patch 先做 `git -C "$REPO" apply --check /absolute/path/change.patch`。`cherry-pick --no-commit` 会改工作树，只能在自有干净演练树中使用；它不是只读预检。
4. 冲突时记录触发代码和语义，选择移植一个完整、可解释的修复或暂不采用。禁止 `-X theirs` 和 unrelated-histories 强行通过。
5. 行为变化有针对性反例；先验证旧实现失败，再验证移植后通过，运行相关既有测试及分析。不要为机械文档改动新建运行时测试。
6. 记录上游 SHA、本地补丁、未采纳部分及原因、调用方、测试输入/环境、适配责任人和删除条件。独立审查后串行集成，组合回归通过才提升验证基线。
7. 回退使用本次明确的独立提交或 patch；后续若有其他改动，不能直接整文件覆盖。代码回退不自动还原真实数据或已发布产物。

Core 固定 `8380d0e7462f061a964323e9bf3129a236fcc5d5`。不以更新上游之名替换 Core/SDK/框架、恢复已决定隐藏的 UI、改变持久化合同或自动发布。现有控制器和状态框架没有具体问题时继续保留。

## 6. 后续维护去向

- **主线开发**：从当时重新核验的 main 建立隔离工作树，保持旧 APP WIP；不要在旧 checkout 自动 reset。
- **历史分支**：四个已完成精确归档的分支已删除，PR #3 已关闭；其余分支继续保留，任何进一步删除都需逐项精确批准。
- **上游演练补丁**：需要新的采用任务和相关行为验收，不能随文档整合夹带进入 main。
- **CI 精简**：参见 [CI 与发布](ci-release-and-recovery.md)，配置重叠与分支补丁等价分别判断。

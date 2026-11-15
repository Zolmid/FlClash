# 已验证基线与证据索引

业务源码：`d0af9d83c4f37199caceb436b3c3ae66cdb36cd6`，观察日期2026-11-15。本文区分已发布产品、开发源码及实际验收，不将未执行项补成PASS。

## 1. 产品与源码身份

| 对象 | 完整来源 | 证据边界 |
|---|---|---|
| 已发布1.1.9 | `bfb49ed8a41a9b531a64783f9407959085e4444e` | [正式run43608456827](https://github.com/Zolmid/FlClash/actions/runs/43608456827)，不是新main的发行验收 |
| 开发主线 | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | A1完成，以下V1/V2与产物核验 |
| Apple工具 | `97f297743718b6d46272d244ad375b5ca903f499` | 与App SHA分开，现有环境/调度pin |
| Core | `8380d0e7462f061a964323e9bf3129a236fcc5d5` | 原gitlink，不是独立滚动升级 |

GitHub Release的target_commitish可写main，应以tag解引用后的commit为准。A1前后公开清单逐字节一致。

Public manifest SHA256: `0d4c9a3accf34804ca8af870c620ec69f8d97a4e691d9317650e9787b2a35b06`

## 2. 实际托管执行

| 角色 | Run | Source | 结果 |
|---|---|---|---|
| candidate-standard | [43681141225](https://github.com/Zolmid/FlClash/actions/runs/43681141225) | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | success; 9 successful jobs |
| candidate-cloud-zolnit | [43682721647](https://github.com/Zolmid/FlClash/actions/runs/43682721647) | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | success; 7 successful jobs |
| candidate-cloud-auto | [43683057155](https://github.com/Zolmid/FlClash/actions/runs/43683057155) | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | success; 7 successful jobs |
| main-standard | [43685937818](https://github.com/Zolmid/FlClash/actions/runs/43685937818) | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | success; 9 successful jobs |
| main-cloud | [43685937860](https://github.com/Zolmid/FlClash/actions/runs/43685937860) | `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6` | success; 7 successful jobs |

标准Dart job日志确认选择器与履历用例在内的32项Node测试实际执行、零失败；main专用changelog通过，push缺省BUILD_PROFILE真实求值为auto。条件跳过的发布jobs不计作正式发布成功。

## 3. 同源双profile产物

下表记录验证时的artifact身份和外层SHA256。内部SHA256SUMS、profile、source/event/workflow SHA、run/attempt、Core与工具链也已核对。下载前仍需查询API的expired/digest；保留期不是永久存储承诺。

| Profile | 平台/架构 | Run/attempt | Artifact ID | 外层SHA256 |
|---|---|---|---|---|
| zolnit | android/arm64 | 43682721647/1 | 14149097531 | `fce13333d7568c138bc7604319b8a1c429e8f57256416cba56cb2720481200f9` |
| zolnit | linux/x64 | 43682721647/1 | 14149062086 | `6c70fb2ccadc93df0833746e7f376b5953dd697a4477f3f996c8bf5ed31cb6b7` |
| zolnit | macos/arm64 | 43682721647/1 | 14149850870 | `6bff00640a1025225d49ef08dae361b8f1fca0ad941be3ea7ea842e7eeb83134` |
| zolnit | macos/x64 | 43682721647/1 | 14149141996 | `bd5dd8ec85cad012c1448a69de45bf9441dd98ebf75b72f3581487e25ed6ef38` |
| zolnit | windows/x64 | 43682721647/1 | 14148848605 | `8d99f9de9df5a272b4b364a3f30e1e349e3734b0a8a37d9e4a9c5e6b70877a52` |
| zolnit | ios/arm64 | 43682721647/1 | 14148833384 | `42af24bf4b7b65c52b6fd1386ba81d721df32d94bdfd957d11a5965de8ae749e` |
| auto | android/arm64 | 43683057155/1 | 14149663885 | `bae41d5d6b695c747de36e771cbbf0974b6cf37c2d1d947246f82b36776bcdd2` |
| auto | linux/x64 | 43683057155/1 | 14149373939 | `07b67691c1dbb9e5e1d2e3464c8f20fc367f259e8a0917ac2ef4ef4bd88e1683` |
| auto | macos/arm64 | 43683057155/1 | 14149359706 | `219ba8f9cfaf0b192b969435edf3e8954dd60dd9c414388b18622e804c46cf8d` |
| auto | macos/x64 | 43683057155/1 | 14149304974 | `d01a089a124e772e25bbae4def4960c12277d588ee77e44f5ef256ad68ae06cd` |
| auto | windows/x64 | 43683057155/1 | 14148874648 | `09fed70ece64ada5ad4f24f6e0019c093b90b68ff9dd2f5633cd53e5c09c3164` |
| auto | ios/arm64 | 43683057155/1 | 14148889354 | `78e94b2e01df16d69936a5a5ac896dca34c24df5fa32e8a2ebc42ba78184f905` |

不同profile的参数和最终字节可以不同，分别核对各自摘要；不能以同名文件或run_number代替repo/run/attempt/artifact ID绑定。

## 4. 本地与历史证据

| 范围 | 观察结果 | 限制 |
|---|---|---|
| Flutter与礼品卡 | 全分析PASS，12个界面/恢复和8个包协议测试PASS | mock HTTP/隔离存储，不是设备支付或VPN |
| 发布辅助/CI | 32 Node、80 release Python、10 CI Python PASS，2真实样本SKIPPED | 合成错误来源、摘要、幂等和恢复；skip不算PASS |
| iOS开发包 | Xcode27.1/SDK27.1，三个arm64目标，ad-hoc且无发行描述文件 | 生成CocoaPods项目补丁另有摘要，不冒充干净HEAD完整编译输入 |
| 上游演练 | 真实63aaf6d8保存hunk，旧代码新期望FAIL、移植PASS，全分析PASS | 独立7bfc4a46，不是整版上游同步，也未进入产品main |
| 取消演练 | 实际超时结束自有父子进程组，无关哨兵存活 | 本地POSIX命令；不是宿主崩溃或native Agent迟到回包证明 |
| 检查点 | 只读重载、HEAD/tree/回执及无在途工作核对通过 | 没有重放push、CI、签名或发布 |

既有APP交接报告：公开1.1.9在原登记iPhone完成OTA覆盖安装和构建号回读；Linux在隔离Ubuntu完成1.1.8→1.1.9升级；macOS公开DMG签名/票据/Gatekeeper和Android正式签名已有记录。这些是bfb49ed8版本的历史证据，不是d0af9d83或后续文档提交的新V3/V4验收。

## 5. 未完成与后续要求

用户已明确将真机/VPN验收另列。新候选的实机安装、各平台系统权限/网络、锁屏/切网、真实支付和新正式分发未由本次工作认证。Windows登录历史调查曾暂停；TestFlight资料补交、移动微信启用也不是本手册自动恢复的动作。

新版本需要新的版本/build、准确App/tools/core来源、候选门禁和具体发行授权；不得移动1.1.9标签或同版本覆盖。

## 6. 本地运维证据

整包控制记录位于`.dev/flclash-refactor-20261115/control/`，包括A1-execution.json、checkpoint.json、review/handoff和evidence。独立客户端克隆不保证有这些文件，因此本章保留可移植的公共run链接、完整SHA与摘要。凭据、真实设备标识和签名材料不进入本仓库。

## 7. C 增量：证据与尚待验收

- APP/CI 组合回归固定源码 `7fd40a7a4777047b554a786ea4085ec1d62a0240`：61 项 APP 测试、23 项 CI Python、80 项 release Python（另 2 skipped）、32 项 Node 与 analyze 通过；actionlint 首次因找不到命令退出 127，使用 1.7.12 重新检查两个 workflow 通过。测试时仅临时关闭 `setup.build_assets`，保留 `rust_api`，随后恢复原配置。此结果不包含新 iOS 原生候选，也不证明设备或生产行为。
- CI 独立复核未发现 P1/P2；对历史 [正式运行 43608456827](https://github.com/Zolmid/FlClash/actions/runs/43608456827) 的四次真实只读 GET 和合成 caller 上下文回放成功，不是新 gate 的 hosted 运行。C 新候选尚未 dispatch。
- iOS 独立候选 `f56261c89300a7792caeb7ba96f45882583a6abd` 的作者本地 harness 与 SDK 检查通过；独立复审和完整 Runner build 仍在进行，候选尚不属于本文所在源码树，也不是发布通过。真实系统通知、弹窗、权限、后台、OnDemand、实际隧道、升级/降级及 V3 均未验证。
- `1.1.10+2026111501` 仅局部预留；尚无新 tag 或发版。A1 时 main 为 `d0af9d83`，后续需重查；公开 v1.1.9 仍以 `bfb49ed8` 的历史记录为准。tools `97f29774` 与 Core `8380d0e7` 未变。历史分支清理清单已准备，未删除。

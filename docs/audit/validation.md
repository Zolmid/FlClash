# 应用层整合检查点验证

本记录区分首个应用层检查点与后续 UI 补齐批次；不能用历史 iOS 构建结果替代交接提交的云端验证。
原核保持 `8380d0e7462f061a964323e9bf3129a236fcc5d5`，`.gitmodules`、Go 依赖锁、
helper 鉴权、`build.yaml`/`pages.yaml` 和覆盖率门槛均未更改。

## 首个完整应用层检查点

以下结果对应 `88476f4641da39e1dd24c84f065aa06054ab2200`。

| 检查 | 结果 |
| --- | --- |
| `flutter pub get --enforce-lockfile` | 通过，保留现有依赖 |
| build_runner / intl_utils | 重新生成完成；生成文件全部纳入 |
| 全目录 Dart 格式 / `flutter analyze --no-fatal-infos` | 通过，无分析问题 |
| `flutter test --no-pub --reporter expanded --coverage` | **4252 passed / 2 skipped** |
| `dart run tool/check_coverage.dart coverage/lcov.info 75` | **86.37%**，全部既有分组门槛通过 |
| `dart run tool/changelog.dart verify` | 提交前和该 SHA 提交后均通过：`Changelog is consistent with git.`；不发布、不打 tag、不改版本 |
| cloud-build actionlint / 事件选择检查 | 通过；17 种事件与 inputs 场景 |
| hooks 单测 / 默认 comment-density / staged whitespace | 通过；未调整门槛 |
| Go wrapper | 原核上的 host test/vet、低内存 test、Android/Darwin portable vet 通过，详见 [Core](core.md) |
| Android 纯 Kotlin/JVM | 117 项通过；不是完整 SDK 编译，详见 [Android](android.md) |
| tray / window 插件 | Dart 回归、Linux native CTest 与 Windows 源码定向检查通过，详见 [托盘](desktop-tray.md) |
| Windows proxy ownership | 可移植 C++ gtest 8 项通过；Windows cloud job 已接线 configure/build/CTest，原生执行结果以对应运行核验为准 |
| setup / Rust 构建适配 | 领域单测与检查通过，详见 [构建](dependencies-build.md) |

Flutter 测试按现有 CI 暂时关闭 setup 的 Go 构建 hook，保留 rust_api hook；测试后两个 hook 均恢复
`build_assets: true`。未运行宿主 App。iOS Mach footprint 的 C 实现放在既有 `core/ios/bride.c`，
Go 桥只注册读取回调；它的 Apple SDK 编译由真实 iOS 云构建验证，未在 Linux 模拟编译 iOS。

`build.yaml` 的 changelog verify 仅在 main/tag 执行，因此整合分支“9 项全绿”不包含该步。
本地已补充执行；每个最终交接 SHA 提交后还须复跑同一命令，并在交接消息记录结果。
未修改任何 changelog 校验规则。

## 后续 UI 补齐批次

生产源码在最终全量检查开始时冻结；随后唯一的 Dart 改动是下述测试夹具修正。

| 检查 | 实际结果 |
| --- | --- |
| build_runner | 完成，协程卡片 enum 的序列化输出已纳入；未手改生成文件 |
| `dart format --output=none --set-exit-if-changed lib test tool plugins setup.dart` | 901 个文件，0 个格式差异 |
| `flutter analyze --no-fatal-infos` | 全量前及夹具修正后均无问题 |
| `flutter test --no-pub --reporter expanded --coverage` | **4313 passed / 2 skipped / 1 failed**；唯一失败是新增 SSID 对话框测试的尺寸夹具，见下文 |
| 修正后 `flutter test --no-pub --reporter expanded test/widgets/on_demand_test.dart` | **16 passed**，包括该新增用例及原有断言 |
| `dart run tool/check_coverage.dart coverage/lcov.info 75` | 全量产生的覆盖率 **86.52%（38967/45037）**，所有既有分组门槛通过 |
| 原生语言/安装器验证 | 主套件包含 4 项原生语言契约测试；独立固定 provider 包的 2 项实际 Liquid 渲染测试、分析与格式通过，见 [原生语言](native-localization.md) |
| 默认 comment-density、差异空白与本地文档链接 | 通过，未放宽规则 |
| `dart run tool/changelog.dart verify` | 本批提交前通过：`Changelog is consistent with git.`；提交后还须对交接 SHA 复跑并报告 |

SSID 夹具仅设置 `tester.view.physicalSize`，没有生产环境的 `ThemeManager`，也没有给
`CommonDialog` 读取的 `viewSizeProvider` 赋值。该 provider 默认 `Size.zero`，导致对话框高度约束为负。
修正是在该夹具中按自身 size 参数覆盖 provider；原焦点、提交保存及旧测试断言均保留，未修改 App。
原先的定向运行未暴露这个遗漏，不能据此省略全量检查。修正后复跑整个受影响 suite，复用其他
未改源码和测试的本次全量结果，不重复执行全部已通过 suite。两次执行合起来覆盖 4314 个通过用例及
2 个跳过用例；这不是声称本地最后一次全量命令一次性全绿。随后外层已 fetch `b9af3521` 并独立核验
标准 CI `38724531295` 与 Cloud all/project `38724531398` 全部成功。

## 独立 review 修复批次

八项阻断及 Windows 真实 ISCC 编译门禁的精确范围、验证和平台限制见
[审查修复记录](review-fixes.md)。本轮只运行受影响的 12 个 Flutter suite，**206 项全部通过**，
分析无问题，模型/provider 生成输出已纳入。未重复执行历史已通过的 Flutter 全套测试，
未更改 CI/覆盖率门槛、版本或发布 guard。主任务在本批 fixup SHA 提交后继续执行 changelog verify，
完整原生构建及新增 ISCC 门禁由该 SHA 的 Cloud job 验证。

## 后续验证

本检查点 push 后，cloud-build 自动使用 `all/project` 构建 Linux、Windows、Android、macOS arm64/Intel
和项目 iOS IPA，共六份平台产物；Windows 新增的 5 项托盘 CTest 会实际 configure/build/run。
本地 Linux 结果不代表 Windows/macOS/Xcode/Android SDK 编译成功。
main 合并仍须外层独立 review 和最终同 SHA 全平台验证。

首个检查点遗漏的应用层 UI 净增量已由后续批次补齐，详见[产品审计](product-ui.md)与下列领域记录：
[仪表盘键盘编辑](dashboard-keyboard.md)、[原始 YAML 创建](profile-creation.md)、
[运行时 UI](runtime-ui.md)、[输入交互](dialog-inputs.md)和[原生繁中](native-localization.md)。
依赖新内核的增强因维护成本延后，优先等待 FlClash 上游带入验证版本。
签名真机 VPN、前后台/锁屏/低内存/切网、Widget/QS、UAC/安装器和真实桌面会话仍未验证。

# 应用层整合检查点验证

本记录对应本次 Patched 应用层检查点；不能用历史 iOS 构建结果替代本提交的云端验证。
原核保持 `8380d0e7462f061a964323e9bf3129a236fcc5d5`，`.gitmodules`、Go 依赖锁、
helper 鉴权、`build.yaml`/`pages.yaml` 和覆盖率门槛均未更改。

## 本地结果

| 检查 | 结果 |
| --- | --- |
| `flutter pub get --enforce-lockfile` | 通过，保留现有依赖 |
| build_runner / intl_utils | 重新生成完成；生成文件全部纳入 |
| 全目录 Dart 格式 / `flutter analyze --no-fatal-infos` | 通过，无分析问题 |
| `flutter test --no-pub --reporter expanded --coverage` | **4252 passed / 2 skipped** |
| `dart run tool/check_coverage.dart coverage/lcov.info 75` | **86.37%**，全部既有分组门槛通过 |
| `dart run tool/changelog.dart verify` | 提交前通过：`Changelog is consistent with git.`；不发布、不打 tag、不改版本 |
| cloud-build actionlint / 事件选择检查 | 通过；17 种事件与 inputs 场景 |
| hooks 单测 / 默认 comment-density / staged whitespace | 通过；未调整门槛 |
| Go wrapper | 原核上的 host test/vet、低内存 test、Android/Darwin portable vet 通过，详见 [Core](core.md) |
| Android 纯 Kotlin/JVM | 117 项通过；不是完整 SDK 编译，详见 [Android](android.md) |
| tray / window 插件 | Dart 回归、Linux native CTest 与 Windows 源码定向检查通过，详见 [托盘](desktop-tray.md) |
| Windows proxy ownership | 可移植 C++ gtest 8 项通过；Windows cloud job 也实际运行该目标 |
| setup / Rust 构建适配 | 领域单测与检查通过，详见 [构建](dependencies-build.md) |

Flutter 测试按现有 CI 暂时关闭 setup 的 Go 构建 hook，保留 rust_api hook；测试后两个 hook 均恢复
`build_assets: true`。未运行宿主 App。iOS Mach footprint 的 C 实现放在既有 `core/ios/bride.c`，
Go 桥只注册读取回调；它的 Apple SDK 编译由真实 iOS 云构建验证，未在 Linux 模拟编译 iOS。

`build.yaml` 的 changelog verify 仅在 main/tag 执行，因此整合分支“9 项全绿”不包含该步。
本地已补充执行；主任务还在提交后对交接 SHA 复跑同一命令。未修改任何 changelog 校验规则。

## 后续验证

本检查点 push 后，cloud-build 自动使用 `all/project` 构建 Linux、Windows、Android、macOS arm64/Intel
和项目 iOS IPA，共六份平台产物；Windows 新增的 5 项托盘 CTest 会实际 configure/build/run。
本地 Linux 结果不代表 Windows/macOS/Xcode/Android SDK 编译成功。
main 合并仍须外层独立 review 和最终同 SHA 全平台验证。

尚缺的应用层 UI 净增量列在[产品审计](product-ui.md)，继续按下一批实施；依赖新内核的增强则因维护成本延后。
签名真机 VPN、前后台/锁屏/低内存/切网、Widget/QS、UAC/安装器和真实桌面会话仍未验证。

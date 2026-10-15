# 统一云端构建

开发仓库：`Zolmid/FlClash`。日常编辑、静态检查和共享代码测试使用 FlClash 云环境；
原生构建由同一个 GitHub Actions 工作流调度不同操作系统的执行器。

入口：[Actions → Cloud build](https://github.com/Zolmid/FlClash/actions/workflows/cloud-build.yml)。
选择 **Run workflow**、待构建的分支，以及 `platform=all`，即可启动全部平台。
也可以只选一个平台；`macos` 同时构建 Apple Silicon 和 Intel 两种架构。
各任务独立运行，一项失败不会取消其他平台；构建完成后在该次运行的 Artifacts 下载，保留 14 天。

使用现有 Git 认证执行 `git push` 即可触发自动构建，无需新增 token 或修改网络配置：

| push 分支 | 构建目标 | iOS 源码 |
| --- | --- | --- |
| `main` | 全平台（`all`） | 当前主项目（`project`） |
| `codex/patched-integration` | 全平台（`all`），供合并前独立 review | 当前主项目（`project`） |
| `codex/ios-support` | 仅 iOS | 当前主项目（`project`） |

仅修改 Markdown 文件或 `docs/**` 时不自动构建。其他分支不受此规则影响。
手动 **Run workflow** 仍保留全部平台与 iOS 源码选项；自动构建永远不选择 Patched 对照。
工作流在统一选择任务中处理 push 事件缺省的 inputs，平台矩阵、iOS 条件、源码 checkout、
缓存与 artifact 命名均使用该选择结果。并发按分支和目标隔离，`cancel-in-progress: false`
保留正在运行的任务；新增 push 不会取消现有运行。

| 目标 | 云端执行器 | 当前源码 | 产物 |
| --- | --- | --- | --- |
| Linux x64 | Ubuntu 22.04 | 所选 FlClash 分支 | 包含完整运行目录的 tar.gz |
| Windows x64 | Windows 2022 | 所选 FlClash 分支 | 包含 exe、DLL 和资源的 zip |
| Android arm64 | Ubuntu 24.04 | 所选 FlClash 分支 | Debug 开发签名 APK |
| macOS arm64 | macOS 26 | 所选 FlClash 分支 | 保留权限与符号链接的 app zip |
| macOS x64 | macOS 15 Intel | 所选 FlClash 分支 | app zip |
| iOS arm64 | macOS 26 / Xcode | 显式选择的 iOS 源码 | 无 provisioning 的 IPA |

这些是用于开发验证的构建产物：Android 为 Debug，其余为 Release 模式，桌面产物不是安装器。
每个下载包含 `source-provenance.txt` 和 `SHA256SUMS`，用于确认源码、子模块、工具链和校验值。
工作流仅授予 `contents: read` 权限。自动和手动构建均不使用生产签名，不发布 Release，
不上传 TestFlight，不向 Telegram、Homebrew 或 F-Droid 推送。
上游已有的 `build.yaml` 保持原样，继续负责已有检查。
Windows 云任务在编译后实际运行代理归属状态 gtest 和托盘菜单原生 CTest；
只编译桌面 bundle 不计作这些测试已经执行。

## iOS 源码选择

默认 `ios_source=project` 构建本仓库所选分支的实验性 iOS 移植。
实现包含 Runner、Packet Tunnel 扩展、Widget、Flutter 服务桥，以及普通和低内存 Go 静态库。
它保留当前 FlClash 的 `core/Clash.Meta` 子模块和 `com.follow.clash` 应用标识。
本地共享代码检查不能证明 Xcode 编译通过或真机 VPN 可用。

`ios_source=patched-reference` 构建独立参考项目
[`chenx-dust/FlClash-Patched`](https://github.com/chenx-dust/FlClash-Patched)，固定提交
`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`。
产物名称包含 `patched-reference`，用于与移植版本比较，不是本仓库的构建产物。
同一次 `all` 运行中，其他四个平台仍构建当前所选的 FlClash 分支。

`project` 模式在原生工程或构建失败时会明确失败，不会自动退回参考项目。
选择 `platform=all`、`ios_source=project` 时，五个平台均来自同一条开发分支。

## 本地 iOS 构建

在安装 Xcode、Flutter、Go、Rust 和 `aarch64-apple-ios` Rust target 的 Mac 上运行：

```bash
git submodule update --init --recursive
flutter pub get --enforce-lockfile
rustup target add aarch64-apple-ios
dart setup.dart ios --env dev --no-codesign -v
```

产物为 `dist/*-ios-arm64-unsigned.ipa`。Xcode 构建阶段调用
`plugins/setup/setup_hooks/bin/build_ios.dart`，生成 `libclash/ios/arm64/` 下的
`libclash.a` 和 `libclash_lowmem.a`，分别供主应用和 Packet Tunnel 使用。
只构建 Go 静态库可在仓库根目录执行：

```bash
PLATFORM_NAME=iphoneos ARCHS=arm64 SRCROOT="$PWD/ios" \
  dart run plugins/setup/setup_hooks/bin/build_ios.dart
```

Simulator 和非 arm64 slice 会明确失败。

## 工具链

- FlClash：Flutter 3.47.6、Go 1.27.1、Rust 1.99.0。
- Android：Temurin Java 17、NDK r28c（28.2.13676358），SDK 版本由项目 Gradle 配置决定。
- Patched iOS 参考：Flutter 3.47.7、Go 1.26.8、Rust 1.99.0。
- Apple 构建：Xcode 26.3，执行器缺少该版本时使用 26.2。

工具链独立固定。更新参考提交时，应重新核对其 workflow、子模块、锁文件和 iOS 打包逻辑，
同时更新相应版本，不能只移动 SHA。`project` 模式当前使用 FlClash 主线工具链。
原生 Go/Rust hooks 保持开启，使用真实核心与插件进行编译。

## 签名与调试

Android 未配置生产 keystore 时，项目使用开发密钥和 `.dev` application ID。
此工作流使用 Debug APK，避免触发上游 Release 任务中的 Crashlytics mapping 上传。
不同执行器的开发密钥可能不同，升级安装前可能需要卸载旧的开发包。
macOS 产物为 ad hoc 签名，未经公证；Windows 产物没有生产签名。
iOS 的 `--no-codesign` 打包流程执行 ad hoc 签名，但不含可供普通设备安装的 provisioning。
真机运行需要匹配的证书、描述文件、Network Extension entitlement 和 App Group。

当前移植与 Patched 均只接受 **iOS arm64 真机目标**，拒绝 Simulator 构建。
Linux 云环境可编辑 Swift/Dart/Go/Rust 源码、分析差异和测试共享代码，不能运行 Xcode 或 iOS。
GitHub Actions 的 macOS 执行器用于编译；交互式断点、热重载、Network Extension 日志和 VPN 实测
需要可连接的 Mac 与 iPhone。编译通过不等于运行可靠。

iOS 首轮迁入了 `ios/`、Dart 服务桥、Go iOS/TUN 适配及构建 hooks；后续跨平台整合逐项审计，
不整树覆盖 Patched，具体取舍见[整合审计](patched-integration-audit.md)。
首次 Xcode 构建后，仍需在真机验证 VPN 启停与竞态、后台/锁屏、Wi-Fi/蜂窝切换、DNS/IPv6、
低内存、Widget，以及已有四平台回归。主应用最低 iOS 15，Widget 最低 iOS 18。

## 首轮移植验证（2026-10-15）

- 依赖解析、代码生成、格式检查和 Flutter 分析通过。
- 448 项 Flutter 回归、47 项 setup hooks 测试、55 项 Rust 测试、9 项 Wi-Fi 插件测试通过。
- Go 单元测试、host/Android vet 与使用 Darwin+iOS tags 的纯 Go 检查通过；这不能代替 Apple SDK 链接。
- Linux Release safe mode 构建成功，真实 Go/Rust hooks 保持开启。现有托盘的
  `app_indicator_new` 在云环境 Clang 下触发弃用错误，本地生成目录设置
  `CMAKE_CXX_FLAGS=-Wno-error=deprecated-declarations` 后完成构建，未改托盘源码。
- iOS plist、资源及工程引用已静态检查；新增的 Swift 原生测试尚未运行。
- [iOS 云端构建 38702052110](https://github.com/Zolmid/FlClash/actions/runs/38702052110)
  的 job `116312342357` 已成功，实际源提交为
  `2c8c9f8fdba0749832f221431af7cad85ac9a4ed`。Xcode Release 编译、未签名 IPA 打包、
  provenance 收集、artifact 上传和缓存收尾均通过。
- 产物 [ios-project-arm64-unsigned-2](https://github.com/Zolmid/FlClash/actions/runs/38702052110/artifacts/11956459587)：
  artifact ID `11956459587`，78,734,654 bytes，2026-10-29 到期。
- 这验证了移植项目可以生成 IPA；证书与 provisioning 配置、签名真机安装、VPN 和后台运行仍待验证。


## 已核验的 iOS 自动构建基线

外层独立核验 `3222b8d609caaf74c28f61712c8d654e4937eed9` 的
[iOS 自动构建 38703895573](https://github.com/Zolmid/FlClash/actions/runs/38703895573)
及[原有 9 项 CI 38703895671](https://github.com/Zolmid/FlClash/actions/runs/38703895671)
全部成功：4069 tests passed / 6 skipped，覆盖率 88.13%。
这组结果属于 iOS 支持分支的基线，不作为后续 Patched 整合提交的验证结果。
未签名 IPA 生成成功仍不代表签名真机 VPN、后台行为或其他设备交互已经验证。

## 整合分支检查点（外层独立核验）

- `0713ff79bbea1d85a33e06fb5a20c257076f04a3` 的
  [Cloud all/project 38710369127](https://github.com/Zolmid/FlClash/actions/runs/38710369127)
  已完整成功，包含 Linux、Windows、Android、macOS arm64/Intel 和项目 iOS IPA 共六份产物。
- `11406fa0db2042e5a107d137b9a81528e20e1a39` 的
  [标准 CI 38711463436](https://github.com/Zolmid/FlClash/actions/runs/38711463436)
  九项全部成功；[Cloud 38711463348](https://github.com/Zolmid/FlClash/actions/runs/38711463348)
  的结果仍由外层监控核验。

上述结果只覆盖对应 SHA，不包含后续整合提交。后续仍需同 SHA 全平台构建和独立 review 才合入 main。
保留原 `8380d0e` core 与依赖锁；长期同步策略及 iOS TUN FD 升级复核边界见
[上游维护说明](upstream-maintenance.md)。

# ZolNit 客户端开发指南

本文说明如何在任一干净检出中搭建、修改、检查和提交 ZolNit 客户端。所有命令都使用当前检出的路径，不依赖某台机器的绝对路径。写作基线为 `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6`（main）与产品基线 `bfb49ed8a41a9b531a64783f9407959085e4444e`（1.1.9）。“源码确认”指当前文件可见的值；“控制台观察”指 [验证基线](verification-baseline.md) 记录的本机版本；“未核对”指本次没有证据。

相关入口：[AGENTS.md](../../AGENTS.md)、[.agents/commands.md](../../.agents/commands.md)、[.agents/rules.md](../../.agents/rules.md)、[.agents/project.md](../../.agents/project.md)。架构见 [architecture.md](architecture.md)，平台身份见 [platform-contracts.md](platform-contracts.md)，诊断见 [testing-and-debugging.md](testing-and-debugging.md)。

## 1. 工具链：CI 固定值与本机观察值

| 项目 | CI 或仓库固定值 | 本机观察值（控制台） | 语言或最低约束 | 证据 |
|---|---|---|---|---|
| Flutter | 3.47.6（`FLUTTER_VERSION`）；iOS patched-reference 来源为 3.47.7 | 3.47.6，framework `5fc346839b5d0eef006ed8404392afb4dfae428d` | 由 SDK 决定 | [cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 101、560 行 |
| Dart | 随 Flutter 提供，仓库未单独固定 | 3.13.5 | 根包 `sdk: '>=3.10.0 <4.0.0'`；`setup_hooks` 为 `^3.10.0` | [pubspec.yaml](../../pubspec.yaml)，[setup_hooks/pubspec.yaml](../../plugins/setup/setup_hooks/pubspec.yaml) |
| Go | CI `GO_VERSION` 1.27.1 | 1.27.1 | `core/go.mod` 声明 `go 1.27.0` | [build.yaml](../../.github/workflows/build.yaml)，[core/go.mod](../../core/go.mod) |
| Rust | `RUSTUP_TOOLCHAIN` 1.99.0 | 未核对 | 由 [rust-toolchain.toml](../../plugins/rust_api/rust/rust-toolchain.toml) 决定 | [cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 103 行 |
| Xcode | 27.1（`/Applications/Xcode_27.1.app`） | 27.1，build 27A9275 | 部署目标取各 Xcode target；SDK 版本不是最低 OS 版本 | [cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 161 行 |
| Core | gitlink `core/Clash.Meta` = `8380d0e7462f061a964323e9bf3129a236fcc5d5` | 同左 | 分支 `FlClash` | [.gitmodules](../../.gitmodules) |

语言约束与运行时版本不能互相替代。例如 Dart 3.13.5 满足根包的 `>=3.10.0`，但如果 CI 的 Flutter 换成另一个小版本，Dart 版本也会随之变化。升级 Flutter 前，先读 [.agents/flutter-upgrade.md](../../.agents/flutter-upgrade.md)。

## 2. 干净检出与 worktree

仓库不要求特定绝对路径。下面的写法在任意目录中都可以执行。只要替换 `<remote>` 为已配置的 Git 远端名称即可。

```bash
# 1. 从远端获取一个只读基线，并在隔离目录中工作
git -C /absolute/path/to/parent clone <remote-url> zolnit-client
ZOLNIT_REPO=/absolute/path/to/parent/zolnit-client
git -C "$ZOLNIT_REPO" switch --detach d0af9d83c4f37199caceb436b3c3ae66cdb36cd6

# 2. 或者在已有的 main 检出上创建 worktree（不改动原检出）
git -C <existing-checkout> worktree add ../zolnit-client-feature -b <branch> d0af9d83c4f37199caceb436b3c3ae66cdb36cd6
```

子模块只按 gitlink 固定版本初始化，不能使用远端最新分支：

```bash
git -C "$ZOLNIT_REPO" submodule update --init core/Clash.Meta
git -C "$ZOLNIT_REPO/core/Clash.Meta" rev-parse HEAD   # 应为 8380d0e7462f061a964323e9bf3129a236fcc5d5
```

`.gitmodules` 的 `branch = FlClash` 只影响 `git submodule update --remote`。本仓库规则禁止使用该命令。CI 的 iOS patched-reference 路径另有 `git -C core/mihomo fetch --unshallow --tags`（[cloud-build.yml](../../.github/workflows/cloud-build.yml) 第 595 行）；这是特定来源的历史路径，普通开发不执行。

## 3. 包装器与 PATH

- 默认情况下直接使用 PATH 中的 `flutter`、`dart`、`go`、`cargo`，并用 `which flutter dart go` 核对版本。
- 若团队有锁定工具链的包装器，例如 `workspaces/client/.toolchain/zn-run`，应先读实际脚本确认 PATH、环境与额外行为；不能仅凭名称认定它只改变 PATH。A1 的本机命令环境记录见验证基线。
- 预提交钩子缓存必须放在任务专用目录：`PRE_COMMIT_HOME=<任务专用缓存目录>`。不要使用 `$HOME` 或 `$CODEX_HOME` 作为缓存目录。

## 4. 依赖解析与离线策略

CI 的 ZolNit 子包使用锁定解析（[build.yaml](../../.github/workflows/build.yaml) 第 125 行附近）：

```bash
cd packages/zolnit_client
flutter pub get --enforce-lockfile
```

根包的文档命令为 `flutter pub get`（[.agents/commands.md](../../.agents/commands.md)）。`--enforce-lockfile` 在锁文件缺项或需要改写时直接失败，适合审查依赖变化。离线状态下依赖 pub 缓存；本仓库没有 `--offline` 的 CI 证据，不要把它写进发布步骤。

iOS 与 Android 的构建需要 Xcode 与 Android SDK 本地就绪。Go 与 Rust 产物由构建钩子生成，不由 pub 下载。

## 5. 构建钩子与原生产物

- 根包的 `plugins/setup/hook/build.dart` 在 `flutter build` 与 `flutter test` 时运行，驱动 `plugins/setup/setup_hooks` 中的 `CoreBuilder`，编译 Go 核心与 Rust Helper（[.agents/commands.md](../../.agents/commands.md) 的 Building 一节）。
- `plugins/setup/setup_hooks` 是纯 Dart 包，依赖只包括 `code_assets`、`crypto`、`hooks`、`logging`、`path`、`yaml`（[pubspec.yaml](../../plugins/setup/setup_hooks/pubspec.yaml)）。它不是 Flutter 包，因此可以用 `dart` 单独测试。
- 钩子开关在根 `pubspec.yaml` 的 `hooks.user_defines` 中：`setup.build_assets` 与 `rust_api.build_assets`。只能用于纯 Dart 测试循环，不能提交为 `false`，否则 `setup.dart` 会拒绝打包（[.agents/commands.md](../../.agents/commands.md)）。
- Android 的 `:core` 模块依赖 `gomobile bind` 生成 AAR，只需要 `go` 在 PATH 中，gomobile 工具来自 `core/go.mod`。
- iOS 的 C ABI 位于 [core/ios/](../../core/ios/)，由 Runner 与 NECore 共同链接（[architecture.md](architecture.md)）。


### 本地构建与打包入口

先进入本任务隔离 checkout，核对上述工具链及构建钩子；以下只生成本地产物，不安装/启动 App，也不授予真实签名或发布权限。仓库既有完整命令说明见 [.agents/commands.md](../../.agents/commands.md)。

| 目标 | 仓库已有命令 | 环境与输出边界 |
|---|---|---|
| macOS | `dart setup.dart macos` | macOS/Xcode27，产物在 dist；实际签名类型另验 |
| Windows | `dart setup.dart windows` | Windows SDK/构建工具链；x64 与 WOA 运行验收分开 |
| Linux | `dart setup.dart linux` | Linux 图形/打包依赖；编译不代表系统 Helper 已安装 |
| Android | `dart setup.dart android` | JDK17、Gradle 版本目录和 NDK；正式签名取决于准确受控配置，不在此提供凭据 |
| iOS 开发包 | `dart setup.dart ios --env dev --no-codesign` | macOS/Xcode、Rust aarch64-apple-ios target；输出 arm64 unsigned IPA，不能直接代表真机安装资格 |

`setup.dart` 会执行完整构建并写 dist；诊断单个 Dart 行为优先相应单元测试，不重复五平台打包。Android compileSdk/targetSdk/NDK 来自 `android/gradle/libs.versions.toml` 与模块 Gradle 文件；不要只根据本机已安装版本推断编译输入。App 身份、渠道和构建开关对照平台章节及 Cloud 的显式 profile，不能把开发 APK/unsigned IPA上传为既有正式版本。

## 6. 代码生成与本地化

| 类型 | 命令 | 输入与输出 | 注意 |
|---|---|---|---|
| Riverpod、freezed、json、drift | `dart run build_runner build --delete-conflicting-outputs` | 模型、provider、数据库表；输出见 [build.yaml](../../build.yaml) | 修改后必须重跑，不手改 `*.g.dart` |
| 本地化 | `dart run intl_utils:generate` | `arb/intl_*.arb` 写入 `lib/l10n/` | 每个语言必须有相同的键。[.agents/skills/localization/SKILL.md](../../.agents/skills/localization/SKILL.md) 给出了扫描中文硬编码的步骤 |
| Dart 与 Rust 桥接 | `cd plugins/rust_api && flutter_rust_bridge_codegen generate` | `plugins/rust_api/rust/src/api/` | 只在改动 Rust API 时运行 |
| 图标 | 脚本依赖 `rsvg-convert` | `assets_source/images/icon/*.svg` | 托盘与 Windows 图标由脚本生成，不手改 |

本地化的最终检查是 `flutter test test/l10n` 与 `test/lint/dynamic_message_key_test.dart`（[localization/SKILL.md](../../.agents/skills/localization/SKILL.md) 第 6 步）。

ZolNit 原生视图的界面文案来自同一套 ARB，经 `zolnit_native_ui` 合同快照传入原生层。快照字段的修改要同时更新 Dart 与 Swift、Kotlin、C++ 的解析。见 [platform-contracts.md](platform-contracts.md) 第 3 节。

## 7. 分层测试与 CI 中已验证的命令

CI 中的测试分为四类边界。每类的命令都来自仓库内的工作流或工具脚本，不依赖本文作者的假设。

| 边界 | 工作目录 | CI 验证的命令 | 来源 |
|---|---|---|---|
| ZolNit 客户端子包 | `packages/zolnit_client` | `flutter pub get --enforce-lockfile`；`dart format --output=none --set-exit-if-changed lib test`；`flutter analyze --no-fatal-infos`；`flutter test --reporter expanded` | [build.yaml](../../.github/workflows/build.yaml) 约第 125 行 |
| 构建钩子包（纯 Dart） | `plugins/setup/setup_hooks` | `dart pub get`；`dart analyze`；`dart test` | [build.yaml](../../.github/workflows/build.yaml) 约第 134 行 |
| Go 核心包装 | `core`（需要 `CGO_ENABLED=0`） | `go test -count=1 . ./clientbundle ./cmd/zolnit-bundle-probe`；`go test -count=1 -tags=zolnit_acceptance . ./cmd/zolnit-bundle-probe`；`go vet . ./clientbundle ./cmd/...`；`gofmt -l` 检查 | [build.yaml](../../.github/workflows/build.yaml) 第 318–334 行 |
| Rust Helper 与桥接库 | 仓库根 | `cargo fmt --manifest-path services/helper/Cargo.toml -- --check`；`cargo test --manifest-path services/helper/Cargo.toml`；`cargo test --manifest-path plugins/rust_api/rust/Cargo.toml`；Windows 上追加 `cargo test --manifest-path services/helper/Cargo.toml --features windows-service` | [build.yaml](../../.github/workflows/build.yaml) 第 455–487 行 |

Go 测试必须带 `CGO_ENABLED=0`。`core` 中的 `*_test.go` 文件（例如 [core/clientbundle/return_route_test.go](../../core/clientbundle/return_route_test.go)）覆盖了 Go 侧的 bundle 与返回路由逻辑。优先使用 CI 已列出的包，不为局部修改无边界扩大到 `go test ./...`。嵌套的独立 Go module 不等于当前 module 的子包，不能声称该模式自动运行整个 Core 子模块的全部测试。

根包的 Dart 测试由 `tool/test.dart` 统一执行。它把 `test/` 下的 `*_test.dart` 打包成若干入口，减少 `flutter test` 的启动开销：

```bash
dart run tool/test.dart                          # 全部 test/
dart run tool/test.dart test/providers test/common
dart run tool/test.dart -- --reporter expanded   # 透传 flutter test 参数
```

根包的 `flutter test` 不包括插件目录。插件 Dart 测试用 `bash tool/check_plugins.sh`，或显式传路径。原生平台目录下的测试（例如 [plugins/zolnit_native_ui/darwin/Tests/ZolnitNativeUiCoreTests](../../plugins/zolnit_native_ui/darwin/Tests/ZolnitNativeUiCoreTests)）不会被 `flutter test` 执行，需要相应的平台工具链。

## 8. 测试边界：哪些不能互相替代

- `flutter test` 在宿主机运行 Dart 逻辑与 widget 测试。它不证明 Android VPN、iOS NECore、Windows Helper 的真实行为。
- `cargo test` 只覆盖 Rust 库与 Helper 的单元逻辑。Windows 服务路径需要 `windows-service` 特性，并且只能在 Windows 上运行。
- Go 测试覆盖 `core` 包的协议、bundle 与返回路由。它不运行 gomobile 绑定或 Android 设备。
- CI 的 hosted 构建证明编译与打包路径。它不证明设备行为，见 [testing-and-debugging.md](testing-and-debugging.md) 第 1 节。

## 9. 命令副作用与安全模式

| 命令 | 副作用 | 规则 |
|---|---|---|
| `flutter pub get` | 更新 `.dart_tool/` 与依赖缓存 | 依赖变化必须单独审查 |
| `flutter test`、`flutter build` | 运行构建钩子，编译 Go 与 Rust，写入 `libclash/` | 需要 Go；Windows 与 Linux 还需要 cargo 与 rustc |
| `dart setup.dart <platform>` | 构建并打包到 `dist/` | 打包会产生本地产物；仅在需要包验收且副作用已检查的任务中运行，不等于正式发布授权 |
| 非 SAFE_MODE 的 `flutter run` | 创建 TUN、设置系统代理；macOS 改写系统 DNS、注册登录项；Windows 与 Linux 通过 Helper 启动 Core | 不在共享主机上运行 |
| `flutter run ... --dart-define=SAFE_MODE=true` | 关闭宿主网络改动，不开放 Core 监听端口 | 主机上唯一允许的启动方式 |

[.agents/commands.md](../../.agents/commands.md) 给出的安全模式示例是 `flutter run --dart-define-from-file=env.json --dart-define=SAFE_MODE=true`。ZolNit 子包 README 给出 macOS 的 `flutter run -d macos --dart-define=APP_ENV=dev --dart-define=SAFE_MODE=true --dart-define=ZOLNIT_DISTRIBUTION=direct`。两者都只能在任务自己记录 pid 后结束进程，不能按名称结束用户自己的 FlClash。

## 10. 提交规则

提交信息遵循 Conventional Commits，由 `commit-msg` 钩子检查，不添加 `Co-authored-by` 作者声明。`comment-density` 钩子会拒绝超过阈值的注释，因此注释只保留代码无法表达的约束、上游行为或易误读的原因。提交前的结构审查见 [.agents/skills/pre-commit-quality-review/SKILL.md](../../.agents/skills/pre-commit-quality-review/SKILL.md)。

## 11. 常见失败的第一步

| 现象 | 第一步 |
|---|---|
| `pub get --enforce-lockfile` 失败 | 比较 `pubspec.yaml` 与 `pubspec.lock` 是否有未提交改动；不放宽约束 |
| 构建时找不到 `go` | `which go` 与 `go version`；查看 `.dart_tool/setup_build_cache/hook.log` |
| 生成类与源码不一致 | 重跑 `build_runner build --delete-conflicting-outputs` |
| 本地化键缺失 | 检查所有 `arb/intl_*.arb` 是否同步，再重跑 `intl_utils:generate` |
| `comment-density` 失败 | 删除叙述性注释 |
| 插件测试未被发现 | 显式传路径，或运行 `bash tool/check_plugins.sh` |

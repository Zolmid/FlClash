# 统一云端构建

开发仓库：`Zolmid/FlClash`。日常编辑、静态检查和共享代码测试使用 FlClash 云环境；
原生构建由同一个 GitHub Actions 工作流调度不同操作系统的执行器。

入口：[Actions → Cloud build](https://github.com/Zolmid/FlClash/actions/workflows/cloud-build.yml)。
选择 **Run workflow**、待构建的分支，以及 `platform=all`，即可启动全部平台。
也可以只选一个平台；`macos` 同时构建 Apple Silicon 和 Intel 两种架构。
各任务独立运行，一项失败不会取消其他平台；构建完成后在该次运行的 Artifacts 下载，保留 14 天。

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
工作流只响应手动触发，不发布 Release，不上传 TestFlight，不向 Telegram、Homebrew 或 F-Droid 推送。
上游已有的 `build.yaml` 保持原样，继续负责已有检查。

## iOS 源码选择

默认 `ios_source=patched-reference` 构建独立参考项目
[`chenx-dust/FlClash-Patched`](https://github.com/chenx-dust/FlClash-Patched)，固定提交
`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`。
产物名称包含 `patched-reference`。**这不表示当前 FlClash 主线已经实现 iOS 支持。**
同一次 `all` 运行中，其他四个平台仍构建当前所选的 FlClash 分支。

`ios_source=project` 构建本仓库所选分支。完成 iOS 移植前，它会明确失败，不会自动退回参考项目。
移植完成后选择此项，才是五个平台均来自同一条开发分支的构建。
若迁移后的原生目录结构或构建命令与 Patched 不同，应同步调整工作流的 iOS 检查及命令。

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

当前 Patched 明确只接受 **iOS arm64 真机目标**，拒绝 Simulator 构建。
Linux 云环境可编辑 Swift/Dart/Go/Rust 源码、分析差异和测试共享代码，不能运行 Xcode 或 iOS。
GitHub Actions 的 macOS 执行器用于编译；交互式断点、热重载、Network Extension 日志和 VPN 实测
需要可连接的 Mac 与 iPhone。编译通过不等于运行可靠。

后续移植应覆盖 `ios/`、Dart 服务桥、Go iOS/TUN 适配、构建 hooks 和对应 mihomo 修改。
Patched 已转为独立演进的分叉，不能只复制 `ios/` 或直接整体合并。
至少验证 VPN 启停与竞态、后台/锁屏、Wi-Fi/蜂窝切换、DNS/IPv6、低内存，以及已有四平台回归。

# 依赖、构建与 Windows 安装器审计

审计主线：`3222b8d609caaf74c28f61712c8d654e4937eed9`（`codex/patched-integration` 的保留起点）。
参考分支：`refs/remotes/patched-audit/main`，固定 `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`。
共同基线：`7c61c90ac20493b474d19c75ec96262b478b4b88`。以下结论来自该基线至参考提交的路径历史及与主线的逐文件比较，不以整树覆盖代替迁移。

## 按来源提交的处理

| Patched SHA | 处理 | 当前实现或理由 |
| --- | --- | --- |
| `ab86dadb2ea8ac0fad7ffd255246ca32a5cc39b2` | 迁入 | macOS 与 iOS hook 均设置 CARGO_PROFILE_RELEASE_STRIP=none，Flutter 最终封装 Mach-O；其他平台不关闭 strip。 |
| `4512b1d77a07f778b8c34e24b7f2c070a8233b3e` | 迁入 | bindgen 使用 Flutter 选定的 NDK/API，按 Rust triple 写带后缀环境变量并给 clang versioned target。保留当前 r28c，不随参考升级到 r30；带空格 sysroot 参数加引号。 |
| `38f781a743f5653c3a330f265d89130e83f817eb` | 迁入/主线替代 | Android Windows host 从 NDK lib/lib64/bin 找 libclang，并把同一 NDK bin 前置到 PATH；主线已有库名 rust_api 和 Rust 1.99.0，不回退其 1.98.1。 |
| `9c65454dcf82b47a26ab3e61a16b576081710550` | 已迁入 | 已有 iOS LIBCLANG_PATH、SDK、deployment target 与 strip 关闭；本轮提取到可独立测试的 cargo_environment.dart。 |
| `9d8b8ea0c2fa15009d88b39b53aee4d519b95ddf` | 已迁入 | iOS libc 精确 0.2.189，避免 backtrace 0.3.76 的 dyld API 兼容问题；保留 Cargo.lock。 |
| `927dd7475ca5e8ffae8058bf0dd7e315283e7dbd` | 迁入 | --arch x64-v2/v3 选择 GOAMD64，hook target/fingerprint/cache 分离；同 ABI 的 Helper 仍绑定实际 Core SHA256，不削弱完整性校验。 |
| `5f99ba518208397173d15704aa64d1a340e8f765` | 迁入 | 临时 setup.goamd64 user define 支持 CRLF，打包失败也 finally 恢复完整原 pubspec；拒绝覆盖已有 goamd64。 |
| `e195005ed6df3080f57e8118343b0540ddc7761a` | 迁入/兼容 | 用户/包架构名统一 x64，保留原 amd64/v1/v2/v3 参数别名；Go GOARCH 仍为 amd64。 |
| `1de91ebbfce8013bced5e99426d0b227aa82cb9f` | 迁入并加固 | env.json 的 APP_ARCH 白名单校验；Inno 更新协议增加64位hex nonce与本实例PID、核对镜像路径、原子ready、父端nonce ack确认、60秒退出等待、写失败中止；更新路径不按进程名强杀。下载/摘要验证由 Dart updater 域实现。 |
| `38b13a757f17d988f56007eae5aa8a117ab7d18e` | 迁入 | 设置 UninstallDisplayIcon 指向当前安装的可执行文件。 |
| `bd7da00c72e60a8481d38fb788813aa0b7cd5cd3` | 迁入/主线替代 | 安装后以原用户清理本应用残留代理，卸载先请求运行中应用清理；保留主线 helper 卸载、用户注册归属检查和当前 AppId。具体代理归属判断留在 proxy 插件。 |
| `da3a9e57878bfda7dc85fdec463e87964c7b62c4` | 延后 | 已调研正式 metacubex/sing-tun v0.4.28-0.20261008092224-bfc905547122 与 sing-wireguard v0.0.0-20261002050126-e5fa1a607406；用户决定本轮保留原核8380与原依赖锁，依赖新API的DNSMode等原生功能同步延后，两个require与checksum已恢复主线。 |
| `52e8c47a56dd0e2654c0ecd051e67fc1d1af55bb` | 拒绝历史replace | 该提交曾使用 chenx-dust/sing-tun replace；后续 da3a9e57 已删除。保留主线正式 metacubex 旧锁，不移植已被参考撤回的 replace。 |
| `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` | 主线替代 | 保留 build_config.yaml 的 core_version=v1.19.32 与 linker -X，避免浅克隆 git describe 得到空值；已在 core/method.go、Dart Core 接口与 About 页接入对实际运行 Core 的 getCoreVersion 查询。 |
| `3dbd540284f201cc78f5ce76c8a132c8cbf6fc1c` | 主线替代 | 保留 macOS host slice hook 与对应 host 执行器，当前 setup 不接受跨主机架构；无需引入 XCODE_XCCONFIG_FILE 覆盖以绕开主线限制。 |
| `0d764e8b8fddcfd35860e6b6dd8e255d777b5deb` | 拒绝身份替换 | 保留 com.follow.clash、既有 Windows AppId、协议 schemes、launch_at_startup fork 与发行身份，防止升级安装分裂或窃取其他应用注册。 |
| `0cbab86e87b0979c7394caf77203cbada3840ccf` | 部分已有/主线替代 | iOS打包/静态库/导出配置已迁入；保留固定 chen08209/flutter_distributor v0.6.11-flclash.3，不改成 chenx-dust 浮动 FlClash 分支。不引入未经对应发布工作流支持的 pacman/portable zip/geodata 下载范围。 |
| `446f2159ded1f3c72d2791c524577747ee955fee` | 已迁入 | iOS 使用 FlutterGeneratedPluginSwiftPackage，无新增 CocoaPods 依赖；SDK固定策略由统一CI维护。 |
| `65c15c871636dd78544cc33ab85e9f375c587a3f` | 主线替代 | 保留当前 Flutter3.47.6/Go1.27.1/Rust1.99.0/NDKr28c pin；主线 CodeForge 已内置且需要当前 Dart 下限。本轮不改SDK、不改CI阈值。 |
| `243bf0250c7a15057d733c673f2d4647f2ce5d97` | 主线替代 | 已有 in-repo CodeForge/Ropey/Rust API；保留主线编辑器修改和生成绑定，避免替换成参考旧副本。 |
| `df4f88e097803270c97e056c70cf6b7d3b7570a0` | 主线替代/依赖冻结 | 主线 ShortcutLabels 已直接处理 PhysicalKeyboardKey 标签，不依赖 uni_platform 调用；pubspec/锁中的既有声明保持本轮冻结，不混入无关 manifest 清理。 |
| `5c12cb08cd3f6625a289e419c8b9da60678ec234` | 主线替代 | Material Symbols/SVG等UI依赖由实际调用决定；不为复制参考资源新增整套未使用字体。 |
| `8012efc6fcf06515c11d9da1dc0ddca205fe46be` | 迁入并加固 | Windows scheduled autostart 已接入，保留 SAFE_MODE/debug，使用当前用户 LeastPrivilege、安装路径归属与串行最新意图收敛；失败保留有效方式。完整证据见 [windows-autostart.md](windows-autostart.md)。 |
| `38b8e3d912537f416d45ebdedca765acca7451d6` | 已迁入其他域 | Linux 独立托盘资源及 pubspec/tool 输出已改为 tray/linux；保留主线 macOS template tray 资源，原生行为由 desktop 审计覆盖。 |

## 保留的依赖与安全边界

`pubspec.yaml` 与锁文件保留主线解析结果：`material_ui` 1.5 系列、本地 `window`、本地 YAML writer、当前 Riverpod/Drift/codegen 组合。参考的多数约束更旧，不应据此回退。`file_picker` 12.3 与 `connectivity_plus` 7.2 已覆盖迁入调用实际使用的 API，未发现需要 13.1/7.3 新 API 的调用；因此不因版本差异升级。`rquickjs` 0.12 的现有脚本入口、Promise、JSON 与超时/内存保护 API 均覆盖参考脚本实现；参考 0.14 没有本次功能必需的新 API。保留这些已测版本的决定已与主任务对齐。

保留主线 Tokio IPC 的 socket mode 0600、Unix effective-UID（本用户或 root）检查、peer PID、帧大小/背压与关闭语义。参考的另一套线程/控制帧实现不能覆盖这些现有鉴权和协议。`services/helper` 的 Core SHA256 约束、错误码与启动所有权保持原样。iOS/Android继续使用移动端 stub，不编译桌面 IPC/全局热键。

Windows `/UPDATE=1` 只在提权后的 `PrepareToInstall` 验证 `/UPDATEPID`、`/UPDATENONCE` 和严格等于 `{srcexe}.{nonce}.ready` 的 `/UPDATEREADY`。每次尝试使用独立的64字符十六进制nonce路径，不删除旧尝试的标记，迟到安装器不能覆盖重试的握手。安装器持有并验证目标 PID 的镜像路径；以 `CREATE_NEW` 写入 `ready.tmp`、关闭后 rename 发布 ready；只有父端在仍有效的握手内从 `ready.ack.tmp` 原子发布 `ready.ack` 且nonce精确一致，安装器才等待该进程 handle 退出。临时文件在已有nonce路径后只追加后缀，避免重复nonce延长文件名。缺少/错误ack、父端退出或30秒ack等待超时均中止，防止父端已超时的迟到安装器在用户稍后退出时继续安装。标记失败或退出等待失败也中止更新，不执行同名进程 taskkill。更新后以原用户重启；普通手动安装及卸载保留已有清理逻辑。Dart端负责2分钟握手超时、精确nonce校验与失败保留运行中的应用；超时或失败绝不发布ack。

## Go 版本与 API

两个新模块均从 `github.com/metacubex` 下载并由 Go 校验 checksum：sing-tun 的 Origin 为 `bfc90554712202e186b36a5f9550d9f34602cfb2`，sing-wireguard 为 `e5fa1a6074066275400b52d90708a3ff676d8df3`。升级候选曾通过兼容检查，但用户随后决定本轮保留原 mihomo 8380 与原依赖锁；因此两项 require 及四行候选 checksum 均已撤回。没有回退 Go 1.27、移除 gomobile tool 或引入 chenx-dust replace。

sing-tun 新增 `Options.DNSMode`、`DNSModeDisabled/Native/Hijack`、`DNSModeOrDefault()`，以及 IPv4/IPv6 DNS 地址推导；候选版本的旧 TUN 与 WireGuard 调用在 Core 单测中保持兼容；本轮最终未启用新模块或DNSMode功能。将来迁入仍须验证系统DNS、IPv6和网络切换。

## 验证

- setup hooks：`dart analyze` 无问题，`dart test` 56项通过，新增覆盖 macOS strip、NDK lib/lib64/bin、Windows PATH、三个 ABI 的 target/API/include，以及GOAMD64参数。
- `setup.dart`、相关测试和 Rust hook：Dart分析通过；root Flutter测试由主任务统一执行，不在本子任务触发根项目构建或codegen。
- Rust：`RUSTUP_TOOLCHAIN=stable RUSTUP_AUTO_INSTALL=0 cargo test --locked` 55项通过，包含peer UID/IPC测试。现有工具链未安装rustfmt；没有下载SDK。
- Go（候选依赖验证，最终未迁入）：升级候选时 `CGO_ENABLED=0 go test -p 4 .` 通过。`GOOS=windows GOARCH=amd64 go test -run ^$ -exec=/bin/true` 的 mihomo outbound/TUN listener 编译通过（未执行Windows测试）；`GOOS=android GOARCH=arm64 go vet . ./mobile` 通过。
- Linux无 Inno Setup、Windows UAC 或Xcode。安装器新增协议有源码契约测试，但真实提权拒绝、ready写入失败、PID等待和重启仍须Windows验证；Mac Mach-O对齐与iOS签名也须Apple执行器验证。

本依赖迁移不改变 CI 阈值、生产签名或发布目的地；统一 cloud 工作流的最终配置复核如下。

## 最终构建配置复核

对照本地 `refs/remotes/origin/main=f2112fc4ad202bbe597e6728acaef7700eeb58a5`，
`.gitmodules`、`core/Clash.Meta` gitlink、`core/go.mod` 和 `core/go.sum` 的差异均为空；
子模块工作目录实际 HEAD 也是 `8380d0e7462f061a964323e9bf3129a236fcc5d5`。
`build.yaml` 与 `pages.yaml` 同样无差异，原公开仓库、tag 与 Pages release guards 没有放开。

统一 cloud build 保留 `all/project` 手动默认值，all 包含5个原生矩阵目标加1个独立iOS目标，共6份平台产物；
自动 push 的 main/集成分支构建all/project，ios-support分支只构建ios/project。
权限为 `contents: read`，开发产物没有生产签名或发布步骤。Windows job 的 proxy ownership（内部 gtest）
与 tray menus（5项原生测试）均有独立 CMake configure、build 和 CTest 执行步骤。

本地已运行 `dart --packages=.dart_tool/package_config.json tool/changelog.dart verify`，
结果为 `Changelog is consistent with git.`；没有跳过 main/tag CI 的 changelog 校验，亦未改根 Flutter/codegen。

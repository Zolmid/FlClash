# FlClash 0.9.1 上游同步

本次以 `chen08209/FlClash` 的正式标签 `v0.9.1` 为同步目标，不同步标签之后的开发提交。

- 上游标签：`8d4f9744948751f1273fe871e1d05276fac09b0e`。
- 整合起点：`Zolmid/FlClash` 的 `main`，`c651e44b4f48994a57f748957718c9bdf08be75a`；已包含先前 iOS/Patched 整合及独立审查后的修复。
- 真实共同祖先：`03f955382409a4a7ac1f3f92e46d9fcc6d39f106`。
- 共同祖先后上游有 16 项提交，本仓库有 10 项提交；使用 Git 三方合并，保留双方历史。
- 开发分支：`codex/upstream-0.9.1`。该分支 push 自动运行主项目全平台云构建；不使用 Patched 源码。

## 采用的上游更新

版本更新至 `0.9.1+2026101702`。采用新版 `lib/ui` 分层、表面/排版规范、玻璃材质和菜单、首页与当前出口布局、连接/请求/DNS 表格、代理分组、配置资源管理和主题选择。旧首页网格组件由新版 DashboardEditor 替代。

采用大配置 profile-base、spill 文件响应、请求流量处理与 Android Core 后台串行通道，移除上游已停用的 Firebase analytics/crash reporting。保留正常启动失败恢复与应用生命周期所有权，不使用 Firebase 标记作新状态来源。

TUN 设置按上游逐配置所有权模型合并：桌面全局仅覆盖上游明确保留的键，其余使用配置与显式覆盖；移动端 VPN 参数仍由移动端设置与最终构建结果生成。iOS 保留完整有效 TUN 元数据，脚本执行后提取小字段，不将大配置再次拉回 Flutter。

采用新增法语、西语、韩语，补齐本仓库功能文案，并保留繁中。所有八种语言的键与占位符保持一致，模型、Provider 和语言生成文件通过仓库工具重新生成。

## 保留的本仓库差异

- iOS 原生工程、NetworkExtension、Widget/快捷操作、App Group 数据迁移及安全模式；NE 失败不回退 App 监听器。
- 规则配置快照 token/进程身份、iOS App/NE 路由失效处理，手动 DNS、AGE、内存分项与 footprint。
- Android commandRevision、ServiceState 所有权、实际/请求 VPN 快照、runState 事件与 detach 清理、小组件和 QS 设置。
- Windows 系统代理 old/pending 所有权与卸载精确清理、自启隔离；Linux tray 程序勾选不发用户选择事件。
- 托盘功能、备份安全 staging/回滚、多备份 WebDAV、按最新成功/尝试时间调度与按配置 single-flight。
- 自有更新来源 `Zolmid/FlClash`、独立严格 TLS、manifest/path/哈希校验、下载与安装隔离；上游归属仍单独保留。
- TV/遥控器、编辑器、前台轮询降频，以及稳定导航栈与焦点边界；按新版界面接口迁移。

## 合并时的兼容性修复

0.9.1 的 Android 通道改为字节传输，iOS 仍发送字符串；共享 Service 解码同时处理两种表示，保留后台大 JSON 解码，避免直接强转造成 iOS 事件丢失。

iOS App 与 NE 共用 App Group 数据目录，spill 响应分别使用 `responses-app` / `responses-ne`，各自只清理自己的文件；Dart 路径白名单仅对 iOS 接受这两个目录。异步文件读取留在 RPC pending/generation 保护内，断线与重复帧不能完成已过期请求。

profile-base 加载仍走 iOS App HTTP provider 隔离；新增的读取/构建配置接口固定路由 App Core。iOS 先完成应用配置并原子写共享配置，再启动 NE；避免 NE 在新 base 还未展开时读取旧配置。其他平台保留上游并发启动。

iOS 启动参数来自同一次最终构建快照；跨 CIDR 解析等异步边界后以及原生发送前均校验配置身份与代际，切配置时丢弃旧快照并重建最新请求，避免旧配置启动覆盖新意图。

Windows bypass 同时保留本仓库 IPv6 CIDR/zone 规范化、`<local>` 和上游新增尾随斜线清理。

## 依赖与验证边界

`core/Clash.Meta` 保持 `8380d0e7462f061a964323e9bf3129a236fcc5d5` 及原上游 URL；0.9.1 未要求切换这个依赖。不接入自有核心 fork，不独立追逐 mihomo 功能。后续仍优先由 FlClash 上游带入已验证内核，升级 sing-tun 时复核 iOS FD 接管和失败清理约定。

保留 Flutter 3.47.6、Go 1.27.1、Rust 1.99.0 和依赖锁；测试/覆盖率门槛不降低。云构建权限继续 `contents: read`，iOS 为未签名 IPA，手动入口保留。正式 release 的上游 guard、Telegram/Homebrew 外部发布动作未放开。

本地检查使用仓库固定工具链；Go、Dart/Flutter、格式、changelog 和工作流检查按最终整合代码执行。macOS/iOS/Windows 真正原生编译需以该提交的云端结果为准；Linux 的测试或旧 IPA 成功不能证明新版本已在 Xcode 编译或真机 VPN 验证通过。本轮没有启动 FlClash 或修改主机代理/VPN。

ZolNit/Xboard 专用客户端仍处于独立 Web 预览阶段，本次上游同步不实施尚未确认的客户端品牌/登录改版。

## 本地验证记录

- Flutter 3.47.6 / Dart 3.13.5 固定工具链：依赖解析、模型/Provider/语言生成、全项目分析和格式检查通过。
- Go wrapper 全包测试、vet、Android arm64 `with_gvisor` vet 通过；Clash.Meta 子模块未修改。
- 官方 `tool/test.dart` 全量入口通过；一份共享 isolate 下受残留状态影响的测试按上游入口自动独立复跑后通过，未修改该入口或放宽断言。
- 生成代码排除后的覆盖率为 **88.12%**，全部分组门槛通过，包括新版 UI 的 91% 门槛。
- 核心、iOS/Android 通道、VPN、TUN 元数据与启动切配置、窗口导航、更新器、WebDAV、调度、语言、代理及界面定向回归通过。
- 六个平台选择值的工作流矩阵检查、只读权限、不中断已有运行、原发布 guard 及发布前测试依赖检查通过。

新提交的 Apple/Windows/Android 原生编译结果另由云构建记录；此处本地通过不标记为真机 VPN 或 Xcode 编译验证。

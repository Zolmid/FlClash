# 上游同步与长期维护

后续优先同步 [`chen08209/FlClash`](https://github.com/chen08209/FlClash)，由该项目带入它已经验证的
core 版本。本仓库集中维护 iOS 桥接、五平台构建和有实际价值的应用层差异，不单独追逐
mihomo / Clash.Meta 的新特性，不建立一条独立滚动升级内核的维护线。

当前依赖继续使用原 `core/Clash.Meta` 子模块、原上游路径和固定提交
`8380d0e7462f061a964323e9bf3129a236fcc5d5`。来源分支是 `chen08209/Clash.Meta` 的 **FlClash**；
该仓库的 `main` 是无关项目，不应作为内核同步来源。不要用 `git submodule update --remote`
绕过 FlClash 主项目的依赖选择与验证。自有 `Zolmid/Clash.Meta` 仓库保留，但本轮不接为依赖。

同步上游时，先核对应用层提交与真实共同祖先，再按功能合并；保留本仓库的平台桥接与安全保证，
不整树替换。若上游更新 core，连同应用协议与工具链一起验证，在同一个应用提交上运行现有测试、
覆盖率门槛和五平台云构建。不要把旧 SHA 的测试或未签名 IPA 编译成功当作新版本、真机 VPN 的证明。

本次审计中，高级规则实际匹配、精确节点累计流量、Overlay 状态控制、系统 DNSMode、mmap 缓存、
AnyTLS 低内存池及其他必须改内核的增强，统一记为**因维护成本本轮不引入，优先上游支持**。
已完成的探索代码完整留在隔离资料中，不接入生产协议，不以静态模拟数据冒充实际能力。
只有真机证据说明某个内核改动对 iOS 可靠性必不可少时，才单独论证必要的最小补丁。

应用层可以可靠实现的功能继续迁入，包括现核支持的 DNS 查询、运行时规则管理、AGE、内存展示，
以及平台小组件、托盘、备份、调度、更新器、语言和编辑器交互。
具体“已整合”“主线已有”“依赖改内核而延后”的依据与来源见[完整审计](patched-integration-audit.md)。

日常云环境使用已有 Git 认证执行 `git push`；main 和整合分支会自动构建主项目全平台。
不需要新增 token、修改网络限制或扩展 Actions 权限。云端 artifacts 属于开发验证产物；
正式 Release 与 updater manifest 是另一条发布流程。现有 `build.yaml` 上游发布 guard 及
外部 Telegram/Homebrew 动作不因本轮整合而放开，未发布正式版本时更新检查应正常显示无更新。

同步上游带入新的 sing-tun 时，必须复核 iOS TUN FD 的所有权约定：当前桥接会复制 Network Extension
提供的描述符，并根据 `configure tun interface` 错误前缀判断失败发生于接管前还是接管后，决定由哪一侧
关闭副本。需要核对新版构造/失败路径及错误格式，避免 double-close 或 FD 泄漏；这是平台适配维护边界，
本轮不为此修改内核。相关实现位于 `core/tun/tun_ios.go`，以真实 Apple 构建和真机路径验证为准。

0.9.1 的具体同步基线、功能保留、iOS 新通信/配置路径适配与验证边界见
[0.9.1 同步记录](upstream-0.9.1-integration.md)。

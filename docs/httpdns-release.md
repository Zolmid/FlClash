# 1.1.11 HTTPDNS 发布候选

本地候选基于 `75bda28a`。2026-11-22 只读查询 GitHub latest release 仍为
[v1.1.10](https://github.com/Zolmid/FlClash/releases/tag/v1.1.10)，因此下一版本为
`1.1.11+2026112201`。Core 保持 `8380d0e7462f061a964323e9bf3129a236fcc5d5`。
本文件不表示已发布、已完成移动 SDK 鉴权或设备验收。

## 编译及发布门禁

`packages/zolnit_client/lib/src/owned_dns_config.dart` 保存无凭据的发布配置：
`strict=true`，固定自有 relay，bootstrap 主机仅 `link.zolmid.com`。
Core 从已验证配置发现精确节点主机，不把普通流量 DNS 改成直连。

- `cloud-build.yml` 的正式五平台构建、显式 Flutter 编译和产物 provenance 带同一配置。
- `setup.dart` 根据 direct distribution、native UI 或 client bundle 写入 `env.json`，
  覆盖 Android 打包和 iOS unsigned / direct IPA 后续归档。
- direct/native 客户端即使漏传新 define，运行时仍使用同一 strict 默认值；release
  不接受显式的非 strict 配置。普通非客户端构建不启用这个默认值。
- 发布装配检查所有平台的 `owned_dns=strict-v1`，保留现有签名、版本、notes 和 Core 合约。
- `assemble_release.py preflight` 当前明确失败为
  `MOBILE_DNS_SDK_PRODUCTION_BLOCKED`。无环境变量跳过开关；正式 tag、签名、上传和发布由主控负责。

Dart / Go bootstrap 通过 Alibaba 公共 resolver 的 IPv4 literal 拨号，保留
`dns.alidns.com` TLS 验证，独立处理 A/AAAA；单族故障可使用另一族有效答案，全部失败不走系统 DNS。
TTL 取有效答案的最小值。业务 API / WS / release URL、Host、SNI 和证书验证保持原主机名。
主控的 iOS Shared `requestHeaders` / `responseHeaders` 修复保留。

## 官方 SDK 的生产结论

[Android 官方文档](https://help.aliyun.com/zh/dns/httpdns-android-sdk-development-guide)
和 [iOS 官方文档](https://help.aliyun.com/zh/dns/httpdns-ios-sdk-development-guide)
提供 FusionDNS 自建端点及独立 AK/SK 接口。它们支持配置自建服务，不证明当前部署已经具备
短期授权、域名限制、租约刷新或正确的 TLS 身份绑定。

核验的 Android 2.3.3 AAR SHA256 为
`48722b25b2a546253148e246737c3350fc28dff56c6f1e38528b6605dde7dbb5`。
其 `com.alibaba.pdns.net.f` 的 Fusion 分支安装 `com.alibaba.pdns.net.a` verifier；
后者只比较类型 7 的 IP SAN 与连接主机。公共云分支则使用 `dns.alidns.com` verifier。
稳定 API 未提供独立 literal-dial / TLS-hostname 绑定参数。因此不能把现有域名证书直接
当成自建 literal-IP 端点的证书，不能通过关闭校验、修改 SDK 私有状态或 LocalDNS 来掩盖差异。
iOS 2.3.1 头文件具有 `setFusionDNSWithIPv4:IPv6:Host:Port:HealthCheckDomain:accessKeyId:accesskeySecret:`，
但尚无本项目真实短期签名租约和证书正反例验收，不能据此声称两个平台生产接线完成。

阿里云长期查询密钥只能由主控保存在服务端；不写入 Dart define、发布包、诊断配置或日志。
默认 Dart 适配器和两端官方 backend 的旧公共云凭据初始化现已 fail-closed。
保留的合成适配器测试及 SDK 编译 smoke 只证明接口/类型和回退门禁，不是生产鉴权证明。
已有 HTTPS JSON relay 不计作完成移动 SDK 要求。

## 解除阻断的最小选择

1. 提供具备可信 **IP-SAN 证书** 的专用 FusionDNS 端点及 SDK 兼容协议，或取得厂商支持的
   literal bootstrap + 独立 TLS 主机名接口。不要把节点动态地址当作固定 resolver 地址承诺。
2. 主控提供自建服务短期 grant / refresh 合约：仅自有精确域名、明确过期时间、会话撤销、
   无第三方递归、失败限流；仅发送自建短期签名材料，服务端代理阿里云长期查询密钥。
3. 完成本地 SDK 请求/签名协议、过期/轮换/撤销，以及两端有效/错误证书测试后再开启生产 SDK；
   SDK 失败仍只能转严格 relay/bootstrap，不能转 LocalDNS。

若用户另行决定先发布严格 relay 方案，需明确豁免本次移动 SDK 发布条件，并同步调整预检和
发布描述；不能静默把 relay、加密 JSON、混淆或“短期”标签当成 SDK 的安全验收。

Go Core 节点拨号及 Android/iOS NE 后台续租仍使用 strict relay/bootstrap；移动 SDK 不覆盖这些路径。
系统浏览器、受管 WebView、OTA 安装仍属 OS 管理 DNS 例外。真实 SDK 鉴权、手机网络切换、
系统 TUN 和真实线路仍由后续明确验收覆盖。

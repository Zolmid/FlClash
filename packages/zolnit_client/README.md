# ZolNit 客户端模块

范围仅为客户端：Xboard HTTP API 适配、Stripe 原生/浏览器动作、付款二维码、Apple StoreKit 2 购买与恢复。
不包含任何服务端、Xboard 插件、数据库连接、支付创建或 webhook 实现。现有五平台 Web 预览已获用户确认，
宿主入口为 lib/views/zolnit/home.dart，通过 lib/providers/zolnit.dart 装配会话与支付；仍由原有 Core 生命周期
管理连接。本轮首个验收平台是 macOS 官网渠道，界面组件通过不等于各平台系统组件或真机 VPN 已验收。

## 当前入口

- `XboardClient`：账户、套餐、订阅、节点、订单、支付方式、优惠券、工单、邀请、流量接口；Bearer 仅在内存中。
- `ZolnitSessionController`：登录、退出、账户快照、套餐/节点/订单、续费操作及付款返回后的服务端状态同步。
- `ZolnitBillingClient`：现有插件的公开配置、权益、可购续费报价、合约查询、取消和恢复。
- `XboardCheckoutBackend`：校验本人订单并探测连续付费 intent，保留既有 checkout 外层 `type/data`。
- `CheckoutController`：支付动作 single-flight、返回后查询、有限轮询、过期 QR、账户代际与 dispose 保护。
- `NativeCheckoutPlatform`：Android 银行卡/支付宝通过 Flutter Stripe 调用原生 SDK；微信使用专用 Android 桥接。
- `PaymentQrView`：仅编码服务端返回的 QR 载荷，过期自动隐藏，不把 client secret 或普通链接伪装成钱包收款码。
- `ApplePurchaseController` / `StoreKitGateway`：StoreKit 2 商品、本地化价格、账户绑定、购买、恢复与未完成交易重试。
- `ClientPaymentPolicy`：Apple 原生构建默认商店渠道；官网 macOS 构建可显式指定 `ZOLNIT_DISTRIBUTION=direct`。
- `CheckoutLifecycleBinding`：付款页面存活期间监听 App resumed，仅刷新 Xboard 状态；关闭页面时 close。

Android 宿主使用 FlutterFragmentActivity / AppCompat；macOS 也登记 `zolnit` 返回 scheme。
OS 只登记 zolnit scheme，应用内仍兼容旧 Clash 导入格式。支付返回链接在普通导入日志之前被识别，
所有深链日志均不记录原始 URL。
原有权限、VPN、ServiceState 和 commandRevision 所有权不变。

## 客户端调用约定

1. 用户选择套餐后，通过 Xboard `order/save` 创建订单；金额、折扣及权益以服务端响应为准。
2. 创建一个随登录会话存活的客户端对象，调用 `setAuthorization(auth_data)`，不把订阅 token 当登录 token。
3. 按构建渠道创建 `ClientPaymentPolicy`；将 `allowStripe` 传给 CheckoutController，不使用后端开关绕过商店渠道。
   将 policy.platformHeader / distributionHeader 传给 XboardClient 的 clientPlatform / distribution，随请求发送
   X-ZolNit-Platform / X-ZolNit-Distribution，供后端会话选择 native、hosted 或 IAP 契约；这些头不作为服务端授权凭据。
4. 配置精确的 HTTPS 收银台 origin 白名单，不允许 HTTP、URL 内嵌凭据或任意第三方域名。
5. 启动 checkout 后 attach 付款界面、轮询或手动刷新。SDK 成功、浏览器返回、深链参数都不能授予权益。
6. 只有 Xboard 订单状态 3 才显示已完成，并重新获取 getSubscribe；状态 1 是开通中，4 是折抵，不是退款。
7. 退出/切换账户时先 reset 支付控制器、setAccount 和 setAuthorization；dispose 页面与监听器。

登录响应的 auth_data 已含 Bearer 前缀；返回的 token 是订阅令牌，不用于登录鉴权。密码不持久保存，宿主当前
只保留本次进程中的登录会话。订阅配置使用服务端 subscribe_url，保留参数后选择 flag=meta；server/fetch 是
节点展示列表，不能用它重建连接密码或写死节点。空列表不表示所有线路离线。宿主通过一次配置同步维护原来的
profile ID，校验完成且账户代际仍有效才发布配置；不会为同步调用 resetSecurity。

真实 plan/fetch 使用 month_price/quarter_price/half_year_price/year_price/two_year_price/three_year_price/
onetime_price/reset_price 兼容字段，单位为分；普通 order/save 使用对应周期字段。客户端不自行计算折扣、余值或
人民币/SGD 结算报价。节点、分流和 IPv4/IPv6 规则由面板配置提供，不改变固定 core。

原生 IAP 在登录会话就绪后启用监听；未配置商品时传空 productIds，显示不可购买，不使用假商品 ID。
购买前 prepare 必须返回匹配当前账户的 appAccountToken UUID；商品价格取 StoreKit，而非 Xboard 的普通优惠价。
收到 purchased/restored 后提交 SDK 的 serverVerificationData；仅服务端确认该账户/商品/交易已开通时完成 native transaction。
服务端不可达、尚未开通或身份不匹配时保留未完成交易，可重试或通过恢复购买再次验证；不会在客户端延长有效期。
`restored` 仅表示系统恢复调用已结束，不表示已授予任何权益。正式账户页面还需依实际后端能力接入注销。

## 已对照现有服务端的接口

运维会话已用既有专用验证账户验证登录及只读账户、订阅、套餐、节点、权益和合约接口；本会话核对了对应公开
PHP 源码，并独立读取公开 config。该证据不等于宿主已用真实账户登录、真实付款或 VPN 已完成验证。

| 功能 | 既有路径（均在 /api/v1 下） |
| --- | --- |
| 登录、账户、订阅、节点 | passport/auth/login、user/info、user/getSubscribe、user/server/fetch |
| 普通套餐与订单 | user/plan/fetch、user/order/save/detail/fetch/check/checkout/cancel/getPaymentMethod |
| 续费配置与权益 | zolnit-stripe/config、entitlement、plans |
| 合约管理 | zolnit-stripe/subscriptions、subscriptions/{id}/cancel、subscriptions/{id}/resume |
| 已有连续付费订单 | zolnit-stripe/recurring-orders/{tradeNo}、zolnit-stripe/subscribe |

subscriptions 返回 subscriptions 列表和独立 entitlement；权限使用服务端 can_cancel/can_resume，
时间使用 paid_through/next_renewal_at；current_period_end 不作为已付权益证明。取消响应可能同时取消未付款首单，
不能在本地假定只影响下一期。恢复与取消均需用户明确操作并重新获取服务端快照。

准备付款先读取本人 order/detail，再查询 recurring-orders/{tradeNo}。仅 intent 明确返回 HTTP 404 时进入普通
checkout；401/403/409、超时、5xx 和畸形响应均不回退。连续付费即使金额为零也必须展示服务端首期、后续、
结算与抵扣信息，经明确同意后调用 subscribe，携带原 trade_no、quote_id 等字段及 consent=true，不创建替代订单。

桌面 Hosted Checkout 消费 type:1,data:HTTPS-url 或已确认的 hosted 对象。运维会话已确认该后端适配上线，
并独立验证测试会话及清理；这不等于客户端界面或真实扣款验收。既有 Embedded 会话仍使用网站继续，不能为桌面重复创建付款。
Embedded 的 cs_ client_secret 不属于 PaymentIntent，客户端明确拒绝将其送进原生 Stripe SDK。

付款成功和取消均可通过站内 HTTPS 落地页唤起 zolnit://safepay；可含 trade_no/session_id，但不能携带 bearer
或任何支付 secret。前台深链通知不转发原始 URL，App resumed 同样触发原订单查询；回跳参数不证明交付。

## 后续原生支付能力：仍需服务端契约与渠道配置

下面的 Android PaymentIntent 扩展与 Apple 路径仍是尚未部署确认的原生契约，不由客户端实现后端。
Apple Developer/App Store Connect 应用、商品和 Android 微信应用登记/签名尚未配置，实际入口保持未就绪。

Stripe 使用既有 `/api/v1/user/order/checkout`。普通订单兼容 `type:1,data:https-url` 和 `type:-1,data:true`；
后者同样再次查订单状态，不能据金额跳过连续付费探测。后续原生扩展动作建议保留 `data` 对象：

```json
{
  "type": 3,
  "data": {
    "trade_no": "XBOARD_ORDER_ID",
    "kind": "stripe_android",
    "wallet": "wechat_pay",
    "publishable_key": "pk_test_EXAMPLE",
    "client_secret": "pi_EXAMPLE_secret_EXAMPLE",
    "return_url": "zolnit://safepay",
    "wechat_app_id": "wxEXAMPLE",
    "qr": {"payload": "PROVIDER_QR_PAYLOAD", "expires_at": 1900000000}
  }
}
```

kind 为 `hosted` 时提供 url；为 `qr` 时提供 qr；wallet 还支持 `card` / `alipay`。QR 可缺省，
但有 QR 时必须附其真实过期时间；native/扫码动作应属于同一订单且避免并存的可重复付款尝试。
Android 微信需要 Stripe 的 Android app next_action，不能只返回网页收银台。
客户端不把 QR 失败转成创建新订单，也不把旧 `type:0` 无过期载荷当成已协商好的扩展协议。

Apple 路径必须由 `AppleBillingPaths` 显式配置，不猜测或硬编码现有 Xboard 接口：

- prepare 输入 product_id，返回 account_id / product_id / app_account_token。
- verify 输入 product_id / transaction_id / verification_data / source；返回相同 transaction_id、product_id、
  account_id，以及严格 bool applied。applied 只能表示服务端验证与持久交付均已完成。
- 商品映射、服务端验签、账户归属、幂等、退款/撤销/续费及权益账务全部由后端会话负责。

客户端不需要 Stripe secret key、webhook secret、Apple 私钥或共享密钥。用户给出的 Mac 测试密钥文件未在
当前云环境挂载，本轮未读取；今后也不应作为 Flutter asset、Dart define 或 Web 资源打包。

## SDK 与验证边界

锁定 Flutter Stripe 14.2.0，对应 Stripe Android 23.22.0。微信桥接使用相同版本的 stripe-wechatpay 和
官方示例要求的微信 SDK 6.7.0，版本升级时必须一起核对，不能仅升级一边。
Android 微信的包名、签名、App ID 需要在微信开放平台配置。Stripe 官方模块说明测试模式只生成模拟微信参数，
无法证明真实微信唤起或扣款；本轮不为验证客户端而发起 live 交易。
来源：https://github.com/stripe/stripe-android/blob/v23.22.0/wechatpay/README.md

本地定向验证：`flutter pub get --enforce-lockfile`、`flutter analyze --no-fatal-infos`、`flutter test`。
Android SDK 编译、App 旋转/后台/进程重启、支付 App 回跳，以及 Apple 沙盒需对应设备和真实商店配置验证。
本机为 macOS，客户端模拟测试使用临时锁定 Flutter；Android SDK、完整 Xcode、商店资料和真机支付未在本轮验收。
Dart 通过不等于原生路径已验证。安装身份采用用户批准的 com.zolmid.zolnit，调试身份另加独立后缀；
不读取、迁移或覆盖上游 FlClash 数据，不生成签名。验证命令：

```bash
flutter run -d macos --dart-define=APP_ENV=dev --dart-define=SAFE_MODE=true --dart-define=ZOLNIT_DISTRIBUTION=direct
```

只运行 SAFE_MODE；正常 VPN/代理、签名上架和真实扣款由用户另行授权。
Root CI 的 Plugins job 单独验证本模块和微信桥接；开发分支 push 另运行全平台 project 云构建。
客户端分支另产出 macOS arm64 安全调试包，显式 SAFE_MODE=true、ZOLNIT_DISTRIBUTION=direct，
并保留原来的全部 release 编译。只运行该安全调试产物；CI 产物属于开发验收，不是正式网站安装发布。

安装与更新由 ZolNit 网站统一提供。公开清单约定为 https://link.zolmid.com/client/releases.json，
schema_version=1、app_id=com.zolmid.zolnit；当前未发布正式产物，updates_enabled=false、releases=[]。
禁用、空或尚未支持的清单保持不可安装，不回退上游/GitHub旧身份包。后续真实签名产物和条目校验需另行验收。

Web 原型仍独立并使用模拟数据，不连接真实账户或创建真实付款；宿主页面消费真实业务接口，不提供模拟付款成功按钮。

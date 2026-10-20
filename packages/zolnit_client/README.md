# ZolNit 客户端模块

范围仅为客户端：Xboard HTTP API 适配、Stripe 原生/浏览器动作、付款二维码、Apple StoreKit 2 购买与恢复。
不包含任何服务端、Xboard 插件、数据库连接、支付创建或 webhook 实现。正式品牌页面继续通过独立 Web
预览确认，本模块不替换现有 FlClash 导航或启动 Core。

## 当前入口

- `XboardClient`：账户、套餐、订阅、节点、订单、支付方式、优惠券、工单、邀请、流量接口；Bearer 仅在内存中。
- `XboardCheckoutBackend`：保留现有 checkout 外层 `type/data`；接收下述扩展动作草案，路径不变。
- `CheckoutController`：支付动作 single-flight、返回后查询、有限轮询、过期 QR、账户代际与 dispose 保护。
- `NativeCheckoutPlatform`：Android 银行卡/支付宝通过 Flutter Stripe 调用原生 SDK；微信使用专用 Android 桥接。
- `PaymentQrView`：仅编码服务端返回的 QR 载荷，过期自动隐藏，不把 client secret 或普通链接伪装成钱包收款码。
- `ApplePurchaseController` / `StoreKitGateway`：StoreKit 2 商品、本地化价格、账户绑定、购买、恢复与未完成交易重试。
- `ClientPaymentPolicy`：Apple 原生构建默认商店渠道；官网 macOS 构建可显式指定 `ZOLNIT_DISTRIBUTION=direct`。
- `CheckoutLifecycleBinding`：付款页面存活期间监听 App resumed，仅刷新 Xboard 状态；关闭页面时 close。

Android 宿主已改为 FlutterFragmentActivity / AppCompat，并仅注册 `zolnit://safepay` 返回入口。
旧 Clash 导入链接保持。支付返回链接在普通导入日志之前被识别，不记录带 client secret 的 URL。
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

原生 IAP 在登录会话就绪后启用监听；未配置商品时传空 productIds，显示不可购买，不使用假商品 ID。
购买前 prepare 必须返回匹配当前账户的 appAccountToken UUID；商品价格取 StoreKit，而非 Xboard 的普通优惠价。
收到 purchased/restored 后提交 SDK 的 serverVerificationData；仅服务端确认该账户/商品/交易已开通时完成 native transaction。
服务端不可达、尚未开通或身份不匹配时保留未完成交易，可重试或通过恢复购买再次验证；不会在客户端延长有效期。
`restored` 仅表示系统恢复调用已结束，不表示已授予任何权益。正式账户页面还需依实际后端能力接入注销。

## 后端会话交接：接口草案，尚未确认存在

下面只是客户端需要消费的数据形状，不是已开发的 API，也不宣称 Xboard 当前已提供相应插件。
后端路径与字段由负责 Xboard 的独立会话确认后再调整。客户端不替该会话核实或实现后端能力。

Stripe 使用既有 `/api/v1/user/order/checkout`。兼容 `type:1,data:https-url` 和零价 `type:-1,data:true`；
零价同样再次查订单状态。扩展动作建议保留 `data` 对象：

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
当前环境没有 Android SDK、macOS 或 Xcode；Dart 通过不等于这些原生路径已验证。
Root CI 的 Plugins job 单独验证本模块和微信桥接；开发分支 push 另运行全平台 project 云构建。

Web 原型独立，订单与二维码占位明确标为演示，无法调用以上原生 SDK；不连接真实账户或创建真实付款。

# ZolNit 客户端模块

范围仅为客户端：Xboard HTTP API 适配、Stripe 原生/浏览器动作、付款二维码、Apple StoreKit 2 购买与恢复。
不包含任何服务端、Xboard 插件、数据库连接、支付创建或 webhook 实现。五平台 Web 预览用于页面内容与配色对照，
宿主入口为 lib/views/zolnit/home.dart，通过 lib/providers/zolnit.dart 装配会话与支付；仍由原有 Core 生命周期
管理连接。本轮首个验收平台是 macOS 官网渠道，界面组件通过不等于各平台系统组件或真机 VPN 已验收。
根用户已授权在隔离分支 codex/native-client-shared 同时推进 Android Compose、Apple SwiftUI、Windows WinUI 3
展示层，复用 Dart 账户、支付、订阅及现有 Go/VPN 所有者；Linux 保留 Flutter。此处描述当前代码，原生宿主编译与设备验收分别记录。

## 当前入口

- `XboardClient`：账户、套餐、订阅、节点、订单、支付方式、优惠券、工单、邀请、流量接口；鉴权令牌只交由平台安全存储保存，不进入普通偏好、日志或原生视图。
- `ZolnitSessionController`：登录、恢复、退出、账户快照、套餐/线路/订单和支付返回同步；安全存储读写串行，旧账号回调不能覆盖新账号。
- `ZolnitSessionVault` / `SecureZolnitSessionVault`：通过平台安全存储恢复跨重启登录；关闭窗口保留，明确退出或鉴权失效时删除。
- `ZolnitNativeHome` / `zolnit_native_ui`：ARB 唯一文案、无凭据状态快照与用户命令；未知流量保留 null，命令受账号代际和安全模式约束。
- `ZolnitOrdersClient`：类型化订单和支付方式查询，详情响应必须匹配请求的订单号。
- `ZolnitAccountClient`：账户资料、登录会话查询和撤销、修改密码及到期/流量提醒设置。
- `ZolnitSupportClient`：工单列表、按时间排序的消息、创建、回复和关闭。
- `ZolnitInviteClient`：邀请码、固定顺序的奖励统计、佣金分页和生成邀请码；邀请链接沿用网站的 `/#/register?code=`。
- `ZolnitTrafficClient`：面板流量明细；上传/下载字节已计入节点倍率，不再次乘算。
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

登录响应的 auth_data 已含 Bearer 前缀；返回的 token 是订阅令牌，不用于登录鉴权。密码不持久保存。宿主先从平台安全存储恢复并校验会话，
再自动同步账号所属订阅；只有同步成功且账号代际有效时才允许启动后连接。网络错误保留令牌供重试，关闭客户端不执行退出。
订阅配置使用服务端 subscribe_url，保留参数后选择 flag=meta；server/fetch 是
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

账户、工单、邀请和流量模块依据 `references/Xboard` 中的既有控制器及资源结构适配；账户资料和登录会话已接入页面，
改密与撤销登录会话分别经过表单提交和明确确认后发送。工单、邀请和流量明细的独立页面尚未接入，
没有自动创建工单、生成邀请码、撤销会话或修改账户。对应写操作仅使用 MockClient 验证请求字段与错误传递，
尚未做真实账户验收；不会把测试通过当作这些接口已在部署环境确认。列表忽略缺少标识的记录，畸形响应报错，
缺失的佣金统计保持未知；写操作仅接受服务端明确的 `data:true`。

节点页显示当前面板节点、地区、标签与倍率，支持搜索和地区筛选。只接受本人订阅配置中包含该节点的 Selector，
当前 Core 已连接且非 SAFE_MODE 时才请求切换或探测。延迟读取既有测量状态，未检测显示“—”，不生成演示速率。
偏好设置复用原有自启动、启动后连接、主题和语言状态；不增加独立的连接生命周期。安全模式仅保留偏好。
登录页支持恢复跨重启会话、重复提交保护和旧账户回调隔离。注册和找回密码分别打开官网已存在的
`/#/register`、`/#/forgetpassword`，邮箱与人机验证由官网完成，未实现原生验证码或伪造验证通过。

套餐模型保留网站 `zn-plan-*` 内容中的说明、月/总流量标签、特性和购买提示，现有套餐页按这些字段展示，
避免把按量套餐写成月流量或重复列出设备数与速度。未使用该结构的普通面板内容仍按纯文本显示。

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

## 新连续包月流程

1. 用户在套餐页选择已就绪的 Stripe 渠道（来自已登录的 `zolnit-stripe/config`，enabled 且 configured）。
2. `GET zolnit-stripe/plans?payment_id=&plan_id=&period=monthly` 取得服务端报价；`available:false`、字段缺失、
   `quote_expires_at` 已过期都直接失败，不降级为普通订单。金额、9 折、手续费、首期付款、原套餐余值抵扣、赠送权益替换、
   立即切换和下次扣款时间全部以服务端为准，客户端不自行计算。
3. 展示首期 / 后续 / 抵扣条款并取得明确同意；拒绝则不发任何写请求。
4. `POST zolnit-stripe/recurring-orders {payment_id, plan_id, quote_id, consent:true}` 创建原生订单，返回 trade_no。
5. 同一进程内为该 trade_no 记住已批准的条款，付款时读取 `recurring-orders/{tradeNo}`；其 quote_id 与金额字段和已批准条款
   一致就不再重复确认，任一字段变化则重新展示并要求同意，拒绝即停止。
6. `POST zolnit-stripe/subscribe` 取得 Hosted 收银台并在系统浏览器打开；返回后只靠订单状态查询确认交付。
   已知的连续包月订单若意图返回 404 或任何错误，都不会回退到普通 checkout。

## 服务端错误提示

非 2xx 响应按 UTF-8 解析 JSON，`ClientFailure.serverMessage` 只在可安全展示时才有值：非空、不超过 300 字符、无控制字符、
不含堆栈 / SQL / 文件路径特征，也不是通用的 “Server Error”。`toString()` 永远不包含该文本。401 与账户身份查询
`user/info` 的 403 只给 `unauthenticated`，不带服务端文本；其他 403 保留业务错误分类，付款探测仍禁止回退。

- 原生 XBoard 路径：业务错误（例如存在未支付订单）常以 HTTP 500 返回，4xx / 5xx 的可展示 message 都保留；服务端按请求头
  `Content-Language` 本地化，客户端按当前界面语言发送 zh-CN / zh-TW / ja-JP / ko-KR / ru-RU / en-US。
- 插件路径（`/api/v1/zolnit-stripe/`）：仅读取 4xx，按与网站 `public/entry.js` 的 checkoutError 相同的顺序映射为
  `pending_order`、`quote_expired`、`checkout_exists`、`checkout_processing`、`rate_limited`，界面显示本地化文案；
  消息含中文时原样显示，其余不显示服务端文本。

## Android 原生 Stripe

后端尚未提供 README 草案中的 `type:3 / kind:stripe_android` 动作，Android direct 请求目前只会得到 Embedded 结果，
被客户端按设计拒绝。因此 Android 的 Stripe 入口默认如实显示为不可用；仅在后端就绪后用
`--dart-define=ZOLNIT_ANDROID_NATIVE_STRIPE=true` 联调，桌面与 Apple 渠道策略不受影响。

桌面 Hosted Checkout 消费 type:1,data:HTTPS-url 或已确认的 hosted 对象。运维会话已确认该后端适配上线，
并独立验证测试会话及清理；这不等于客户端界面或真实扣款验收。既有 Embedded 会话仍使用网站继续，不能为桌面重复创建付款。
Embedded 的 cs_ client_secret 不属于 PaymentIntent，客户端明确拒绝将其送进原生 Stripe SDK。
网站加密货币预览和 `cpmt_` 结果尚无完整客户端支付契约，当前不作为可用支付方式展示或调用。

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

## 独立客户端 bundle API v1（默认关闭）

客户端已接入 `GET /api/v1/zolnit/client/bundle`，使用现有 Bearer 会话以及
`X-ZolNit-Platform`、`X-ZolNit-Distribution` 和真实运行 Core 返回的
`X-ZolNit-Core-Version`。当前构建固定 v1.19.32；这不是最低兼容版本的验收结论。
此路径不读取订阅 URL，不依据 UA 猜测身份，也不使用管理端凭据。

响应外层 `data` 是同一账户、权益过滤和生成时刻的原子快照：

- `schema_version=1`、`account_id`、不可复用的 `bundle_id`、`issued_at`、`expires_at`；
  有效期最多 300 秒，按接收完成时的时钟校验。
- `connection` 包含 `engine=mihomo`、`format=yaml`、`sha256` 和 `document`；
  哈希覆盖 document 原始 UTF-8 字节，解析及重新序列化前校验。
- `outbounds` 的 `id` 为 `protocol:panel-id`，`proxy_name` 为
  `zn.node.<protocol>.<panel-id>`，`display_name` 只用于展示。
- `routing` 维持元数据 v1；首轮 AI/影音组分别为 `zn.service.ai` 和
  `zn.service.media`，各有 `.auto` / `.manual`。节点绑定同一 outbounds，最终出口有
  明确验证来源、`exit_id` 和 `failure_domain`；未知出口不进入自动池。

SDK 负责包结构、时间、哈希及元数据身份校验；宿主在 isolate 中校验 YAML 实际代理与
outbounds 一一对应、组名无歧义、无动态代理源，再走现有 Core 校验和配置应用路径。
没有数字账户 ID 的 user/info 不用于猜测绑定：第一份有效包绑定当前认证代际的 account_id，
后续必须一致。登出或认证代际变化使旧绑定和在途结果失效。

私有缓存写入应用数据目录，以 bundle_id 哈希命名，替换配置指针前完成校验，最多保留当前
及上一份快照。401 沿用会话失效流程；403 只标记权益不可用并拦截旧配置再次应用，保留登录与
账户/付费快照；503 保留同账户的最近有效记录。过期对象保留为显式手动选择的数据来源，
自动候选清空并收敛到 REJECT，不把缓存存在当作仍有自动资格。权益、版本或绑定拒绝时不能
使用缓存重连；普通刷新故障也仅允许同账户已有显式手动或 DIRECT 意图。

`ZOLNIT_CLIENT_BUNDLE` 一般构建默认 false；本开发分支的五平台 Cloud 构建显式开启它，
并在来源记录中写入 `client_bundle=true`。自动模式默认启用能力检测，仍需取得实际 Core 的匹配
租约及合格候选；旧 Core、过期/撤销租约、`routing.nodes: []` 都保持自动不可用，不能用名称或
延迟补齐资格。边缘 HTML/未知 403 和网络错误显示接口不可用，不登出、不判定套餐过期，也不
恢复缓存。只有结构化 `error.code=entitlement_unavailable` 的 403 才撤销权益相关资格。

### 实际 Core 所有者与租约

租约随 `setupConfig.routing-lease` 进入实际 Core。装载新配置前，旧自动 Selector 先收敛到
REJECT、撤销资格；`hub.ApplyConfig`、选择初始化和新租约安装共用 `selectMu`，锁序仍为
`configMu -> selectMu`。安装时自动组统一从 REJECT 开始，新 bundle 身份和期限参与应用摘要，
即使 YAML 一样也不能只更新 Flutter 的时间而跳过 Core 安装。

`getRoutingLease` 返回实例、配置代际、意图令牌、账户代际、bundle、摘要和期限。每轮探测前
取得的令牌随自动选择写入，Core 在同一把锁内检查完整身份、期限、实际 Selector/代理对象和
当前服务模式。手动意图旋转令牌，旧探测不能在手动再返回自动后写入。Core 定时器独立撤销
过期资格并设 REJECT，不依赖前台 Dart timer；旧定时器和旧配置/实例令牌也不能碰新 Selector。

| 平台 | 现有生命周期所有者 | 新增的选择控制边界 |
| --- | --- | --- |
| Android | 原生 ServiceState / ServiceController | 服务中的 Go Core 负责互斥与租约 |
| macOS | DesktopCoreLifecycle 的进程 lease | RPC 到该独立 Core；实例/配置代际阻止重启前任务 |
| Windows / Linux | 既有 Helper 单个受管子进程及 DesktopCoreLifecycle | Helper 不直接改 Selector；租约在其启动的 Core 内执行 |
| iOS | App Core 与 Network Extension 分别持有自己的实例 | 活跃连接的租约 RPC 路由到 Extension；不可回退 App Core 假确认 |

这条跨进程边界使用实际 Core 的 RPC 租约，不另建一个前台文件锁或第二个进程生命周期所有者。
Core 单测覆盖无 Flutter 的 TTL 定时拒绝、旧配置/实例/定时器、手动 ABA、直接连接别名和原子
配置安装；宿主测试覆盖令牌传递、续期、403/503/TTL 和账户变化。它们不等于 iOS 挂起、Helper
崩溃恢复或真实设备联网已经验收。

测试只用仓库内 synthetic bundle 和无凭据 RFC 5737 代理夹具。真实 Core 离线检查只解析
代理、Selector 和域名规则，并确认选择结果；不执行完整配置应用、监听、DNS、TUN 或联网。
业务测试、离线 Core 检查与 CI 均不证明真实账号、出口、AI/影音解锁或设备行为已验收。

### 凭据隔离的真实 Core 联调驱动

源码在 `core/cmd/zolnit-bundle-probe/`，使用固定子模块内的 `adapter.ParseProxy` 和
`Proxy.DialContext`；不调用完整配置解析/应用，不启动应用、VPN、系统代理、DNS 监听或外部控制器。
只提取静态代理及其精确的 `dialer-proxy` 链；规则、规则源、DNS/TUN 配置都不执行。
支持的协议由代码显式列出，不支持的协议/代理组链直接失败，不使用 DIRECT 或通用订阅回退。

客户端开发者先在干净提交上构建，并交付带 SHA256 的就绪二进制；根聊天无需编译或运行开发测试，
只在其安排的账号窗口中运行已交付驱动。下面是开发者构建命令：

```sh
ZOLNIT_PROBE_SHA=$(git rev-parse HEAD)
ZOLNIT_CORE_VERSION=$(sed -n 's/^core_version: *//p' build_config.yaml)
(cd core && CGO_ENABLED=0 go build -mod=readonly \
  -ldflags="-X github.com/metacubex/mihomo/constant.Version=$ZOLNIT_CORE_VERSION -X main.sourceCommit=$ZOLNIT_PROBE_SHA" \
  -o /private/tmp/zolnit-bundle-probe ./cmd/zolnit-bundle-probe)
```

驱动只从 stdin 接收一个 JSON 帧，不提供 bundle 文件、URL 或命令行载荷参数：

```json
{"http_status":200,"source_path":"/api/v1/zolnit/client/bundle","body":{"data":{}}}
```

上面的空 data 仅占位，不能用于验收；body 必须是完整原始 API 响应对象（保留外层 data），不得再次包一层 data。由根聊天现有的凭据请求程序
在内存中取得真实 HTTP 状态和响应，发送正常客户端 UA 与三个 X-ZolNit 上下文头，再将该帧写 stdout。
Bearer、原始响应及连接凭据不得进入 shell 参数、环境变量、日志、临时文件或聊天。非 JSON 响应
应以空 body 和实际 HTTP 状态送入；驱动报接口不可用。输入帧的来源由该请求程序保证，驱动不把
`source_path` 文本当作独立的 HTTPS 来源证明。

```sh
# “现有凭据请求程序”只代表根聊天持有的内存请求入口，不是仓库内的凭据脚本。
现有凭据请求程序 | /private/tmp/zolnit-bundle-probe --account-id 2
现有凭据请求程序 | /private/tmp/zolnit-bundle-probe --account-id 2 \
  --probe --outbound-id '协议:面板ID' --target gstatic --timeout-seconds 10
```

`--version` 可在不读取 stdin 的情况下核对源码提交和实际链接的 Core 版本。
第一条只校验 schema、账户、300 秒 TTL、原始 UTF-8 SHA256、outbound 和服务组映射；
第二条还对显式选定的 outbound 发一次 HTTPS HEAD。目标仅允许内置 gstatic/cloudflare，
禁止重定向和环境代理，连接默认限时 10 秒、允许 1–20 秒，截止时间不超过包 TTL。
该限时不包含 stdin 等待和本地校验，运维调用方须另设请求/进程总超时。QUIC 代理可以创建客户端 UDP socket，
不开放代理服务监听。stdout 只输出固定错误码、Core/源码版本、数量、状态码和用时，不输出
账户、bundle_id、节点地址、显示名称、哈希原文、响应体或错误详情。驱动不保存输入或结果文件。

`routing.nodes=[]` 仍可验证并显式测一个授权 outbound，但不产生自动服务资格。成功仅证明本次
选定协议到测试地址的传输和 HTTPS 请求完成；不证明出口国家、账号产品权限、AI/影音解锁，
也不覆盖 iOS Extension 或实际移动设备。403/503/无效 TTL 不连接、不读取旧缓存。

### 出口国家观测 v1（本地运维交付）

先核对服务语义：[Country 官方文档](https://country.is/) 的 `GET /` 返回调用方 IP 的国家；
[OpenAPI 4.2.3](https://api.country.is/openapi.json) 定义所需字段为 ip、country，country 允许 null，
并说明 Cloudflare 的国家数据可优先使用。它是单个服务对本次源地址的地理归属观测，不是物理
位置证明、产品解锁或自动路由资格，也不能从 CDN 机房 `colo` 推断出口国家。

新模式固定为 `--observe-egress --account-id 2 --outbound-id '协议:面板ID'`，只经该显式代理
向 `https://api.country.is/` 发一个 GET；不能同时使用 `--probe` 或任何 `--target` 参数。
不接受任意 URL、IP 查询参数、重定向或环境代理，不追加其他供应商回退，也不重试或批量探测。
默认无动作开关时仍只校验 bundle，原 `--probe` 的 HTTPS HEAD 模式保留。

stdin 帧继续保留原 API 响应；新增顶层 `observation: {"key_b64u": "执行窗口密钥"}`。
根聊天在其进程内用密码学随机源创建 32 字节密钥，采用不带 padding 的 base64url 编码（43 字符）；
同一账户/执行窗口的多个样本复用它，结束后丢弃，下一窗口换新密钥。密钥不得使用密码/Bearer
替代，不经命令行、环境变量、日志或文件传递，驱动不会把它送给观测服务或输出。
驱动仅校验长度及非全零，随机性由执行方保证；实际配置仍只经 stdin 进入进程。

包绑定、SHA256、映射、TTL 和窗口密钥通过后才允许联网。连接默认 10 秒、范围 1–20 秒，
并受 bundle 截止时间约束；stdin/本地解析不属于该连接计时，调用方另设进程总超时。
HTTP 响应头最多 8192 字节，响应体最多 4096 字节；只接受 HTTP 200、application/json 和
未压缩/identity 响应，重复 JSON 键、尾随内容、未知国家、私有/保留地址均失败，不输出部分结果。

观测成功新增 `country_code`（249 国 ISO alpha-2 白名单）和 `egress_tag`；其余仍是固定错误码、
Core/源码版本、模式、数量、HTTP 状态及用时。code 为 `egress_observation_ok`，mode 为
`egress_observation`，target 为 `country_is`。失败不含 country_code/egress_tag；上游 403/429/5xx
只报 `egress_http_status`，不表示套餐过期。原始响应、IP、显示名称、节点地址、凭据及密钥不输出或落盘。

标记为 `eg1.` 加小写十六进制 HMAC-SHA256：输入是
`zolnit-egress-observation/eg1\0https://api.country.is/\0<规范化IP>`（\0 表示 NUL 字节）。
IPv4-mapped IPv6 先还原 IPv4；标记不包含国家、协议或节点 ID。同窗口相同标记只表示该服务
观察到了相同的规范化 IP，不证明同一机器/物理出口；换密钥后不可跨窗口比较。它是带密钥标记，
不使用可枚举的无盐 IP 哈希。本模式不修改应用配置、VPN、OS 代理/DNS 设置或 routing.nodes。

### 已报告的真实验收范围

根聊天于 2026-10-25 报告：macOS arm64 二进制源码 3782e1ee / Core v1.19.32，SHA256 为
`5feacd910e4f0055d45a66391574788cbcce837592decac4c941e747e99c71e9`。
真实过期 403 帧返回 entitlement_unavailable；临时授权窗口的真实 200 帧校验通过，20 outbounds，
SHA256/映射均有效。按面板香港/新加坡标签选取的 REALITY/HY2 共 4 个显式手动样本均到 gstatic
返回 HTTP 204、isolated_connection_ok；routing_node_count 始终为 0。标签不等于实际出口国家。
原到期时间已由根聊天恢复，会话已撤销；客户端侧未接收真实配置或凭据。这是该驱动 4 个样本
的真实 Core/网络证据，不覆盖国家归属、AI/影音资格、Extension、Helper 或其他设备。

### iOS Extension / Windows Helper 实机验收准备（未执行）

macOS stdin 驱动创建独立的 Core adapter，不连接应用 IPC；它不能验收 Extension、Helper 或后台租约。
当前真实 `routing.nodes=[]` 只允许包校验与显式手动连接，不得为设备测试填入虚构的运营资格。
自动租约的设备验证须另用明确标为 synthetic 的保留地址夹具，在隔离测试设备上完成。

| 平台 | 所需设备与用户操作 | 必须记录的实际证据 |
| --- | --- | --- |
| iOS | arm64 iPhone/iPad、iOS 15+；带匹配 Network Extension / App Group 权限及有效 provisioning 的签名开发包。用户允许测试 VPN，并提供可中断网络的窗口；unsigned CI IPA 不能直接替代。 | 实际 Core 路由为 Extension、两个进程身份、租约配置代际；App 自然进入后台/锁屏超过租约期限后，自动组变为 REJECT，手动/DIRECT 保留；停止再启动测试 VPN 后新实例拒绝旧 guard。 |
| Windows | 可控 x64 测试机或 VM；安装同提交的 App/Core/Helper，核对 Helper 协议及 Core 哈希。安装、SCM 服务重启可能需要管理员同意。 | 暂停 Flutter 前台而保留 Helper/Core 与 IPC，超过期限后自动组变为 REJECT；Helper 重启时旧 Core 随 Job 退出，再由正常启动路径创建新实例；旧 session/guard 不能停止或修改新实例。 |

不能先唤醒前台或刷新 bundle 再读取结果，否则前台可能重建配置/租约而掩盖后台行为。
`getRoutingLease` 内部调用 `ensureRoutingLeaseFreshLocked`，查询本身会执行到期撤销；它返回 null
不足以单独证明定时器生效。应先经已授权的既有 IPC 读取 `getProxies`，再读取租约状态。
Windows 不能以杀死/正常退出 App 代替“前台暂停”：Core 的 IPC EOF 会触发退出清理。

当前缺口是独立观测入口：现有 RPC 可以提供状态，但没有交付可在 iOS App 被挂起或 Windows
前台被冻结时独立取证的运维工具。须先提供经过授权的只读观察入口，或不会被恢复/刷新覆盖的
Core 事件证据，再进行上述后台验收；不能用重新打开节点页后的状态或纯 Go 测试代替。
仅带回源码/构建身份、进程是否存活、时间差、配置代际、选择是否 REJECT、旧写入是否拒绝和
手动状态是否保留；完整 guard、账户、bundle、配置、节点地址和凭据均留在执行设备内。

## 服务智能分流元数据 v1（既有兼容载体，未上线）

新 ZolNit 客户端已实现上节的独立鉴权原子 bundle 接入。本节仅记录 0d7a4a5a 的既有兼容载体与
离线测试结构；已暂停新增订阅 YAML 传输集成，后端不应据此将扩展接入生产订阅。

自动分流保持 Mihomo rule 模式和原规则目标；只替换受管订阅中的服务 Selector，并以独立的
自动 Selector、手动 Selector、DIRECT 三个选项承接。自动组初始选择 REJECT，获得真实探测后才选节点。
旧 AI 服务 → 节点选择 → url-test 继承链会被截断；没有合格元数据时保留显式手动与直连，自动不可用。
本轮没有修改订阅模板、Xboard、库存或后端接口，也没有推断服务端已经支持下列扩展。
受管订阅由客户端在 isolate 中读取原始 YAML，保留 Core RawConfig 会省略的扩展字段；
节点定义和元数据来自同一快照，生成的配置仍通过既有 Core 应用与校验路径。

受管订阅可在 YAML 顶层提供以下对象；示例名称仅示意，不是内置节点清单：

~~~yaml
x-zolnit-routing:
  version: 1
  authority: zolnit
  revision: operator-inventory-revision
  services:
    - id: ai
      kind: ai
      group: AI 服务
      automatic: AI 自动
      manual: AI 手动
      providers: [chatgpt, claude, gemini_api]
      allowed_countries: [US, JP, SG, TW]
  nodes:
    - id: stable-public-node-id
      proxy_name: Exact subscription proxy name
      final_egress:
        country: US
        source: operator_verified
        verified: true
      failure_domain: stable-machine-or-egress-id
      services: [ai]
      enabled: true
      revision: final-egress-revision
~~~

group 必须是订阅中已有的规则策略组；automatic、manual 是尚未占用的专用组名。
同一出口的 REALITY/HY2 等变体应共享 failure_domain；中转、入口位置和最终出口不能互换。
最终出口来源只接受 operator_verified 或 egress_probe 的明确确认。国家使用现行 ISO 3166-1
alpha-2 代码，不能从国旗、名称、标签或套餐推测。节点需与实际 Core outbound 精确对应；未知、
缺项、禁用、不支持的产品或有歧义的重复身份不能进入自动池。动态新增节点无需客户端更新固定清单。

产品键为 chatgpt、openai_api、claude、gemini_api、gemini_web、netflix、operator。
AI 只接受前五种产品，按所列产品官方地区集合的交集限制，并额外排除 HK。
operator 仅用于非 AI 的普通连通性策略。2026-10-24 的地区快照与来源在
lib/src/routing_regions.dart；产品范围不同，不把 Gemini 网页支持范围当作 API 范围。
国家信息无法处理地域例外，故涉及这类例外的 UA 在 OpenAI/Netflix 自动范围中保守排除。

探测经既有 Core 对固定的公开产品地址测量，每服务独立累计；多产品组需各探测均返回有效延迟，
取实际测量最大值。它证明传输可达性，不能证明登录、账号资格、内容解锁或付费 API 调用成功。
丢包率没有独立测量时保持未知，不从延迟编造。每 30 秒轮转最多八个候选并检查当前出口，
并发上限四；冷却、连续恢复、至少 60 秒驻留和重复改善证据限制抖动。用户显式选择手动组或
DIRECT 后自动结果不得覆盖它。账号/配置代际变化使在途探测失效；SAFE_MODE 不探测或切换。

本地测试使用纯元数据、虚拟时钟和假 Core。真实出口确认、服务端扩展输出、VPN 和设备行为仍需
对应环境验收，不能由本模块测试或其他提交的 CI 结果代替。


### 服务端输出规则与首轮范围

扩展随现有 flag=meta 的订阅 YAML 输出，不需要新增客户端 API。先按本次用户/协议兼容过滤得到
实际 outbounds，再用稳定服务器 ID 关联受控运营元数据，最终以实际输出的 proxy_name 生成 nodes。
源文件可以单独保存证据引用、验证时间、内部索引；客户端不读取源文件路径，也不验证这些证据或时间。
authority 是格式标识，不是签名。来源可信性依赖既有受管订阅传递和服务端对运营元数据的保护。

| 原策略组 | 首轮 service | kind | providers | 客户端生成的自动 / 手动组 |
| --- | --- | --- | --- | --- |
| AI 服务 | ai | ai | chatgpt, openai_api, claude, gemini_api, gemini_web | AI 自动 / AI 手动 |
| 海外影音 | media | media | netflix | 影音自动 / 影音手动 |
| 节点选择 | 首轮不声明 | — | — | 保留原框架 |
| 国内服务、国内影音 | 首轮不声明 | — | — | 保留原策略 |
| 通用服务、其他流量 | 首轮不声明 | — | — | 保留原策略 |

kind 的合法值只有 ai、media、general、domestic；group/automatic/manual 都是清单给出的精确名称，
并非固定服务列表。上表定义首轮对接范围，不禁止以后接入其他已有策略组。operator 当前测 Google
普通连通性地址，不是国内服务探测；netflix 也不证明全部影音产品或内容可用，不能为填满分类虚构资格。
后端不要预建 automatic/manual 两组；它们必须在原 proxy-groups 和 proxies 名称中尚未占用。

| 字段 | 服务端必须输出的类型 / 语义 |
| --- | --- |
| version / authority | 整数 1 / 字符串 zolnit |
| revision | 非空公开版本字符串；运营策略变动时更新 |
| services | 1–16 个服务对象；节点清单 nodes 可为空，最多 4096 项 |
| service.id | 唯一稳定字符串；供 node.services 引用 |
| service.kind | 上述四个合法值之一，无缺省 |
| service.group / automatic / manual | 已有规则策略组 / 未占用的专用自动组 / 未占用的专用手动组 |
| service.providers | 非空、无重复、仅支持已列出的七种产品键；AI 只允许前五种 AI 键 |
| service.allowed_countries | 非空、无重复的现行 ISO 大写二字母国家代码；再与客户端产品地区快照求交集 |
| node.id / proxy_name | 全清单唯一的稳定字符串 ID / 与实际 proxies.name 逐字一致的名称 |
| node.final_egress | country、source、verified 三项均显式给出；source 仅两种，verified 仅 true 才可入池 |
| node.failure_domain | 公开且稳定的最终出口或机器标识；协议变体共享它，各 outbound 的 id 仍须不同 |
| node.services | 无重复的已声明 service.id 列表；空列表表示没有自动资格 |
| node.enabled | 显式 bool；false 表示不进入自动候选，无缺省 |
| node.revision | 最终出口定义的公开版本字符串；出口重分类、来源或定义变化时更新 |

ID/failure_domain 采用 1–128 个 ASCII 字符，首字符为字母或数字，其后只允许字母、数字、冒号、
句点、下划线和连字符。数字 ID 也必须用 YAML 字符串，例如 '123'。其他文本字段非空、最长 256，
不得带首尾空白或 ASCII 控制字符。未知附加字段会被忽略；不要附加凭据、私有源路径或订阅 token。

没有隐式缺省。服务级格式错误、未知产品/版本/国家声明、重复身份或名称冲突使清单不可用于自动路由；
单个节点缺项、来源/最终国家未知、未确认、未匹配 actual proxy 或引用未知服务时排除该节点。
禁用节点和无资格节点不能入自动池。AI 服务被遗漏或错标时，也不得保留原 AI 服务的宽泛自动继承。
空候选和缺少健康证据都停在 REJECT；保留显式手动与 DIRECT，不回退节点选择/通用 url-test。

传输无关的完整离线 Core 输入在 packages/zolnit_client/test/fixtures/routing-core-offline.json。它只含 RFC 5737 保留地址、无认证 SOCKS5
示例和 select 组，所有监听端口为 0、DNS/TUN 关闭。fixture 的 verified 是合成测试断言，
不是实际出口证明，不能直接作为上线配置。

### 当前策略参数与观测范围

| 项目 | 实现值 |
| --- | --- |
| 最小驻留 / 样本有效期 | Core 确认选择后 60 秒 / 最近观测 90 秒 |
| 延迟平滑 / 成功率窗口 | EWMA α=0.25 / 最近 20 个完成的服务样本 |
| 评分 | 平滑延迟 ms + (1−成功率)×2000 + 已测丢包率×2000 |
| 改善切换 | 评分收益同时达到 20 ms、当前评分 20%，同一候选至少 2 次不同的新观测 |
| 软失败确认 | 连续 2 个失败样本；单次失败不绕过驻留 |
| 冷却退避 | 15、30、60、120、240、300 秒，上限 5 分钟；恢复后重置 |
| 恢复确认 | 冷却结束后连续 2 个成功样本 |
| 调度 | 每 30 秒尝试；忙时跳过，不重叠；每服务轮转至多 8 个候选，另检查当前出口；并发上限 4 |

每个样本由所列产品的 Core URLTest 构成：逐个探测固定公开 URL，均返回非负延迟才成功，
取实际最大延迟；负值为失败，无 Core 响应则不记节点失败。没有 DNS/TCP/TLS 阶段拆分、带宽、
独立抖动或丢包测量；丢包率保持 null，评分项缺失不等于实测为 0。来源 verified 也不是 URLTest 证据。

hardFailure=true 的立即冷却和同服务 failure_domain 传播只在纯引擎注入测试中覆盖；
当前运行时没有明确机器硬故障分类来源，不能声称已在真实设备采集。HTTP/TLS 可达性不证明账号、
API 授权、产品资格、内容目录或解锁。既有 16 项引擎、9 项元数据、5 项转换、8 项假 Core 接入测试
属于本地逻辑证据；完整包构建、真实 Core 验证、账号与设备验收必须分别记录。

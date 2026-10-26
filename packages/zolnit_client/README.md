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

Android direct 支持已有 type:1 Hosted Checkout 与已确认的 type:3 / kind:stripe_android 动作。
当前原生协商范围为 WeChat 单次付款；不据此声明银行卡、支付宝或微信连续包月已开放。
微信 AppID 从 `--dart-define=ZOLNIT_WECHAT_APP_ID=...` 固定，默认空值明确返回 sdk_unavailable。
当前 type3 响应包含冻结的 wechat_app_id；仅兼容旧载荷缺字段时使用客户端固定值，
显式 null/空值无效，任意不匹配均拒绝。包名/签名/AppID 的
真实登记与 SDK 跳转仍待验收，不使用临时 AppID，也不将不支持的原生动作降级为其他收银台。

桌面 Hosted Checkout 消费 type:1,data:HTTPS-url 或已确认的 hosted 对象。运维会话已确认该后端适配上线，
并独立验证测试会话及清理；这不等于客户端界面或真实扣款验收。既有 Embedded 会话仍使用网站继续，不能为桌面重复创建付款。
Embedded 的 cs_ client_secret 不属于 PaymentIntent，客户端明确拒绝将其送进原生 Stripe SDK。
网站加密货币预览和 `cpmt_` 结果尚无完整客户端支付契约，当前不作为可用支付方式展示或调用。

付款成功和取消均可通过站内 HTTPS 落地页唤起 zolnit://safepay；可含 trade_no/session_id，但不能携带 bearer
或任何支付 secret。前台深链通知不转发原始 URL，App resumed 同样触发原订单查询；回跳参数不证明交付。

## 原生支付合同与尚未配置的渠道

下面是本地消费者已对齐的合同；后端部署范围与真实支付能力由根会话独立确认，不由客户端测试证明。
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
    "qr": {"payload": "PROVIDER_QR_PAYLOAD", "expires_at": 1900000000}
  }
}
```

kind 为 `hosted` 时提供 url；为 `qr` 时提供 qr；wallet 还支持 `card` / `alipay`。QR 可缺省，
但有 QR 时必须附其真实过期时间；native/扫码动作应属于同一订单且避免并存的可重复付款尝试。
Android 微信需要 Stripe 的 Android app next_action，不能只返回网页收银台。
客户端不把 QR 失败转成创建新订单，也不把旧 `type:0` 无过期载荷当成已协商好的扩展协议。

Apple 从 `/api/v1/zolnit-apple/config` 获取账户绑定、SKU 到套餐/周期的映射与固定 prepare/verify 路径。
enabled/configured 均为 true 且 StoreKit 返回实际商品时才显示购买；价格仅使用商店当地价格。

- prepare 输入 product_id，返回 account_id / product_id / app_account_token / entitlement_effect；替换赠送权益时还需 gift.expires_at。
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

安装与更新只使用 https://link.zolmid.com/client/releases.json：顶层严格为
schema_version=1、app_id=com.zolmid.zolnit、updates_enabled、releases。关闭时 releases 必须为空；
启用条目严格为 tag / notes / assets，asset 严格为 name / url / size / sha256。tag 仅接受稳定
vMAJOR.MINOR.PATCH，各分量不超过 2147483647；客户端选择当前平台、架构及包类型的最新兼容版本。
文件名为 ZolNit-VERSION-PLATFORM-ARCH.EXT，URL 必须精确匹配
https://link.zolmid.com/client/downloads/TAG/NAME，不接受重定向、其他域名、查询参数或编码路径变体。
清单最多 1 MiB、30 个版本，每版 64 个包；包最多 2 GiB，下载后校验精确大小及小写 SHA256。
重复 JSON 字段、重复版本/包、非法架构和版本均拒绝。下载续传、取消及安装恢复保留现有校验。
禁用或空清单保持不可安装，不回退上游/GitHub身份包。启用解析已实现，正式签名、真实安装升级和官网发布仍待验收。

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

已有实际入口：显式验收构建使用 `ZOLNIT_ROUTING_OBSERVATION=true`，通过 init 参数开启 Core 的
被动生产器；普通构建默认不产生诊断文件。Extension 从 App 已保存的 setup 参数继承开关，需
在测试 VPN 启动前应用对应配置。Core 在固定 `<home>/diagnostics/lease-observation-<role>.json`
写入脱敏快照（Unix 目录 0700、文件 0600），role 区分 desktop / ios_app / ios_extension / android_service。
诊断文件不含 account、bundle、guard、token、配置摘要、节点名称/地址，只使用既有实例 nonce 的
域分离摘要关联实例与手动选择，不生成或依赖 country.is 的 HMAC 窗口密钥。

生产器由实际 Core 独立运行，每秒发布一次，有界保留 8 个事件，单文件不超过 32 KiB；文件替换
在独立写线程中完成，不把磁盘 IO 放入 Selector 锁。watchdog 在实际 REJECT 后、前台通知前
记录事件；`query_expired`、RPC 撤销、配置替换和手动/自动写入采用不同事件类型。
读取 `getRoutingLeaseObservation` 只复制原始状态，不调用到期清理，不重置定时器或追加控制事件。

独立 `zolnit-lease-observer` 直接只读打开快照，不连接 Core/Helper/Flutter IPC：
`--file <快照路径> --expect-role desktop --watch-seconds 330 --interval-ms 250`。
观察最多 600 秒、256 条状态变化；默认要求采样时间在 5 秒内（可限定 1–60 秒），不将 PID 或
文件新鲜度当作进程存活证明。`deadline_result` 是对已采样真实选择的解释，不执行修复；
`not_rejected` / `unverified` 不得算通过。导出的 iOS 文件须显式 `--allow-historical`，不能冒充实时状态。
独立 iOS 验收 target 为 `ios/LeaseObserver/LeaseObserver.xcodeproj`，scheme 为
`LeaseObserverAcceptance`，只编译原有 Foundation reader 和诊断显示，不链接 Core、Flutter 或 VPN
框架。独立进程每秒从 App Group 读文件，只在自身前台活动时轮询，不向主 App/Extension 发 RPC，
不读写共享偏好，也不启动 VPN。显示文件新鲜度、实际 `deadline_result` 和已验证的脱敏 JSON；
`not_rejected`、`unverified`、陈旧/时钟偏差/已停止生产器不能当作后台保护通过。

该 target 只允许显式 `Debug` 验收构建，默认开关为 NO，拒绝 Release/归档；不加入 Runner 的构建
或嵌入依赖。默认 bundle 为 `com.zolmid.zolnit.debug.LeaseObserver`，App Group 严格沿用
`group.$(APP_BUNDLE_ID)`。在已有完整 Xcode/iPhoneOS SDK 的机器执行：
`python3 tool/acceptance/build_ios_observer.py --output <尚不存在的输出目录>`。
可用 `--app-bundle-id <主 App 的 base bundle>` 明确匹配另一验收包；脚本关闭签名和自动凭据获取，
只构建 arm64 unsigned App/IPA，不注册外部应用、不生成签名资料。当前 Mac 缺 Xcode/iPhoneOS SDK，
实际 unsigned 尝试返回 `xcode_iphoneos_sdk_unavailable`、未产生 IPA；仅工程/权限/门禁检查、
Foundation 行为及基于本机 Mac SDK 的 SwiftUI 类型检查通过，不代表 iOS 编译或设备运行。

iOS 验收包必须成对匹配：原有历史 unsigned 主包使用 `com.zolmid.zolnit`，而独立 observer
默认使用 `com.zolmid.zolnit.debug.LeaseObserver`。开发分支 project 源码的 CI 现统一以
`com.zolmid.zolnit.debug` 构建主 App/NECore/Widget 和 observer，App Group 均为
`group.com.zolmid.zolnit.debug`；只在这个未签名验收主包显式开启 `ZOLNIT_ROUTING_OBSERVATION`。
普通构建仍默认关闭该诊断；其他分支和 patched-reference 保留原命令。产物来源记录两者的
bundle/App Group 和诊断开关，不能将旧正式 bundle 的包直接混配到 debug observer。

核对签名条件只需先确认系统版本和所需能力是否已具备：主 App/NECore 目标为 iOS 15+，
Widget 目标为 iOS 18+；设备安装需要匹配团队/设备的 provisioning，包含 Packet Tunnel 和 App
Group 能力，独立 observer 需要相同 App Group。unsigned/ad hoc 临时代码签名不代表已具备这些
权限。源码和构建准备不读取或索取 Apple 账号密码、证书私钥，也不创建外部 App ID/App Group、
申请会员或自动获取 provisioning；签名/设备运行条件未确认时，只交付 unsigned 构建。

Windows 隔离入口为 `pwsh -NoProfile -File .\tool\acceptance\windows_helper.ps1`。它在自建私有临时
目录编译绑定 Core 哈希的 `isolated-acceptance` Helper、Core、只读 observer 和专用前端；Helper
走私有 stdin/stdout，复用实际 Hub/Job 子进程所有权，不访问共享 HTTP 入口、SCM、服务注册表或
既有服务。只暂停自己持有句柄的前端并从独立 observer 验证 watchdog REJECT/手动选择保留，
再终止自建 Helper、确认 Job 结束旧 Core，重启新实例并确认同代际/截止时间的旧 guard 被拒绝、
新 guard 可用；清理仅限自建目录、Job 和保留的进程句柄。该程序验证专用前端进程暂停，
不等同 Flutter 前台或 SCM 服务重启验收。需 Windows x64 和已有 Go/Cargo；本机已完成可移植
Rust 测试、Windows Rust 编译检查、Go 交叉构建、PowerShell 语法和非 Windows 拒绝分支；
真实 Windows 的暂停、Job 清零和目录清理尚未执行，不能记为通过。清理失败返回非零状态。

Windows 架构验收分开记录，不从进程位数推断物理设备：

| 执行类型 | 必须检测到的原生 OS | 四个用户态程序 | 证据范围 |
| --- | --- | --- | --- |
| NativeArm64 | ARM64 | ARM64 Helper/Core/observer/harness | ARM64 用户态；不证明物理硬件或 TUN |
| X64OnArm64 | Windows 11 ARM64 | 全部 x64，经仿真执行 | x64 仿真用户态；不证明 x64 内核/物理机 |
| NativeX64 | x64 | 全部 x64 | x64 用户态；VM 与物理机仍需单独标明 |

便携验收包由既有 Windows CI runner 生成两份：`windows-helper-tools-x64.zip` 和
`windows-helper-tools-arm64.zip`，每份只有四个匹配的可执行文件、运行脚本和 SHA256/源码清单。
包内 Helper 使用静态 CRT，Go 关闭 CGO；实际 Windows 链接与运行仍需验收。包的
`classification=build-only`、`executed=false` 不代表已在目标架构运行。
测试者无需 Go/Rust/VS，解压后进入对应目录执行一条命令：

- ARM64 原生：`pwsh -NoProfile -File .\windows_helper.ps1 -PrebuiltDirectory . -ExecutionType NativeArm64`
- WOA x64 仿真：使用 x64 包，`pwsh -NoProfile -File .\windows_helper.ps1 -PrebuiltDirectory . -ExecutionType X64OnArm64`
- x64 用户态：使用 x64 包，`pwsh -NoProfile -File .\windows_helper.ps1 -PrebuiltDirectory . -ExecutionType NativeX64`

脚本先核对 OS/进程架构、Windows 版本及全部文件的 PE/SHA256，再在自建私有目录中执行；
不会安装应用或服务，也不启用 TUN。不要混用包中的文件，不把 build-only 清单或开始运行的
架构记录当作成功，须等待退出码为 0 及 Job/目录清理完成。VM/物理机信息由验收记录单独注明，
工具保持 hardwareType=unknown，不自动把 x64 架构认作物理机。
若从源码准备包，使用 `-BuildOnly -ExecutionType NativeArm64 -OutputDirectory <新目录>`
可在 x64 Windows 上交叉构建 ARM64，严禁执行外架构目标程序；`NativeX64` 同理。

检测使用 `IsWow64Process2` 的 native machine；未知或混合 PE 架构在启动前拒绝，不根据
`PROCESSOR_ARCHITECTURE` 或 `GetNativeSystemInfo` 单独认定 WOA。四个程序和 Core 哈希绑定
必须匹配。构建映射已有 Windows ARM64 Core 和 MSVC Helper；本地两架构 Go 交叉构建及
ARM64 Rust 编译检查不等于完整原生 Flutter/WinUI 客户端已交付。既有完整 Windows 产物仍为 x64。
固定依赖的 Wintun 包中已发现 ARM64 native-subsystem payload，但签名、加载、内核驱动和 TUN
行为仍未验收；以上隔离 harness 始终关闭 TUN，结果不得推广为驱动兼容。
[Microsoft 仿真边界](https://learn.microsoft.com/en-us/windows/arm/apps-on-arm-x86-emulation) 明确
只覆盖用户态，内核组件需要 ARM64；[既有 runner 工具清单](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md)
列出 ARM64 编译工具，交叉构建不需要新增 ARM64 runner，但不能据此声称已在 ARM64 上运行。

既有开发分支 CI 已接线，只有 `codex/native-client-shared` 启用新增验收：标准 build 的
`desktop/windows-2022` job 在 Flutter 构建前安装既有版本 Rust/rustfmt 并实际调用上述隔离
harness，并只交叉构建两架构便携包；Cloud build 的 `ios/macos-26` job 在源码为 project 时构建独立 unsigned observer。
不新增 runner/job、事件触发器或权限；patched-reference、其他分支与正式发布不运行这些步骤。
Xcode 从私有临时源码副本构建并在 finally 清理，避免生成 workspace 元数据污染 checkout。
iOS 步骤校验 arm64、源码 SHA、bundle/App Group、IPA/可执行文件摘要、无 provisioning/签名目录；
缺少或畸形产物直接失败。收集主包时还会直接读取最终 IPA 中 Main/NECore/Widget 的 bundle
和 ad hoc 嵌入 entitlements，与 observer 的实际 App Group 声明对照，并输出
`acceptance-pair.json`；不以预期构建参数代替实际产物，也不把占位签名判为可安装设备签名。
Windows 的失败和目录清理错误继续返回非零；两端均将包含源码 SHA
和证据范围的日志上传为独立 14 天开发 artifact，执行失败时也保留已有日志。
本地只验证配置、脚本与失败传播；新增工作流尚未推送或触发，不能记为已产出 IPA 或 Windows
VM 验收成功。后续 VM 结果仍不等于签名 iOS 设备、真实 Flutter 前台或 SCM 服务验收。

桌面提权 Core 写出的目录及每次替换快照交还发起客户端的用户，Unix 保留 0700/0600；
Windows 沿用账户目录 ACL，仍待真实 Helper 环境验收。物理 iPhone/iPad 还需要同一开发团队、
匹配现有 App Group 的 observer provisioning、设备许可和首次解锁/锁屏数据保护验证；本轮不申请
或生成这些凭据，也不唤醒现有客户端来替代独立观察。

本地已验证隔离的实际 Core 可执行进程、独立观察器、真实定时器、手动选择保留、重启后拒绝旧
进程 guard；纯 Foundation 读入口仅在 macOS 合成容器验证。iOS 仍需签名实机、独立读取进程的
App Group provisioning，并核对首次解锁/锁屏数据保护允许记录；Windows 仍需受控 x64 设备、
匹配 Helper/Core、管理员服务重启与前台挂起窗口。这些权限和物理行为均未由 CI/Go 测试验收。

### 后台续租接线与验证边界

`ios/Shared/ClientBundleRenewalState.swift` 保持为 Foundation 值状态机；本分支另有原生 owner、
HTTP/Core 适配器、持久 epoch 与会话发布器。Android 对接现有加密存储与 ServiceController。
这些接线经过合成离线验证，尚无平台完整构建、真实安全存储或后台设备验收。iOS 缺少已签名
共享 Keychain 配置时返回 signing_capability_required；Flutter 保留既有续租路径。
Main 保持 `session.dart` / `zolnit_vault.dart` 的登录持久化、验证恢复和注销代际权威；普通关闭
不删除登录。macOS/Windows 关窗口继续复用当前用户进程，真正退出沿用现有 CoreProcessLease
停止路径，不新建守护服务、不将用户凭据交给 LocalSystem Helper。

iOS 已加入受配置控制的接入点：`PacketTunnelProvider.startTunnel` 在 Core/TUN 成功后启动 NE 续租 owner，
`stopTunnel` 取消并排空 owner 后停止 TUN；`handleAppMessage` 接收不含凭据的代际/停止控制。
`PacketTunnelSharedStateStore` 只承担非秘密 owner/epoch 状态，不承载 Bearer。
`CoreMessageRouter` / `ServiceChannel` 处理 owner 交接；VPN 活跃时 Main 的
`ZolnitRouting._leaseTimers/refreshBundle` 停止独立续租，读取 NE 状态。NE 使用独立可取消的
URLSession 请求、ephemeral/no-cache/拒绝重定向策略，复用既有 Bearer 和实际 Core-Version，
仅请求现有 bundle GET；60 秒基准调度，401 与403、429、传输失败分别处理，TTL 始终由服务端
issued/expires 决定且不超过300秒，不用旧磁盘快照或本地延期替代网络续租。

Core 不读账号 Keychain、Bearer 或登录 API。将现有 CLI 的纯 bundle/hash/binding 校验提炼为
共享 Go 包供原生桥接与 CLI 复用；验证后的 bundle 经 `installClientBundle` 安装，原 Core 租约定时器
继续作为到期保护。安装与注销必须由单一 NE 队列串行：网络成功只暂存，收到匹配 Core 安装
ACK 才更新有效租约。Main/NE/Core owner 实例、session epoch、attempt sequence 不符则丢弃。

注销顺序：Main 先发布递增 epoch 屏障并停止旧代际入队，再取消 URLSessionTask，排空或围栏
已提交的 Core 安装，撤销自动租约/关联连接，然后按旧 epoch 删除授权并清理旧 bundle。
仅取消 HTTP 不足以撤销已在执行的 Core 安装；若不能确认排空/撤销，保持关闭并阻止新 owner
接管，不能让迟到安装 ACK 恢复权限。登录/恢复、owner 交接、续租安装和注销使用同一串行
协调契约；新登录不能被旧代际删除操作覆盖。状态机 `generation` 仅为 owner 内存围栏，
不替代 Main 持久化的 `SessionEpoch`；适配器完成对应 Main 屏障后才 ACK publication intent。
`OwnerInstance` 是本地不复用的 opaque handle，安装适配器另须保留并验证完整 Core instance guard。
普通 owner stop 的 clear-old-bundle 仅清理易失续租/暂存状态，保留登录和既有显式手动缓存；
账号退出的持久私有数据清理由现有账号生命周期按旧 epoch 执行，不删除新登录的记录。

待明确批准的边界是实际共享 Keychain/迁移与签名，不是新增后端授权：Main/NE 需要专用共享
Keychain access group，建议命名 `$(AppIdentifierPrefix)$(APP_BUNDLE_ID).renewal`：未来仅在
`ios/Runner/Runner.entitlements` 和 `ios/NECore/NECore.entitlements` 声明；Widget/observer 不加入。
Main 保留现有私有组用于受控迁移，NE 不获得 Main 私有组或 wildcard。运行时从受签名配置解析
access group，不能把 Team ID 当作 AppIdentifierPrefix 硬编码；Dart vault 与原生 reader 使用相同
service/account 名称及旧 epoch 定位。不得把 Bearer 放进共用诊断 App Group 文件。
现有 iOS item 默认 when-unlocked。锁屏续租建议评估 after-first-unlock-this-device-only，
不启用同步/生物识别交互，首次解锁前无可用授权；这是保护等级与迁移决策，尚未执行。
迁移需先验证共享记录和代际可读，再切换权威并清理旧私有项；注销覆盖新旧旧代际项。
Windows 现有 vault 的 AES key 由当前用户 Credential Manager 保护；SYSTEM 服务没有相同
凭据语境。macOS 现有 legacy login Keychain 也不能假设新签名进程自动继承访问权。
本地验证未创建真实凭据、Keychain item、外部 App ID/App Group、签名或后台服务。
iOS plist 仅声明构建变量；尚未配置共享 entitlements，也未执行旧 Keychain 迁移。

### 回国线路展示映射

可选 `routing.ui_groups` 中的 `return_route` 只映射现有 Core Selector 和其真实成员；
`direct`、`hk_lite`、`hk_optimized` 为角色 ID，直达不等于 `DIRECT`。映射缺失、重复、成员
不存在或引用 `DIRECT`、`REJECT`、自有 service selector 时整组隐藏。八语言标签共享到
Flutter、Compose、SwiftUI 和 WinUI；原生命令仅提交角色 ID，由当前账号/配置再次校验后
通过既有代理选择队列调用 Core。回国选择不改写连接文档、规则或 AI/手动/DIRECT 策略。

### AI / 产品 HTTP 健康判据与正式开放缺口

原 URLTest 传入空 expectedStatus，任意 HTTP 响应（包括 403）都可能产生正 RTT。自动调度现改用
结构化 Core probe、GET、禁止重定向、每请求 5 秒、正文最多 4096 字节；不再将 URLTest 的延迟
直接当成功。各服务仍使用下列固定产品源站，不以 country.is 或 gstatic 替换 AI/影音探测：

| provider | 固定 URL | 可用的公开 HTTP 样本 |
| --- | --- | --- |
| chatgpt | https://chatgpt.com/ | 200 且未识别为挑战/错误页 |
| openai_api | https://api.openai.com/v1/models | 200，或文档定义认证入口的结构化匿名 401；仅传输可达 |
| claude | https://claude.ai/ | 200 且未识别为挑战/错误页，仅 Web 入口 |
| gemini_api | https://generativelanguage.googleapis.com/v1beta/models | 200，或结构化 401 UNAUTHENTICATED；权限型 403 为资格未知 |
| gemini_web | https://gemini.google.com/ | 200 且未识别为挑战/错误页 |
| netflix | https://www.netflix.com/ | 200 仅为公开 HTTP 可达，不证明内容目录/解锁 |
| operator | https://www.gstatic.com/generate_204 | 严格 204；不能给任何产品授予资格 |

无密钥探测不把所有非 2xx 当网络故障：OpenAI 的结构化匿名认证 401、Gemini 的结构化
401 UNAUTHENTICATED 可提供传输 RTT，资格仍未知；网页 401、API 权限型 JSON 403、3xx、404、
429、5xx 均为中性/资格未知，不增加节点失败计数或冷却。403 的非 API 权限响应及常见 200
挑战页标记为当前匿名探测受阻，不猜测是地区、账户还是边缘原因；不作为成功，也不直接增加
节点失败、冷却或撤销产品资格。仅明确传输错误产生当前客户端路径失败样本，不传播机器硬故障。
provider 观测按配置代际、实际节点、provider 和策略语义独立保存；未知、预算耗尽、冷却或取消
不创造失败样本，也不续期旧成功。所有声明的 provider 都有 90 秒内实际有效样本时才产生聚合
传输分数，有效期取其中最早到期时间，不被其他 provider 的新成功延长。样本过期只使健康分数
未知，仍合格的现有选择保持粘性，直到 bundle 租约到期、资格撤销或明确传输失败。未知健康
不能选出新候选。类别 membership、国家、verified、bundle 更新均不能生成
provider 成功或产品解锁资格。
ZolNit 登录/套餐不会因 AI 源站的 401/403 发生变更。

正式自动开放仍有实质缺口：公开模型列表的匿名响应不是产品就绪/资格接口，401/404 不能证明付费 API 可用；
公共 200 和有限挑战检测也无法证明账户权限、额度、模型访问或实际产品操作。必须与根聊天
提供的服务端资格来源和产品级最终联调结合，明确可维护的有效探测语义；当前客户端不请求或
持有用户 AI API 密钥，不依据 HTTP 200、GeoIP 或 RTT 自动补齐资格，routing.nodes 的开放仍由后端控制。
[OpenAI 错误语义](https://developers.openai.com/api/docs/guides/error-codes)、
[Claude API 错误语义](https://platform.claude.com/docs/en/api/errors)、
[Gemini API 错误语义](https://ai.google.dev/gemini-api/docs/api-errors) 进一步表明认证/权限/限额错误不同于节点断网。

根聊天报告：519 首轮 20 入口中 18 成功、2 连接失败；1c36 的 IPv6 初始化修正后，11 的 IPv6
HY2 成功。同一 peer 的最小 2×2 对照中，10/IPv4 与 9/IPv6 的 gstatic HEAD、country GET 四项
均 exit 0、国家观测均 TW，节点与驱动参数未改。20 个入口累计均已有成功观测；1c36 首次 9 的
失败仍保留为原因未明的瞬时失败，不能断言 VLESS IPv6 完全不可用，也不能据此宣称长期稳定。
后续同一 Linux peer 等待两次 35 秒权限传播后，对 9/11 各做三轮 Country 观测、轮间 30 秒，
6/6 成功且均 TW，同窗口 egress_tag 一致；完整请求用时约 1057–1273 ms，不是链路 ping。
根聊天报告清理字段全部 true、剩余进程 0。未为这条已成功路径修改 TLS 或绕过证书。
短窗口观测不等于丢包率、回国方向或 AI/影音资格证明。
519 旧二进制保持不变；后续同窗口 9/11 短采样由根聊天执行，不在客户端代码验收中重复联网。

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
丢包率没有独立测量时保持未知，不从延迟编造。共享调度器对本客户端进程的智能分流自动 HTTP
探测执行滚动 60 秒 30 次硬预算、总并发 2、同源并发 1；周期、激活、重配、账号代际共享额度
和源站冷却，配置清理不重置它们。标记为 automatic-routing 的请求还由实际 Core HTTP 发送点
执行同样的硬额度/并发/同源429闸门，跨宿主早返回与配置刷新保留；Core 拒绝返回 unknown，
不把 RPC 完成误当作网络结束。普通手动 Probe 未打该标记，保留原行为。派发才计额度，排队最多 30 项；预算/冷却拒绝不等待，保持
unknown。Core 手动测速、Mihomo 自身 health-check 和账户 API 不在这个自动探测预算内，不能
把该值宣传为设备全部网络请求的上限。预算为进程内状态，不跨应用重启持久化。
活跃时轮次最小间隔 30 秒，每服务当前节点加 1 候选；冷启动最多 2 个候选。需求信号为界面
可见或已收到的 Core 累计流量增长；无该信号时 60 秒且不探索已有选择之外的节点，无自动
服务/候选则不探测。信号缺失不是测量到流量为零。持续无有效观测/同源不可用退避最多 300 秒。
默认 30/min 的依据是当前 AI 五 provider、影音一个 provider，两个节点、每分钟两轮需 24 次，
余量容纳启动/变化但硬上限不变。它独立于 bundle API 的 30/min 配额，也不承诺全覆盖 16 类
服务的所有候选；证据不足保持 unknown/REJECT。
只有同配置/用户意图、同命名出口、完整 URL 和同 provider/地区策略语义共享在途及 30 秒内
结果，缓存保留原 sequence/观测时间。不同节点/语义不借成功，类别仍先检查原 membership。
429 冷却按源站跨节点/语义/重配共享；同源最多 1 个在途。Retry-After 支持秒数和 HTTP-date，
不早于服务端期限、不缩短旧冷却，缺失/畸形按 60/120/240/300 秒回退；取消的旧请求若实际
收到429仍建立冷却。GET 正文最多保留 4096 字节、请求 5 秒、禁止重定向；只额外暴露规范化
Retry-After，不发送 AI 凭据。冷却不是节点惩罚，也不能换节点继续探测同源。
冷却、连续恢复、至少 60 秒驻留和重复改善证据限制抖动。用户显式选择手动组或
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
| 失败确认 | 明确传输失败按失败策略处理；过期/未知样本保留仍合格的现选节点，不续期健康、不选新节点 |
| 冷却退避 | 15、30、60、120、240、300 秒，上限 5 分钟；恢复后重置 |
| 恢复确认 | 冷却结束后连续 2 个成功样本 |
| 调度 | 自动探测 30/滚动分钟、并发 2/同源 1；活跃 30 秒、空闲 60 秒；每服务最多 2 节点；持续无效退避最多 300 秒 |

样本由固定产品 URL 的结构化 Core GET 观测构成，所有所需 provider 都有独立新鲜有效证据
才使用最大延迟；最早 provider 到期撤销候选，无 Core 响应不记节点失败。没有 DNS/TCP/TLS 阶段拆分、带宽、
独立抖动或丢包测量；丢包率保持 null，评分项缺失不等于实测为 0。来源 verified 也不是 URLTest 证据。

hardFailure=true 的立即冷却和同服务 failure_domain 传播只在纯引擎注入测试中覆盖；
当前运行时没有明确机器硬故障分类来源，不能声称已在真实设备采集。HTTP/TLS 可达性不证明账号、
API 授权、产品资格、内容目录或解锁。既有 16 项引擎、9 项元数据、5 项转换、8 项假 Core 接入测试
属于本地逻辑证据；完整包构建、真实 Core 验证、账号与设备验收必须分别记录。

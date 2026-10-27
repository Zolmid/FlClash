// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh_CN';

  static String m0(count, skipped) => "将添加 ${count} 项，跳过 ${skipped} 项已存在";

  static String m1(detail) => "清除数据失败：${detail}";

  static String m2(code) =>
      "Windows 拒绝运行 FlClashCore.exe（错误 ${code}）。智能应用控制、AppLocker 等应用控制策略会拦截未签名程序，请在该策略中放行 FlClash 或关闭策略后重试。";

  static String m3(name) =>
      "应用连续两次未能完成启动。为打断崩溃循环，已取消选中配置 ${name}，并跳过本次自动配置，你可以随时重新选中它。";

  static String m4(url) => "是否要通过 ${url} 创建配置？";

  static String m5(count, label) =>
      "${Intl.plural(count, other: '自定义配置不支持子规则，已丢弃 ${label} 条 SUB-RULE 规则')}";

  static String m6(message) => "内核无法解析该代理：${message}";

  static String m7(proxy, target) =>
      "${proxy} 经 ${target} 拨号，而 ${target} 又会回到 ${proxy}，形成环路";

  static String m8(name) => "名称 ${name} 已被其他代理或策略组使用";

  static String m9(path) => "策略组之间存在循环引用：${path}";

  static String m10(name) => "空组兜底只能是代理，${name} 不存在或是策略组";

  static String m11(name, message) => "${name}不是有效的正则：${message}";

  static String m12(name) => "拨号代理 ${name} 不存在";

  static String m13(names) => "以下代理集不存在：${names}";

  static String m14(names) => "以下代理或策略不存在：${names}";

  static String m15(name) => "${name} 是内置策略名，不能在此使用";

  static String m16(count) => "${count} 项存在问题，应用配置可能失败";

  static String m17(count) => "${count} 天前";

  static String m18(count) => "${count} 天前";

  static String m19(label) => "确定删除选中的${label}吗？";

  static String m20(label) => "确定删除当前${label}吗？";

  static String m21(label) => "${label}详情";

  static String m22(name) => "经 ${name} 拨号会绕回使用它的代理，连接已中止";

  static String m23(label) => "${label}不能为空";

  static String m24(count) => "${count} 个条目";

  static String m25(label) => "${label}当前已存在";

  static String m26(count) => "${count} 项失败";

  static String m27(label, message) => "${label}：${message}";

  static String m28(name) => "${name} 已是最新版本";

  static String m29(name) => "${name} 已更新";

  static String m30(name) => "正在更新 ${name}...";

  static String m31(count) => "${count} 个";

  static String m32(count) => "${count} 超时";

  static String m33(action) => "已被“${action}”使用，保存后将移到这里";

  static String m34(modifiers) => "至少包含 ${modifiers} 中的一个";

  static String m35(count) => "${count} 小时前";

  static String m36(count) => "${count} 小时前";

  static String m37(target) => "${target} 是一个无效的策略";

  static String m38(proxyName) => "${proxyName} 是一个无效的代理";

  static String m39(providerName) => "${providerName} 是一个无效的代理集";

  static String m40(ruleSet) => "${ruleSet} 不是有效的规则集";

  static String m41(subRule) => "${subRule} 是一个无效的SUB_RULE";

  static String m42(count) => "${count} 项";

  static String m43(line, message) => "第 ${line} 行：${message}";

  static String m44(appName) =>
      "1. 打开 系统设置 > 隐私与安全性\n2. 选择 定位服务\n3. 在右侧列表中找到并勾选 ${appName}\n\n完成设置后，返回应用即可正常使用。感谢您的配合。";

  static String m45(label, max) => "${label}最多${max}个字符";

  static String m46(size) => "已释放 ${size}";

  static String m47(count) => "${count} 分钟前";

  static String m48(count) => "${count} 分钟前";

  static String m49(count) => "${count} 个月前";

  static String m50(count) => "${count} 个月前";

  static String m51(code) => "服务器拒绝访问（HTTP ${code}），链接可能已过期或凭据有误";

  static String m52(code) => "服务器拒绝了请求（HTTP ${code}）";

  static String m53(code) => "该地址下没有内容（HTTP ${code}），请确认链接是否正确";

  static String m54(detail) => "网络请求失败：${detail}";

  static String m55(code) => "服务器出现问题（HTTP ${code}），请稍后再试";

  static String m56(label) => "暂无${label}";

  static String m57(label, min, max) => "${label}必须在 ${min} 到 ${max} 之间";

  static String m58(label) => "${label}必须为数字";

  static String m59(label) => "${label} 必须在 1024 到 49151 之间";

  static String m60(port) => "端口 ${port}";

  static String m61(days) => "剩余 ${days} 天";

  static String m62(date, days) => "${date} 到期，剩余 ${days} 天";

  static String m63(time) => "更新于 ${time}";

  static String m64(label, profiles) =>
      "${label} 仍被 ${profiles} 使用，删除后这些配置会异常。确定删除吗？";

  static String m65(count, label) =>
      "${Intl.plural(count, other: '${label} 个代理')}";

  static String m66(name, count) => "${name} 等 ${count} 个代理";

  static String m67(removed) =>
      "以下代理将被删除：${removed}。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？";

  static String m68(removed, added) =>
      "以下代理将被删除：${removed}。以下代理将新增：${added}。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？";

  static String m69(label) =>
      "${label} 仍被当前配置的规则、策略组、拨号代理、DNS 或 NTP 引用，删除后这些引用会失效。确定删除吗？";

  static String m70(count, label) =>
      "${Intl.plural(count, other: '${label} 个策略组')}";

  static String m71(maximum) => "请输入 0 到 ${maximum} 之间的整数。";

  static String m72(count, label) =>
      "${Intl.plural(count, other: '${label} 条规则')}";

  static String m73(appName) => "${appName}（安全模式）";

  static String m74(count) => "${count} 秒";

  static String m75(count) => "${count} 项生效";

  static String m76(count) => "${count} 项异常";

  static String m77(time) => "检测于 ${time}";

  static String m78(count) => "${count} 项设置";

  static String m79(link) => "无法从 ${link} 中读取代理";

  static String m80(label) => "${label}只能是一项";

  static String m81(value) => "峰值 ${value}";

  static String m82(value) => "累计 ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · 怠速 ${idleInterval}";

  static String m84(interval) => "${interval} · 怠速已禁用";

  static String m85(label) => "${label}必须为URL";

  static String m86(count) => "${count} 年前";

  static String m87(count) => "${count} 年前";

  static String m88(amount, cycle) => "每${cycle} ${amount}，一次支付";

  static String m89(date) => "${date} 到期，升级或续费都可以在这里完成。";

  static String m90(plan) => "当前套餐 · ${plan}";

  static String m91(days) => "剩余 ${days} 天";

  static String m92(date) => "${date} 到期";

  static String m93(count) => "支持 ${count} 台设备同时在线";

  static String m94(mbps) => "速率上限 ${mbps} Mbps";

  static String m95(gb) => "每月 ${gb} GB 高速流量";

  static String m96(name) => "你好，${name}。";

  static String m97(rate) => "${rate}× 计量";

  static String m98(count) => "线路：${count}";

  static String m99(count) => "/ ${count} 台";

  static String m100(days) => "${days} 天后重置";

  static String m101(node) => "当前线路：${node}";

  static String m102(percent) => "省 ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "accessControl": MessageLookupByLibrary.simpleMessage("访问控制"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "只允许选中应用进入VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "访问控制决定哪些应用使用代理。",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "应用访问控制已关闭",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "选中应用将会被排除在VPN之外",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("访问控制设置"),
    "accessDenied": MessageLookupByLibrary.simpleMessage("访问被拒绝"),
    "account": MessageLookupByLibrary.simpleMessage("账号"),
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("测试全部延迟"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("直连模式"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("全局模式"),
    "actionMode": MessageLookupByLibrary.simpleMessage("切换模式"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("规则模式"),
    "actionStart": MessageLookupByLibrary.simpleMessage("启动/停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("更新全部配置"),
    "actionView": MessageLookupByLibrary.simpleMessage("显示/隐藏"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("添加代理"),
    "addFilters": MessageLookupByLibrary.simpleMessage("添加筛选"),
    "addNodes": MessageLookupByLibrary.simpleMessage("添加节点"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("添加覆写项"),
    "addProfile": MessageLookupByLibrary.simpleMessage("添加配置"),
    "addProxies": MessageLookupByLibrary.simpleMessage("添加代理"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("添加策略组"),
    "addRule": MessageLookupByLibrary.simpleMessage("添加规则"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("添加设置项"),
    "addSsid": MessageLookupByLibrary.simpleMessage("添加SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("附加规则"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("附加参数"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("名称前缀"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("名称后缀"),
    "address": MessageLookupByLibrary.simpleMessage("地址"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAV服务器地址"),
    "addressTip": MessageLookupByLibrary.simpleMessage("请输入有效的WebDAV地址"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("进阶配置"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "进阶配置包含网络、DNS、附加规则与脚本。",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("配置已加密"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("Age Key 生成"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "已生成 X25519 密钥对，请妥善保存",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 私钥"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "请先输入正确的 Age 私钥",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 公钥"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 私钥"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入有效的 Age 私钥 (必须以 AGE-SECRET-KEY- 开头)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage("Age 私钥 (可选)"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "该配置已用 age 加密，需要 age 私钥才能解密",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allData": MessageLookupByLibrary.simpleMessage("全部数据"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage("全部被引用的代理"),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "全部被引用的代理集",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("允许应用绕过VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage("开启后部分应用可绕过 VPN"),
    "allowLan": MessageLookupByLibrary.simpleMessage("局域网代理"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("允许局域网访问"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage("允许从局域网访问外部控制器"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("允许通过局域网访问代理"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("允许的 IP"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("始终连接"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage("在任何网络环境下保持 VPN 连接"),
    "answers": MessageLookupByLibrary.simpleMessage("应答"),
    "app": MessageLookupByLibrary.simpleMessage("应用"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("应用访问控制"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("应用图标设计"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("暂无本地代理"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("追加系统DNS"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage("强制为配置附加系统 DNS"),
    "application": MessageLookupByLibrary.simpleMessage("应用程序"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("修改应用程序相关设置"),
    "ascending": MessageLookupByLibrary.simpleMessage("升序"),
    "authentication": MessageLookupByLibrary.simpleMessage("认证"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "认证开启后，使用本地代理端口需要账号密码。",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "认证启用时，系统代理不生效。",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("授权"),
    "authorized": MessageLookupByLibrary.simpleMessage("已授权"),
    "auto": MessageLookupByLibrary.simpleMessage("自动"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自动检查更新"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage("应用启动时自动检查更新"),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("自动关闭连接"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "自动关闭连接会在切换代理后断开已有连接。",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("自动包含"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自启动"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("跟随系统自启动"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自动运行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("自动运行会在打开应用时启动代理。"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("自动设置系统DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自动更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔"),
    "back": MessageLookupByLibrary.simpleMessage("返回"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage("返回时回首页"),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage("退出前先返回仪表盘"),
    "backup": MessageLookupByLibrary.simpleMessage("备份"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("备份与恢复"),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "本地日期（YYYY-MM-DD）",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "该备份来自更高版本的应用，请先更新应用再恢复",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage("当前平台"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("备份成功"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "本地时间（HHmmss）",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage("应用版本号"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基础配置"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("全局修改基础配置"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基础信息"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基础策略"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("批量添加"),
    "batchImport": MessageLookupByLibrary.simpleMessage("批量导入"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage("每行一个链接"),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage("每行一项，也可用逗号分隔"),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage("每行一条，键和值之间用空格分隔"),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage("每行一个URL"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "忽略电池优化可保证应用在后台运行。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("绑定"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("黑名单模式"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("阻止连接"),
    "brightness": MessageLookupByLibrary.simpleMessage("亮度"),
    "browse": MessageLookupByLibrary.simpleMessage("浏览"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("排除域名"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "排除域名仅在系统代理启用时生效。",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage("绕过私有路由地址"),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "开启绕过私有路由地址后，局域网、回环和组播地址不经过虚拟网卡。",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("缓存"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("缓存算法"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("缓存已损坏，是否清空？"),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("缓存大小"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "请在系统设置中允许访问相机以扫描二维码，或从相册选择二维码图片。",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage("需要相机权限"),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("相机不可用"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("取消全选"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("无法保存"),
    "captureDns": MessageLookupByLibrary.simpleMessage("接管系统 DNS"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "将所有系统 DNS 查询导入内部 DNS 模块",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "切换代理失败，已恢复上一次的选择",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("重大变更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新功能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("问题修复"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("性能优化"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("已回滚"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("校验 TLS 证书"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "关闭证书校验后，订阅和备份可能遭中间人攻击。",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("检查更新"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("当前应用已经是最新版了"),
    "cipher": MessageLookupByLibrary.simpleMessage("加密方式"),
    "clear": MessageLookupByLibrary.simpleMessage("清除"),
    "clearData": MessageLookupByLibrary.simpleMessage("清除数据"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "将删除所有配置、设置和本地数据，随后关闭应用。重新打开即可从头开始。",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("清除搜索"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage("客户端指纹"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("导出剪贴板"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("剪贴板导入"),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "无法复制到剪贴板，所选内容可能过大",
    ),
    "close": MessageLookupByLibrary.simpleMessage("关闭"),
    "closeAll": MessageLookupByLibrary.simpleMessage("断开全部"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("关闭连接"),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "是否关闭使用原代理的连接？",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("折叠"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage("折叠代理链"),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "代理链超过三个节点时隐藏中间节点",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "收起快捷设置面板",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "点击快捷设置开关后收起面板",
    ),
    "color": MessageLookupByLibrary.simpleMessage("颜色"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("配色风格"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compact": MessageLookupByLibrary.simpleMessage("紧凑"),
    "compatible": MessageLookupByLibrary.simpleMessage("兼容模式"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage("检测到配置中存在数据"),
    "confirm": MessageLookupByLibrary.simpleMessage("确定"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage("确定要清除所有数据？"),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "确定要清除所选数据吗？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "确定要删除当前策略组吗？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage("确定要退出当前窗口吗？"),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage("确定要强制崩溃核心？"),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage("确定后将会覆盖已有数据"),
    "congestionControl": MessageLookupByLibrary.simpleMessage("拥塞控制"),
    "congestionController": MessageLookupByLibrary.simpleMessage("TCP 拥塞控制"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 拥塞控制仅在 mips 栈生效。",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("已连接"),
    "connecting": MessageLookupByLibrary.simpleMessage("连接中…"),
    "connection": MessageLookupByLibrary.simpleMessage("连接"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("连接数"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("连接统计"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "实时连接、最近请求、DNS查询",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("连接"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("查看当前连接数据"),
    "connectivity": MessageLookupByLibrary.simpleMessage("连通性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容不能为空"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage("控制全局附加规则"),
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("复制环境变量"),
    "copyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("复制成功"),
    "core": MessageLookupByLibrary.simpleMessage("内核"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows 智能应用控制拦截了未签名的 FlClashCore.exe。请打开 Windows 安全中心 → 应用和浏览器控制 → 智能应用控制设置，选择「关闭」后重新启动 FlClash。智能应用控制关闭后无法再开启，除非重装 Windows。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("核心状态"),
    "country": MessageLookupByLibrary.simpleMessage("区域"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("检测到崩溃"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("崩溃测试"),
    "create": MessageLookupByLibrary.simpleMessage("创建"),
    "createProfile": MessageLookupByLibrary.simpleMessage("创建配置"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("创建时间"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage("含启动键，不可移除"),
    "custom": MessageLookupByLibrary.simpleMessage("自定义"),
    "customColor": MessageLookupByLibrary.simpleMessage("自定义颜色"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("名称为空"),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "未选择任何代理或代理集，内核会拒绝该策略组",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("自定义"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "基于应用代理和其他配置组建策略组与规则",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage("自定义配置资源"),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "自定义配置资源包含代理、规则集、筛选与图标集。",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("剪切"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("仪表盘"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("可添加"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage("检测到数据有更改，是否保存"),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "保存更改失败，已回滚",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("目录"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("默认域名服务器"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "用于解析 DNS 服务器",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage("默认选中"),
    "defaultText": MessageLookupByLibrary.simpleMessage("默认"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "配置必须是包含 name 和 type 的 YAML 映射",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("延迟"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("失败"),
    "delayTest": MessageLookupByLibrary.simpleMessage("延迟测试"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "基于ClashMeta的多平台代理客户端，简单易用，开源无广告。",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("降序"),
    "destination": MessageLookupByLibrary.simpleMessage("目标地址"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("目标地理定位"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("目标IP ASN"),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage("依赖第三方api，仅供参考"),
    "developerMode": MessageLookupByLibrary.simpleMessage("开发者模式"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage("开发者模式已启用。"),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("拨号代理"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "拨号代理为连接 NTP 服务器使用的出站。",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("直连"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage("禁用ICMP转发"),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "禁用 ICMP 转发后由虚拟网卡直接应答 ping，ping 将不再显示真实延迟。",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage("禁用 TCP 保持活动"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("禁用UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("已关闭"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("是否放弃更改？"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免责声明"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "一旦你安装、复制或使用本软件，即视为你已阅读并同意本声明的全部内容。如你不同意本声明的任何条款，请立即停止使用并卸载本软件。",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("接受声明"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "我已阅读并理解此声明",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "为确认你已知悉，请阅读以下声明并勾选下方选项：",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("确认声明"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "开发者有权随版本更新修改本声明，修改后的内容随新版本发布即生效。你在更新后继续使用本软件，即视为接受修改后的声明。",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("声明变更"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "在使用 FlClash（以下简称“本软件”）前，请仔细阅读并充分理解本声明的全部内容。点击“同意”即表示你已阅读、理解并接受以下全部条款；如不同意，请点击“退出”并停止使用本软件。",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "在适用法律允许的最大范围内，开发者及所有贡献者均不对因使用或无法使用本软件而产生的任何直接、间接、偶然、特殊、惩罚性或后果性损害承担责任，包括但不限于数据丢失、设备损坏、网络异常、业务中断、利润损失或因此引起的任何法律纠纷，即使已被告知发生此类损害的可能性。",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("责任限制"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "本软件以 GPL-3.0 协议开源。你可以在遵守该协议的前提下自由使用、修改和分发本软件，但须同样以 GPL-3.0 协议开源并保留原作者的版权声明。\n\n本软件包含的第三方组件（包括 Clash.Meta 内核）分别遵循其各自的开源协议。基于本软件修改或分发的版本所产生的任何问题，与原作者无关。",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage("开源协议"),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "本软件自身不提供任何代理服务器、节点、订阅、机场或网络接入服务，也不与任何此类服务的提供者存在合作、代理或担保关系。",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "本软件不会收集或上传你的订阅地址、节点信息、配置内容、访问的网站、连接记录、流量内容和日志，这些数据仅保存在你的设备本地，开发者无法获取。\n\n本软件只会在你使用相应功能时访问外部网络，例如更新订阅时访问你提供的订阅地址、检查更新时访问 GitHub。\n\n本软件在所有平台上均未集成任何数据统计或崩溃上报服务。",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage("数据收集与隐私"),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "你应自行确认使用本软件在你所在国家或地区是合法的，并对使用本软件的全部行为及其后果独立承担法律责任。\n\n你导入的订阅、节点与配置由你自行选择和判断，其来源是否合法、内容是否安全、服务是否稳定，均由你与相关提供者自行负责。",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "用户责任",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage("在此输入上述声明"),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "与声明内容不一致",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "为确认你已知悉，请在下方输入框中完整复述以下声明：",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("复述声明"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "本软件是基于 Clash.Meta（mihomo）内核的开源网络代理客户端，仅提供配置管理、规则分流与流量转发等本地工具功能。",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage("软件性质"),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "订阅链接、配置文件、规则集、脚本、外部资源及外部链接均由第三方提供，开发者无法也不会对其合法性、准确性、安全性和可用性进行审查或担保。\n\n因使用第三方内容导致的数据泄露、财产损失、账号封禁或其他任何损失，由你与第三方自行解决，开发者不承担任何责任。",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage("第三方内容"),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "本软件仅供学习交流、技术研究等非商业用途。严禁将本软件用于任何商业目的，包括但不限于付费分发、捆绑销售、作为商业服务的组成部分或以本软件名义开展经营活动；任何商业行为均与本软件及其开发者无关。\n\n严禁将本软件用于违反你所在国家或地区法律法规的活动，包括但不限于绕过依法设置的网络访问限制、传播违法信息、实施网络攻击或侵犯他人合法权益。",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("使用限制"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "本软件按“现状”和“可用”的原则提供，不附带任何明示或默示的担保，包括但不限于适销性、特定用途适用性、不侵权以及持续可用、无错误、无安全漏洞的担保。\n\n开发者不保证本软件能满足你的需求，也不保证本软件的运行不会中断或不会出现错误。",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("无担保声明"),
    "disconnected": MessageLookupByLibrary.simpleMessage("已断开"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("更新 DNS 相关设置"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS 劫持"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "未添加时劫持所有发往 53 端口的 DNS 请求（any:53）。",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS劫持"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage("关闭后，AAAA 查询将返回空结果"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS模式"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "添加的项会覆写所有 URL 和文件配置的 DNS，未添加的项沿用配置自身的设置。自定义配置的 DNS 在其内容中设置。",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS查询"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage("核心 DNS 解析记录"),
    "docked": MessageLookupByLibrary.simpleMessage("固定"),
    "domain": MessageLookupByLibrary.simpleMessage("域名"),
    "done": MessageLookupByLibrary.simpleMessage("完成"),
    "download": MessageLookupByLibrary.simpleMessage("下载"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("下行带宽"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("下载速度"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("下载流量"),
    "duration": MessageLookupByLibrary.simpleMessage("时长"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage("连接延迟"),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS 域"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage("功能标志"),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("实例 ID"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "路径延迟（延迟优先）",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("监听地址"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage("本地端点"),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("丢包率"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage("最低直连延迟"),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage("下一跳节点 ID"),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage("路径延迟（跳数优先）"),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("节点 ID"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage("传输协议"),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage("公共服务器"),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage("远端端点"),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("路由代价"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage("接收包数"),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage("发送包数"),
    "edit": MessageLookupByLibrary.simpleMessage("编辑"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("编辑仪表盘"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("编辑全局规则"),
    "editProxy": MessageLookupByLibrary.simpleMessage("编辑代理"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("编辑策略组"),
    "editRule": MessageLookupByLibrary.simpleMessage("编辑规则"),
    "editSsid": MessageLookupByLibrary.simpleMessage("编辑SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("编辑器不可用"),
    "elapsed": MessageLookupByLibrary.simpleMessage("耗时"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("空组兜底"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("英语"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage("启用外部控制器"),
    "enabled": MessageLookupByLibrary.simpleMessage("已开启"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT 增强"),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "优化 UDP 和 P2P 应用的连接体验",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("端点"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("强制路由"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "即使存在更具体的路由也确保流量经过隧道",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("个条目"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("错误"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("错误详情"),
    "es": MessageLookupByLibrary.simpleMessage("西班牙语"),
    "exclude": MessageLookupByLibrary.simpleMessage("从最近任务中隐藏"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("排除 APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "允许 Apple 推送通知流量绕过隧道",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage("排除蜂窝服务"),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "允许 Wi-Fi 通话等蜂窝服务流量绕过隧道",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage("应用在后台时,从最近任务中隐藏应用"),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "排除设备间通信",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "允许 AirDrop、AirPlay 等设备间通信流量绕过隧道",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("排除目标端口"),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "发往这些目标端口的流量不经过虚拟网卡。",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("排除筛选"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("排除网卡"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "从这些网卡（如 docker0）进入的流量不经过虚拟网卡。",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage("排除本地网络"),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "允许直接访问本地网络上的设备",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("排除节点过滤器"),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("排除源端口"),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "源端口为这些端口的流量不经过虚拟网卡。",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("排除SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "连接到被排除 SSID 的 Wi-Fi 时，将会自动切换应用运行状态。",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("排除类型"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("排除用户 ID"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "这些用户 ID 的进程产生的流量不经过虚拟网卡。",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("退出"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("退出全屏"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("出口节点"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("预期状态"),
    "expireTime": MessageLookupByLibrary.simpleMessage("到期时间"),
    "exportFile": MessageLookupByLibrary.simpleMessage("导出文件"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("导出日志"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("导出成功"),
    "extend": MessageLookupByLibrary.simpleMessage("扩展"),
    "extendMode": MessageLookupByLibrary.simpleMessage("扩展模式"),
    "extendScript": MessageLookupByLibrary.simpleMessage("扩展脚本"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部控制器"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "外部控制器开启后，可通过 9090 端口控制内核。",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage("外部控制器密钥"),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部获取"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部链接"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("超大"),
    "fade": MessageLookupByLibrary.simpleMessage("淡入"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IP过滤"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Fake IP 模式下，匹配的域名返回真实 IP 而非 Fake IP",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IP过滤模式"),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Fake-IP 过滤模式中，blacklist 排除匹配项，whitelist 仅用于匹配项，rule 按规则匹配。",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP范围"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP范围（IPv6）"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("备用"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("一般情况下使用境外 DNS"),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "匹配的域名直接使用 fallback，不查询 nameserver",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback过滤"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "按 GeoIP 代码检查 nameserver 结果；不属于该地区时采用 fallback",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "匹配这些 GeoSite 分类的域名直接使用 fallback",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver 结果命中这些 CIDR 前缀时改用 fallback 结果",
    ),
    "features": MessageLookupByLibrary.simpleMessage("特性"),
    "file": MessageLookupByLibrary.simpleMessage("文件"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("直接上传配置文件"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage("文件有修改，是否保存修改"),
    "fileName": MessageLookupByLibrary.simpleMessage("文件名"),
    "filter": MessageLookupByLibrary.simpleMessage("筛选"),
    "filters": MessageLookupByLibrary.simpleMessage("筛选"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("查找进程"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage("开启后会有一定性能损耗"),
    "floating": MessageLookupByLibrary.simpleMessage("悬浮"),
    "followProfile": MessageLookupByLibrary.simpleMessage("跟随配置"),
    "followSystem": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("字体"),
    "fontSize": MessageLookupByLibrary.simpleMessage("大小"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("强制DNS映射"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "强制 DNS 映射对通过 DNS 映射得到域名的连接也进行嗅探。",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("强制嗅探域名"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "强制嗅探域名中的域名同样会被嗅探，其余已有域名的连接不嗅探。",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage("您确定要强制重启核心吗？"),
    "fr": MessageLookupByLibrary.simpleMessage("法语"),
    "general": MessageLookupByLibrary.simpleMessage("常规"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("应用与核心的通用设置"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "从 Age 私钥生成",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("生成"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("自动更新"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自动更新间隔必须大于0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geo 选项"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低内存模式"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "开启将使用 Geo 低内存加载器",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP 代码"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage("高性能 Geo 匹配器"),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "开启将使用最小完美哈希算法进行匹配",
    ),
    "global": MessageLookupByLibrary.simpleMessage("全局"),
    "go": MessageLookupByLibrary.simpleMessage("前往"),
    "goDownload": MessageLookupByLibrary.simpleMessage("前往下载"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage("前往配置附加规则"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("前往配置脚本"),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("协程数"),
    "grid": MessageLookupByLibrary.simpleMessage("网格"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("个"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("是否缓存修改"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("按入站用户哈希"),
    "header": MessageLookupByLibrary.simpleMessage("标题"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("健康检查"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper 服务不可用，无法启用 TUN 模式，请重新安装 FlClash。",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("十六进制"),
    "hide": MessageLookupByLibrary.simpleMessage("隐藏"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("从列表中隐藏"),
    "hideIp": MessageLookupByLibrary.simpleMessage("隐藏 IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("隐藏密码"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage("隐藏超时代理"),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "不显示上次延迟测试超时的代理",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("隐藏超时"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage("高优先级自启动"),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "使用 Windows 计划任务更早启动",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("跳跃间隔"),
    "host": MessageLookupByLibrary.simpleMessage("主机"),
    "hostname": MessageLookupByLibrary.simpleMessage("主机名"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("追加 Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("快捷键冲突"),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "全局快捷键在窗口隐藏时依然生效，点击操作即可录制组合键。",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("快捷键管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage("使用键盘控制应用程序"),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("未设置"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "未能注册，可能已被其他应用占用",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("小时"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("色相"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP 转发"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "开启后支持 ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("图标"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("图标记录"),
    "iconSets": MessageLookupByLibrary.simpleMessage("图标集"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "暂无图标集，可在「自定义配置资源 → 图标集」中添加",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("图标来源"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("图标样式"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("色块"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("隐藏"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("纯图标"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("图标链接"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage("忽略电池优化"),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage("忽略证书验证"),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "允许使用无效证书的 HTTPS 连接，这会降低安全性",
    ),
    "import": MessageLookupByLibrary.simpleMessage("导入"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage("此文件不是可导入的配置"),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "导入会替换此配置现有的策略组、规则和设置",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("通过文件导入"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("从链接导入"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("从 URL 导入"),
    "importUrl": MessageLookupByLibrary.simpleMessage("通过URL导入"),
    "inbound": MessageLookupByLibrary.simpleMessage("入站"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage("包含所有网络"),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "将所有网络流量路由到隧道，包括本地和蜂窝服务",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("包含所有代理"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "引入不包含策略组的所有代理，可在下方额外添加策略组",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage("包含所有代理集"),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "开启后将覆盖引入的代理集",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage("包含网卡"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "只有从包含网卡进入的流量经过虚拟网卡，设置后排除网卡不再生效。",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("包含用户 ID"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "只有这些用户 ID 的进程产生的流量经过虚拟网卡。",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("长期有效"),
    "init": MessageLookupByLibrary.simpleMessage("初始化"),
    "initFailed": MessageLookupByLibrary.simpleMessage("启动失败"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash 启动时出错，无法继续运行。可以复制错误详情用于反馈；如果问题反复出现，清除数据后通常可以重新启动。",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("初始化"),
    "initiator": MessageLookupByLibrary.simpleMessage("发起方"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("发起"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("请输入正确的快捷键"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage("输入策略组名称"),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("输入规则内容"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "读取应用列表权限已被拒绝，无法获取已安装的应用。请前往系统设置手动开启。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "当前系统在授权前不会提供已安装的应用列表，授权后即可配置分应用代理。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要读取应用列表权限",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("已安装字体"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("智能选择"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("网卡名称"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "网卡名称为出站连接使用的网卡。",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage("出站网卡"),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("清空"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("自定义"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("跟随配置"),
    "internet": MessageLookupByLibrary.simpleMessage("互联网"),
    "interval": MessageLookupByLibrary.simpleMessage("间隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("内网 IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("无效备份文件"),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "请输入有效文件名，不含路径分隔符或特殊字符，且不超过 255 字节。",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "请输入 CIDR 格式的 IP 段，如 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "请输入有效目录，不含 . 或 .. 路径段、反斜杠或特殊字符。",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP 标记不能超过 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage("请输入域名或 IP 地址"),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("不是有效的图标集"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage("不是有效的订阅链接或代理分享链接"),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "请输入地址和端口，如 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "仅支持 tcp 或 udp",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "请输入端口或范围，如 443 或 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "该二维码不包含配置文件链接",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "请输入数字或范围，如 80 或 8000-9000，多个用 / 分隔",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP 地址"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("滥用记录"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("代理"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("命中标记"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("组织"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage("类型查询失败"),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("优"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("等级"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("重新查询"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("风险"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("质量"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("采用来源"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("各来源"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage("出站 IP 不一致"),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("无法判定类型"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("限流"),
    "ipType": MessageLookupByLibrary.simpleMessage("类型"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("商业"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("机房"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("移动网络"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("住宅"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("类型未知"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP 版本"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/掩码"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("开启 IPv6 后才会接收 IPv6 流量。"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "开启 IPv6 后，VPN 允许 IPv6 入站。",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6超时（毫秒）"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("日语"),
    "justNow": MessageLookupByLibrary.simpleMessage("刚刚"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP 保持活动空闲时间"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage("TCP保持活动间隔"),
    "key": MessageLookupByLibrary.simpleMessage("键"),
    "ko": MessageLookupByLibrary.simpleMessage("韩语"),
    "label": MessageLookupByLibrary.simpleMessage("标签"),
    "language": MessageLookupByLibrary.simpleMessage("语言"),
    "large": MessageLookupByLibrary.simpleMessage("大"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("上次更新"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("启动未完成"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "应用上次在启动过程中意外退出。已跳过本次自动配置，你可以手动启动重试。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("布局"),
    "level": MessageLookupByLibrary.simpleMessage("等级"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("行距"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("自动换行"),
    "link": MessageLookupByLibrary.simpleMessage("链接"),
    "linkDesc": MessageLookupByLibrary.simpleMessage("通过订阅链接或代理分享链接获取配置文件"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("液态玻璃"),
    "list": MessageLookupByLibrary.simpleMessage("列表"),
    "listen": MessageLookupByLibrary.simpleMessage("监听"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("监听路由标记"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "监听路由标记仅在 Linux 生效。",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("监听端口"),
    "liveConnections": MessageLookupByLibrary.simpleMessage("实时连接"),
    "loading": MessageLookupByLibrary.simpleMessage("加载中…"),
    "local": MessageLookupByLibrary.simpleMessage("本地"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("备份数据到本地"),
    "localImage": MessageLookupByLibrary.simpleMessage("本地图片"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "本地网络权限被拒绝：已改用 gvisor 栈，局域网无法访问。",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("本地代理"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置权限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置权限已被拒绝，无法获取当前 Wi-Fi 名称。请前往系统设置手动开启位置权限。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "根据系统要求，获取Wi-Fi名称需要您授予位置权限。Android 上请选择“始终允许”，否则应用在后台时无法获取 Wi-Fi 名称。",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要位置权限",
    ),
    "log": MessageLookupByLibrary.simpleMessage("日志"),
    "logLevel": MessageLookupByLibrary.simpleMessage("日志等级"),
    "logcat": MessageLookupByLibrary.simpleMessage("日志捕获"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("关闭日志捕获会隐藏日志入口。"),
    "logs": MessageLookupByLibrary.simpleMessage("日志"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("日志与诊断"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("日志捕获记录"),
    "logsTest": MessageLookupByLibrary.simpleMessage("日志测试"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP 回环解锁"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("用于 UWP 回环解锁"),
    "loose": MessageLookupByLibrary.simpleMessage("宽松"),
    "manual": MessageLookupByLibrary.simpleMessage("手动"),
    "matchCase": MessageLookupByLibrary.simpleMessage("区分大小写"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("匹配来源IP"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "目标为 MATCH-TARGET 的规则路由到这里，默认取本配置末尾 MATCH 规则的目标。",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("匹配目标"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失败次数"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("应用内存"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("常驻内存"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("应用及共享"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("清理"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("堆内存空闲"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("堆内存使用中"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage("内核未运行"),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("运行时开销"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("协程栈"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "基于进程常驻内存估算，可能与系统显示的数值不同。",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "内核与应用运行在同一进程，内核部分按运行时统计估算，其余计入应用及共享内存。",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage("进程物理内存占用"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("GC 元数据"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage("保留空闲堆"),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("堆对象"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("已归还系统"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage("堆内未使用空间"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("内存信息"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("应用与内核占用的内存"),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage("运行时元数据"),
    "memoryOther": MessageLookupByLibrary.simpleMessage("其他运行时内存"),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage("无法读取内存，正在重试…"),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("内存已释放"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("栈"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Go 内存占用"),
    "messageTest": MessageLookupByLibrary.simpleMessage("消息测试"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("这是一条消息。"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("退出时最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage("修改系统默认退出事件"),
    "minutes": MessageLookupByLibrary.simpleMessage("分钟"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合端口"),
    "mode": MessageLookupByLibrary.simpleMessage("模式"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("单色"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage("单色托盘图标"),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("更多"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU 必须是 1 到 65535 之间的整数",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage("多个值使用逗号分隔"),
    "name": MessageLookupByLibrary.simpleMessage("名称"),
    "nameserver": MessageLookupByLibrary.simpleMessage("域名服务器"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析域名"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("域名服务器策略"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "为匹配的域名、GeoSite 分类或规则集指定 DNS 服务器",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("底栏"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("需要登录"),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage("请求已取消"),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "无法连接到服务器，请检查网络连接或代理设置",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage("修改网络相关设置"),
    "networkException": MessageLookupByLibrary.simpleMessage("网络异常，请检查连接后重试"),
    "networkExtension": MessageLookupByLibrary.simpleMessage("网络扩展"),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "无法解析服务器地址，请确认链接正确且 DNS 可用",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("网络 ID"),
    "networkName": MessageLookupByLibrary.simpleMessage("网络名称"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("网络不存在"),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "请求过于频繁（HTTP 429），请稍后再试",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("网络密码"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("网络速度"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage("显示实时网速"),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "在系统状态区域显示实时网速，可能会稍微增加耗电",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("网络接管"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "请求超时，请检查网络或代理后重试",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "安全连接失败，服务器证书可能无效，或连接被拦截",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("网络类型"),
    "networking": MessageLookupByLibrary.simpleMessage("组网"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage("查看点对点组网状态"),
    "networkingError": MessageLookupByLibrary.simpleMessage("错误"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "当前配置中没有点对点组网出站",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("新建"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage("手动编写配置文件"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("下一个匹配"),
    "no": MessageLookupByLibrary.simpleMessage("否"),
    "noData": MessageLookupByLibrary.simpleMessage("暂无数据"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("没有子目录"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage("暂无筛选条件"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("暂无快捷键"),
    "noInfo": MessageLookupByLibrary.simpleMessage("暂无信息"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("不再提示"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("无网络"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("无网络应用"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage("未找到远端备份"),
    "noResolve": MessageLookupByLibrary.simpleMessage("不解析IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("不解析主机名"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("没有匹配的结果"),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "无法读取流量，正在重试…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("节点流量"),
    "nodes": MessageLookupByLibrary.simpleMessage("节点"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage("该外部资源不是文本文件"),
    "none": MessageLookupByLibrary.simpleMessage("无"),
    "notRunning": MessageLookupByLibrary.simpleMessage("未运行"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("当前代理组无法选中"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("更新 NTP 相关设置"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("同步间隔（分钟）"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "开启 NTP 后从 NTP 服务器获取时间，而非系统时钟。",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("添加一个配置文件后即可开始使用"),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("混淆"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("混淆主机"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("混淆模式"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("混淆参数"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("混淆密码"),
    "offline": MessageLookupByLibrary.simpleMessage("离线"),
    "onDemand": MessageLookupByLibrary.simpleMessage("按需运行"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "按需运行会在连上排除的 Wi-Fi 时暂停代理。",
    ),
    "online": MessageLookupByLibrary.simpleMessage("在线"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("仅配置"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("仅 Emoji"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("仅图标"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("仅统计代理流量"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "开启后，将只统计代理流量",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("在 GitHub 打开"),
    "optional": MessageLookupByLibrary.simpleMessage("可选"),
    "options": MessageLookupByLibrary.simpleMessage("选项"),
    "other": MessageLookupByLibrary.simpleMessage("其他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("其他贡献者"),
    "outbound": MessageLookupByLibrary.simpleMessage("出站"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("出口"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("出站 IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("出站模式"),
    "override": MessageLookupByLibrary.simpleMessage("覆写"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("覆盖目标地址"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "覆盖目标地址使用嗅探到的域名替换原目标地址发起连接。",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("覆写 DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "开启后将覆盖配置中的 DNS 选项",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("覆写项"),
    "overrideMode": MessageLookupByLibrary.simpleMessage("覆写模式"),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("覆写 NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "开启后将覆盖配置中的 NTP 选项",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage("覆写脚本"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("自定义"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "自定义模式，支持完全自定义修改代理组以及规则",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("上级目录"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("解析纯IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "解析纯 IP 会嗅探只有 IP 地址的连接。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("密码"),
    "paste": MessageLookupByLibrary.simpleMessage("粘贴"),
    "peers": MessageLookupByLibrary.simpleMessage("初始节点"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("从相册选择"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("窗口置顶"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("请绑定WebDAV"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage("请输入脚本名称"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "请上传有效的二维码",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("插件"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("插件主机"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("插件模式"),
    "port": MessageLookupByLibrary.simpleMessage("端口"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("请输入不同的端口"),
    "portHopping": MessageLookupByLibrary.simpleMessage("端口跳跃"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("端口"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage("请输入大于 0 的整数"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("预共享密钥"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("预见性返回"),
    "preferH3": MessageLookupByLibrary.simpleMessage("优先使用 HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("优先使用 DOH 的 HTTP/3"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前置条件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("请按下组合键"),
    "preview": MessageLookupByLibrary.simpleMessage("预览"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("上一个匹配"),
    "privateKey": MessageLookupByLibrary.simpleMessage("私钥"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("私钥密码"),
    "process": MessageLookupByLibrary.simpleMessage("进程"),
    "profile": MessageLookupByLibrary.simpleMessage("配置"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入有效间隔时间格式"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入自动更新间隔时间"),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "配置文件已经修改，是否关闭自动更新？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置名称",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "仅作用于当前配置，未添加的项使用默认值。",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "仅作用于当前配置，并优先于网络设置中的虚拟网卡覆写项。",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入有效配置URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("配置"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("配置排序"),
    "project": MessageLookupByLibrary.simpleMessage("项目"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage("关闭连接提示"),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "切换节点后询问是否关闭连接",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("协议"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("协议参数"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("协议版本"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("仅支持远程资源"),
    "providers": MessageLookupByLibrary.simpleMessage("外部资源"),
    "proxies": MessageLookupByLibrary.simpleMessage("代理"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("代理"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("代理链"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "检测到选中的代理存在异常",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("节点过滤器"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("策略组"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "检测到当前策略组异常",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("策略组为空"),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage("策略组名称不能为空"),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "启动后在这里显示策略组",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("代理域名服务器"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析代理节点的域名"),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage("代理域名服务器策略"),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "指定代理节点的域名服务器策略",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("代理集"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "检测到选中的代理集存在异常",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("代理集"),
    "proxyType": MessageLookupByLibrary.simpleMessage("代理类型"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("修剪缓存"),
    "publicKey": MessageLookupByLibrary.simpleMessage("公钥"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("纯黑"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("纯黑模式"),
    "qrcode": MessageLookupByLibrary.simpleMessage("二维码"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("扫描二维码获取配置文件"),
    "query": MessageLookupByLibrary.simpleMessage("查询"),
    "queryDns": MessageLookupByLibrary.simpleMessage("查询 DNS"),
    "queryRule": MessageLookupByLibrary.simpleMessage("规则查询"),
    "quickActions": MessageLookupByLibrary.simpleMessage("快捷操作"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("快速编辑"),
    "quickFill": MessageLookupByLibrary.simpleMessage("一键填入"),
    "random": MessageLookupByLibrary.simpleMessage("随机"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("最近请求"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("推荐"),
    "recordType": MessageLookupByLibrary.simpleMessage("记录类型"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("启用 RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage("在 Darwin 上批量接收数据包"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir端口"),
    "redo": MessageLookupByLibrary.simpleMessage("重做"),
    "regex": MessageLookupByLibrary.simpleMessage("正则"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("正则搜索"),
    "relayed": MessageLookupByLibrary.simpleMessage("中继"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("释放内存"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage("释放内存失败"),
    "remote": MessageLookupByLibrary.simpleMessage("远程"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage("备份数据到 WebDAV"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("远程目标"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("远程 DNS 解析"),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rename": MessageLookupByLibrary.simpleMessage("重命名"),
    "replace": MessageLookupByLibrary.simpleMessage("替换"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("全部替换"),
    "request": MessageLookupByLibrary.simpleMessage("请求"),
    "requests": MessageLookupByLibrary.simpleMessage("请求"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("请求与更新"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("查看最近请求记录"),
    "required": MessageLookupByLibrary.simpleMessage("必填"),
    "reset": MessageLookupByLibrary.simpleMessage("重置"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "当前页面存在更改，确定重置吗？",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage("配置与脚本"),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage("应用设置"),
    "resetTip": MessageLookupByLibrary.simpleMessage("确定要重置吗？"),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔"),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自动更新间隔必须大于0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("资源"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部资源相关信息"),
    "respectRules": MessageLookupByLibrary.simpleMessage("遵守规则"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "遵守规则使 DNS 连接遵守规则，需配置 Proxy Server Nameserver。",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("响应码"),
    "restart": MessageLookupByLibrary.simpleMessage("重启"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("您确定要重启核心吗？"),
    "restore": MessageLookupByLibrary.simpleMessage("恢复"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("恢复所有数据"),
    "restoreException": MessageLookupByLibrary.simpleMessage("恢复异常"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage("通过文件恢复数据"),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "通过 WebDAV 恢复数据",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage("恢复隐藏组"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("仅恢复配置文件"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("恢复策略"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("兼容"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("覆盖"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("恢复成功"),
    "result": MessageLookupByLibrary.simpleMessage("结果"),
    "retry": MessageLookupByLibrary.simpleMessage("重试"),
    "role": MessageLookupByLibrary.simpleMessage("角色"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("路由地址"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("配置监听路由地址"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("排除路由地址"),
    "routeMode": MessageLookupByLibrary.simpleMessage("路由模式"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage("绕过私有路由地址"),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("使用配置"),
    "routes": MessageLookupByLibrary.simpleMessage("路由"),
    "routingMark": MessageLookupByLibrary.simpleMessage("路由标记"),
    "ru": MessageLookupByLibrary.simpleMessage("俄语"),
    "rule": MessageLookupByLibrary.simpleMessage("规则"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("匹配完整域名"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "匹配域名关键字",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用域名正则表达式匹配",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配域名后缀",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "匹配DSCP标记（仅限 tproxy udp 入站）",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage("匹配请求目标端口范围"),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 所属国家代码"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 Geosite 内的域名",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("匹配入站名称"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage("匹配入站端口"),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage("匹配入站类型"),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "匹配入站用户名，支持使用 / 分隔多个用户名",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 所属 ASN"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "匹配 IP 地址范围，IP-CIDR6 只是一个别名",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 地址范围"),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 IP 后缀范围",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage("匹配所有请求，无需条件"),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage("匹配TCP或者UDP"),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程匹配，在Android平台可以匹配包名",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程名称正则表达式匹配，在Android平台可以匹配包名",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程名称通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "使用完整进程路径匹配",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程路径正则表达式匹配",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程路径通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "匹配重匹配名称，多个名称用/分隔",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "引用规则集合，需配置rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 所属国家代码",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 所属 ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 地址范围",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 后缀范围",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage("匹配请求来源端口范围"),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "匹配至子规则，需要注意括号的使用",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 Linux USER ID",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("已禁用"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("规则为空"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("已启用"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("命中"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("最后命中"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage("最后未命中"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "规则必须是 YAML 列表，每项一条规则，例如 - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("未命中"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BT 下载直连",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "屏蔽 DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage("防止代理回环"),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("屏蔽 QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("屏蔽 STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("局域网直连"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple 与 Microsoft 直连",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("规则集"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage("目标 IP"),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage("入站名称"),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage("入站用户"),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage("请输入有效的 IP 地址。"),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "未命中规则（模式策略或 DIRECT 回退）",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "请输入 1 到 65535 之间的端口。",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage("进程路径"),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage("嗅探域名"),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("来源端口"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage("域名或 IP 地址"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("规则集"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage("规则集中没有可用的条目"),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage("无法读取该 mrs 文件"),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "规则集同时包含域名和 IP 段，无法判断类型",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("规则目标"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "规则必须以受支持的类型开头，例如 DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("规则类型"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "无法更改规则，配置可能已变化，请刷新后重试。",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("规则"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage("查看规则及匹配统计"),
    "runTime": MessageLookupByLibrary.simpleMessage("运行时长"),
    "running": MessageLookupByLibrary.simpleMessage("运行中"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("运行时配置"),
    "safeMode": MessageLookupByLibrary.simpleMessage("安全模式"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("饱和度"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("是否保存更改？"),
    "script": MessageLookupByLibrary.simpleMessage("脚本"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage("脚本模式，使用扩展脚本改写整个配置"),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("滚动到已选"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("密钥"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("全选"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "选择 MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage("选择备份"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("请选择规则集"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage("请选择分流策略"),
    "selected": MessageLookupByLibrary.simpleMessage("已选择"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("启用 SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage("在 Darwin 上批量发送数据包"),
    "server": MessageLookupByLibrary.simpleMessage("服务器"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("全部可用"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("可用"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("已被封禁"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("检测"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("全部检测"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("即将上线"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage("不允许的 ISP"),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("检测失败"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("管理服务"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("仅限自制内容"),
    "servicePending": MessageLookupByLibrary.simpleMessage("待检测"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("访问受限"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage("显示在仪表盘"),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("服务状态"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("不可用"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage("地区不支持"),
    "settingEntries": MessageLookupByLibrary.simpleMessage("设置项"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage("无法从链接中读取代理"),
    "show": MessageLookupByLibrary.simpleMessage("显示"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("显示隐藏组"),
    "showLess": MessageLookupByLibrary.simpleMessage("收起"),
    "showMore": MessageLookupByLibrary.simpleMessage("展开"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "通知栏显示停止按钮",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "在常驻通知上显示停止按钮。若系统因此总是展开通知，可关闭",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("显示密码"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "显示当前配置名称",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "连接时在快捷开关上显示配置名称",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage("托盘中选择代理"),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "在托盘菜单中显示代理组和节点，方便快速切换",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("显示超时"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("侧边栏背景模糊"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage("侧边栏透出窗口后方模糊的桌面"),
    "signIn": MessageLookupByLibrary.simpleMessage("登录"),
    "signOut": MessageLookupByLibrary.simpleMessage("登出"),
    "signedIn": MessageLookupByLibrary.simpleMessage("已登录"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("静默启动"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("静默启动时不显示窗口。"),
    "singleAdd": MessageLookupByLibrary.simpleMessage("单条添加"),
    "singleImport": MessageLookupByLibrary.simpleMessage("单条导入"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "这里只能填写一条链接，多条请在列表的快速编辑中填写",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("尺寸"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("跳过证书验证"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("跳过域名"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage("嗅探到跳过域名中的域名时不予采用。"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("跳过目标地址"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("跳过来源地址"),
    "slide": MessageLookupByLibrary.simpleMessage("滑动"),
    "sliders": MessageLookupByLibrary.simpleMessage("滑块"),
    "small": MessageLookupByLibrary.simpleMessage("小"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("协议"),
    "sniffer": MessageLookupByLibrary.simpleMessage("域名嗅探"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "域名嗅探从 TLS、HTTP、QUIC 流量中识别域名，供规则匹配。",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks端口"),
    "softStyle": MessageLookupByLibrary.simpleMessage("柔和"),
    "sort": MessageLookupByLibrary.simpleMessage("排序"),
    "source": MessageLookupByLibrary.simpleMessage("来源"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("源IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊代理"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊规则"),
    "spectrum": MessageLookupByLibrary.simpleMessage("光谱"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("网速统计"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("分流策略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage("分流策略不能为空"),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs为空"),
    "stackMode": MessageLookupByLibrary.simpleMessage("栈模式"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("堆栈信息"),
    "standard": MessageLookupByLibrary.simpleMessage("标准"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "标准模式，在配置的基础上附加规则",
    ),
    "start": MessageLookupByLibrary.simpleMessage("启动"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("从零开始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("正在启动VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("启动与后台"),
    "status": MessageLookupByLibrary.simpleMessage("状态"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("关闭 DNS 后将使用系统 DNS。"),
    "stop": MessageLookupByLibrary.simpleMessage("暂停"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("正在停止VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("已停止"),
    "strategy": MessageLookupByLibrary.simpleMessage("策略"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("严格路由"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "严格路由防止 DNS 等流量绕过虚拟网卡，关闭 IPv6 时会阻断本机的 IPv6 连接。",
    ),
    "style": MessageLookupByLibrary.simpleMessage("风格"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("样式设置"),
    "submit": MessageLookupByLibrary.simpleMessage("提交"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("订阅信息"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage("输入 sudo 密码"),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("休眠支持"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "设备空闲时挂起核心以降低耗电",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("挂起中…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage("滑动切页"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("切换配置"),
    "sync": MessageLookupByLibrary.simpleMessage("同步"),
    "system": MessageLookupByLibrary.simpleMessage("系统"),
    "systemApp": MessageLookupByLibrary.simpleMessage("系统应用"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("设置系统的 HTTP 代理"),
    "tab": MessageLookupByLibrary.simpleMessage("标签页"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("选项卡动画"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("仅在移动视图中有效"),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("活跃"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage("当前端点"),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS 名称"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("端点"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("出口节点"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "可用作出口节点",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("健康状态"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage("健康告警"),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("密钥已过期"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("密钥到期"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage("最后握手"),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("最后在线"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage("需要批准设备"),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("节点密钥"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP 中继"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("子网"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("标签"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("点击图标重试"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("点击授权"),
    "target": MessageLookupByLibrary.simpleMessage("目标"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP并发"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("开启后允许 TCP 并发"),
    "testInterval": MessageLookupByLibrary.simpleMessage("测试间隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("测速链接"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用时测试"),
    "textReplacement": MessageLookupByLibrary.simpleMessage("文本替换："),
    "textScale": MessageLookupByLibrary.simpleMessage("文本缩放"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage("应用内的文字将以这个大小显示"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "themeColor": MessageLookupByLibrary.simpleMessage("主题色彩"),
    "themeMode": MessageLookupByLibrary.simpleMessage("主题模式"),
    "tight": MessageLookupByLibrary.simpleMessage("紧凑"),
    "time": MessageLookupByLibrary.simpleMessage("时间"),
    "timeout": MessageLookupByLibrary.simpleMessage("超时"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("氛围"),
    "tip": MessageLookupByLibrary.simpleMessage("提示"),
    "toggle": MessageLookupByLibrary.simpleMessage("切换"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("切换标签"),
    "tolerance": MessageLookupByLibrary.simpleMessage("容差"),
    "tools": MessageLookupByLibrary.simpleMessage("工具"),
    "torch": MessageLookupByLibrary.simpleMessage("手电筒"),
    "total": MessageLookupByLibrary.simpleMessage("总计"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("下载总量"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("总流量"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("上传总量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy端口"),
    "traffic": MessageLookupByLibrary.simpleMessage("流量"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("双向"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("流量统计"),
    "transport": MessageLookupByLibrary.simpleMessage("传输协议"),
    "tun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "虚拟网卡授权失败，已关闭。",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("虚拟网卡仅在管理员模式生效。"),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("系统 DNS 模式"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("不设置"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("劫持"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("原生"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "添加的项会覆写所有配置的虚拟网卡设置，未添加的项沿用配置自身的设置。自定义配置自己添加的项优先。",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("关闭"),
    "turnOn": MessageLookupByLibrary.simpleMessage("开启"),
    "tvMode": MessageLookupByLibrary.simpleMessage("电视模式"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage("在此设备上使用遥控器布局"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP 中继模式"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP 超时"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP 超时以秒为单位，仅在 gvisor、system 和 mixed 栈生效。",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage("怠速更新周期"),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage("失焦时怠速"),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "应用窗口失去焦点时使用怠速更新周期",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage("UI 信息更新周期"),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("极致"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("未授权"),
    "undo": MessageLookupByLibrary.simpleMessage("撤销"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("统一延迟"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage("去除握手等额外延迟"),
    "uninitialized": MessageLookupByLibrary.simpleMessage("未初始化"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "未知变量，请选择下方支持的变量。",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("未知网络错误"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("向下还原"),
    "unnamed": MessageLookupByLibrary.simpleMessage("未命名"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("取消置顶"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "下载的文件与发布的校验值不符，已丢弃。",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("正在下载更新"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage("无法启动安装程序。"),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash 未获得安装应用的权限，因此未安装更新。",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash 无法写入其安装目录，请手动下载更新。",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("立即更新"),
    "upload": MessageLookupByLibrary.simpleMessage("上传"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("上行带宽"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("上传速度"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("上传流量"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("通过 URL 获取配置文件"),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("使用Hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "查询上游 DNS 前先匹配配置中的 hosts",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("使用系统Hosts"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "解析域名时匹配操作系统的 Hosts 文件",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("已用"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("已用流量"),
    "userAgent": MessageLookupByLibrary.simpleMessage("用户代理"),
    "username": MessageLookupByLibrary.simpleMessage("用户名"),
    "value": MessageLookupByLibrary.simpleMessage("值"),
    "version": MessageLookupByLibrary.simpleMessage("版本"),
    "view": MessageLookupByLibrary.simpleMessage("查看"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("虚拟 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("鲜明"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "检测到VPN相关配置改动",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN 通过 VpnService 自动路由系统所有流量。",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV配置"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("白名单模式"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("写入系统"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "写入系统会同时设置系统时钟，Android 上不生效。",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("是"),
    "zhCN": MessageLookupByLibrary.simpleMessage("中文简体"),
    "zhTW": MessageLookupByLibrary.simpleMessage("繁体中文"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage("获取帮助"),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "查看开通与续费订单",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage("登录密码"),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "连接设置",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage("查看账号信息和订单。"),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("我的账户"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("开通中"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("高级设置"),
    "zolnitAiService": MessageLookupByLibrary.simpleMessage("AI 服务"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("全部线路"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("全部地区"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("应付金额"),
    "zolnitAppleAutoRenewal": MessageLookupByLibrary.simpleMessage(
      "App Store 自动续费订阅",
    ),
    "zolnitAppleConsent": MessageLookupByLibrary.simpleMessage(
      "订阅将按显示的 App Store 价格自动续费，直到你在 App Store 订阅管理中取消。",
    ),
    "zolnitAppleManage": MessageLookupByLibrary.simpleMessage(
      "管理 App Store 订阅",
    ),
    "zolnitApplePending": MessageLookupByLibrary.simpleMessage(
      "正在等待 App Store 或服务端验证。",
    ),
    "zolnitAppleRestore": MessageLookupByLibrary.simpleMessage(
      "恢复 App Store 购买",
    ),
    "zolnitAppleSubscribe": MessageLookupByLibrary.simpleMessage(
      "通过 App Store 订阅",
    ),
    "zolnitAppleUnavailable": MessageLookupByLibrary.simpleMessage(
      "此套餐暂不支持 App Store 购买。",
    ),
    "zolnitAuthorizeMonthly": MessageLookupByLibrary.simpleMessage("授权连续包月"),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("账户余额"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage("按月付费，轻松开始"),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取续费信息。",
    ),
    "zolnitBundleAutomaticPending": MessageLookupByLibrary.simpleMessage(
      "自动分流仍在验证中，当前可使用手动或直连。",
    ),
    "zolnitBundleExpired": MessageLookupByLibrary.simpleMessage(
      "自动选择信息已过期。请刷新配置；手动或直连仍可用。",
    ),
    "zolnitBundleFetchHint": MessageLookupByLibrary.simpleMessage("获取连接配置"),
    "zolnitBundleForbidden": MessageLookupByLibrary.simpleMessage(
      "当前账号暂时无法获取连接配置，请检查套餐与流量。",
    ),
    "zolnitBundleInvalid": MessageLookupByLibrary.simpleMessage(
      "连接配置校验失败，自动选择已暂停。",
    ),
    "zolnitBundleNoCandidates": MessageLookupByLibrary.simpleMessage(
      "尚无已确认的出口资格。自动选择不可用，仍可手动或直连。",
    ),
    "zolnitBundleRefreshFailed": MessageLookupByLibrary.simpleMessage(
      "连接配置刷新失败。手动或直连仍可用。",
    ),
    "zolnitBundleUnavailable": MessageLookupByLibrary.simpleMessage(
      "连接配置暂时不可用。",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("创建订单"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("取消订单"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "确认取消这个待付款订单？",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage("取消自动续费"),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "停止后续自动扣款；首期尚未付款的订单也会取消。已付权益以服务端结果为准。",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("已取消"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage("修改密码"),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "已有一笔结算正在处理，请在账号页查看状态，请勿重复提交。",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "结算会话正在准备或核对，请稍后重试。",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("选择套餐"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("已完成"),
    "zolnitConnectAction": MessageLookupByLibrary.simpleMessage("连接"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage("准备连接"),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage("启动后自动连接"),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "启动时自动连接到上次使用的线路。",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage("连接到套餐包含的线路。"),
    "zolnitConnectionPageUnavailable": MessageLookupByLibrary.simpleMessage(
      "连接页面暂时无法显示，请重试。",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("复制邀请码"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "请输入有效邮箱和至少八位密码。",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("已折抵"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("当前套餐"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLabel": MessageLookupByLibrary.simpleMessage("当前套餐"),
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("当前选择"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("半年"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("季"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("三年"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("两年"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("年"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("天"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "这里显示账户的登录会话，和节点的在线 IP 数不同。",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage("登录会话"),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取登录会话，请重试。",
    ),
    "zolnitDisconnectAction": MessageLookupByLibrary.simpleMessage("断开连接"),
    "zolnitDisconnecting": MessageLookupByLibrary.simpleMessage("正在断开…"),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("邮箱"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage("熟悉的多端体验"),
    "zolnitExistingRenewal": MessageLookupByLibrary.simpleMessage(
      "请先在账号页的“自动续费”中取消原套餐续费，再开通新的连续包月。",
    ),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage("操作未完成，请稍后重试。"),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("首期付款"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage("后续付款"),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage("忘记密码？"),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("赠送权益"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "首期付款确认后开始付费周期，并替换剩余赠送时间。",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage("全球优选线路"),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage("查看套餐和可用线路。"),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("半年付"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage("帮助与支持"),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("邀请码"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage("邀请码已复制"),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "可用佣金",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "已确认佣金",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "待确认佣金",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage("佣金比例"),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage("邀请链接已复制"),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage("生成邀请码"),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "生成邀请码失败，请重试。",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage("好体验，值得分享。"),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage("邀请链接"),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取邀请数据，请重试。",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage("邀请好友，从这里开始。"),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("人"),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage("已注册"),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage("邀请规则"),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage("你的专属邀请"),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "好友通过链接注册并开通套餐后，你将获得邀请奖励。",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "邀请好友注册并开通套餐，收获一份奖励。",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("延迟"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage("最新公告"),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "不必研究复杂设置。你想去的世界，轻轻一点就到。",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage("离你的世界，再近一点"),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "登录你的账户，管理套餐与连接。",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage("注册或找回密码"),
    "zolnitManageRenewals": MessageLookupByLibrary.simpleMessage("管理自动续费"),
    "zolnitMediaService": MessageLookupByLibrary.simpleMessage("海外影音"),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("全局模式"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage("智能分流"),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("月付"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage("连续包月"),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("我的空间"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("新密码"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage("下次续费"),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "你还没有有效套餐，选择一个开始使用。",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage("暂无可显示的登录会话。"),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage("没有匹配的线路。"),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage("暂无可用付款方式"),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage("当前套餐暂无可用线路。"),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage("暂无公告"),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("暂无订单"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("暂无有效套餐"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage("暂无自动续费合约"),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "延迟以最近一次实际检测为准，未检测时显示 —。",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("线路"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage("可用线路会随套餐自动更新。"),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("线路"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "线路会随账号套餐自动更新。",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage("当前尚未连接"),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("公告"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage("当前密码"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("一次性"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage("在线设备"),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("订单记录"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("已付权益"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("已付权益截止"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "请输入当前密码，并使用至少八个字符的不同新密码。",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage("密码已更新。"),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("前往付款"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "付款返回后仍需确认订单状态。",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage("付款状态"),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "此付款方式尚未就绪。",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("待付款"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "你有一笔待处理订单，请在“订单”中继续付款或关闭后再下单。",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ 月"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "首期付款或原套餐余值抵扣确认后，开始新套餐周期。",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage("套餐有效期"),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("套餐"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage("套餐"),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "从日常浏览到畅快影音，选择适合你的连接方式。",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("偏好设置"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage("设置"),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "安全模式保留你的偏好，但不会自动连接或改变系统网络。",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "管理启动和连接设置。",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "线路会随账号套餐自动更新。",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("季付"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "确认报价后，再授权自动续费。",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage("报价已过期，请刷新后重试。"),
    "zolnitQuoteLabel": MessageLookupByLibrary.simpleMessage("本次报价"),
    "zolnitQuoteUnavailable": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取报价，请重试。",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage("操作过于频繁，请稍后重试。"),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage("推荐线路"),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "套餐包含的线路",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage("推荐线路"),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "我同意按所展示的首期付款及后续续费条款为此套餐连续付款。",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "当前暂时无法为该套餐开通连续包月。",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("注册"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "注册和找回密码将在 ZolNit 官网完成邮箱与安全验证。",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage("续费当前套餐"),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("续费套餐"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage("自动续费"),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage("重置流量"),
    "zolnitRestoringSession": MessageLookupByLibrary.simpleMessage("正在恢复登录…"),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage("恢复自动续费"),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "恢复后将按已授权的套餐安排自动扣款。",
    ),
    "zolnitReturnDirect": MessageLookupByLibrary.simpleMessage("直达回国"),
    "zolnitReturnEnabled": MessageLookupByLibrary.simpleMessage("启用回国"),
    "zolnitReturnHkLite": MessageLookupByLibrary.simpleMessage("香港优选"),
    "zolnitReturnHkOptimized": MessageLookupByLibrary.simpleMessage("香港优化"),
    "zolnitReturnLocal": MessageLookupByLibrary.simpleMessage("本地直连"),
    "zolnitReturnRoute": MessageLookupByLibrary.simpleMessage("回国线路"),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage("退出此会话"),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage("登录会话已结束。"),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "结束此登录会话？该设备需重新登录才能管理账户。",
    ),
    "zolnitRouteCurrent": m101,
    "zolnitRouteUnavailable": MessageLookupByLibrary.simpleMessage("不可用"),
    "zolnitSafeMode": MessageLookupByLibrary.simpleMessage("安全模式"),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "安全模式不会修改系统网络。",
    ),
    "zolnitSavePercent": m102,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage("搜索线路或地区"),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("选择"),
    "zolnitSelectServer": MessageLookupByLibrary.simpleMessage("选择线路"),
    "zolnitSessionExpired": MessageLookupByLibrary.simpleMessage(
      "登录已失效，请重新登录。",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("登录"),
    "zolnitSignInRejected": MessageLookupByLibrary.simpleMessage(
      "邮箱或密码不正确，请重试。",
    ),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("退出登录"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage("开机时启动 ZolNit"),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "打开设备后，让 ZolNit 提前准备好。",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("使用中"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("已到期"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("未订阅"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage("选择套餐"),
    "zolnitSync": MessageLookupByLibrary.simpleMessage("同步账号数据"),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage("账号数据已同步"),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage("正在同步账号数据…"),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("账号信息"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("邀请有礼"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("订单记录"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage("让连接回归简单。"),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("三年付"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("剩余流量"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage("本期已用流量"),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("两年付"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage("登录会话"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage("查看包月报价"),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage("打开 ZolNit 网站"),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("欢迎回来"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("我的空间"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("年付"),
  };
}

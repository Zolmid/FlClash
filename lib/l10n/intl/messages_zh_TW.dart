// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_TW locale. All the
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
  String get localeName => 'zh_TW';

  static String m0(count, skipped) => "將新增 ${count} 項，跳過 ${skipped} 項已存在";

  static String m1(detail) => "清除資料失敗：${detail}";

  static String m2(code) =>
      "Windows 拒絕執行 FlClashCore.exe（錯誤 ${code}）。智慧型應用程式控制、AppLocker 等應用程式控制原則會封鎖未簽署的程式，請在原則中允許 FlClash，或關閉原則後重試。";

  static String m3(name) =>
      "應用連續兩次未能完成啟動。為打斷崩潰迴圈，已取消選中配置 ${name}，並跳過本次自動配置，你可以隨時重新選中它。";

  static String m4(url) => "是否透過 ${url} 建立設定檔？";

  static String m5(count, label) =>
      "${Intl.plural(count, one: '已捨棄 1 條 SUB-RULE 規則，因為自訂設定檔不支援子規則', other: '已捨棄 ${label} 條 SUB-RULE 規則，因為自訂設定檔不支援子規則')}";

  static String m6(message) => "核心無法解析該代理：${message}";

  static String m7(proxy, target) =>
      "${proxy} 經 ${target} 撥號，而 ${target} 又會回到 ${proxy}，形成環路";

  static String m8(name) => "名稱 ${name} 已被其他代理或策略組使用";

  static String m9(path) => "策略組之間存在迴圈引用：${path}";

  static String m10(name) => "空組兜底只能是代理，${name} 不存在或是策略組";

  static String m11(name, message) => "${name}不是有效的正則：${message}";

  static String m12(name) => "撥號代理 ${name} 不存在";

  static String m13(names) => "以下代理集不存在：${names}";

  static String m14(names) => "以下代理或策略不存在：${names}";

  static String m15(name) => "${name} 是內建策略名，不能在此使用";

  static String m16(count) => "${count} 項存在問題，應用配置可能失敗";

  static String m17(count) => "${count} 天前";

  static String m18(count) => "${count} 天前";

  static String m19(label) => "確定刪除選取的${label}嗎？";

  static String m20(label) => "確定刪除目前${label}嗎？";

  static String m21(label) => "${label}詳情";

  static String m22(name) => "經 ${name} 撥號會繞回使用它的代理，連線已中止";

  static String m23(label) => "${label}不能為空";

  static String m24(count) => "${count} 筆項目";

  static String m25(label) => "${label}目前已存在";

  static String m26(count) => "${count} 項失敗";

  static String m27(label, message) => "${label}：${message}";

  static String m28(name) => "${name} 已是最新版本";

  static String m29(name) => "${name} 已更新";

  static String m30(name) => "正在更新 ${name}…";

  static String m31(count) =>
      "${Intl.plural(count, one: '1 個群組', other: '${count} 個群組')}";

  static String m32(count) => "${count} 個逾時";

  static String m33(action) => "已用於「${action}」，儲存後將移至此處";

  static String m34(modifiers) => "至少包含 ${modifiers} 中的一個";

  static String m35(count) => "${count} 小時前";

  static String m36(count) => "${count} 小時前";

  static String m37(target) => "${target} 是一個無效的策略";

  static String m38(proxyName) => "${proxyName} 是一個無效的代理";

  static String m39(providerName) => "${providerName} 是一個無效的代理集";

  static String m40(ruleSet) => "${ruleSet} 不是有效的規則集";

  static String m41(subRule) => "${subRule} 是一個無效的 SUB_RULE";

  static String m42(count) => "${count} 項";

  static String m43(line, message) => "第 ${line} 行：${message}";

  static String m44(appName) =>
      "1. 開啟「系統設定」>「隱私權與安全性」\n2. 選擇「定位服務」\n3. 在右側清單中找到並勾選 ${appName}\n\n完成設定後，返回應用程式即可使用。感謝您的配合。";

  static String m45(label, max) => "${label}最多可輸入 ${max} 個字元";

  static String m46(size) => "已釋放 ${size}";

  static String m47(count) => "${count} 分鐘前";

  static String m48(count) => "${count} 分鐘前";

  static String m49(count) => "${count} 個月前";

  static String m50(count) => "${count} 個月前";

  static String m51(code) => "伺服器拒絕訪問（HTTP ${code}），連結可能已過期或憑據有誤";

  static String m52(code) => "伺服器拒絕了請求（HTTP ${code}）";

  static String m53(code) => "該地址下沒有內容（HTTP ${code}），請確認連結是否正確";

  static String m54(detail) => "網路請求失敗：${detail}";

  static String m55(code) => "伺服器出現問題（HTTP ${code}），請稍後再試";

  static String m56(label) => "目前沒有${label}";

  static String m57(label, min, max) => "${label}必須在 ${min} 到 ${max} 之間";

  static String m58(label) => "${label}必須為數字";

  static String m59(label) => "${label}必須介於 1024 到 49151 之間，設為 0 可停用";

  static String m60(port) => "連接埠 ${port}";

  static String m61(days) =>
      "${Intl.plural(days, one: '剩餘 1 天', other: '剩餘 ${days} 天')}";

  static String m62(date, days) =>
      "${date} 到期，剩餘 ${Intl.plural(days, one: '1 天', other: '${days} 天')}";

  static String m63(time) => "更新於 ${time}";

  static String m64(label, profiles) =>
      "${label} 仍被 ${profiles} 使用，刪除後這些配置會異常。確定刪除嗎？";

  static String m65(count, label) =>
      "${Intl.plural(count, other: '${label} 個代理')}";

  static String m66(name, count) => "${name} 等 ${count} 個代理";

  static String m67(removed) =>
      "以下代理將被刪除：${removed}。改了名字的行按新代理處理，自定義配置中對被刪除代理的引用會標為缺失。確定應用嗎？";

  static String m68(removed, added) =>
      "以下代理將被刪除：${removed}。以下代理將新增：${added}。改了名字的行按新代理處理，自定義配置中對被刪除代理的引用會標為缺失。確定應用嗎？";

  static String m69(label) =>
      "${label} 仍被當前配置的規則、策略組、撥號代理、DNS 或 NTP 引用，刪除後這些引用會失效。確定刪除嗎？";

  static String m70(count, label) =>
      "${Intl.plural(count, one: '1 個代理群組', other: '${label} 個代理群組')}";

  static String m71(maximum) => "請輸入 0 到 ${maximum} 之間的整數。";

  static String m72(count, label) =>
      "${Intl.plural(count, other: '${label} 條規則')}";

  static String m73(appName) => "${appName}（安全模式）";

  static String m74(count) => "${count} 秒";

  static String m75(count) => "${count} 項生效";

  static String m76(count) =>
      "${Intl.plural(count, one: '1 個問題', other: '${count} 個問題')}";

  static String m77(time) => "檢測於 ${time}";

  static String m78(count) => "${count} 項設定";

  static String m79(link) => "無法從 ${link} 中讀取代理";

  static String m80(label) => "${label}只能是一項";

  static String m81(value) => "峰值 ${value}";

  static String m82(value) => "總計 ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · 閒置 ${idleInterval}";

  static String m84(interval) => "${interval} · 已停用閒置更新";

  static String m85(label) => "${label}必須為 URL";

  static String m86(count) => "${count} 年前";

  static String m87(count) => "${count} 年前";

  static String m88(amount, cycle) => "每${cycle} ${amount}，一次付清";

  static String m89(date) => "${date} 到期，升級或續約都可以在這裡完成。";

  static String m90(plan) => "目前方案 · ${plan}";

  static String m91(days) => "剩餘 ${days} 天";

  static String m92(date) => "${date} 到期";

  static String m93(count) => "支援 ${count} 台裝置同時上線";

  static String m94(mbps) => "速率上限 ${mbps} Mbps";

  static String m95(gb) => "每月 ${gb} GB 高速流量";

  static String m96(name) => "你好，${name}。";

  static String m97(rate) => "${rate}× 計量";

  static String m98(count) => "${count} 個節點";

  static String m99(count) => "/ ${count} 台";

  static String m100(days) => "${days} 天後重置";

  static String m101(percent) => "省 ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("關於"),
    "accessControl": MessageLookupByLibrary.simpleMessage("存取控制"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "僅允許選取的應用程式使用 VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "存取控制決定哪些應用程式使用代理。",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "應用程式存取控制已關閉",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選取的應用程式將不使用 VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("存取控制設定"),
    "accessDenied": MessageLookupByLibrary.simpleMessage("存取被拒絕"),
    "account": MessageLookupByLibrary.simpleMessage("帳號"),
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("測試全部延遲"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("直連模式"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("全域模式"),
    "actionMode": MessageLookupByLibrary.simpleMessage("切換模式"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("系統代理"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("規則模式"),
    "actionStart": MessageLookupByLibrary.simpleMessage("啟動／停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("虛擬網路卡"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("更新全部配置"),
    "actionView": MessageLookupByLibrary.simpleMessage("顯示／隱藏"),
    "add": MessageLookupByLibrary.simpleMessage("新增"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("新增代理"),
    "addFilters": MessageLookupByLibrary.simpleMessage("新增篩選"),
    "addNodes": MessageLookupByLibrary.simpleMessage("新增節點"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("新增覆寫項"),
    "addProfile": MessageLookupByLibrary.simpleMessage("新增設定檔"),
    "addProxies": MessageLookupByLibrary.simpleMessage("新增代理"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("新增策略群組"),
    "addRule": MessageLookupByLibrary.simpleMessage("新增規則"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("新增設定項"),
    "addSsid": MessageLookupByLibrary.simpleMessage("新增 SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("附加規則"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("附加參數"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("名稱字首"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("名稱字尾"),
    "address": MessageLookupByLibrary.simpleMessage("位址"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAV 伺服器位址"),
    "addressTip": MessageLookupByLibrary.simpleMessage("請輸入有效的 WebDAV 位址"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("進階設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "進階設定包含網路、DNS、附加規則與腳本。",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("配置已加密"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("產生 Age 金鑰"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "已產生 X25519 金鑰配對，請妥善儲存",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 私鑰"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "請先輸入正確的 Age 私鑰",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 公鑰"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 私鑰"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "請輸入有效的 Age 私鑰（必須以 AGE-SECRET-KEY- 開頭）",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage("Age 私鑰（選填）"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "該配置已用 age 加密，需要 age 私鑰才能解密",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allData": MessageLookupByLibrary.simpleMessage("全部資料"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage("所有引用的代理"),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "所有引用的代理提供者",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("允許應用程式略過 VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後，部分應用程式可略過 VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("區域網路代理"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("允許區域網路存取"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "允許從區域網路存取外部控制器",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("允許透過區域網路存取代理"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("允許的 IP"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("一律連線"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage("在任何網路環境下保持 VPN 連線"),
    "answers": MessageLookupByLibrary.simpleMessage("回覆"),
    "app": MessageLookupByLibrary.simpleMessage("應用程式"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("應用程式存取控制"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("應用圖示設計"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("暫無本地代理"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("追加系統 DNS"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "強制為設定檔附加系統 DNS",
    ),
    "application": MessageLookupByLibrary.simpleMessage("應用程式"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("修改應用程式相關設定"),
    "ascending": MessageLookupByLibrary.simpleMessage("遞增"),
    "authentication": MessageLookupByLibrary.simpleMessage("驗證"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "為本機代理連接埠啟用驗證，防止其他應用程式擅自使用",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "驗證啟用時不生效",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("授權"),
    "authorized": MessageLookupByLibrary.simpleMessage("已授權"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動檢查更新"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "應用程式啟動時自動檢查更新",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("自動關閉連線"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "切換節點後自動關閉連線",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("自動包含"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("開機自動啟動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("系統啟動時自動啟動"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動執行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("開啟應用程式時自動執行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("自動設定系統DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "back": MessageLookupByLibrary.simpleMessage("返回"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage("返回時回到首頁"),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage("結束前先返回儀表板"),
    "backup": MessageLookupByLibrary.simpleMessage("備份"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("備份與還原"),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "本機日期（YYYY-MM-DD）",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "該備份來自更高版本的應用，請先更新應用再恢復",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage("目前平台"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("備份成功"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "本機時間（HHmmss）",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage("應用程式版本號"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基礎設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("修改全域基本設定"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基礎資訊"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基礎策略"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("批次新增"),
    "batchImport": MessageLookupByLibrary.simpleMessage("批次匯入"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage("每行一個連結"),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage("每行一項，也可用逗號分隔"),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage("每行一條，鍵和值之間用空格分隔"),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage("每行一個URL"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "為確保背景執行，請關閉本應用程式的電池最佳化。點選以開啟設定。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("綁定"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("黑名單模式"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("阻止連線"),
    "brightness": MessageLookupByLibrary.simpleMessage("亮度"),
    "browse": MessageLookupByLibrary.simpleMessage("瀏覽"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("略過的網域"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("僅在系統代理啟用時生效"),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage("繞過私有路由地址"),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "開啟繞過私有路由地址後，區域網、迴環和組播地址不經過虛擬網絡卡。",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("快取"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("快取演算法"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("快取已損毀，是否清空？"),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("快取大小"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "請在系統設定中允許訪問相機以掃描二維碼，或從相簿選擇二維碼圖片。",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage("需要相機許可權"),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("相機不可用"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("取消全選"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("無法儲存"),
    "captureDns": MessageLookupByLibrary.simpleMessage("接管系統 DNS"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "將所有系統 DNS 查詢導入內部 DNS 模組",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "切換代理失敗，已還原先前的選擇",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("重大變更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新功能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("問題修復"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("效能最佳化"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("已復原"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("驗證 TLS 憑證"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "拒絕不受信任的憑證。關閉後，訂閱與備份可能遭受中間人攻擊",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("檢查更新"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("目前已是最新版本"),
    "cipher": MessageLookupByLibrary.simpleMessage("加密方式"),
    "clear": MessageLookupByLibrary.simpleMessage("清除"),
    "clearData": MessageLookupByLibrary.simpleMessage("清除資料"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "將刪除所有配置、設定和本地資料，隨後關閉應用。重新開啟即可從頭開始。",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("清除搜尋"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage("客戶端指紋"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("匯出至剪貼簿"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("剪貼簿匯入"),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage("無法寫入剪貼簿"),
    "close": MessageLookupByLibrary.simpleMessage("關閉"),
    "closeAll": MessageLookupByLibrary.simpleMessage("中斷所有連線"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("關閉連線"),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "是否關閉使用原代理的連線？",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("收合"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage("摺疊代理鏈"),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "代理鏈超過三個節點時隱藏中間節點",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "收合快速設定面板",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "點選快速設定開關後收合面板",
    ),
    "color": MessageLookupByLibrary.simpleMessage("顏色"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("色彩風格"),
    "columns": MessageLookupByLibrary.simpleMessage("列數"),
    "compact": MessageLookupByLibrary.simpleMessage("緊湊"),
    "compatible": MessageLookupByLibrary.simpleMessage("相容模式"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage("偵測到設定檔中已有資料"),
    "confirm": MessageLookupByLibrary.simpleMessage("確定"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage("確定要清除所有資料嗎？"),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "確定要清除所選資料嗎？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "確定要刪除目前策略群組嗎？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage("確定要關閉目前的視窗嗎？"),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "確定要強制讓核心當機嗎？",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage("確定後將覆蓋現有資料"),
    "congestionControl": MessageLookupByLibrary.simpleMessage("擁塞控制"),
    "congestionController": MessageLookupByLibrary.simpleMessage("壅塞控制"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 壅塞控制僅適用於 mips 協定堆疊。",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("已連線"),
    "connecting": MessageLookupByLibrary.simpleMessage("連線中"),
    "connection": MessageLookupByLibrary.simpleMessage("連線"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("連線數"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("連線統計"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "即時連線、最近請求與 DNS 查詢",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("連線"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("檢視目前的連線資料"),
    "connectivity": MessageLookupByLibrary.simpleMessage("連線狀態："),
    "content": MessageLookupByLibrary.simpleMessage("內容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("內容不能為空"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage("控制全域附加規則"),
    "copy": MessageLookupByLibrary.simpleMessage("複製"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("複製環境變數"),
    "copyLink": MessageLookupByLibrary.simpleMessage("複製連結"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("複製成功"),
    "core": MessageLookupByLibrary.simpleMessage("核心"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows 智慧型應用程式控制封鎖了未簽署的 FlClashCore.exe。請開啟 Windows 安全性 → 應用程式與瀏覽器控制 → 智慧型應用程式控制設定，選擇「關閉」後重新啟動 FlClash。關閉後，必須重新安裝 Windows 才能再次啟用智慧型應用程式控制。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("核心狀態"),
    "country": MessageLookupByLibrary.simpleMessage("地區"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("檢測到崩潰"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("當機測試"),
    "create": MessageLookupByLibrary.simpleMessage("建立"),
    "createProfile": MessageLookupByLibrary.simpleMessage("建立設定檔"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("建立時間"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage("包含啟動按鈕，無法移除"),
    "custom": MessageLookupByLibrary.simpleMessage("自訂"),
    "customColor": MessageLookupByLibrary.simpleMessage("自訂顏色"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("名稱為空"),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "未選擇任何代理或代理集，核心會拒絕該策略組",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("自定義"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "基於應用代理和其他配置組建策略組與規則",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage("自定義配置資源"),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "自訂設定檔資源包含代理、規則集、篩選與圖示集。",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("剪下"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("儀表板"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("可新增項目"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage("資料已變更，是否儲存？"),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "儲存變更失敗，已復原",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("目錄"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("預設 DNS 伺服器"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "用於解析 DNS 伺服器的網域",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage("預設選中"),
    "defaultText": MessageLookupByLibrary.simpleMessage("預設"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "配置必須是包含 name 和 type 的 YAML 對映",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("延遲"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("失敗"),
    "delayTest": MessageLookupByLibrary.simpleMessage("延遲測試"),
    "delete": MessageLookupByLibrary.simpleMessage("刪除"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "以 mihomo 為基礎的多平台代理用戶端，簡單易用，開放原始碼且無廣告。",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("遞減"),
    "destination": MessageLookupByLibrary.simpleMessage("目標位址"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("目標地理定位"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("目標 IP ASN"),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage("使用第三方 API，僅供參考"),
    "developerMode": MessageLookupByLibrary.simpleMessage("開發者模式"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage("開發者模式已啟用。"),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("撥號代理"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "用於連線 NTP 伺服器的出站代理",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("直連"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage("禁用ICMP轉發"),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "禁用 ICMP 轉發後由虛擬網絡卡直接應答 ping，ping 將不再顯示真實延遲。",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage("禁用 TCP 保持活動"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("停用 UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("已關閉"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("是否放棄更改？"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責聲明"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "一旦你安裝、複製或使用本軟體，即視為你已閱讀並同意本宣告的全部內容。如你不同意本宣告的任何條款，請立即停止使用並解除安裝本軟體。",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("接受宣告"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "我已閱讀並理解此聲明",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "請閱讀以下聲明並勾選方塊，確認你已理解內容：",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("確認聲明"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "開發者有權隨版本更新修改本宣告，修改後的內容隨新版本釋出即生效。你在更新後繼續使用本軟體，即視為接受修改後的宣告。",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("宣告變更"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本軟體僅供學習交流、科學研究等非商業用途，嚴禁用於商業目的。任何商業行為均與本軟體無關。",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "在適用法律允許的最大範圍內，開發者及所有貢獻者均不對因使用或無法使用本軟體而產生的任何直接、間接、偶然、特殊、懲罰性或後果性損害承擔責任，包括但不限於資料丟失、裝置損壞、網路異常、業務中斷、利潤損失或因此引起的任何法律糾紛，即使已被告知發生此類損害的可能性。",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("責任限制"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "本軟體以 GPL-3.0 協議開源。你可以在遵守該協議的前提下自由使用、修改和分發本軟體，但須同樣以 GPL-3.0 協議開源並保留原作者的版權宣告。\n\n本軟體包含的第三方元件（包括 Clash.Meta 核心）分別遵循其各自的開源協議。基於本軟體修改或分發的版本所產生的任何問題，與原作者無關。",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage("開源協議"),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "本軟體自身不提供任何代理伺服器、節點、訂閱、機場或網路接入服務，也不與任何此類服務的提供者存在合作、代理或擔保關係。",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "本軟體不會收集或上傳你的訂閱位址、節點資訊、設定內容、造訪的網站、連線記錄、流量內容和記錄，這些資料僅儲存在你的裝置本機，開發者無法取得。\n\n本軟體只會在你使用相應功能時存取外部網路，例如更新訂閱時存取你提供的訂閱位址、檢查更新時存取 GitHub。\n\n本軟體在所有平台上均未整合任何資料統計或當機回報服務。",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage("資料收集與隱私"),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "你應自行確認使用本軟體在你所在國家或地區是合法的，並對使用本軟體的全部行為及其後果獨立承擔法律責任。\n\n你匯入的訂閱、節點與配置由你自行選擇和判斷，其來源是否合法、內容是否安全、服務是否穩定，均由你與相關提供者自行負責。",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "使用者責任",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage("在此輸入上述宣告"),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "與宣告內容不一致",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "為確認你已知悉，請在下方輸入框中完整複述以下宣告：",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("複述宣告"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "本軟體是基於 Clash.Meta（mihomo）核心的開源網路代理客戶端，僅提供配置管理、規則分流與流量轉發等本地工具功能。",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage("軟體性質"),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "訂閱連結、配置檔案、規則集、指令碼、外部資源及外部連結均由第三方提供，開發者無法也不會對其合法性、準確性、安全性和可用性進行審查或擔保。\n\n因使用第三方內容導致的資料洩露、財產損失、賬號封禁或其他任何損失，由你與第三方自行解決，開發者不承擔任何責任。",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage("第三方內容"),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "本軟體僅供學習交流、技術研究等非商業用途。嚴禁將本軟體用於任何商業目的，包括但不限於付費分發、捆綁銷售、作為商業服務的組成部分或以本軟體名義開展經營活動；任何商業行為均與本軟體及其開發者無關。\n\n嚴禁將本軟體用於違反你所在國家或地區法律法規的活動，包括但不限於繞過依法設定的網路訪問限制、傳播違法資訊、實施網路攻擊或侵犯他人合法權益。",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("使用限制"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "本軟體按“現狀”和“可用”的原則提供，不附帶任何明示或默示的擔保，包括但不限於適銷性、特定用途適用性、不侵權以及持續可用、無錯誤、無安全漏洞的擔保。\n\n開發者不保證本軟體能滿足你的需求，也不保證本軟體的執行不會中斷或不會出現錯誤。",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("無擔保宣告"),
    "disconnected": MessageLookupByLibrary.simpleMessage("已中斷"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("發現新版本"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("更新 DNS 相關設定"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS 劫持"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "未新增時劫持所有發往 53 連接埠的 DNS 請求（any:53）。",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS 劫持"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage("關閉後，AAAA 查詢將回傳空結果"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS 模式"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "新增的項會覆寫所有 URL 和檔案配置的 DNS，未新增的項沿用配置自身的設定。自定義配置的 DNS 在其內容中設定。",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS 查詢"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage("核心 DNS 解析紀錄"),
    "docked": MessageLookupByLibrary.simpleMessage("固定"),
    "domain": MessageLookupByLibrary.simpleMessage("網域"),
    "done": MessageLookupByLibrary.simpleMessage("完成"),
    "download": MessageLookupByLibrary.simpleMessage("下載"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("下行頻寬"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("下載速度"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("下載流量"),
    "duration": MessageLookupByLibrary.simpleMessage("持續時間"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage("連線延遲"),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS 域"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage("功能旗標"),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("實例 ID"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "路徑延遲（延遲優先）",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("監聽位址"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage("本機端點"),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("封包遺失率"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage("最低直連延遲"),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage("下一跳節點 ID"),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage("路徑延遲（跳數優先）"),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("節點 ID"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage("傳輸通訊協定"),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage("公共伺服器"),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage("遠端端點"),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("路由成本"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage("接收封包數"),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage("傳送封包數"),
    "edit": MessageLookupByLibrary.simpleMessage("編輯"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("編輯儀表板"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("編輯全域規則"),
    "editProxy": MessageLookupByLibrary.simpleMessage("編輯代理"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("編輯策略群組"),
    "editRule": MessageLookupByLibrary.simpleMessage("編輯規則"),
    "editSsid": MessageLookupByLibrary.simpleMessage("編輯 SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("編輯器無法使用"),
    "elapsed": MessageLookupByLibrary.simpleMessage("耗時"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("空組兜底"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage("啟用外部控制器"),
    "enabled": MessageLookupByLibrary.simpleMessage("已開啟"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT 增強"),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "改善 UDP 與 P2P 應用程式的連線體驗",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("端點"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("強制路由"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "即使存在更精確的路由，也確保流量經過通道",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("筆項目"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("錯誤"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("錯誤詳情"),
    "es": MessageLookupByLibrary.simpleMessage("西班牙文"),
    "exclude": MessageLookupByLibrary.simpleMessage("從最近使用的應用程式中隱藏"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("排除 APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "允許 Apple 推播通知流量略過通道",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage("排除行動網路服務"),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "允許 Wi-Fi 通話等行動網路服務流量略過通道",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "應用程式在背景執行時，從最近使用的應用程式中隱藏",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "排除裝置間通訊",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "允許 AirDrop、AirPlay 等裝置間通訊流量略過通道",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("排除的目的地連接埠"),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "發往排除目的地連接埠的流量不通過 TUN。",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("排除篩選"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("排除網絡卡"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "從這些網路介面（例如 docker0）進入的流量不經過虛擬網路介面。",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage("排除本機網路"),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "允許直接存取本機網路上的裝置",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("排除節點篩選器"),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("排除的來源連接埠"),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "來自排除來源連接埠的流量不通過 TUN。",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("排除 SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "連線至排除清單中的 Wi-Fi SSID 時，自動切換應用程式執行狀態",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("排除類型"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("排除的使用者 ID"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "排除的使用者 ID 所屬程序的流量不通過 TUN。",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("結束"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("離開全螢幕"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("出口節點"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("預期狀態"),
    "expireTime": MessageLookupByLibrary.simpleMessage("到期時間"),
    "exportFile": MessageLookupByLibrary.simpleMessage("匯出檔案"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("匯出日誌"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("匯出成功"),
    "extend": MessageLookupByLibrary.simpleMessage("擴充套件"),
    "extendMode": MessageLookupByLibrary.simpleMessage("擴充套件模式"),
    "extendScript": MessageLookupByLibrary.simpleMessage("擴充套件指令碼"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部控制器"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "設定 Mihomo 核心的外部存取",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage("外部控制器金鑰"),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部取得"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部連結"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("超大"),
    "fade": MessageLookupByLibrary.simpleMessage("淡入"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("FakeIP 篩選"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "在 Fake IP 模式下，符合的網域會回傳真實 IP，而非 Fake IP",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IP過濾模式"),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Fake-IP 過濾模式中，blacklist 排除匹配項，whitelist 僅用於匹配項，rule 按規則匹配。",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("FakeIP 範圍"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP範圍（IPv6）"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("備用"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("一般使用境外 DNS 伺服器"),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "符合的網域直接使用 fallback，不查詢 nameserver",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("備用 DNS 篩選"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "依 GeoIP 代碼檢查 nameserver 的結果；若不屬於指定地區，則使用 fallback",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "符合這些 GeoSite 分類的網域直接使用 fallback",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver 的結果符合這些 CIDR 前綴時，改用 fallback 的結果",
    ),
    "features": MessageLookupByLibrary.simpleMessage("特性"),
    "file": MessageLookupByLibrary.simpleMessage("檔案"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("直接上傳設定檔"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage("檔案已修改，是否儲存變更？"),
    "fileName": MessageLookupByLibrary.simpleMessage("檔案名稱"),
    "filter": MessageLookupByLibrary.simpleMessage("篩選"),
    "filters": MessageLookupByLibrary.simpleMessage("篩選"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("尋找處理程序"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage("開啟後會增加部分效能負擔"),
    "floating": MessageLookupByLibrary.simpleMessage("懸浮"),
    "followProfile": MessageLookupByLibrary.simpleMessage("依照設定檔"),
    "followSystem": MessageLookupByLibrary.simpleMessage("跟隨系統"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("字型"),
    "fontSize": MessageLookupByLibrary.simpleMessage("大小"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("強制DNS對映"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "強制 DNS 對映對透過 DNS 對映得到域名的連線也進行嗅探。",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("強制嗅探域名"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "強制嗅探域名中的域名同樣會被嗅探，其餘已有域名的連線不嗅探。",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "確定要強制重新啟動核心嗎？",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("法文"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("應用程式與核心的一般設定"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "從 Age 私鑰產生",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("產生"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔必須大於 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geo 選項"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo 資源"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo 低記憶體模式"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後使用 Geo 低記憶體載入器",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP 代碼"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage("高效能 Geo 比對器"),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後使用最小完美雜湊演算法進行比對",
    ),
    "global": MessageLookupByLibrary.simpleMessage("全域"),
    "go": MessageLookupByLibrary.simpleMessage("前往"),
    "goDownload": MessageLookupByLibrary.simpleMessage("前往下載"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage("前往配置附加規則"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("前往設定指令碼"),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("協程數"),
    "grid": MessageLookupByLibrary.simpleMessage("格線"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("個群組"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("是否暫存變更？"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("按入站使用者雜湊"),
    "header": MessageLookupByLibrary.simpleMessage("標題"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("健康檢查"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper 服務無法使用，無法啟用 TUN 模式，請重新安裝 FlClash。",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("十六進位"),
    "hide": MessageLookupByLibrary.simpleMessage("隱藏"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("從清單中隱藏"),
    "hideIp": MessageLookupByLibrary.simpleMessage("隱藏 IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("隱藏密碼"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage("隱藏超時代理"),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "不顯示上次延遲測試超時的代理",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("隱藏逾時"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage("高優先順序自動啟動"),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "使用 Windows 工作排程器提早啟動",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("跳躍間隔"),
    "host": MessageLookupByLibrary.simpleMessage("主機"),
    "hostname": MessageLookupByLibrary.simpleMessage("主機名"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("追加 Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("快速鍵衝突"),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "全域快速鍵在視窗隱藏時仍然生效，點選操作即可錄製組合鍵。",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("快速鍵管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage("使用鍵盤控制應用程式"),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("未設定"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "無法註冊，可能已被其他應用程式占用",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("小時"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("色相"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP 轉發"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後支援 ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("圖片"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("圖示紀錄"),
    "iconSets": MessageLookupByLibrary.simpleMessage("圖示集"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "暫無圖示集，可在「自定義配置資源 → 圖示集」中新增",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("圖示來源"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("圖示樣式"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("色塊"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("隱藏"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("純圖示"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("圖示連結"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "忽略電池最佳化",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage("忽略憑證驗證"),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "允許使用無效憑證的 HTTPS 連線，這會降低安全性",
    ),
    "import": MessageLookupByLibrary.simpleMessage("匯入"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage("此檔案不是可匯入的配置"),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "匯入會替換此配置現有的策略組、規則和設定",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("透過檔案匯入"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("從連結匯入"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("從 URL 匯入"),
    "importUrl": MessageLookupByLibrary.simpleMessage("透過 URL 匯入"),
    "inbound": MessageLookupByLibrary.simpleMessage("入站"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage("包含所有網路"),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "將所有網路流量路由至通道，包括本機網路與行動網路服務",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("包含所有代理"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "引入所有代理，但不包含策略群組；可在下方額外新增策略群組",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage("包含所有代理集"),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "開啟後將覆蓋已引入的代理集",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage("包含的網路介面"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "僅從包含的網路介面進入的流量會通過 TUN，排除的網路介面不再生效。",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("包含的使用者 ID"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "僅包含的使用者 ID 所屬程序的流量會通過 TUN。",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("長期有效"),
    "init": MessageLookupByLibrary.simpleMessage("初始化"),
    "initFailed": MessageLookupByLibrary.simpleMessage("啟動失敗"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash 啟動時出錯，無法繼續執行。可以複製錯誤詳情用於反饋；如果問題反覆出現，清除資料後通常可以重新啟動。",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("初始化"),
    "initiator": MessageLookupByLibrary.simpleMessage("發起端"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("來源"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("請輸入正確的快速鍵"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage("輸入策略群組名稱"),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("輸入規則內容"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "讀取應用程式清單的權限已遭拒絕，無法取得已安裝的應用程式。請前往系統設定手動開啟權限。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "目前的系統在授權前不會提供已安裝的應用程式清單，授權後即可為各應用程式設定代理。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要讀取應用程式清單的權限",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("已安裝字型"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("智慧選擇"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("網路卡名稱"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage("出站連線使用的網路卡名稱"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage("出站網路卡"),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("清空"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("自訂"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("依照設定檔"),
    "internet": MessageLookupByLibrary.simpleMessage("網際網路"),
    "interval": MessageLookupByLibrary.simpleMessage("間隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("內網 IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無效備份檔案"),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "請輸入有效的檔案名稱，不得包含路徑分隔符號或特殊字元，且不得超過 255 位元組。",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "請輸入 CIDR 格式的 IP 段，如 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "請輸入有效的目錄，不得包含 . 或 .. 路徑區段、反斜線或特殊字元。",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP 標記不能超過 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage("請輸入域名或 IP 地址"),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("不是有效的圖示集"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage("不是有效的訂閱連結或代理分享連結"),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "請輸入地址和埠，如 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "僅支援 tcp 或 udp",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "請輸入埠或範圍，如 443 或 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "該二維碼不包含配置檔案連結",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "請輸入數字或範圍，如 80 或 8000-9000，多個用 / 分隔",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP 地址"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("濫用記錄"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("代理"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("命中標記"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("組織"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage("型別查詢失敗"),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("優"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("等級"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("重新查詢"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("風險"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("品質"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("採用來源"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("各來源"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage("出站 IP 不一致"),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("無法判定型別"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("限流"),
    "ipType": MessageLookupByLibrary.simpleMessage("型別"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("商業"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("機房"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("行動網路"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("住宅"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("未知類型"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP 版本"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP／遮罩"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("開啟後將可以接收 IPv6 流量"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("允許 IPv6 入站"),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6超時（毫秒）"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("日語"),
    "justNow": MessageLookupByLibrary.simpleMessage("剛剛"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP 保持活動空閒時間"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage("TCP 保持連線間隔"),
    "key": MessageLookupByLibrary.simpleMessage("鍵"),
    "ko": MessageLookupByLibrary.simpleMessage("韓文"),
    "label": MessageLookupByLibrary.simpleMessage("標籤"),
    "language": MessageLookupByLibrary.simpleMessage("語言"),
    "large": MessageLookupByLibrary.simpleMessage("大"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("上次更新"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("啟動未完成"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "應用上次在啟動過程中意外退出。已跳過本次自動配置，你可以手動啟動重試。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("佈局"),
    "level": MessageLookupByLibrary.simpleMessage("等級"),
    "light": MessageLookupByLibrary.simpleMessage("淺色"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("行距"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("自動換行"),
    "link": MessageLookupByLibrary.simpleMessage("連結"),
    "linkDesc": MessageLookupByLibrary.simpleMessage("透過訂閱連結或代理分享連結獲取配置檔案"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("清單"),
    "listen": MessageLookupByLibrary.simpleMessage("監聽"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("監聽路由標記"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "監聽路由標記僅在 Linux 生效。",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("監聽連接埠"),
    "liveConnections": MessageLookupByLibrary.simpleMessage("實時連線"),
    "loading": MessageLookupByLibrary.simpleMessage("載入中…"),
    "local": MessageLookupByLibrary.simpleMessage("本機"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("備份資料到本機"),
    "localImage": MessageLookupByLibrary.simpleMessage("本地圖片"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "本地網路許可權被拒絕：已改用 gvisor 棧，區域網無法訪問。",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("本地代理"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置權限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置權限已遭拒絕，無法取得目前的 Wi-Fi 名稱。請前往系統設定手動開啟位置權限。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "依系統要求，取得 Wi-Fi 名稱需要位置權限。在 Android 上請選擇「一律允許」，否則應用程式在背景執行時無法取得 Wi-Fi 名稱。",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要位置權限",
    ),
    "log": MessageLookupByLibrary.simpleMessage("日誌"),
    "logLevel": MessageLookupByLibrary.simpleMessage("日誌等級"),
    "logcat": MessageLookupByLibrary.simpleMessage("擷取日誌"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("停用後隱藏日誌入口"),
    "logs": MessageLookupByLibrary.simpleMessage("日誌"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("日誌與診斷"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("擷取的日誌紀錄"),
    "logsTest": MessageLookupByLibrary.simpleMessage("日誌測試"),
    "loopback": MessageLookupByLibrary.simpleMessage("迴路解鎖工具"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("解除 UWP 迴路限制"),
    "loose": MessageLookupByLibrary.simpleMessage("寬鬆"),
    "manual": MessageLookupByLibrary.simpleMessage("手動"),
    "matchCase": MessageLookupByLibrary.simpleMessage("區分大小寫"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("比對來源 IP"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "目標為 MATCH-TARGET 的規則會路由至此處，預設使用此設定檔末尾 MATCH 規則的目標。",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("比對目標"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗次數"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("應用程式記憶體"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("常駐記憶體"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("應用及共享"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("清理"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("堆記憶體空閒"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("堆記憶體使用中"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage("核心未執行"),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("執行時開銷"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("協程棧"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "基於程序常駐記憶體估算，可能與系統顯示的數值不同。",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "核心與應用執行在同一程序，核心部分按執行時統計估算，其餘計入應用及共享記憶體。",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage("處理程序實體記憶體用量"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("GC 中繼資料"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage("保留的閒置堆積"),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("堆積物件"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("已歸還系統"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage("堆積內未使用的空間"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("記憶體資訊"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("應用程式與核心使用的記憶體"),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage("執行階段中繼資料"),
    "memoryOther": MessageLookupByLibrary.simpleMessage("其他執行階段記憶體"),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage("無法讀取記憶體，正在重試…"),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("記憶體已釋放"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("堆疊"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Go 記憶體用量"),
    "messageTest": MessageLookupByLibrary.simpleMessage("訊息測試"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("這是一則訊息。"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("結束時最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage("變更系統預設的結束行為"),
    "minutes": MessageLookupByLibrary.simpleMessage("分鐘"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合連接埠"),
    "mode": MessageLookupByLibrary.simpleMessage("模式"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("單色"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage("單色系統匣圖示"),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("更多"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU 必須是 1 到 65535 之間的整數",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage("多個值請以逗號分隔"),
    "name": MessageLookupByLibrary.simpleMessage("名稱"),
    "nameserver": MessageLookupByLibrary.simpleMessage("DNS 伺服器"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("用於解析網域"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("DNS 伺服器策略"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "為符合的網域、GeoSite 分類或規則集指定 DNS 伺服器",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("底欄"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("需要登入"),
    "network": MessageLookupByLibrary.simpleMessage("網路"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage("請求已取消"),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "無法連線到伺服器，請檢查網路連線或代理設定",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage("修改網路相關設定"),
    "networkException": MessageLookupByLibrary.simpleMessage("網路異常，請檢查連線後重試"),
    "networkExtension": MessageLookupByLibrary.simpleMessage("網路延伸功能"),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "無法解析伺服器地址，請確認連結正確且 DNS 可用",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("網路 ID"),
    "networkName": MessageLookupByLibrary.simpleMessage("網路名稱"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("網路不存在"),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "請求過於頻繁（HTTP 429），請稍後再試",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("網路密碼"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("網速"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage("顯示即時網速"),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "在系統狀態區域顯示即時網速，可能稍微增加耗電量",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("流量接管"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "請求超時，請檢查網路或代理後重試",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "安全連線失敗，伺服器證書可能無效，或連線被攔截",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("網路類型"),
    "networking": MessageLookupByLibrary.simpleMessage("組網"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage("檢視點對點組網狀態"),
    "networkingError": MessageLookupByLibrary.simpleMessage("錯誤"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "目前設定中沒有點對點組網的出站",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("新增"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage("手動編寫設定檔"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("下一個符合項目"),
    "no": MessageLookupByLibrary.simpleMessage("否"),
    "noData": MessageLookupByLibrary.simpleMessage("暫無資料"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("沒有子目錄"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage("目前沒有篩選條件"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("目前沒有快速鍵"),
    "noInfo": MessageLookupByLibrary.simpleMessage("暫無資訊"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("不再提醒"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("無網路"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("無網路應用程式"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage("未找到遠端備份"),
    "noResolve": MessageLookupByLibrary.simpleMessage("不解析 IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("不解析主機名稱"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("沒有匹配的結果"),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "無法讀取流量，正在重試…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("節點流量"),
    "nodes": MessageLookupByLibrary.simpleMessage("節點"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage("該外部資源不是文字檔案"),
    "none": MessageLookupByLibrary.simpleMessage("無"),
    "notRunning": MessageLookupByLibrary.simpleMessage("未執行"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("無法選取目前的代理群組"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("更新 NTP 相關設定"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("同步間隔（分鐘）"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "從 NTP 伺服器取得時間，取代系統時鐘",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("沒有設定檔，請先新增設定檔"),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("混淆"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("混淆主機"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("混淆模式"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("混淆引數"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("混淆密碼"),
    "offline": MessageLookupByLibrary.simpleMessage("離線"),
    "onDemand": MessageLookupByLibrary.simpleMessage("按需執行"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage("設定應用程式在特定情境下的執行狀態"),
    "online": MessageLookupByLibrary.simpleMessage("上線"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("僅設定檔"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("僅 Emoji"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("僅圖示"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("僅統計代理"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後，將只統計代理流量",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("在 GitHub 開啟"),
    "optional": MessageLookupByLibrary.simpleMessage("可選"),
    "options": MessageLookupByLibrary.simpleMessage("選項"),
    "other": MessageLookupByLibrary.simpleMessage("其他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("其他貢獻者"),
    "outbound": MessageLookupByLibrary.simpleMessage("出站"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("出口"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("出站 IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("出站模式"),
    "override": MessageLookupByLibrary.simpleMessage("覆寫"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("覆蓋目標地址"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "覆蓋目標地址使用嗅探到的域名替換原目標地址發起連線。",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("覆寫 DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後將覆蓋設定檔中的 DNS 選項",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("覆寫項"),
    "overrideMode": MessageLookupByLibrary.simpleMessage("覆寫模式"),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("覆寫 NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "開啟後將覆蓋設定檔中的 NTP 選項",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage("覆寫指令碼"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("自訂"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "自訂模式，可完整自訂代理群組與規則",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("上一層目錄"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("解析純IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "解析純 IP 會嗅探只有 IP 地址的連線。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("密碼"),
    "paste": MessageLookupByLibrary.simpleMessage("貼上"),
    "peers": MessageLookupByLibrary.simpleMessage("初始節點"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("從相簿選擇"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("視窗置頂"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("請綁定 WebDAV"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage("請輸入指令碼名稱"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "請上傳有效的 QR 碼",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("外掛"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("外掛主機"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("外掛模式"),
    "port": MessageLookupByLibrary.simpleMessage("連接埠"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("請輸入不同的連接埠"),
    "portHopping": MessageLookupByLibrary.simpleMessage("埠跳躍"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("埠"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage("請輸入大於 0 的整數"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("預共享金鑰"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("預測式返回"),
    "preferH3": MessageLookupByLibrary.simpleMessage("優先使用 HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("優先使用 DoH 的 HTTP/3"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前置條件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("請按下按鍵"),
    "preview": MessageLookupByLibrary.simpleMessage("預覽"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("上一個符合項目"),
    "privateKey": MessageLookupByLibrary.simpleMessage("私鑰"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("私鑰密碼"),
    "process": MessageLookupByLibrary.simpleMessage("處理程序"),
    "profile": MessageLookupByLibrary.simpleMessage("設定檔"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("請輸入有效的更新間隔"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("請輸入自動更新間隔"),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "設定檔已修改，是否關閉自動更新？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "請輸入設定檔名稱",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "僅作用於當前配置，未新增的項使用預設值。",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "僅適用於此設定檔，並優先於網路設定中的 TUN 覆寫項目。",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "請輸入有效的設定檔 URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "請輸入設定檔 URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("設定檔"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("設定檔排序"),
    "project": MessageLookupByLibrary.simpleMessage("專案"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage("關閉連線提示"),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "切換節點後詢問是否關閉連線",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("協議"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("協議引數"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("協議版本"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("僅支援遠端資源"),
    "providers": MessageLookupByLibrary.simpleMessage("外部資源"),
    "proxies": MessageLookupByLibrary.simpleMessage("代理"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("代理"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("代理鏈"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage("偵測到選取的代理異常"),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("節點篩選器"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("策略群組"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "偵測到目前策略群組異常",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("策略群組為空"),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage("策略群組名稱不能為空"),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "核心啟動後會在此顯示群組",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("代理 DNS 伺服器"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage("用於解析代理節點的網域"),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "代理 DNS 伺服器策略",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "指定代理節點的 DNS 伺服器策略",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("代理集"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "偵測到選取的代理集異常",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("代理集"),
    "proxyType": MessageLookupByLibrary.simpleMessage("代理類型"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("清理快取"),
    "publicKey": MessageLookupByLibrary.simpleMessage("公鑰"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("純黑"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("純黑模式"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR 碼"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("掃描 QR 碼取得設定檔"),
    "query": MessageLookupByLibrary.simpleMessage("查詢"),
    "queryDns": MessageLookupByLibrary.simpleMessage("查詢 DNS"),
    "queryRule": MessageLookupByLibrary.simpleMessage("規則查詢"),
    "quickActions": MessageLookupByLibrary.simpleMessage("快捷操作"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("快速編輯"),
    "quickFill": MessageLookupByLibrary.simpleMessage("一鍵填入"),
    "random": MessageLookupByLibrary.simpleMessage("隨機"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("最近請求"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("推薦"),
    "recordType": MessageLookupByLibrary.simpleMessage("紀錄類型"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("啟用 RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage("在 Darwin 上批次接收封包"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir 連接埠"),
    "redo": MessageLookupByLibrary.simpleMessage("重做"),
    "regex": MessageLookupByLibrary.simpleMessage("正則"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("規則運算式搜尋"),
    "relayed": MessageLookupByLibrary.simpleMessage("中繼"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("釋放記憶體"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage("釋放記憶體失敗"),
    "remote": MessageLookupByLibrary.simpleMessage("遠端"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage("備份資料到 WebDAV"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("遠端目標"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("遠端 DNS 解析"),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rename": MessageLookupByLibrary.simpleMessage("重新命名"),
    "replace": MessageLookupByLibrary.simpleMessage("替換"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("全部替換"),
    "request": MessageLookupByLibrary.simpleMessage("請求"),
    "requests": MessageLookupByLibrary.simpleMessage("請求"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("請求與更新"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("檢視最近的請求紀錄"),
    "required": MessageLookupByLibrary.simpleMessage("必填"),
    "reset": MessageLookupByLibrary.simpleMessage("重置"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "目前頁面存在更改，確定重置嗎？",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage("設定檔與指令碼"),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage("應用程式設定"),
    "resetTip": MessageLookupByLibrary.simpleMessage("確定要重置嗎？"),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔必須大於0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("資源"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部資源相關資訊"),
    "respectRules": MessageLookupByLibrary.simpleMessage("遵守規則"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS 連線遵循 rules，需設定 proxy-server-nameserver",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("回應碼"),
    "restart": MessageLookupByLibrary.simpleMessage("重新啟動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("確定要重新啟動核心嗎？"),
    "restore": MessageLookupByLibrary.simpleMessage("還原"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("還原所有資料"),
    "restoreException": MessageLookupByLibrary.simpleMessage("還原異常"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage("透過檔案還原資料"),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "透過 WebDAV 還原資料",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage("還原隱藏群組"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("僅還原設定檔"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("還原策略"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("相容"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("覆蓋"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("還原成功"),
    "result": MessageLookupByLibrary.simpleMessage("結果"),
    "retry": MessageLookupByLibrary.simpleMessage("重試"),
    "role": MessageLookupByLibrary.simpleMessage("角色"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("路由位址"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("設定要監聽的路由位址"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("排除路由地址"),
    "routeMode": MessageLookupByLibrary.simpleMessage("路由模式"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage("略過私有路由位址"),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("使用設定檔"),
    "routes": MessageLookupByLibrary.simpleMessage("路由"),
    "routingMark": MessageLookupByLibrary.simpleMessage("路由標記"),
    "ru": MessageLookupByLibrary.simpleMessage("俄語"),
    "rule": MessageLookupByLibrary.simpleMessage("規則"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("邏輯規則 AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("比對完整網域"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "比對網域關鍵字",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用網域規則運算式比對",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "比對網域後綴",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用萬用字元比對，僅支援 * 與 ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "比對 DSCP 標記（僅適用於 tproxy UDP 入站）",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "比對請求目標連接埠範圍",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("比對 IP 所屬國家代碼"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "比對 GeoSite 內的網域",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("比對入站名稱"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage("比對入站連接埠"),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage("比對入站類型"),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "比對入站使用者名稱，可用 / 分隔多個名稱",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("比對 IP 所屬 ASN"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "比對 IP 位址範圍，IP-CIDR6 只是一個別名",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage("比對 IP 位址範圍"),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "比對 IP 後綴範圍",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage("比對所有請求，無需條件"),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "比對 TCP 或 UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("邏輯規則 NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("邏輯規則 OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "依處理程序比對；在 Android 平台可比對套件名稱",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用處理程序名稱的規則運算式比對；在 Android 平台可比對套件名稱",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用處理程序名稱的萬用字元比對，僅支援 * 與 ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "使用完整處理程序路徑比對",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用處理程序路徑規則運算式比對",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用處理程序路徑的萬用字元比對，僅支援 * 與 ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "比對重新比對名稱，多個名稱以 / 分隔",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "引用規則集合，需設定 rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "比對來源 IP 所屬國家代碼",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "比對來源 IP 所屬 ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "比對來源 IP 位址範圍",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "比對來源 IP 後綴範圍",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "比對請求來源連接埠範圍",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "比對至子規則，請留意括號的使用方式",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "比對 Linux USER ID",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("已停用"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("規則為空"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("已啟用"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("命中"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("最後命中"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage("最後未命中"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "規則必須是 YAML 列表，每項一條規則，例如 - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("未命中"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BT 下載直連",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "遮蔽 DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage("防止代理迴環"),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("遮蔽 QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("遮蔽 STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("區域網直連"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple 與 Microsoft 直連",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("規則集"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage("目標 IP"),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage("入站名稱"),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage("入站使用者"),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage("請輸入有效的 IP 位址。"),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "未命中規則（模式策略或 DIRECT 回退）",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "請輸入 1 到 65535 之間的連接埠。",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage("程序路徑"),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage("嗅探網域"),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("來源連接埠"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage("網域或 IP 位址"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("規則集"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage("規則集中沒有可用的條目"),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage("無法讀取該 mrs 檔案"),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "規則集同時包含域名和 IP 段，無法判斷型別",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("規則目標"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "規則必須以受支援的型別開頭，例如 DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("規則類型"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "無法變更規則，設定可能已變更，請重新整理後再試。",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("規則"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage("檢視規則及匹配統計"),
    "runTime": MessageLookupByLibrary.simpleMessage("執行時長"),
    "running": MessageLookupByLibrary.simpleMessage("執行中"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("執行中設定"),
    "safeMode": MessageLookupByLibrary.simpleMessage("安全模式"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("飽和度"),
    "save": MessageLookupByLibrary.simpleMessage("儲存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("是否儲存變更？"),
    "script": MessageLookupByLibrary.simpleMessage("指令碼"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "指令碼模式，使用外部擴充指令碼，一鍵覆寫設定",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("捲動至選取項目"),
    "search": MessageLookupByLibrary.simpleMessage("搜尋"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("金鑰"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("全選"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "選擇 MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage("選擇備份"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("請選擇規則集"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage("請選擇分流策略"),
    "selected": MessageLookupByLibrary.simpleMessage("已選取"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("啟用 SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage("在 Darwin 上批次傳送封包"),
    "server": MessageLookupByLibrary.simpleMessage("伺服器"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("全部可用"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("可用"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("已被封禁"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("檢測"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("全部檢測"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("即將上線"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage("不允許的 ISP"),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("檢測失敗"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("管理服務"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("僅限自制內容"),
    "servicePending": MessageLookupByLibrary.simpleMessage("待檢測"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("訪問受限"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage("已顯示於儀表板"),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("服務狀態"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("不可用"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage("地區不支援"),
    "settingEntries": MessageLookupByLibrary.simpleMessage("設定項"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage("無法從連結中讀取代理"),
    "show": MessageLookupByLibrary.simpleMessage("顯示"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("顯示隱藏群組"),
    "showLess": MessageLookupByLibrary.simpleMessage("收合"),
    "showMore": MessageLookupByLibrary.simpleMessage("展開"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "通知列顯示停止按鈕",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "在常駐通知中顯示停止按鈕。若系統因此總是展開通知，可關閉此選項",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("顯示密碼"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "顯示目前設定檔名稱",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "連線時在快捷開關上顯示設定檔名稱",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage("在系統匣中選擇代理"),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "在系統匣選單中顯示代理群組與節點，方便快速切換",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("顯示逾時"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("側邊欄背景模糊"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage("側邊欄透出視窗後方模糊的桌面"),
    "signIn": MessageLookupByLibrary.simpleMessage("登入"),
    "signOut": MessageLookupByLibrary.simpleMessage("登出"),
    "signedIn": MessageLookupByLibrary.simpleMessage("已登入"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("靜默啟動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("在背景啟動"),
    "singleAdd": MessageLookupByLibrary.simpleMessage("單條新增"),
    "singleImport": MessageLookupByLibrary.simpleMessage("單條匯入"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "這裡只能填寫一條連結，多條請在列表的快速編輯中填寫",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("尺寸"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("跳過證書驗證"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("跳過域名"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage("嗅探到跳過域名中的域名時不予採用。"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("跳過目標地址"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("跳過來源地址"),
    "slide": MessageLookupByLibrary.simpleMessage("滑動"),
    "sliders": MessageLookupByLibrary.simpleMessage("滑桿"),
    "small": MessageLookupByLibrary.simpleMessage("小"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("協議"),
    "sniffer": MessageLookupByLibrary.simpleMessage("域名嗅探"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "域名嗅探從 TLS、HTTP、QUIC 流量中識別域名，供規則匹配。",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks 連接埠"),
    "softStyle": MessageLookupByLibrary.simpleMessage("柔和"),
    "sort": MessageLookupByLibrary.simpleMessage("排序"),
    "source": MessageLookupByLibrary.simpleMessage("來源"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("來源 IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊代理"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊規則"),
    "spectrum": MessageLookupByLibrary.simpleMessage("光譜"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("網速統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("分流策略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage("分流策略不能為空"),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs 為空"),
    "stackMode": MessageLookupByLibrary.simpleMessage("堆疊模式"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("堆疊資訊"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準模式，覆寫基本設定並支援新增規則",
    ),
    "start": MessageLookupByLibrary.simpleMessage("啟動"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("從零開始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("正在啟動 VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("啟動與背景"),
    "status": MessageLookupByLibrary.simpleMessage("狀態"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("關閉後將使用系統 DNS"),
    "stop": MessageLookupByLibrary.simpleMessage("暫停"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("正在停止 VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("已停止"),
    "strategy": MessageLookupByLibrary.simpleMessage("策略"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("嚴格路由"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "嚴格路由可防止 DNS 等流量繞過虛擬網路介面，關閉 IPv6 時會阻擋本機的 IPv6 連線。",
    ),
    "style": MessageLookupByLibrary.simpleMessage("風格"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("樣式設定"),
    "submit": MessageLookupByLibrary.simpleMessage("提交"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("訂閱資訊"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage("輸入 sudo 密碼"),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("休眠支援"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "裝置閒置時暫停核心，以降低耗電量",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("暫停中…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage("滑動切換頁面"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("切換配置"),
    "sync": MessageLookupByLibrary.simpleMessage("同步"),
    "system": MessageLookupByLibrary.simpleMessage("系統"),
    "systemApp": MessageLookupByLibrary.simpleMessage("系統應用程式"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("系統代理"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("設定系統的 HTTP 代理"),
    "tab": MessageLookupByLibrary.simpleMessage("分頁"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("分頁動畫"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("僅在行動裝置檢視中生效"),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("活躍"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage("目前端點"),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS 名稱"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("端點"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("出口節點"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "可用作出口節點",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("健康狀態"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage("健康警告"),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("金鑰已過期"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("金鑰到期"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage("最後交握"),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("最後上線"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage("需要核准裝置"),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("節點金鑰"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP 中繼"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("子網路"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("標籤"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("輕觸圖示以重試"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("點選授權"),
    "target": MessageLookupByLibrary.simpleMessage("目標"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP 並行"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("開啟後允許 TCP 並行"),
    "testInterval": MessageLookupByLibrary.simpleMessage("測試間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("測速連結"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時測試"),
    "textReplacement": MessageLookupByLibrary.simpleMessage("文字替換："),
    "textScale": MessageLookupByLibrary.simpleMessage("文字縮放"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage("應用內的文字將以這個大小顯示"),
    "theme": MessageLookupByLibrary.simpleMessage("主題"),
    "themeColor": MessageLookupByLibrary.simpleMessage("主題色彩"),
    "themeMode": MessageLookupByLibrary.simpleMessage("主題模式"),
    "tight": MessageLookupByLibrary.simpleMessage("緊密"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "timeout": MessageLookupByLibrary.simpleMessage("逾時"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("染色"),
    "tip": MessageLookupByLibrary.simpleMessage("提示"),
    "toggle": MessageLookupByLibrary.simpleMessage("切換"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("切換標籤"),
    "tolerance": MessageLookupByLibrary.simpleMessage("容差"),
    "tools": MessageLookupByLibrary.simpleMessage("工具"),
    "torch": MessageLookupByLibrary.simpleMessage("手電筒"),
    "total": MessageLookupByLibrary.simpleMessage("總計"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("已下載"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("總流量"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("已上傳"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxy 連接埠"),
    "traffic": MessageLookupByLibrary.simpleMessage("流量"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("雙向"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("流量統計"),
    "transport": MessageLookupByLibrary.simpleMessage("傳輸協議"),
    "tun": MessageLookupByLibrary.simpleMessage("虛擬網路卡"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "虛擬網絡卡授權失敗，已關閉。",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("僅在系統管理員模式下生效"),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("系統 DNS 模式"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("不設定"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("劫持"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("原生"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "此處新增的項目會覆寫所有設定檔的 TUN 設定；未新增的項目保留設定檔原值。自訂設定檔自行新增的項目優先。",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("關閉"),
    "turnOn": MessageLookupByLibrary.simpleMessage("開啟"),
    "tvMode": MessageLookupByLibrary.simpleMessage("電視模式"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage("在此裝置上使用遙控器佈局"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP 中繼模式"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP 逾時"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP 逾時以秒為單位，僅適用於 gvisor、system 和 mixed 協定堆疊。",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage("閒置更新週期"),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "失去焦點時閒置",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "應用程式視窗失去焦點時，使用閒置更新週期",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage("UI 資訊更新週期"),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("極致"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("未授權"),
    "undo": MessageLookupByLibrary.simpleMessage("撤銷"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一延遲"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage("排除交握等額外延遲"),
    "uninitialized": MessageLookupByLibrary.simpleMessage("未初始化"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "未知變數，請選擇下方支援的變數。",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("未知網路錯誤"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("還原視窗"),
    "unnamed": MessageLookupByLibrary.simpleMessage("未命名"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("取消置頂"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "下載的檔案與發佈的校驗值不符，已捨棄。",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("正在下載更新"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage("無法啟動安裝程式。"),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash 未獲得安裝應用程式的權限，因此未安裝更新。",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash 無法寫入其安裝目錄，請手動下載更新。",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("立即更新"),
    "upload": MessageLookupByLibrary.simpleMessage("上傳"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("上行頻寬"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("上傳速度"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("上傳流量"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("透過 URL 取得設定檔"),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("使用 Hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "查詢上游 DNS 前，先比對設定中的 hosts",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("使用系統 Hosts"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "解析網域時，比對作業系統的 Hosts 檔案",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("已用"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("已用流量"),
    "userAgent": MessageLookupByLibrary.simpleMessage("使用者代理"),
    "username": MessageLookupByLibrary.simpleMessage("使用者名稱"),
    "value": MessageLookupByLibrary.simpleMessage("值"),
    "version": MessageLookupByLibrary.simpleMessage("版本"),
    "view": MessageLookupByLibrary.simpleMessage("檢視"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("虛擬 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("鮮明"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "偵測到 VPN 相關設定變更",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "透過 VpnService 自動路由所有系統流量",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV 設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("白名單模式"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("寫入系統"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage("同時設定系統時鐘"),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("是"),
    "zhCN": MessageLookupByLibrary.simpleMessage("簡體中文"),
    "zhTW": MessageLookupByLibrary.simpleMessage("正體中文"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage("有問題，我們在這裡"),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "查看開通與續費訂單",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage("登入密碼"),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "依你的習慣連線",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage("屬於你的連線空間。"),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("我的帳戶"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("開通中"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("進階設定"),
    "zolnitAdvancedHint": MessageLookupByLibrary.simpleMessage("查看連線設定與更多選項"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("全部節點"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("全部地區"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("應付金額"),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("帳戶餘額"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage("按月付費，輕鬆開始"),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "暫時無法取得續訂資訊。",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("建立訂單"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("取消訂單"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "確認取消這個待付款訂單？",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage("取消自動續訂"),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "停止後續自動扣款；首期尚未付款的訂單也會取消。已付權益以伺服器結果為準。",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("已取消"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage("修改密碼"),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "已有一筆結算正在處理，請在帳號頁查看狀態，請勿重複提交。",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "結算工作階段正在準備或核對，請稍後重試。",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("選擇方案"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("已完成"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage("輕輕一點，即刻連線"),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage("啟動後自動連線"),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "使用上一次選擇的訂閱設定檔。",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "選擇你的線路，剩下的交給 ZolNit。",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("複製邀請碼"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("複製連結"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "請輸入有效電子郵件和至少八位密碼。",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("已折抵"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("目前方案"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("目前選擇"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("半年"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("季"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("三年"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("兩年"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("年"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("天"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "這裡顯示帳戶的登入工作階段，與節點的線上 IP 數不同。",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage("登入工作階段"),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "暫時無法取得登入工作階段，請重試。",
    ),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("電子郵件"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage("熟悉的多端體驗"),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage("操作未完成，請檢查輸入或網路後重試。"),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("首期付款"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage("後續付款"),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage("忘記密碼？"),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("贈送權益"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "首期付款確認後開始付費週期，並取代剩餘贈送時間。",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage("全球優選線路"),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage("準備好，去看看更大的世界。"),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("半年付"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage("說明與支援"),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("邀請碼"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage("邀請碼已複製"),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "可用佣金",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "已確認佣金",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "待確認佣金",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage("佣金比例"),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage("邀請連結已複製"),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage("產生邀請碼"),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "產生邀請碼失敗，請重試。",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage("好體驗，值得分享。"),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage("邀請連結"),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "暫時無法取得邀請資料，請重試。",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage("邀請好友，從這裡開始。"),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("人"),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage("已註冊"),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage("邀請規則"),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage("你的專屬邀請"),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "好友透過連結註冊並開通方案後，你將獲得邀請獎勵。",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "邀請好友註冊並開通方案，獲得一份獎勵。",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("延遲"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage("最新公告"),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "不必研究複雜設定。你想去的世界，輕輕一點就到。",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage("離你的世界，再近一點"),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "登入你的帳戶，管理方案與連線。",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage("註冊或找回密碼"),
    "zolnitMembershipEyebrow": MessageLookupByLibrary.simpleMessage(
      "YOUR MEMBERSHIP",
    ),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("全域模式"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage("智慧分流"),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("月付"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage("連續包月"),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("我的空間"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("新密碼"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage("下次續訂"),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "你還沒有有效方案，選擇一個開始使用。",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage("暫無可顯示的登入工作階段。"),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "沒有符合的節點，試試其他關鍵字或地區。",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage("暫無可用付款方式"),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage("目前訂閱暫無可用節點。"),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage("暫無公告"),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("暫無訂單"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("暫無有效方案"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage("暫無自動續訂合約"),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "延遲以最近一次實際檢測為準，未檢測時顯示 —。",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("節點名稱"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "同步訂閱後，選擇設定檔中的節點。",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("你的世界，從這裡出發。"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "選擇一條喜歡的線路，輕鬆連線。",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage("目前尚未連線"),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("公告"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage("目前密碼"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("一次性"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage("線上裝置"),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("訂單紀錄"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("已付權益"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("已付權益截止"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "請輸入目前密碼，並使用至少八個字元的不同新密碼。",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage("密碼已更新。"),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("前往付款"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "付款返回後仍需確認訂單狀態。",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage("付款狀態"),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "此付款方式尚未就緒。",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("待付款"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "你有一筆待處理訂單，請在「訂單」中繼續付款或關閉後再下單。",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ 月"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "首期付款或原方案剩餘價值折抵確認後，開始新方案週期。",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage("方案有效期"),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("方案"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage(
      "剛剛好的方案，剛剛好的自由。",
    ),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "從日常瀏覽到流暢影音，選擇適合你的連線方式。",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("偏好設定"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage(
      "依你的習慣連線。",
    ),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "安全模式會保留你的偏好，但不會自動連線或變更系統網路。",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "只留下真正需要的幾項偏好。",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "節點與分流規則由 ZolNit 自動同步。",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("季付"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "先查看伺服器報價，再授權自動續費。",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "結算報價已過期，請返回方案頁重新選擇。",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage("操作過於頻繁，請稍後重試。"),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage("為你推薦的節點"),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "就近優選，讓連線再快一點",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage("推薦線路"),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "我同意按所顯示的首期付款及後續續費條款為此方案連續付款。",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "目前暫時無法為此方案開通連續包月。",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("重新整理"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("註冊"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "註冊和找回密碼將在 ZolNit 官網完成電郵與安全驗證。",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage("續約目前方案"),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("續約方案"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage("自動續訂"),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage("重設流量"),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage("恢復自動續訂"),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "恢復後將按已授權的方案安排自動扣款。",
    ),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage("登出此工作階段"),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "登入工作階段已結束。",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "結束此登入工作階段？該裝置需重新登入才能管理帳戶。",
    ),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "安全模式不會修改系統網路。",
    ),
    "zolnitSavePercent": m101,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage("搜尋節點或地區"),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("選擇"),
    "zolnitSessionOnly": MessageLookupByLibrary.simpleMessage(
      "登入狀態僅保留到本次應用程式關閉。",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("登入"),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("登出"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage("開機時啟動 ZolNit"),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "開啟裝置後，讓 ZolNit 提前準備好。",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("使用中"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("已到期"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("未訂閱"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage("選擇方案"),
    "zolnitSync": MessageLookupByLibrary.simpleMessage("同步連線設定"),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage("連線設定已同步"),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage("正在同步連線設定…"),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("帳戶資訊"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("邀請有禮"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("訂單記錄"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage("讓連線回歸簡單。"),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("三年付"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("剩餘流量"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage("本期已用流量"),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("兩年付"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage("登入工作階段"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage("查看包月報價"),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage("開啟 ZolNit 網站"),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("歡迎回來"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("我的空間"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("年付"),
  };
}

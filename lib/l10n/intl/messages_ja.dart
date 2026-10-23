// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(count, skipped) => "${count}件を追加、${skipped}件は既存のためスキップ";

  static String m1(detail) => "データを消去できませんでした：${detail}";

  static String m2(code) =>
      "Windows が FlClashCore.exe の実行を拒否しました（エラー ${code}）。スマート アプリ コントロールや AppLocker などのアプリ制御ポリシーは未署名のプログラムをブロックします。ポリシーで FlClash を許可するか、ポリシーを無効にしてから再試行してください。";

  static String m3(name) =>
      "アプリの起動が2回連続で完了しませんでした。クラッシュループを断ち切るため、プロファイル ${name} の選択を解除し、今回の自動セットアップをスキップしました。いつでも選択し直せます。";

  static String m4(url) => "${url} からプロファイルを作成しますか？";

  static String m5(count, label) =>
      "${Intl.plural(count, other: 'カスタム設定はサブルールに対応していないため、SUB-RULE ルール ${label} 件を破棄しました')}";

  static String m6(message) => "コアがこのプロキシを解析できません：${message}";

  static String m7(proxy, target) =>
      "${proxy} は ${target} 経由で接続しますが、${target} から再び ${proxy} に戻るため、ループになります";

  static String m8(name) => "名前 ${name} は他のプロキシまたはプロキシグループで使用されています";

  static String m9(path) => "プロキシグループが循環参照しています：${path}";

  static String m10(name) =>
      "空グループのフォールバックはプロキシである必要がありますが、${name} は存在しないかプロキシグループです";

  static String m11(name, message) => "${name}は有効な正規表現ではありません：${message}";

  static String m12(name) => "ダイヤラープロキシ ${name} が存在しません";

  static String m13(names) => "次のプロキシプロバイダーは存在しません：${names}";

  static String m14(names) => "次のプロキシまたはポリシーは存在しません：${names}";

  static String m15(name) => "${name} は組み込みポリシー名のため使用できません";

  static String m16(count) => "${count} 件に問題があり、プロファイルの適用に失敗する可能性があります";

  static String m17(count) => "${count} 日前";

  static String m18(count) => "${count} 日前";

  static String m19(label) => "選択した${label}を削除してもよろしいですか？";

  static String m20(label) => "この${label}を削除してもよろしいですか？";

  static String m21(label) => "${label}の詳細";

  static String m22(name) => "${name} 経由の接続が使用元のプロキシに戻るため、接続を中止しました";

  static String m23(label) => "${label}は空にできません";

  static String m24(count) => "${count} 件";

  static String m25(label) => "${label}はすでに存在します";

  static String m26(count) => "${count} 件が失敗しました";

  static String m27(label, message) => "${label}：${message}";

  static String m28(name) => "${name} はすでに最新です";

  static String m29(name) => "${name} を更新しました";

  static String m30(name) => "${name}を更新中...";

  static String m31(count) => "${count} 個";

  static String m32(count) => "${count} 件タイムアウト";

  static String m33(action) => "「${action}」で使用中です。保存するとこちらに移動します。";

  static String m34(modifiers) => "${modifiers} のいずれかを含めてください";

  static String m35(count) => "${count} 時間前";

  static String m36(count) => "${count} 時間前";

  static String m37(target) => "${target} は無効なポリシーです";

  static String m38(proxyName) => "${proxyName} は無効なプロキシです";

  static String m39(providerName) => "${providerName} は無効なプロキシプロバイダーです";

  static String m40(ruleSet) => "${ruleSet} は無効なルールセットです";

  static String m41(subRule) => "${subRule} は無効な SUB_RULE です";

  static String m42(count) => "${count} 件";

  static String m43(line, message) => "${line}行目：${message}";

  static String m44(appName) =>
      "1. システム設定 > プライバシーとセキュリティ を開く\n2. 位置情報サービス を選択\n3. リストで ${appName} を見つけてチェックを入れる\n\n設定が完了したらアプリに戻ると、通常どおり使用できます。ご協力ありがとうございます。";

  static String m45(label, max) => "${label}は最大${max}文字です";

  static String m46(size) => "${size} を解放しました";

  static String m47(count) => "${count} 分前";

  static String m48(count) => "${count} 分前";

  static String m49(count) => "${count} か月前";

  static String m50(count) => "${count} か月前";

  static String m51(code) =>
      "サーバーがアクセスを拒否しました（HTTP ${code}）。リンクの期限切れか、認証情報が誤っている可能性があります";

  static String m52(code) => "サーバーがリクエストを拒否しました（HTTP ${code}）";

  static String m53(code) =>
      "このアドレスには何も見つかりませんでした（HTTP ${code}）。URL が正しいか確認してください";

  static String m54(detail) => "ネットワークリクエストに失敗しました：${detail}";

  static String m55(code) => "サーバーで問題が発生しました（HTTP ${code}）。しばらくしてから再試行してください";

  static String m56(label) => "${label}はまだありません";

  static String m57(label, min, max) => "${label}は${min}から${max}の範囲で指定してください";

  static String m58(label) => "${label}は数値である必要があります";

  static String m59(label) => "${label} は 1024〜49151 の範囲で指定してください";

  static String m60(port) => "ポート ${port}";

  static String m61(days) => "残り ${days} 日";

  static String m62(date, days) => "${date} に期限切れ、残り ${days} 日";

  static String m63(time) => "${time}に更新";

  static String m64(label, profiles) =>
      "${label} は ${profiles} でまだ使用されており、削除するとそれらが正常に動作しなくなります。削除してもよろしいですか？";

  static String m65(count, label) =>
      "${Intl.plural(count, other: 'プロキシ ${label} 件')}";

  static String m66(name, count) => "${name} など${count}件のプロキシ";

  static String m67(removed) =>
      "次のプロキシが削除されます：${removed}。名前を変えた行は新しいプロキシとして扱われ、削除されたプロキシを参照するカスタムプロファイルでは見つからないと表示されます。適用しますか？";

  static String m68(removed, added) =>
      "次のプロキシが削除されます：${removed}。次のプロキシが追加されます：${added}。名前を変えた行は新しいプロキシとして扱われ、削除されたプロキシを参照するカスタムプロファイルでは見つからないと表示されます。適用しますか？";

  static String m69(label) =>
      "${label} はこのプロファイルのルール、プロキシグループ、ダイヤラープロキシ、DNS または NTP からまだ参照されており、削除するとそれらの参照は無効になります。削除してもよろしいですか？";

  static String m70(count, label) =>
      "${Intl.plural(count, other: 'プロキシグループ ${label} 件')}";

  static String m71(maximum) => "0 から ${maximum} の整数を入力してください。";

  static String m72(count, label) =>
      "${Intl.plural(count, other: 'ルール ${label} 件')}";

  static String m73(appName) => "${appName}（セーフモード）";

  static String m74(count) => "${count} 秒";

  static String m75(count) => "${count} 件が有効";

  static String m76(count) => "${count} 件に問題";

  static String m77(time) => "${time} に検査";

  static String m78(count) => "設定 ${count} 件";

  static String m79(link) => "${link} からプロキシを読み取れませんでした";

  static String m80(label) => "${label}は1項目のみ指定できます";

  static String m81(value) => "ピーク ${value}";

  static String m82(value) => "累計 ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · アイドル ${idleInterval}";

  static String m84(interval) => "${interval} · アイドル無効";

  static String m85(label) => "${label}はURLである必要があります";

  static String m86(count) => "${count} 年前";

  static String m87(count) => "${count} 年前";

  static String m88(amount, cycle) => "${cycle}ごとに${amount}（一括払い）";

  static String m89(date) => "${date}に期限切れです。アップグレードも更新もここからできます。";

  static String m90(plan) => "現在のプラン · ${plan}";

  static String m91(days) => "残り${days}日";

  static String m92(date) => "${date}に期限切れ";

  static String m93(count) => "最大 ${count} 台まで同時にオンライン";

  static String m94(mbps) => "最大速度 ${mbps} Mbps";

  static String m95(gb) => "毎月 ${gb} GB の高速通信";

  static String m96(name) => "こんにちは、${name}さん。";

  static String m97(rate) => "${rate}× 計量";

  static String m98(count) => "サーバー数：${count}";

  static String m99(count) => "/ ${count}台";

  static String m100(days) => "${days}日後にリセット";

  static String m101(percent) => "${percent}%お得";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを経由します",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アクセス制御では、プロキシを利用するアプリを選びます。",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "アプリアクセス制御は無効です",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリはVPNから除外されます",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("アクセス制御の設定"),
    "accessDenied": MessageLookupByLibrary.simpleMessage("アクセス拒否"),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("すべての遅延をテスト"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("ダイレクトモード"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("グローバルモード"),
    "actionMode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("ルールモード"),
    "actionStart": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("プロファイルを更新"),
    "actionView": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addFilters": MessageLookupByLibrary.simpleMessage("フィルターを追加"),
    "addNodes": MessageLookupByLibrary.simpleMessage("ノードを追加"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("上書き項目を追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addProxies": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("設定項目を追加"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSIDを追加"),
    "addedRules": MessageLookupByLibrary.simpleMessage("追加ルール"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("追加パラメータ"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("名前のプレフィックス"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("名前のサフィックス"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーのアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "有効なWebDAVアドレスを入力してください",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("詳細設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "詳細設定には、ネットワーク、DNS、追加ルール、スクリプトがあります。",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("暗号化されたプロファイル"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("Age キー生成"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519 キーペアを生成しました。安全に保管してください",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 秘密鍵"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "先に正しい Age 秘密鍵を入力してください",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 公開鍵"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 秘密鍵"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効な Age 秘密鍵を入力してください（AGE-SECRET-KEY-で始まる必要があります）",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage("Age 秘密鍵（任意）"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "このプロファイルは age で暗号化されており、復号には age 秘密鍵が必要です",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意する"),
    "allData": MessageLookupByLibrary.simpleMessage("すべてのデータ"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "参照されているすべてのプロキシ",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "参照されているすべてのプロキシプロバイダー",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリによるVPNバイパスを許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリが VPN をバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANプロキシ"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("LAN アクセスを許可"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "LAN から外部コントローラーへのアクセスを許可",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN 経由でのプロキシアクセスを許可"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("許可する IP"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("常時接続"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "あらゆるネットワーク環境でVPN接続を維持",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("応答"),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("アプリアイコンのデザイン"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("ローカルプロキシがありません"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを追加"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "設定にシステム DNS を強制的に追加します",
    ),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーション関連の設定を変更します",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("昇順"),
    "authentication": MessageLookupByLibrary.simpleMessage("認証"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "認証を有効にすると、ローカルプロキシポートの利用にユーザー名とパスワードが必要になります。",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "認証が有効な間、システムプロキシは適用されません。",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("許可"),
    "authorized": MessageLookupByLibrary.simpleMessage("許可済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("更新の自動チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "アプリ起動時に更新を自動的にチェックします",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動的に閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシを切り替えると、既存の接続を自動的に閉じます。",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("自動で含める"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システム起動時に自動的に起動します"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "自動実行はアプリを開いたときにプロキシを開始します。",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを自動設定"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "back": MessageLookupByLibrary.simpleMessage("戻る"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage("戻る時にダッシュボードへ"),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "終了する前にダッシュボードへ戻ります",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "ローカル日付（YYYY-MM-DD）",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "このバックアップは新しいバージョンのアプリで作成されています。アプリを更新してから復元してください",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "現在のプラットフォーム",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップが完了しました"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "ローカル時刻（HHmmss）",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "アプリのバージョン",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("基本設定をグローバルに変更します"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基本情報"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基本ポリシー"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("一括追加"),
    "batchImport": MessageLookupByLibrary.simpleMessage("一括インポート"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1つのリンクを入力してください",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1項目、またはカンマ区切りで入力してください",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1件、キーと値はスペースで区切ってください",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1つのURLを入力してください",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "電池の最適化を無視すると、アプリがバックグラウンドで動作し続けます。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("連携"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("接続をブロック"),
    "brightness": MessageLookupByLibrary.simpleMessage("明度"),
    "browse": MessageLookupByLibrary.simpleMessage("参照"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("除外ドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "除外ドメインはシステムプロキシが有効な場合のみ適用されます。",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパス",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパスすると、LAN・ループバック・マルチキャストのアドレスは TUN を通りません。",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("キャッシュ"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("キャッシュアルゴリズム"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("キャッシュサイズ"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "QRコードをスキャンするには、システム設定でカメラへのアクセスを許可するか、アルバムからQRコード画像を選択してください。",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "カメラの権限が必要です",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("カメラを使用できません"),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("すべて選択解除"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("保存できません"),
    "captureDns": MessageLookupByLibrary.simpleMessage("システム DNS を引き継ぐ"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのシステム DNS クエリを内部 DNS モジュールに転送",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "プロキシの切り替えに失敗したため、前回の選択に戻しました",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("破壊的変更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新機能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("不具合修正"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("パフォーマンス"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("取り消し"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("TLS証明書を検証"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "TLS 証明書の検証を無効にすると、サブスクリプションとバックアップが中間者攻撃にさらされます。",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("すでに最新バージョンです"),
    "cipher": MessageLookupByLibrary.simpleMessage("暗号方式"),
    "clear": MessageLookupByLibrary.simpleMessage("クリア"),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "すべてのプロファイル、設定、ローカルデータを削除してアプリを終了します。もう一度開くと最初から始められます。",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("検索をクリア"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "クライアントフィンガープリント",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードへエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "クリップボードにコピーできませんでした。選択範囲が大きすぎる可能性があります",
    ),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "closeAll": MessageLookupByLibrary.simpleMessage("すべて切断"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("接続を閉じる"),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "以前のプロキシを使用している接続を切断しますか？",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("折りたたむ"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "プロキシチェーンを折りたたむ",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシチェーンのノードが3つを超える場合、中間ノードを非表示にします",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "クイック設定パネルを閉じる",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "タイルをタップした後にクイック設定パネルを閉じます",
    ),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("配色スタイル"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compact": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "設定内にデータが見つかりました",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "すべてのデータを消去してもよろしいですか？",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "選択したデータを消去してもよろしいですか？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "このプロキシグループを削除してもよろしいですか？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "現在のウィンドウを閉じてもよろしいですか？",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "コアを強制クラッシュさせてもよろしいですか？",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "確定すると既存のデータを上書きします",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage("輻輳制御"),
    "congestionController": MessageLookupByLibrary.simpleMessage("TCP 輻輳制御"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 輻輳制御は mips スタックでのみ有効です。",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connecting": MessageLookupByLibrary.simpleMessage("接続中…"),
    "connection": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("接続数"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("接続統計"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "ライブ接続、最近のリクエスト、DNS クエリ",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の接続データを表示します"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続状態："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容は空にできません"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "グローバル追加ルールを管理",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピーしました"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows のスマート アプリ コントロールが、署名されていない FlClashCore.exe をブロックしました。Windows セキュリティ → アプリとブラウザーの制御 → スマート アプリ コントロールの設定で「オフ」を選び、FlClash を再起動してください。一度オフにすると、Windows を再インストールしない限り再度オンにはできません。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コアの状態"),
    "country": MessageLookupByLibrary.simpleMessage("地域"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("クラッシュを検出しました"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createProfile": MessageLookupByLibrary.simpleMessage("プロファイルを作成"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("作成日時"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "起動ボタンがあるため削除できません",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "customColor": MessageLookupByLibrary.simpleMessage("カスタムカラー"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("名前が空です"),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "プロキシもプロキシプロバイダーも選択されていないため、コアはこのグループを拒否します",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("カスタム"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "アプリのプロキシと他のプロファイルからプロキシグループとルールを組み立てます",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "カスタムプロファイルのリソース",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムプロファイルのリソースには、プロキシ、ルールプロバイダー、フィルター、アイコンセットがあります。",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("追加できるカード"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "データの変更を検出しました。保存しますか？",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "変更の保存に失敗したため、元に戻しました",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("ディレクトリ"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNS サーバーの解決用",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage("デフォルトの選択"),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "設定は name と type を含む YAML マッピングである必要があります",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("失敗"),
    "delayTest": MessageLookupByLibrary.simpleMessage("遅延テスト"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMetaベースのマルチプラットフォーム対応プロキシクライアント。シンプルで使いやすく、オープンソースで広告もありません。",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("降順"),
    "destination": MessageLookupByLibrary.simpleMessage("宛先"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先GeoIP"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先IP ASN"),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "サードパーティAPIに依存しているため、参考値です",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("開発者モード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "開発者モードが有効になりました。",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("ダイヤラープロキシ"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "ダイヤラープロキシは NTP サーバーへの接続に使用するアウトバウンドです。",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "ICMP 転送を無効化",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "ICMP 転送を無効にすると TUN が ping に直接応答するため、ping に実際の遅延が表示されなくなります。",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage("TCP キープアライブを無効化"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDPを無効化"),
    "disabled": MessageLookupByLibrary.simpleMessage("無効"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("変更を破棄しますか？"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアをインストール、複製または使用した時点で、本声明のすべての内容を読み、同意したものとみなされます。いずれかの条項に同意いただけない場合は、直ちに使用を中止し、本ソフトウェアをアンインストールしてください。",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("声明への同意"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "この声明を読み、理解しました",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "内容を理解したことを確認するため、以下の声明を読み、下のチェックボックスをオンにしてください：",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("声明の確認"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "開発者はバージョンの更新に伴い本声明を変更することがあり、変更内容は新しいバージョンの公開とともに効力を生じます。更新後も本ソフトウェアを引き続き使用した場合、変更後の声明に同意したものとみなされます。",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("本声明の変更"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash（以下「本ソフトウェア」）をご利用になる前に、本声明の内容をよくお読みになり、十分にご理解ください。「同意する」をタップすると、以下のすべての条項を読み、理解し、承諾したものとみなされます。同意いただけない場合は「終了」をタップし、本ソフトウェアの使用を中止してください。",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "適用法で認められる最大限の範囲において、開発者およびすべての貢献者は、本ソフトウェアの使用または使用不能に起因する直接的、間接的、偶発的、特別、懲罰的または結果的な損害（データの消失、機器の損傷、ネットワーク障害、業務の中断、逸失利益、およびそれに起因する法的紛争を含むがこれらに限らない）について、その可能性を知らされていた場合であっても、一切責任を負いません。",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("責任の制限"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは GPL-3.0 ライセンスのもとでオープンソースとして公開されています。同ライセンスを遵守する限り、自由に使用、改変、再配布できますが、派生物も GPL-3.0 で公開し、原著作者の著作権表示を保持する必要があります。\n\n本ソフトウェアに含まれるサードパーティのコンポーネント（Clash.Meta コアを含む）は、それぞれのライセンスに従います。改変版や再配布版に起因する問題について、原著作者は責任を負いません。",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "オープンソースライセンス",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェア自体は、プロキシサーバー、ノード、サブスクリプション、ネットワーク接続サービスを一切提供しておらず、それらのサービス提供者と提携、代理、保証の関係はありません。",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは、サブスクリプション URL、ノード情報、設定内容、閲覧したウェブサイト、接続記録、通信内容、ログを収集またはアップロードしません。これらのデータは端末内にのみ保存され、開発者がアクセスすることはできません。\n\n本ソフトウェアが外部ネットワークにアクセスするのは、プロファイル更新時に指定されたサブスクリプション URL へアクセスする場合や、アップデート確認時に GitHub へアクセスする場合など、該当する機能を使用したときのみです。\n\n本ソフトウェアには、どのプラットフォームでも統計やクラッシュレポートのサービスは一切組み込まれていません。",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "データ収集とプライバシー",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "お住まいの国または地域で本ソフトウェアの使用が合法であることはご自身で確認する必要があり、本ソフトウェアを使用したすべての行為とその結果について、ご自身が単独で法的責任を負います。\n\nインポートするサブスクリプション、ノード、設定はご自身の判断で選択したものです。その出所の適法性、内容の安全性、サービスの安定性については、利用者と各提供者の間で解決してください。",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "利用者の責任",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage("上記の声明を入力"),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "声明の内容と一致しません",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "内容を理解したことを確認するため、以下の声明を下の入力欄に正確に入力してください：",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("声明の復唱"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは Clash.Meta（mihomo）コアをベースとしたオープンソースのネットワークプロキシクライアントであり、設定管理、ルールによる振り分け、トラフィック転送などのローカルツール機能のみを提供します。",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "ソフトウェアの性質",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンク、設定ファイル、ルールセット、スクリプト、外部リソース、外部リンクはすべて第三者が提供するものであり、開発者はその適法性、正確性、安全性、可用性を審査または保証することはできず、また行いません。\n\nサードパーティのコンテンツの使用に起因する情報漏えい、財産上の損失、アカウント停止その他の損失は、利用者と第三者の間で解決するものとし、開発者は一切責任を負いません。",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "サードパーティのコンテンツ",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは学習、交流、技術研究などの非商用目的でのみ使用できます。有償配布、抱き合わせ販売、商用サービスの一部としての利用、本ソフトウェアの名義での事業活動など、あらゆる商用目的での使用を固く禁じます。いかなる商業行為も本ソフトウェアおよび開発者とは一切関係ありません。\n\nお住まいの国または地域の法令に違反する目的での使用を固く禁じます。これには、法に基づくネットワークアクセス制限の回避、違法情報の拡散、サイバー攻撃、他者の権利の侵害などが含まれますが、これらに限りません。",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("使用の制限"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは「現状のまま」かつ「提供可能な範囲で」提供され、商品性、特定目的への適合性、非侵害、継続的な可用性、エラーやセキュリティ上の脆弱性がないことの保証を含め、明示または黙示を問わずいかなる保証も伴いません。\n\n開発者は、本ソフトウェアが利用者の要件を満たすこと、また中断やエラーなく動作することを保証しません。",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("無保証"),
    "disconnected": MessageLookupByLibrary.simpleMessage("切断済み"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンが見つかりました",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS 関連設定の更新"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS ハイジャック"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "追加しない場合、ポート 53 宛てのすべての DNS 問い合わせをハイジャックします（any:53）。",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNSハイジャック"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "無効にすると、AAAA クエリは空の結果を返します",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "ここで追加した項目は、すべての URL・ファイルプロファイルの DNS を上書きします。追加していない項目はプロファイル自身の設定のままです。カスタムプロファイルの DNS はその内容で設定します。",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNSクエリ"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage("コアの DNS 解決記録"),
    "docked": MessageLookupByLibrary.simpleMessage("固定"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "done": MessageLookupByLibrary.simpleMessage("完了"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("ダウンロード帯域幅"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("ダウンロード速度"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("ダウンロード通信量"),
    "duration": MessageLookupByLibrary.simpleMessage("経過時間"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage("接続遅延"),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS ゾーン"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage("機能フラグ"),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("インスタンス ID"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "経路遅延（遅延優先）",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("リッスンアドレス"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "ローカルエンドポイント",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("パケット損失率"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "最小直接接続遅延",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage("ネクストホップのピア ID"),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage("経路遅延（ホップ数優先）"),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("ピア ID"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage("トランスポートプロトコル"),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage("パブリックサーバー"),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "リモートエンドポイント",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("ルートコスト"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage("受信パケット数"),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage("送信パケット数"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("ダッシュボードを編集"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("グローバルルールを編集"),
    "editProxy": MessageLookupByLibrary.simpleMessage("プロキシを編集"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを編集"),
    "editRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSIDを編集"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("エディターを利用できません"),
    "elapsed": MessageLookupByLibrary.simpleMessage("所要時間"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("空グループのフォールバック"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーを有効にする",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("有効"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT 強化"),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "UDP および P2P アプリの接続を最適化",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("エンドポイント"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("ルートを強制"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "より具体的なルートが存在してもトラフィックをトンネル経由にする",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" 件"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("エラー"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("エラーの詳細"),
    "es": MessageLookupByLibrary.simpleMessage("スペイン語"),
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから隠す"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("APNs を除外"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Apple プッシュ通知トラフィックがトンネルをバイパスすることを許可する",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "セルラーサービスを除外",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Wi-Fi 通話などのセルラーサービストラフィックがトンネルをバイパスすることを許可する",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "バックグラウンド時に、最近のタスクからアプリを隠します",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "デバイス間通信を除外",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "AirDrop や AirPlay などのデバイス間通信がトンネルをバイパスすることを許可する",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("除外宛先ポート"),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "除外宛先ポートへの通信は TUN を通りません。",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("除外フィルター"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("除外インターフェース"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "docker0 などの除外インターフェースから入る通信は TUN を通りません。",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワークを除外",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワーク上のデバイスへの直接アクセスを許可する",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("除外ノードフィルター"),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("除外送信元ポート"),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "除外送信元ポートからの通信は TUN を通りません。",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("除外SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "除外した SSID の Wi-Fi に接続すると、アプリの実行状態が自動的に切り替わります。",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("除外タイプ"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("除外ユーザー ID"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "除外ユーザー ID のプロセスの通信は TUN を通りません。",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("全画面表示を終了"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("出口ノード"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("期待するステータス"),
    "expireTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポートが完了しました"),
    "extend": MessageLookupByLibrary.simpleMessage("拡張"),
    "extendMode": MessageLookupByLibrary.simpleMessage("拡張モード"),
    "extendScript": MessageLookupByLibrary.simpleMessage("拡張スクリプト"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーを有効にすると、ポート 9090 でコアを制御できます。",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーのシークレット",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部取得"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("特大"),
    "fade": MessageLookupByLibrary.simpleMessage("フェード"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IPフィルター"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Fake IP モードで一致したドメインには Fake IP ではなく実 IP を返します",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IPフィルターモード"),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Fake-IP フィルターモードでは、blacklist は一致を除外、whitelist は一致のみ、rule はルールで判定します。",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP範囲"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP範囲（IPv6）"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常は海外 DNS を使用"),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "一致するドメインは nameserver へ問い合わせず、直接 fallback を使用します",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver の結果を GeoIP コードで確認し、その地域外なら fallback を使用します",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "これらの GeoSite カテゴリに一致するドメインは直接 fallback を使用します",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver の結果がこれらの CIDR プレフィックスに一致すると fallback の結果へ切り替えます",
    ),
    "features": MessageLookupByLibrary.simpleMessage("機能"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルファイルを直接アップロードします"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されています。変更を保存しますか？",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("ファイル名"),
    "filter": MessageLookupByLibrary.simpleMessage("フィルター"),
    "filters": MessageLookupByLibrary.simpleMessage("フィルター"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "有効にすると、パフォーマンスが多少低下します",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("フローティング"),
    "followProfile": MessageLookupByLibrary.simpleMessage("プロファイルに従う"),
    "followSystem": MessageLookupByLibrary.simpleMessage("システムに従う"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォント"),
    "fontSize": MessageLookupByLibrary.simpleMessage("サイズ"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("DNSマッピングを強制"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "DNS マッピングを強制すると、DNS マッピングでドメインを得た接続もスニッフィングします。",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("強制するドメイン"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "強制するドメインもスニッフィングします。ドメインを持つその他の接続は対象外です。",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "コアを強制再起動してもよろしいですか？",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("フランス語"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("アプリとコアの一般設定"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Age 秘密鍵から生成",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("生成"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔は0より大きくしてください",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geoオプション"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると Geo 低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP コード"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage("高性能 Geo マッチャー"),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると最小完全ハッシュアルゴリズムで照合",
    ),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("開く"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "追加ルール設定へ移動",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("スクリプト設定へ移動"),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("ゴルーチン数"),
    "grid": MessageLookupByLibrary.simpleMessage("グリッド"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("個"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("インバウンドユーザーでハッシュ"),
    "header": MessageLookupByLibrary.simpleMessage("ヘッダー"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("ヘルスチェック"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper サービスが利用できないため、TUN モードを有効にできません。FlClash を再インストールしてください。",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("16進数"),
    "hide": MessageLookupByLibrary.simpleMessage("非表示"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("リストから隠す"),
    "hideIp": MessageLookupByLibrary.simpleMessage("IP を隠す"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("パスワードを隠す"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "タイムアウトしたプロキシを隠す",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "前回の遅延テストがタイムアウトしたプロキシを表示しない",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("タイムアウト非表示"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage("高優先度自動起動"),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Windows タスクスケジューラでより早く起動します",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("ホップ間隔"),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostname": MessageLookupByLibrary.simpleMessage("ホスト名"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Hostsを追加します"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ホットキーが競合しています"),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "グローバルホットキーはウィンドウが非表示でも有効です。アクションをタップしてキーの組み合わせを記録します。",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを操作します",
    ),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("未設定"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "登録できませんでした。他のアプリが使用している可能性があります",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("色相"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP 転送"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると ICMP Ping をサポート",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("アイコン履歴"),
    "iconSets": MessageLookupByLibrary.simpleMessage("アイコンセット"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "アイコンセットはまだありません。「カスタムプロファイルのリソース → アイコンセット」で追加できます",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("アイコンソース"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("背景あり"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("非表示"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("背景なし"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("アイコンURL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "電池の最適化を無視",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "証明書の検証を無視",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "無効な証明書を使用する HTTPS 接続を許可します。セキュリティが低下します",
    ),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "このファイルはインポートできる設定ではありません",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "インポートすると、このプロファイルの現在のプロキシグループ、ルール、設定が置き換えられます",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("リンクからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URL からインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "inbound": MessageLookupByLibrary.simpleMessage("インバウンド"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage("すべてのネットワークを含む"),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルおよびセルラーサービスを含むすべてのネットワークトラフィックをトンネル経由にする",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("すべてのプロキシを含める"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "プロキシグループに属さないすべてのプロキシを取り込みます。下でプロキシグループを追加できます",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "すべてのプロキシプロバイダーを含める",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、取り込んだプロキシプロバイダーを上書きします",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage("対象インターフェース"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "対象インターフェースから入る通信だけが TUN を通り、除外インターフェースは無効になります。",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("対象ユーザー ID"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "対象ユーザー ID のプロセスの通信だけが TUN を通ります。",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("無期限"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "initFailed": MessageLookupByLibrary.simpleMessage("起動に失敗しました"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash の起動中にエラーが発生したため、続行できません。詳細をコピーして問題を報告できます。繰り返し発生する場合は、データを消去すると起動できるようになることがあります。",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("初期化"),
    "initiator": MessageLookupByLibrary.simpleMessage("発信元"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("発信元"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "正しいホットキーを入力してください",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名を入力してください",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("ルールの内容を入力してください"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "アプリ一覧の権限が拒否されたため、インストール済みアプリを取得できません。システム設定から手動で許可してください。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "このシステムでは、許可するまでインストール済みアプリの一覧が提供されません。許可すると、アプリごとのプロキシを設定できます。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "アプリ一覧の権限が必要です",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("インストール済みのフォント"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("スマート選択"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("インターフェース名"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "インターフェース名は、アウトバウンド接続に使用するネットワークインターフェースです。",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "アウトバウンドインターフェース",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("クリア"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("設定に従う"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("間隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無効なバックアップファイル"),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "パス区切りや特殊文字を含まず、255 バイト以内の有効なファイル名を入力してください。",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "192.168.0.0/16 のような CIDR 形式の IP 範囲を入力してください",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      ". や ..、バックスラッシュ、特殊文字を含まない有効なディレクトリを入力してください。",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP マークは 63 を超えられません",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "ドメインまたは IP アドレスを入力してください",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("有効なアイコンセットではありません"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクまたはプロキシの共有リンクではありません",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "0.0.0.0:1053 のようなアドレスとポートを入力してください",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "tcp または udp のみ対応しています",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "443 や 8000-9000 のようなポートまたは範囲を入力してください",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "このQRコードにはプロファイルのリンクが含まれていません",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "80 や 8000-9000 のような数値または範囲を / 区切りで入力してください",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP アドレス"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("不正利用の履歴"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("検出"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("組織"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "IP タイプを判定できませんでした",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("良好"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("レベル"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("再確認"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("リスクあり"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("品質"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("採用したソース"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("各ソース"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "アウトバウンド IP が不一致",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("判定不可"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("レート制限"),
    "ipType": MessageLookupByLibrary.simpleMessage("タイプ"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("ビジネス"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("データセンター"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("モバイル回線"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("住宅"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("タイプ不明"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP バージョン"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "IPv6 トラフィックは IPv6 が有効なときだけ受信します。",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "IPv6 を有効にすると、VPN で IPv6 インバウンドを許可します。",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6タイムアウト（ms）"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP キープアライブ待機時間"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "ko": MessageLookupByLibrary.simpleMessage("韓国語"),
    "label": MessageLookupByLibrary.simpleMessage("ラベル"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "large": MessageLookupByLibrary.simpleMessage("大"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("最終更新"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("起動が完了しませんでした"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "前回、アプリは起動中に予期せず終了しました。今回の自動セットアップはスキップしました。手動で起動して再試行できます。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "level": MessageLookupByLibrary.simpleMessage("レベル"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("行間"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("折り返し"),
    "link": MessageLookupByLibrary.simpleMessage("リンク"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクまたはプロキシの共有リンクからプロファイルを取得します",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("リキッドグラス"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リッスン"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("リッスンのルーティングマーク"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "リッスンのルーティングマークは Linux でのみ有効です。",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("リスニングポート"),
    "liveConnections": MessageLookupByLibrary.simpleMessage("リアルタイム接続"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中…"),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルにデータをバックアップします",
    ),
    "localImage": MessageLookupByLibrary.simpleMessage("ローカル画像"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワークの権限が拒否されたため gvisor スタックを使用します。LAN にはアクセスできません。",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("ローカルプロキシ"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置情報の権限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が拒否されたため、現在の Wi-Fi 名を取得できません。システム設定で位置情報の権限を手動で有効にしてください。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "システムの要件により、Wi-Fi 名の取得には位置情報の権限が必要です。Android では「常に許可」を選択してください。そうしないと、アプリがバックグラウンドにあるときに Wi-Fi 名を取得できません。",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が必要です",
    ),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャプチャ"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "ログキャプチャを無効にすると、ログの入り口が非表示になります。",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("ログと診断"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("キャプチャしたログの記録"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP ループバック解除"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWP ループバック解除用"),
    "loose": MessageLookupByLibrary.simpleMessage("ゆったり"),
    "manual": MessageLookupByLibrary.simpleMessage("手動"),
    "matchCase": MessageLookupByLibrary.simpleMessage("大文字と小文字を区別"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("送信元IPにマッチ"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET を対象にしたルールの行き先。既定ではこのプロファイル末尾の MATCH ルールのターゲットを使います。",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("マッチ先"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗回数"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("アプリのメモリ"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("常駐メモリ"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("アプリと共有"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("クリーンアップ"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("未使用のヒープ"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("使用中のヒープ"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "コアは実行されていません",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("ランタイムのオーバーヘッド"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("ゴルーチンスタック"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスの常駐メモリからの推定値で、システムの表示とは異なる場合があります。",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "コアはアプリと同じプロセスで動作します。コア分はランタイム統計から推定し、残りはアプリと共有メモリとして計上します。",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage("メモリフットプリント"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("GC メタデータ"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage("保持された空きヒープ"),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("ヒープオブジェクト"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("OS に返却済み"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage("ヒープ内の未使用領域"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("アプリとコアが使用するメモリ"),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage("ランタイムメタデータ"),
    "memoryOther": MessageLookupByLibrary.simpleMessage("その他のランタイムメモリ"),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "メモリを読み取れません。再試行中…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("メモリを解放しました"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("スタック"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Go メモリ使用量"),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システム標準の終了動作を変更します",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("分"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixedポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage("モノクロのトレイアイコン"),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("その他"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU は 1 から 65535 までの整数である必要があります",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "複数の値はカンマで区切ってください",
    ),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメインの名前解決に使用します"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "一致するドメイン、GeoSite カテゴリ、またはルールセットに DNS サーバーを割り当てます",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("ボトムバー"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("サインインが必要"),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "リクエストはキャンセルされました",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "サーバーに接続できませんでした。ネットワーク接続またはプロキシ設定を確認してください",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連の設定を変更します"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "ネットワークエラーです。接続を確認してから再試行してください",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage("ネットワーク拡張"),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "サーバーのアドレスを解決できませんでした。URL が正しいこと、DNS が使えることを確認してください",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("ネットワーク ID"),
    "networkName": MessageLookupByLibrary.simpleMessage("ネットワーク名"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("ネットワークが見つかりません"),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "リクエストが多すぎます（HTTP 429）。しばらく待ってから再試行してください",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("ネットワークシークレット"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "リアルタイムのネットワーク速度を表示",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "システムのステータス領域にリアルタイムのネットワーク速度を表示します。消費電力がわずかに増える場合があります",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("トラフィックの引き継ぎ"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "リクエストがタイムアウトしました。ネットワークまたはプロキシを確認してから再試行してください",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "安全な接続に失敗しました。サーバー証明書が無効か、接続が傍受されている可能性があります",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "networking": MessageLookupByLibrary.simpleMessage("メッシュネットワーク"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage("P2P ネットワークの状態を表示"),
    "networkingError": MessageLookupByLibrary.simpleMessage("エラー"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "現在の設定に P2P アウトバウンドはありません",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("新規作成"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage("プロファイルを手動で作成"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("次の一致"),
    "no": MessageLookupByLibrary.simpleMessage("いいえ"),
    "noData": MessageLookupByLibrary.simpleMessage("データがありません"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("サブディレクトリはありません"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage("フィルター条件なし"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ホットキーはまだありません"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報がありません"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("今後表示しない"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークがありません"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワーク不使用アプリ"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "リモートバックアップが見つかりません",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("ホスト名を解決しない"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("一致する結果はありません"),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "通信量を取得できません。再試行しています…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("ノード別通信量"),
    "nodes": MessageLookupByLibrary.simpleMessage("ノード"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "この外部リソースはテキストファイルではありません",
    ),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notRunning": MessageLookupByLibrary.simpleMessage("停止中"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("NTP 関連設定の更新"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("同期間隔（分）"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP を有効にすると、システムクロックではなく NTP サーバーから時刻を取得します。",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルを追加して始めましょう",
    ),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("難読化"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("難読化ホスト"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("難読化モード"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("難読化パラメータ"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("難読化パスワード"),
    "offline": MessageLookupByLibrary.simpleMessage("オフライン"),
    "onDemand": MessageLookupByLibrary.simpleMessage("オンデマンド"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "オンデマンドは、除外した Wi-Fi に接続している間プロキシを一時停止します。",
    ),
    "online": MessageLookupByLibrary.simpleMessage("オンライン"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("設定のみ"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Emoji のみ"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "プロキシトラフィックのみ集計",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効にすると、プロキシのトラフィックのみを集計します",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("GitHub で開く"),
    "optional": MessageLookupByLibrary.simpleMessage("任意"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outbound": MessageLookupByLibrary.simpleMessage("アウトバウンド"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("出口"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("アウトバウンド IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("宛先を上書き"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "宛先を上書きすると、元のアドレスではなく検出したドメインに接続します。",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS 上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルの DNS 設定を上書き",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("上書き項目"),
    "overrideMode": MessageLookupByLibrary.simpleMessage("上書きモード"),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("NTP 上書き"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルの NTP 設定を上書き",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage("上書きスクリプト"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムモード：プロキシグループとルールを完全にカスタマイズできます",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("親ディレクトリ"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("純粋なIPを解析"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "純粋な IP を解析すると、IP アドレスしかない接続をスニッフィングします。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "peers": MessageLookupByLibrary.simpleMessage("ピア"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("アルバムから選択"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("最前面に固定"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("WebDAVを連携してください"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("プラグイン"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("プラグインホスト"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("プラグインモード"),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portHopping": MessageLookupByLibrary.simpleMessage("ポートホッピング"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("ポート"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "0 より大きい整数を入力してください",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("事前共有鍵"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("予測型戻る"),
    "preferH3": MessageLookupByLibrary.simpleMessage("HTTP/3 を優先"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DoH の HTTP/3 を優先します"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前提条件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーの組み合わせを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("前の一致"),
    "privateKey": MessageLookupByLibrary.simpleMessage("秘密鍵"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("秘密鍵のパスフレーズ"),
    "process": MessageLookupByLibrary.simpleMessage("プロセス"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されています。自動更新を無効にしますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "このプロファイルにのみ適用されます。追加していない項目はデフォルト値を使用します。",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "このプロファイルにのみ適用され、ネットワーク設定の TUN 上書き項目より優先されます。",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルのURLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並べ替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage("接続終了の確認"),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を切断するか確認します",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("プロトコル"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("プロトコルパラメータ"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("プロトコルバージョン"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("リモートリソースのみ対応しています"),
    "providers": MessageLookupByLibrary.simpleMessage("外部リソース"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択したプロキシに異常が見つかりました",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("ノードフィルター"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループに異常が見つかりました",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("プロキシグループが空です"),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名は空にできません",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "起動するとここにグループが表示されます",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノードのドメイン解決用",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "プロキシネームサーバーポリシー",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノードのネームサーバーポリシーを指定",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択したプロキシプロバイダーに異常が見つかりました",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyType": MessageLookupByLibrary.simpleMessage("プロキシタイプ"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("キャッシュを整理"),
    "publicKey": MessageLookupByLibrary.simpleMessage("公開鍵"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("ピュアブラック"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("ピュアブラックモード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "QRコードをスキャンしてプロファイルを取得します",
    ),
    "query": MessageLookupByLibrary.simpleMessage("照会"),
    "queryDns": MessageLookupByLibrary.simpleMessage("DNS を照会"),
    "queryRule": MessageLookupByLibrary.simpleMessage("ルールを照会"),
    "quickActions": MessageLookupByLibrary.simpleMessage("クイック操作"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("クイック編集"),
    "quickFill": MessageLookupByLibrary.simpleMessage("クイック入力"),
    "random": MessageLookupByLibrary.simpleMessage("ランダム"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("最近のリクエスト"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("おすすめ"),
    "recordType": MessageLookupByLibrary.simpleMessage("レコードタイプ"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("RecvMsgX を有効にする"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage("Darwin でパケットを一括受信"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "regex": MessageLookupByLibrary.simpleMessage("正規表現"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("正規表現検索"),
    "relayed": MessageLookupByLibrary.simpleMessage("リレー"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("メモリを解放"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "メモリの解放に失敗しました",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV にデータをバックアップ",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("リモート DNS 解決"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("名前を変更"),
    "replace": MessageLookupByLibrary.simpleMessage("置換"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("すべて置換"),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("リクエストと更新"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近のリクエスト記録を表示します"),
    "required": MessageLookupByLibrary.simpleMessage("必須"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "このページには変更があります。リセットしてもよろしいですか？",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "プロファイルとスクリプト",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage("アプリ設定"),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットしてもよろしいですか？"),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔は0より大きくしてください",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソースの関連情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルールに従う"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "ルールに従うを有効にすると DNS 接続がルールに従います。Proxy Server Nameserver の設定が必要です。",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("応答コード"),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("コアを再起動してもよろしいですか？"),
    "restore": MessageLookupByLibrary.simpleMessage("復元"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("すべてのデータを復元"),
    "restoreException": MessageLookupByLibrary.simpleMessage("復元エラー"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "ファイルからデータを復元します",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV を介してデータを復元する",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage("グループを再び非表示"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("プロファイルのみ復元"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("復元方式"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("互換"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("上書き"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("復元が完了しました"),
    "result": MessageLookupByLibrary.simpleMessage("結果"),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "role": MessageLookupByLibrary.simpleMessage("ロール"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "リッスンするルートアドレスを設定します",
    ),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("ルート除外アドレス"),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパス",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "routes": MessageLookupByLibrary.simpleMessage("ルート"),
    "routingMark": MessageLookupByLibrary.simpleMessage("ルーティングマーク"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("論理ルール AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("完全なドメインにマッチ"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインキーワードにマッチ",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインの正規表現でマッチ",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインサフィックスにマッチ",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "ワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCPマークにマッチ（tproxy udpインバウンドのみ）",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "宛先ポート範囲にマッチ",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("IPの国コードにマッチ"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Geosite 内のドメインにマッチ",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("インバウンド名にマッチ"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドポートにマッチ",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドタイプにマッチ",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドユーザー名にマッチ（/ で複数指定可）",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "IPが属するASNにマッチ",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲にマッチ（IP-CIDR6 は別名です）",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲にマッチ",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IPサフィックス範囲にマッチ",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのリクエストにマッチ（条件不要）",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCPまたはUDPにマッチ",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("論理ルール NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("論理ルール OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名でマッチ（Androidではパッケージ名にマッチ）",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名の正規表現でマッチ（Androidではパッケージ名にマッチ）",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名のワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスのフルパスでマッチ",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパスの正規表現でマッチ",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパスのワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "再マッチ名にマッチ（複数は / で区切る）",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ルールセットを参照します。rule-providersの設定が必要です",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPの国コードにマッチ",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPが属するASNにマッチ",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPアドレス範囲にマッチ",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPサフィックス範囲にマッチ",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "送信元ポート範囲にマッチ",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "サブルールへマッチします。括弧の使い方に注意してください",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "LinuxのユーザーIDにマッチ",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("無効"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("ルールが空です"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("有効"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("一致"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("最終一致"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage("最終不一致"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "ルールは 1 項目に 1 つのルールを書いた YAML リストにしてください。例：- DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("不一致"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent を直接接続",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "DNS over TLS をブロック",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "プロキシのループバックを防止",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("QUIC をブロック"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("STUN をブロック"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN 直接接続"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple と Microsoft に直接接続",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage("宛先 IP"),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage("インバウンド名"),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage("インバウンドユーザー"),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "有効な IP アドレスを入力してください。",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "一致するルールなし（モードのポリシーまたは DIRECT）",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "1 から 65535 のポートを入力してください。",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage("プロセスのパス"),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage("検出されたドメイン"),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("送信元ポート"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage("ドメインまたは IP アドレス"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "ルールセットに使用できるエントリがありません",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "この mrs ファイルを読み込めません",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "ルールセットにドメインと IP 範囲が混在しているため、種類を判別できません",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルールターゲット"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "ルールは対応する種類で始めてください。例：DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("ルールの種類"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "ルールを変更できませんでした。設定が変更された可能性があります。更新して再試行してください。",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("ルール"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage("ルールとマッチ統計を表示"),
    "runTime": MessageLookupByLibrary.simpleMessage("稼働時間"),
    "running": MessageLookupByLibrary.simpleMessage("実行中"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("ランタイム設定"),
    "safeMode": MessageLookupByLibrary.simpleMessage("セーフモード"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("彩度"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "スクリプトモード：拡張スクリプトでプロファイル全体を書き換えます",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("選択項目へスクロール"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("キー"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET を選択",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage("バックアップを選択"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("ルールセットを選択してください"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略を選択してください",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("SendMsgX を有効にする"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage("Darwin でパケットを一括送信"),
    "server": MessageLookupByLibrary.simpleMessage("サーバー"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("すべて利用可能"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("利用可能"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("ブロック済み"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("検査"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("すべて検査"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("近日提供予定"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "許可されていない ISP",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("検出に失敗しました"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("サービスを管理"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("オリジナル作品のみ"),
    "servicePending": MessageLookupByLibrary.simpleMessage("未検査"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("アクセス制限"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "ダッシュボードに表示",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("サービスの状態"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("利用不可"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage("対象外の地域"),
    "settingEntries": MessageLookupByLibrary.simpleMessage("設定項目"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "リンクからプロキシを読み取れませんでした",
    ),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("非表示グループを表示"),
    "showLess": MessageLookupByLibrary.simpleMessage("折りたたむ"),
    "showMore": MessageLookupByLibrary.simpleMessage("展開"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "通知に停止ボタンを表示",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "常駐通知に停止ボタンを表示します。これが原因で通知が常に展開される場合はオフにしてください",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("パスワードを表示"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "現在のプロファイル名を表示",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "接続時にクイックスイッチにプロファイル名を表示します",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "トレイにプロキシ選択を表示",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "トレイメニューにプロキシグループとノードを表示し、すばやく切り替えられるようにします",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("タイムアウト表示"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("サイドバーのぼかし"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "ウィンドウ背後のデスクトップをぼかしてサイドバーに透過します",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("サインイン"),
    "signOut": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "signedIn": MessageLookupByLibrary.simpleMessage("サインイン済み"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("サイレント起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "サイレント起動ではウィンドウを表示しません。",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("個別追加"),
    "singleImport": MessageLookupByLibrary.simpleMessage("個別インポート"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "ここにはリンクを 1 つだけ入力してください。複数の場合は一覧のクイック編集を使ってください",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("証明書の検証をスキップ"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("スキップするドメイン"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "スキップするドメインにあるドメインを検出しても使用しません。",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("スキップする宛先アドレス"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("スキップする送信元アドレス"),
    "slide": MessageLookupByLibrary.simpleMessage("スライド"),
    "sliders": MessageLookupByLibrary.simpleMessage("スライダ"),
    "small": MessageLookupByLibrary.simpleMessage("小"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("プロトコル"),
    "sniffer": MessageLookupByLibrary.simpleMessage("スニッファー"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "スニッファーは TLS・HTTP・QUIC の通信からドメインを読み取り、ルールで照合できるようにします。",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("SOCKSポート"),
    "softStyle": MessageLookupByLibrary.simpleMessage("ソフト"),
    "sort": MessageLookupByLibrary.simpleMessage("並べ替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "spectrum": MessageLookupByLibrary.simpleMessage("スペクトル"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("速度統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("振り分け戦略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略は空にできません",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDが空です"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("スタックトレース"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準モード：プロファイルにルールを追加します",
    ),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("最初から作成"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを起動しています…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("起動とバックグラウンド"),
    "status": MessageLookupByLibrary.simpleMessage("状態"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "DNS を無効にすると、システム DNS を使用します。",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止しています…"),
    "stopped": MessageLookupByLibrary.simpleMessage("停止"),
    "strategy": MessageLookupByLibrary.simpleMessage("戦略"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("厳格なルーティング"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "厳格なルーティングは DNS などの通信が TUN を迂回するのを防ぎます。IPv6 がオフの場合、この端末の IPv6 通信は遮断されます。",
    ),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("スタイル設定"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("サブスクリプション情報"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage("sudo のパスワードを入力"),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("サスペンド対応"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "デバイスがアイドル状態の間、バッテリー消費を抑えるためコアを一時停止します",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("一時停止中…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage("スワイプでページ切り替え"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("プロファイルを切り替え"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "システムの HTTP プロキシを設定",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効です"),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("アクティブ"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "現在のエンドポイント",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS 名"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("エンドポイント"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("出口ノード"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "出口ノードとして利用可能",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("ヘルス"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage("ヘルス警告"),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("キーの有効期限切れ"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("キーの有効期限"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage("最終ハンドシェイク"),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("最終確認"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "デバイスの承認が必要",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("ノードキー"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP リレー"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("サブネット"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("タグ"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("アイコンをタップして再試行"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("タップして許可"),
    "target": MessageLookupByLibrary.simpleMessage("宛先"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP同時接続"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP 並列処理を許可"),
    "testInterval": MessageLookupByLibrary.simpleMessage("テスト間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("テストURL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時にテスト"),
    "textReplacement": MessageLookupByLibrary.simpleMessage("テキスト置換："),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストの拡大縮小"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "アプリ内の文字はこの大きさで表示されます",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "tight": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "time": MessageLookupByLibrary.simpleMessage("時刻"),
    "timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("ティント"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("切り替え"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("ラベルを切り替え"),
    "tolerance": MessageLookupByLibrary.simpleMessage("許容値"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "torch": MessageLookupByLibrary.simpleMessage("ライト"),
    "total": MessageLookupByLibrary.simpleMessage("合計"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("ダウンロード量"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("合計トラフィック"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("アップロード量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxyポート"),
    "traffic": MessageLookupByLibrary.simpleMessage("通信量"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("送受信"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック統計"),
    "transport": MessageLookupByLibrary.simpleMessage("トランスポート"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN の権限を取得できなかったため、オフにしました。",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("TUN は管理者モードでのみ有効です。"),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("システム DNS モード"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("無効"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("ハイジャック"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("ネイティブ"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "ここで追加した項目は、すべてのプロファイルの TUN 設定を上書きします。追加していない項目はプロファイル自身の設定のままです。カスタムプロファイル自身が追加した項目が優先されます。",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("オフにする"),
    "turnOn": MessageLookupByLibrary.simpleMessage("オンにする"),
    "tvMode": MessageLookupByLibrary.simpleMessage("TVモード"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "この端末でリモコン向けのレイアウトを使います",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP リレーモード"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP タイムアウト"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP タイムアウトは秒単位で、gvisor・system・mixed スタックでのみ有効です。",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage("アイドル更新間隔"),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "フォーカス喪失時にアイドル",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "アプリウィンドウがフォーカスを失ったときにアイドル更新間隔を使用",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage("UI 情報の更新間隔"),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("最高"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("未許可"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を除きます",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("未初期化"),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "不明な変数です。下の変数から選択してください。",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("不明なネットワークエラー"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unnamed": MessageLookupByLibrary.simpleMessage("名称未設定"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("固定を解除"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "ダウンロードしたファイルが公開されたチェックサムと一致しないため、破棄しました。",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("更新をダウンロード中"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "インストーラーを起動できませんでした。",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash にアプリのインストールが許可されなかったため、更新をインストールしませんでした。",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash はインストール先のフォルダに書き込めません。更新を手動でダウンロードしてください。",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("今すぐ更新"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("アップロード帯域幅"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("アップロード速度"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("アップロード通信量"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL 経由でプロファイルを取得"),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("Hostsを使用"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "上流 DNS へ問い合わせる前に、設定内の hosts エントリを確認します",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムのHostsを使用"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "ドメイン名の解決時に OS の Hosts ファイルを確認します",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("使用済み"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("使用済みトラフィック"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "version": MessageLookupByLibrary.simpleMessage("バージョン"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("仮想 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("ビビッド"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN関連の設定変更を検出しました",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN は VpnService でシステムの全トラフィックを自動的にルーティングします。",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("システムに書き込む"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "システムに書き込むを有効にするとシステムクロックも設定します。Android では無視されます。",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("はい"),
    "zhCN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
    "zhTW": MessageLookupByLibrary.simpleMessage("繁体字中国語"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage("ヘルプを表示"),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "開通・更新の注文を確認",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage("ログインパスワード"),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "接続設定",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage(
      "アカウント情報と注文を確認できます。",
    ),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("マイアカウント"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("有効化中"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("詳細設定"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("すべてのサーバー"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("すべての地域"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("支払い金額"),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("アカウント残高"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage("月払いで、気軽にスタート"),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "更新情報を一時的に取得できません。",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("注文を作成"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("注文を取り消す"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "この未払い注文を取り消しますか？",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage("自動更新を停止"),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "今後の自動請求を停止します。初回の未払い注文も取り消されます。支払済みの利用権はサーバーの結果に従います。",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("取り消し済み"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage("パスワードを変更"),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "決済がすでに処理中です。アカウントで状況を確認し、重複して送信しないでください。",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "決済を準備または確認しています。しばらくしてからもう一度お試しください。",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("プランを選ぶ"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("完了"),
    "zolnitConnectAction": MessageLookupByLibrary.simpleMessage("接続"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "ワンタップですぐに接続",
    ),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage("起動後に自動接続"),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "起動時に前回使用したサーバーへ自動接続します。",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "プランに含まれるサーバーに接続します。",
    ),
    "zolnitConnectionPageUnavailable": MessageLookupByLibrary.simpleMessage(
      "接続ページを表示できません。もう一度お試しください。",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("コードをコピー"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "有効なメールアドレスと8文字以上のパスワードを入力してください。",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("相殺済み"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("現在のプラン"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLabel": MessageLookupByLibrary.simpleMessage("現在のプラン"),
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("選択中"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("半年"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("四半期"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("3年"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("2年"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("1年"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("日"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "アカウントのログインセッションを表示します。ノードのオンライン IP 数とは異なります。",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage("ログインセッション"),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "ログインセッションを取得できません。もう一度お試しください。",
    ),
    "zolnitDisconnectAction": MessageLookupByLibrary.simpleMessage("切断"),
    "zolnitDisconnecting": MessageLookupByLibrary.simpleMessage("切断中…"),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("メールアドレス"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage("どの画面でも使い慣れた操作"),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "処理を完了できませんでした。入力内容と接続を確認し、もう一度お試しください。",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("初回の支払い"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage("次回以降の支払い"),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードをお忘れですか？",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("ギフト利用権"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "初回支払いの確認後に有料期間が始まり、残りの無料期間が置き換わります。",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage("厳選された世界の回線"),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "プランと利用可能なサーバーを確認できます。",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("6か月ごと"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage("ヘルプとサポート"),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("招待コード"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage(
      "招待コードをコピーしました",
    ),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "利用可能な報酬",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "確定報酬",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "保留中の報酬",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage("報酬率"),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage("招待リンクをコピーしました"),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage("招待コードを作成"),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "招待コードの作成に失敗しました。もう一度お試しください。",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage(
      "良い体験を、シェアしよう。",
    ),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage("招待リンク"),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "招待データを読み込めませんでした。もう一度お試しください。",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage(
      "友達を招待して始めましょう。",
    ),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("人"),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage("登録済み"),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage("招待ルール"),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage("あなたの招待"),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "友達がリンクから登録しプランを購入すると、報酬が付与されます。",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "友達を招待して登録・購読すると、報酬がもらえます。",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("遅延"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage("最新のお知らせ"),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "複雑な設定は不要。ワンタッチで世界につながります。",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "あなたの世界を、もっと近くに",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "ログインしてプランと接続を管理します。",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage("新規登録・パスワード再設定"),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("グローバル"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage("スマート分流"),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("月払い"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage("毎月の自動支払い"),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("マイスペース"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("新しいパスワード"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage("次回の更新"),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "有効なプランがありません。下から選んで始めましょう。",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage(
      "表示できるログインセッションはありません。",
    ),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "該当するサーバーはありません。",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage("利用できる支払い方法はありません"),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "この契約で利用できるノードはありません。",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage("お知らせはまだありません"),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("注文はまだありません"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("有効なプランはありません"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage("自動更新の契約はありません"),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "遅延は直近の実測値を表示します。未測定の場合は — と表示されます。",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("サーバー"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "利用可能なサーバーはプランに合わせて自動更新されます。",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("サーバー"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "利用可能なサーバーはアカウントから自動更新されます。",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage("まだ接続されていません"),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("お知らせ"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage("現在のパスワード"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("一回払い"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage("オンラインのデバイス"),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("注文履歴"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("支払済み利用権"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("支払済み利用期限"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "現在のパスワードと、8文字以上で異なる新しいパスワードを入力してください。",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "パスワードを更新しました。",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("支払いへ"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "支払いから戻った後も注文状況の確認が必要です。",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage("支払い状況"),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "この支払い方法はまだ利用できません。",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("支払い待ち"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "保留中の注文があります。「注文」で支払いを続けるか閉じてから、もう一度お試しください。",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ 月"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "初回支払いまたは旧プランの残存価値の充当が確認されると、新しいプランが始まります。",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage("プランの有効期間"),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("プラン"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage("プラン"),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "普段のブラウジングから快適な動画視聴まで、あなたに合った接続を選べます。",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("環境設定"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage("設定"),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "セーフモードでは設定は保持されますが、自動接続やシステムネットワークの変更は行われません。",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "起動と接続の設定を管理します。",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "利用可能なサーバーはアカウントから自動更新されます。",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("3か月ごと"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "自動更新に同意する前にサーバーの見積もりを確認してください。",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "見積もりの有効期限が切れました。プランに戻って選び直してください。",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "操作が多すぎます。しばらくしてからもう一度お試しください。",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage("おすすめのサーバー"),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "近いノードを優先して、より速く接続",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage("おすすめ"),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "表示された初回支払いと更新の条件に基づき、このプランの継続支払いに同意します。",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "現在、このプランでは毎月の自動支払いをご利用いただけません。",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("更新"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("新規登録"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "新規登録とパスワードの再設定は、ZolNit 公式サイトでメールとセキュリティの確認を行います。",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage("現在のプランを更新"),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("プランを更新"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage("自動更新"),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage("通信量をリセット"),
    "zolnitRestoringSession": MessageLookupByLibrary.simpleMessage("ログインを復元中…"),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage("自動更新を再開"),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "承認済みプランに基づく自動請求を再開します。",
    ),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage(
      "このセッションからログアウト",
    ),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "ログインセッションを終了しました。",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "このログインセッションを終了しますか？アカウントを管理するには、そのデバイスで再ログインが必要です。",
    ),
    "zolnitSafeMode": MessageLookupByLibrary.simpleMessage("セーフモード"),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "セーフモードではシステムのネットワーク設定は変更されません。",
    ),
    "zolnitSavePercent": m101,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage("サーバーや地域を検索"),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("選択"),
    "zolnitSelectServer": MessageLookupByLibrary.simpleMessage("サーバーを選択"),
    "zolnitSessionExpired": MessageLookupByLibrary.simpleMessage(
      "ログインの有効期限が切れました。もう一度ログインしてください。",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("ログイン"),
    "zolnitSignInRejected": MessageLookupByLibrary.simpleMessage(
      "メールアドレスまたはパスワードが正しくありません。もう一度お試しください。",
    ),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage(
      "起動時に ZolNit を開始",
    ),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "デバイスの起動後、ZolNit をあらかじめ準備します。",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("利用中"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("未契約"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage("プランを選ぶ"),
    "zolnitSync": MessageLookupByLibrary.simpleMessage("アカウントデータを同期"),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage("アカウントデータを同期しました"),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage("アカウントデータを同期中…"),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("アカウント情報"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("友達紹介"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("注文履歴"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage("接続を、もっとシンプルに。"),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("3年ごと"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("残りの通信量"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage("今期の使用量"),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("2年ごと"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage("ログインセッション"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage(
      "月額の見積もりを表示",
    ),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage("ZolNit サイトを開く"),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("おかえりなさい"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("ワークスペース"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("年払い"),
  };
}

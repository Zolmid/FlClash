// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ko locale. All the
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
  String get localeName => 'ko';

  static String m0(count, skipped) => "추가 ${count}개, 이미 있어서 건너뜀 ${skipped}개";

  static String m1(detail) => "데이터를 지우지 못했습니다: ${detail}";

  static String m2(code) =>
      "Windows에서 FlClashCore.exe 실행을 거부했습니다(오류 ${code}). Smart App Control이나 AppLocker와 같은 앱 제어 정책이 서명되지 않은 프로그램을 차단합니다. 해당 정책에서 FlClash를 허용하거나 정책을 끈 후 다시 시도하세요.";

  static String m3(name) =>
      "앱이 두 번 연속 시작을 완료하지 못했습니다. 반복을 끊기 위해 프로필 ${name}의 선택을 해제하고 자동 설정을 건너뛰었습니다. 언제든지 다시 선택할 수 있습니다.";

  static String m4(url) => "${url}에서 프로필을 만드시겠습니까?";

  static String m5(count, label) =>
      "${Intl.plural(count, other: '사용자 지정 프로필은 하위 규칙을 지원하지 않아 SUB-RULE 규칙 ${label}개를 제외했습니다')}";

  static String m6(message) => "코어가 이 프록시를 해석할 수 없습니다: ${message}";

  static String m7(proxy, target) =>
      "${proxy}이(가) ${target}을(를) 거쳐 다시 ${proxy}(으)로 돌아오므로 다이얼이 순환합니다";

  static String m8(name) => "다른 프록시 또는 프록시 그룹이 이미 사용 중인 이름입니다: ${name}";

  static String m9(path) => "프록시 그룹이 서로를 순환 참조합니다: ${path}";

  static String m10(name) => "빈 폴백은 프록시여야 하지만 존재하지 않거나 프록시 그룹입니다: ${name}";

  static String m11(name, message) => "올바른 정규식이 아닙니다(${name}): ${message}";

  static String m12(name) => "존재하지 않는 다이얼러 프록시: ${name}";

  static String m13(names) => "존재하지 않는 프록시 공급자: ${names}";

  static String m14(names) => "존재하지 않는 프록시 또는 정책: ${names}";

  static String m15(name) => "내장 정책 이름이라 여기에서 사용할 수 없습니다: ${name}";

  static String m16(count) => "문제가 있는 항목 ${count}개, 이 프로필을 적용하면 실패할 수 있습니다";

  static String m17(count) => "${Intl.plural(count, other: '${count}일 전')}";

  static String m18(count) => "${Intl.plural(count, other: '${count}일 전')}";

  static String m19(label) => "선택한 ${label}을(를) 삭제하시겠습니까?";

  static String m20(label) => "이 ${label}을(를) 삭제하시겠습니까?";

  static String m21(label) => "${label} 상세 정보";

  static String m22(name) =>
      "${name}을(를) 거치는 다이얼이 이를 사용하는 프록시로 되돌아와 연결을 중단했습니다";

  static String m23(label) => "${label}을(를) 입력하세요";

  static String m24(count) =>
      "${Intl.plural(count, one: '항목 1개', other: '항목 ${count}개')}";

  static String m25(label) => "${label}이(가) 이미 있습니다";

  static String m26(count) => "${count}개 항목 실패";

  static String m27(label, message) => "${label}: ${message}";

  static String m28(name) => "${name}: 이미 최신 상태입니다";

  static String m29(name) => "${name}: 업데이트됨";

  static String m30(name) => "${name} 업데이트 중...";

  static String m31(count) => "${Intl.plural(count, other: '그룹 ${count}개')}";

  static String m32(count) => "${count}개 시간 초과";

  static String m33(action) => "이미 “${action}”에서 사용 중입니다. 저장하면 이쪽으로 옮겨집니다.";

  static String m34(modifiers) => "${modifiers} 중 하나 이상을 포함하세요";

  static String m35(count) => "${Intl.plural(count, other: '${count}시간 전')}";

  static String m36(count) => "${Intl.plural(count, other: '${count}시간 전')}";

  static String m37(target) => "올바르지 않은 정책: ${target}";

  static String m38(proxyName) => "올바르지 않은 프록시: ${proxyName}";

  static String m39(providerName) => "올바르지 않은 프록시 공급자: ${providerName}";

  static String m40(ruleSet) => "올바르지 않은 규칙 세트: ${ruleSet}";

  static String m41(subRule) => "올바르지 않은 SUB_RULE: ${subRule}";

  static String m42(count) => "${Intl.plural(count, other: '항목 ${count}개')}";

  static String m43(line, message) => "${line}행: ${message}";

  static String m44(appName) =>
      "1. 시스템 설정 > 개인정보 보호 및 보안을 엽니다\n2. 위치 서비스를 선택합니다\n3. 목록에서 ${appName}을(를) 찾아 체크합니다\n\n완료되면 앱으로 돌아와 계속하세요. 협조해 주셔서 감사합니다.";

  static String m45(label, max) => "${label}은(는) 최대 ${max}자까지 입력할 수 있습니다";

  static String m46(size) => "${size} 해제됨";

  static String m47(count) => "${Intl.plural(count, other: '${count}분 전')}";

  static String m48(count) => "${Intl.plural(count, other: '${count}분 전')}";

  static String m49(count) => "${Intl.plural(count, other: '${count}개월 전')}";

  static String m50(count) => "${Intl.plural(count, other: '${count}개월 전')}";

  static String m51(code) =>
      "서버가 접근을 거부했습니다(HTTP ${code}). 링크가 만료되었거나 자격 증명이 잘못되었을 수 있습니다";

  static String m52(code) => "서버가 요청을 거부했습니다(HTTP ${code})";

  static String m53(code) =>
      "이 주소에서 아무것도 찾지 못했습니다(HTTP ${code}). URL이 올바른지 확인하세요";

  static String m54(detail) => "네트워크 요청 실패: ${detail}";

  static String m55(code) => "서버에 문제가 발생했습니다(HTTP ${code}). 나중에 다시 시도하세요";

  static String m56(label) => "${label}이(가) 아직 없습니다";

  static String m57(label, min, max) => "${label}은(는) ${min}에서 ${max} 사이여야 합니다";

  static String m58(label) => "${label}은(는) 숫자여야 합니다";

  static String m59(label) => "${label}은(는) 1024에서 49151 사이여야 합니다";

  static String m60(port) => "포트 ${port}";

  static String m61(days) => "${Intl.plural(days, other: '${days}일 남음')}";

  static String m62(date, days) =>
      "${date} 만료, ${Intl.plural(days, other: '${days}일')} 남음";

  static String m63(time) => "${time} 업데이트";

  static String m64(label, profiles) =>
      "${label}은(는) 아직 ${profiles}에서 사용 중이며, 삭제하면 해당 프로필이 제대로 작동하지 않습니다. 삭제하시겠습니까?";

  static String m65(count, label) =>
      "${Intl.plural(count, other: '프록시 ${label}개')}";

  static String m66(name, count) => "${name} 외 (프록시 ${count}개)";

  static String m67(removed) =>
      "다음 프록시가 삭제됩니다: ${removed}. 이름이 바뀐 줄은 새 프록시로 간주되며, 삭제된 프록시를 지정한 사용자 지정 프로필에는 누락으로 표시됩니다. 그래도 적용하시겠습니까?";

  static String m68(removed, added) =>
      "다음 프록시가 삭제됩니다: ${removed}. 다음 프록시가 추가됩니다: ${added}. 이름이 바뀐 줄은 새 프록시로 간주되며, 삭제된 프록시를 지정한 사용자 지정 프로필에는 누락으로 표시됩니다. 그래도 적용하시겠습니까?";

  static String m69(label) =>
      "${label}은(는) 이 프로필의 규칙, 프록시 그룹, 다이얼러 프록시, DNS 또는 NTP에서 아직 참조 중이며, 삭제하면 작동하지 않게 됩니다. 삭제하시겠습니까?";

  static String m70(count, label) =>
      "${Intl.plural(count, other: '프록시 그룹 ${label}개')}";

  static String m71(maximum) => "0에서 ${maximum} 사이의 정수를 입력하세요.";

  static String m72(count, label) =>
      "${Intl.plural(count, other: '규칙 ${label}개')}";

  static String m73(appName) => "${appName} (안전 모드)";

  static String m74(count) => "${Intl.plural(count, other: '${count}초')}";

  static String m75(count) => "${count}개 적용 중";

  static String m76(count) => "${Intl.plural(count, other: '문제 ${count}건')}";

  static String m77(time) => "확인 시각: ${time}";

  static String m78(count) => "${Intl.plural(count, other: '설정 ${count}개')}";

  static String m79(link) => "읽을 수 있는 프록시가 없습니다: ${link}";

  static String m80(label) => "${label}은(는) 하나만 입력해야 합니다";

  static String m81(value) => "최고 ${value}";

  static String m82(value) => "합계 ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · 유휴 ${idleInterval}";

  static String m84(interval) => "${interval} · 유휴 모드 꺼짐";

  static String m85(label) => "${label}은(는) URL이어야 합니다";

  static String m86(count) => "${Intl.plural(count, other: '${count}년 전')}";

  static String m87(count) => "${Intl.plural(count, other: '${count}년 전')}";

  static String m88(amount, cycle) => "${cycle}에 ${amount}, 한 번에 결제";

  static String m89(date) => "${date}에 만료됩니다. 업그레이드와 갱신 모두 여기서 할 수 있습니다.";

  static String m90(plan) => "현재 요금제 · ${plan}";

  static String m91(days) => "${days}일 남음";

  static String m92(date) => "${date} 만료";

  static String m93(count) => "최대 ${count}대 동시 접속";

  static String m94(mbps) => "최대 속도 ${mbps} Mbps";

  static String m95(gb) => "매월 고속 데이터 ${gb} GB";

  static String m96(name) => "안녕하세요, ${name}님.";

  static String m97(rate) => "${rate}× 계량";

  static String m98(count) => "서버: ${count}";

  static String m99(count) => "/ ${count}대";

  static String m100(days) => "${days}일 후 초기화";

  static String m101(percent) => "${percent}% 절약";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("정보"),
    "accessControl": MessageLookupByLibrary.simpleMessage("접근 제어"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "선택한 앱만 VPN을 거칩니다",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "접근 제어는 프록시를 사용할 앱을 선택합니다.",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "앱 접근 제어가 꺼져 있습니다",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "선택한 앱은 VPN에서 제외됩니다",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("접근 제어 설정"),
    "accessDenied": MessageLookupByLibrary.simpleMessage("접근 거부"),
    "account": MessageLookupByLibrary.simpleMessage("계정"),
    "action": MessageLookupByLibrary.simpleMessage("동작"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("모든 지연 테스트"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("직접 모드"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("전역 모드"),
    "actionMode": MessageLookupByLibrary.simpleMessage("모드 전환"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("시스템 프록시"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("규칙 모드"),
    "actionStart": MessageLookupByLibrary.simpleMessage("시작/중지"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("프로필 업데이트"),
    "actionView": MessageLookupByLibrary.simpleMessage("표시/숨기기"),
    "add": MessageLookupByLibrary.simpleMessage("추가"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("프록시 추가"),
    "addFilters": MessageLookupByLibrary.simpleMessage("필터 추가"),
    "addNodes": MessageLookupByLibrary.simpleMessage("노드 추가"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("덮어쓰기 항목 추가"),
    "addProfile": MessageLookupByLibrary.simpleMessage("프로필 추가"),
    "addProxies": MessageLookupByLibrary.simpleMessage("프록시 추가"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("프록시 그룹 추가"),
    "addRule": MessageLookupByLibrary.simpleMessage("규칙 추가"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("설정 추가"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSID 추가"),
    "addedRules": MessageLookupByLibrary.simpleMessage("추가한 규칙"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("추가 매개변수"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("이름 접두사"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("이름 접미사"),
    "address": MessageLookupByLibrary.simpleMessage("주소"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAV 서버 주소"),
    "addressTip": MessageLookupByLibrary.simpleMessage("올바른 WebDAV 주소를 입력하세요"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("고급 구성"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "고급 구성에는 네트워크, DNS, 추가한 규칙, 스크립트가 포함됩니다.",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("암호화된 프로필"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("Age 키 생성"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519 키 쌍이 생성되었습니다. 안전하게 보관하세요",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 개인 키"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "먼저 올바른 Age 개인 키를 입력하세요",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 공개 키"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 비밀 키"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "올바른 Age 비밀 키를 입력하세요(AGE-SECRET-KEY-로 시작해야 함)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Age 비밀 키(선택 사항)",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "이 프로필은 age로 암호화되어 있어 복호화하려면 age 비밀 키가 필요합니다",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("동의"),
    "allData": MessageLookupByLibrary.simpleMessage("모든 데이터"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage("참조된 모든 프록시"),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "참조된 모든 프록시 공급자",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("앱의 VPN 우회 허용"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 일부 앱이 VPN을 우회할 수 있습니다",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LAN 허용"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("LAN 접근 허용"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "LAN에서 외부 컨트롤러에 접근하도록 허용",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN에서 프록시에 접근하도록 허용"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("허용 IP"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("항상 켜짐"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "모든 네트워크 환경에서 VPN 연결 유지",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("응답"),
    "app": MessageLookupByLibrary.simpleMessage("앱"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("앱 접근 제어"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("앱 아이콘 디자인"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("로컬 프록시 없음"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("시스템 DNS 추가"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "시스템 DNS를 설정에 강제로 추가",
    ),
    "application": MessageLookupByLibrary.simpleMessage("애플리케이션"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("애플리케이션 설정 조정"),
    "ascending": MessageLookupByLibrary.simpleMessage("오름차순"),
    "authentication": MessageLookupByLibrary.simpleMessage("인증"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "인증을 켜면 로컬 프록시 포트에서 사용자 이름과 비밀번호를 요구합니다.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "인증이 켜져 있는 동안에는 시스템 프록시가 적용되지 않습니다.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("허용"),
    "authorized": MessageLookupByLibrary.simpleMessage("허용됨"),
    "auto": MessageLookupByLibrary.simpleMessage("자동"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("업데이트 자동 확인"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "앱 시작 시 자동으로 업데이트 확인",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("연결 자동 종료"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "연결 자동 종료는 프록시를 전환할 때 열려 있는 연결을 끊습니다.",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("자동 포함"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("자동 실행"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("시스템 시작 시 자동 실행"),
    "autoRun": MessageLookupByLibrary.simpleMessage("자동 시작"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "자동 시작은 앱을 열 때 프록시를 시작합니다.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("시스템 DNS 자동 설정"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("자동 업데이트"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("자동 업데이트 간격"),
    "back": MessageLookupByLibrary.simpleMessage("뒤로"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage("대시보드로 돌아가기"),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "종료하기 전에 대시보드로 돌아가기",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("백업"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("백업 및 복원"),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "현지 날짜(YYYY-MM-DD)",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "이 백업은 더 최신 버전의 앱에서 만들어졌습니다. 복원하기 전에 앱을 업데이트하세요",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage("현재 플랫폼"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("백업 완료"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "현지 시간(HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "애플리케이션 버전",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("기본 설정"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("전체 기본 설정 변경"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("기본 정보"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("기본 전략"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("일괄 추가"),
    "batchImport": MessageLookupByLibrary.simpleMessage("일괄 가져오기"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage("한 줄에 링크 하나씩"),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "한 줄에 하나씩 또는 쉼표로 구분하여 입력하세요",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "한 줄에 하나씩, 키, 공백, 값 순서로 입력하세요",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage("한 줄에 URL 하나씩"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "배터리 최적화를 무시하면 앱이 백그라운드에서 계속 실행됩니다.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("연결"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("블랙리스트 모드"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("연결 차단"),
    "brightness": MessageLookupByLibrary.simpleMessage("밝기"),
    "browse": MessageLookupByLibrary.simpleMessage("찾아보기"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("우회 도메인"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "우회 도메인은 시스템 프록시가 켜져 있을 때만 적용됩니다.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage("사설 주소 우회"),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "사설 주소 우회를 켜면 LAN, 루프백, 멀티캐스트 주소는 TUN을 거치지 않습니다.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("캐시"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("캐시 알고리즘"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "캐시가 손상되었습니다. 지우시겠습니까?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("캐시 크기"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "QR 코드를 스캔하려면 시스템 설정에서 카메라 접근을 허용하거나, 앨범에서 QR 코드 이미지를 선택하세요.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "카메라 권한 필요",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("카메라를 사용할 수 없음"),
    "cancel": MessageLookupByLibrary.simpleMessage("취소"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("모두 선택 해제"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("저장할 수 없음"),
    "captureDns": MessageLookupByLibrary.simpleMessage("시스템 DNS 수집"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "모든 시스템 DNS 조회를 내부 DNS 모듈로 리디렉션",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "프록시를 전환하지 못해 이전 선택을 복원했습니다",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("호환성 변경"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("새로운 기능"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("버그 수정"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("성능"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("되돌림"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("TLS 인증서 검증"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "TLS 검증을 끄면 구독과 백업이 중간자 공격에 노출됩니다.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("업데이트 확인"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("이미 최신 버전입니다"),
    "cipher": MessageLookupByLibrary.simpleMessage("암호화 방식"),
    "clear": MessageLookupByLibrary.simpleMessage("지우기"),
    "clearData": MessageLookupByLibrary.simpleMessage("데이터 지우기"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "모든 프로필, 설정, 로컬 데이터를 삭제한 후 앱을 종료합니다. 앱을 다시 열면 처음부터 시작합니다.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("검색 지우기"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage("클라이언트 핑거프린트"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("클립보드로 내보내기"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("클립보드에서 가져오기"),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "클립보드에 복사하지 못했습니다. 선택 영역이 너무 클 수 있습니다",
    ),
    "close": MessageLookupByLibrary.simpleMessage("닫기"),
    "closeAll": MessageLookupByLibrary.simpleMessage("모두 닫기"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("연결 종료"),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "이전 프록시를 사용하는 연결을 종료하시겠습니까?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("접기"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage("프록시 체인 접기"),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "프록시 체인의 노드가 3개를 넘으면 중간 노드 숨기기",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "빠른 설정 패널 닫기",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "타일을 누른 후 패널 닫기",
    ),
    "color": MessageLookupByLibrary.simpleMessage("색상"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("색상 스타일"),
    "columns": MessageLookupByLibrary.simpleMessage("열"),
    "compact": MessageLookupByLibrary.simpleMessage("간결하게"),
    "compatible": MessageLookupByLibrary.simpleMessage("호환 모드"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "설정에서 데이터가 감지되었습니다",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("확인"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "모든 데이터를 지우시겠습니까?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "선택한 데이터를 지우시겠습니까?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "이 프록시 그룹을 삭제하시겠습니까?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage("현재 창을 닫으시겠습니까?"),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "코어를 강제로 비정상 종료시키시겠습니까?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "확인하면 기존 데이터를 덮어씁니다",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage("혼잡 제어"),
    "congestionController": MessageLookupByLibrary.simpleMessage("TCP 혼잡 제어"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 혼잡 제어는 mips 스택에서만 작동합니다.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("연결됨"),
    "connecting": MessageLookupByLibrary.simpleMessage("연결 중…"),
    "connection": MessageLookupByLibrary.simpleMessage("연결"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("연결 수"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("연결 통계"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "실시간 연결, 최근 요청, DNS 쿼리",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("연결"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("현재 연결 정보 보기"),
    "connectivity": MessageLookupByLibrary.simpleMessage("연결 상태: "),
    "content": MessageLookupByLibrary.simpleMessage("내용"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("내용을 입력하세요"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "전역 추가 규칙 관리",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("복사"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("환경 변수 복사"),
    "copyLink": MessageLookupByLibrary.simpleMessage("링크 복사"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("복사했습니다"),
    "core": MessageLookupByLibrary.simpleMessage("코어"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "서명되지 않아 Windows Smart App Control이 FlClashCore.exe를 차단했습니다. Windows 보안 → 앱 및 브라우저 컨트롤 → Smart App Control 설정에서 끔을 선택한 후 FlClash를 다시 시작하세요. Smart App Control은 Windows를 다시 설치하지 않으면 다시 켤 수 없습니다.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("코어 상태"),
    "country": MessageLookupByLibrary.simpleMessage("지역"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("비정상 종료 감지됨"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("비정상 종료 테스트"),
    "create": MessageLookupByLibrary.simpleMessage("만들기"),
    "createProfile": MessageLookupByLibrary.simpleMessage("프로필 만들기"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("생성 시간"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "시작 버튼이 있어 제거할 수 없습니다",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("사용자 지정"),
    "customColor": MessageLookupByLibrary.simpleMessage("사용자 지정 색상"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("이름이 비어 있습니다"),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "선택한 프록시나 프록시 공급자가 없어 코어가 이 그룹을 거부합니다",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("사용자 지정"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "앱 프록시와 다른 프로필로 프록시 그룹과 규칙을 조합합니다",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "사용자 지정 프로필 리소스",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "사용자 지정 프로필 리소스에는 프록시, 규칙 공급자, 필터, 아이콘 세트가 포함됩니다.",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("잘라내기"),
    "dark": MessageLookupByLibrary.simpleMessage("다크"),
    "dashboard": MessageLookupByLibrary.simpleMessage("대시보드"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("추가 가능"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "데이터 변경 사항이 있습니다. 저장하시겠습니까?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "변경 사항을 저장하지 못해 되돌렸습니다",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("디렉터리"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("기본 네임서버"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNS 서버 주소를 확인하는 데 사용",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage("기본 선택"),
    "defaultText": MessageLookupByLibrary.simpleMessage("기본값"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "구성은 이름과 유형이 있는 YAML 매핑이어야 합니다",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("지연"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("실패"),
    "delayTest": MessageLookupByLibrary.simpleMessage("지연 테스트"),
    "delete": MessageLookupByLibrary.simpleMessage("삭제"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMeta 기반의 멀티 플랫폼 프록시 클라이언트로, 간편하게 사용할 수 있으며 오픈 소스이고 광고가 없습니다.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("내림차순"),
    "destination": MessageLookupByLibrary.simpleMessage("목적지"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("목적지 GeoIP"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("목적지 IP ASN"),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "서드파티 API에 의존하므로 참고용으로만 사용하세요",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("개발자 모드"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "개발자 모드가 켜졌습니다.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("다이얼러 프록시"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "다이얼러 프록시는 NTP 서버에 연결할 때 사용하는 아웃바운드입니다.",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("직접"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "ICMP 전달 사용 안 함",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "ICMP 전달을 끄면 TUN이 ping에 직접 응답하므로 ping에 실제 지연 시간이 표시되지 않습니다.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "TCP 킵얼라이브 사용 안 함",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDP 사용 안 함"),
    "disabled": MessageLookupByLibrary.simpleMessage("사용 안 함"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("변경 사항을 취소하시겠습니까?"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("면책 조항"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어를 설치, 복사 또는 사용하면 이 문서 전체를 읽고 동의한 것으로 간주합니다. 어느 조항이라도 동의하지 않는 경우 즉시 본 소프트웨어의 사용을 중단하고 삭제하세요.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("동의"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "이 문구를 읽고 이해했습니다",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "내용을 이해했는지 확인하기 위해 다음 문구를 읽고 아래 항목에 체크하세요.",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("문구 확인"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "개발자는 릴리스와 함께 본 문서를 개정할 수 있으며, 개정 내용은 해당 릴리스가 공개되는 시점에 효력이 발생합니다. 업데이트 후에도 본 소프트웨어를 계속 사용하면 개정된 문서를 수락한 것으로 간주합니다.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("본 문서의 변경"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash(이하 “본 소프트웨어”)를 사용하기 전에 이 문서를 주의 깊게 읽고 모든 내용을 이해했는지 확인하세요. “동의”를 누르면 아래 모든 조항을 읽고 이해했으며 수락한 것으로 간주합니다. 동의하지 않으면 “종료”를 누르고 본 소프트웨어의 사용을 중단하세요.",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "관련 법률이 허용하는 최대 범위에서, 개발자와 기여자는 본 소프트웨어의 사용 또는 사용 불능으로 발생하는 직접, 간접, 부수적, 특별, 징벌적 또는 결과적 손해에 대해 책임을 지지 않습니다. 여기에는 데이터 손실, 기기 손상, 네트워크 장애, 사업 중단, 이익 손실 및 그로 인한 법적 분쟁이 포함되며 이에 국한되지 않고, 그러한 손해의 가능성을 사전에 통지받은 경우에도 마찬가지입니다.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("책임의 제한"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어는 GPL-3.0 라이선스로 공개된 오픈 소스입니다. 파생 저작물도 GPL-3.0으로 배포하고 원저작권 고지를 유지해야 하는 라이선스 조건을 준수하는 한 자유롭게 사용, 수정, 배포할 수 있습니다.\n\nClash.Meta 코어를 포함한 본 소프트웨어의 제3자 구성 요소는 각자의 라이선스를 따릅니다. 원저작자는 수정 또는 재배포된 버전에서 발생하는 어떠한 문제에도 책임을 지지 않습니다.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "오픈 소스 라이선스",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어 자체는 프록시 서버, 노드, 구독, 네트워크 접속 서비스를 일절 제공하지 않으며, 이러한 서비스의 어떤 제공자와도 제휴, 대리 또는 보증 관계가 없습니다.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어는 구독 URL, 노드 정보, 구성 내용, 방문한 웹사이트, 연결 기록, 트래픽 내용, 로그를 수집하거나 업로드하지 않습니다. 이 데이터는 사용자의 기기에만 저장되며 개발자는 접근할 수 없습니다.\n\n본 소프트웨어는 프로필을 업데이트할 때 사용자가 입력한 구독 URL을 가져오거나 업데이트를 확인할 때 GitHub에 접속하는 등 기능이 필요할 때만 네트워크에 접속합니다.\n\n본 소프트웨어에는 어떤 플랫폼에서도 분석 또는 비정상 종료 보고 서비스가 포함되어 있지 않습니다.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "데이터 수집 및 개인정보 보호",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어의 사용이 거주지에서 적법한지 확인할 책임은 사용자에게 있으며, 본 소프트웨어로 한 모든 행위와 그 결과에 대한 법적 책임은 사용자 본인이 부담합니다.\n\n가져오는 구독, 노드, 구성은 사용자 본인의 선택입니다. 출처의 적법성, 콘텐츠의 안전성, 서비스의 신뢰성은 사용자와 해당 제공자 사이의 문제입니다.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "사용자의 책임",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "위 문구를 입력하세요",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "문구와 일치하지 않습니다",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "내용을 이해했는지 확인하기 위해 아래 입력란에 다음 문구를 그대로 입력하세요.",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("문구 다시 입력"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어는 Clash.Meta(mihomo) 코어를 기반으로 한 오픈 소스 네트워크 프록시 클라이언트입니다. 구성 관리, 규칙 기반 라우팅, 트래픽 전달과 같은 로컬 도구만 제공합니다.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "소프트웨어의 성격",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "구독 링크, 구성 파일, 규칙 세트, 스크립트, 외부 리소스, 외부 링크는 모두 제3자가 제공합니다. 개발자는 이들의 적법성, 정확성, 안전성, 가용성을 심사하거나 보증할 수 없으며 보증하지 않습니다.\n\n제3자 콘텐츠로 인한 데이터 유출, 금전적 손실, 계정 정지 및 기타 손해는 사용자와 해당 제3자 사이에서 해결해야 하며, 개발자는 이에 대해 책임을 지지 않습니다.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "제3자 콘텐츠",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어는 학습, 교류, 기술 연구와 같은 비상업적 용도로만 제공됩니다. 유료 배포, 끼워 팔기, 상업 서비스의 일부로 사용, 본 소프트웨어의 이름을 내세운 영업 등 어떠한 상업적 목적의 사용도 엄격히 금지되며, 이에 국한되지 않습니다. 모든 상업 활동은 본 소프트웨어 및 개발자와 무관합니다.\n\n거주 국가 또는 지역의 법령을 위반하는 용도로 본 소프트웨어를 사용하는 것은 엄격히 금지됩니다. 여기에는 합법적으로 부과된 네트워크 접속 제한 우회, 불법 콘텐츠 유포, 네트워크 공격, 타인의 합법적 권리 침해가 포함되며 이에 국한되지 않습니다.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("사용 제한"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "본 소프트웨어는 “있는 그대로”, “이용 가능한 상태로” 제공되며, 상품성, 특정 목적에의 적합성, 비침해성, 중단 없는 이용 가능성, 오류 없음, 보안 취약점 없음에 대한 보증을 포함하되 이에 국한되지 않고 명시적이든 묵시적이든 어떠한 종류의 보증도 하지 않습니다.\n\n개발자는 본 소프트웨어가 사용자의 요구를 충족하거나 중단 및 오류 없이 실행될 것임을 보증하지 않습니다.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("보증 부인"),
    "disconnected": MessageLookupByLibrary.simpleMessage("연결 끊김"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("새 버전 발견"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS 관련 설정 변경"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS 가로채기"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "추가하지 않으면 53번 포트로 가는 모든 DNS 쿼리를 하이재킹합니다(any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS 하이재킹"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "비활성화하면 AAAA 조회는 빈 결과를 반환합니다",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS 모드"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "여기에 추가한 항목은 모든 URL 및 파일 프로필의 DNS를 대체합니다. 추가하지 않은 항목은 프로필 자체 설정을 유지합니다. 사용자 지정 프로필은 내용에서 DNS를 설정합니다.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS 쿼리"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage("코어 DNS 조회 기록"),
    "docked": MessageLookupByLibrary.simpleMessage("고정"),
    "domain": MessageLookupByLibrary.simpleMessage("도메인"),
    "done": MessageLookupByLibrary.simpleMessage("완료"),
    "download": MessageLookupByLibrary.simpleMessage("다운로드"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("다운로드 대역폭"),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("다운로드 속도"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("다운로드 트래픽"),
    "duration": MessageLookupByLibrary.simpleMessage("소요 시간"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage("연결 지연"),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS 영역"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage("기능 플래그"),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("인스턴스 ID"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "경로 지연(지연 시간 우선)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("리스너"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage("로컬 엔드포인트"),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("패킷 손실률"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "최소 직접 연결 지연",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage("다음 홉 피어 ID"),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "경로 지연(홉 수 우선)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("피어 ID"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage("전송 프로토콜"),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage("공개 서버"),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage("원격 엔드포인트"),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("경로 비용"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage("수신 패킷"),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage("송신 패킷"),
    "edit": MessageLookupByLibrary.simpleMessage("편집"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("대시보드 편집"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("전역 규칙 편집"),
    "editProxy": MessageLookupByLibrary.simpleMessage("프록시 편집"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("프록시 그룹 편집"),
    "editRule": MessageLookupByLibrary.simpleMessage("규칙 편집"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSID 편집"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("편집기를 사용할 수 없음"),
    "elapsed": MessageLookupByLibrary.simpleMessage("소요"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("빈 폴백"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("영어"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "외부 컨트롤러 활성화",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("사용"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT 개선"),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "UDP 및 P2P 애플리케이션 연결 최적화",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("엔드포인트"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("경로 강제 적용"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "더 구체적인 경로가 있어도 트래픽이 터널을 통과하도록 보장",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("개 항목"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("오류"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("오류 세부 정보"),
    "es": MessageLookupByLibrary.simpleMessage("스페인어"),
    "exclude": MessageLookupByLibrary.simpleMessage("최근 작업에서 숨기기"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("APNs 제외"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Apple 푸시 알림 트래픽이 터널을 우회하도록 허용",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "셀룰러 서비스 제외",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Wi-Fi 통화 등의 셀룰러 서비스 트래픽이 터널을 우회하도록 허용",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "백그라운드에서 실행 중일 때 최근 앱 목록에서 숨기기",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "기기 간 통신 제외",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "AirDrop 및 AirPlay 등의 기기 간 트래픽이 터널을 우회하도록 허용",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("제외할 대상 포트"),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "제외할 대상 포트로 가는 트래픽은 TUN을 거치지 않습니다.",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("제외 필터"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("제외할 인터페이스"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "docker0와 같이 제외할 인터페이스로 들어오는 트래픽은 TUN을 거치지 않습니다.",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage("로컬 네트워크 제외"),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "로컬 네트워크 기기에 직접 접근하도록 허용",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("프록시 제외 필터"),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("제외할 소스 포트"),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "제외할 소스 포트에서 나가는 트래픽은 TUN을 거치지 않습니다.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("제외할 SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "제외 SSID의 Wi-Fi에 연결되면 앱의 실행 상태가 자동으로 전환됩니다.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("제외 유형"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("제외할 사용자 ID"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "제외할 사용자 ID의 프로세스 트래픽은 TUN을 거치지 않습니다.",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("종료"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("전체 화면 종료"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("출구 노드"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("예상 상태"),
    "expireTime": MessageLookupByLibrary.simpleMessage("만료 시간"),
    "exportFile": MessageLookupByLibrary.simpleMessage("파일 내보내기"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("로그 내보내기"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("내보내기 완료"),
    "extend": MessageLookupByLibrary.simpleMessage("확장"),
    "extendMode": MessageLookupByLibrary.simpleMessage("확장 모드"),
    "extendScript": MessageLookupByLibrary.simpleMessage("확장 스크립트"),
    "externalController": MessageLookupByLibrary.simpleMessage("외부 컨트롤러"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "외부 컨트롤러를 사용하면 9090 포트로 코어를 제어할 수 있습니다.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "외부 컨트롤러 시크릿",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("외부에서 가져오기"),
    "externalLink": MessageLookupByLibrary.simpleMessage("외부 링크"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("매우 크게"),
    "fade": MessageLookupByLibrary.simpleMessage("페이드"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IP 필터"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Fake IP 모드에서 일치하는 도메인에는 Fake IP 대신 실제 IP 주소 반환",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IP 필터 모드"),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Fake-IP 필터 모드에서 블랙리스트는 일치 항목을 제외하고, 화이트리스트는 일치 항목에만 가짜 IP를 사용하며, 규칙은 규칙에 따라 일치시킵니다.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP 범위"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP 범위(IPv6)"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("대체 DNS"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("일반적으로 해외 DNS 사용"),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "일치하는 도메인은 네임서버에 조회하지 않고 대체 DNS를 바로 사용",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("폴백 필터"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "네임서버 결과를 GeoIP 코드와 비교하며, 해당 지역 외의 결과에는 대체 DNS 사용",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "이 GeoSite 분류에 일치하는 도메인은 대체 DNS를 바로 사용",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "네임서버 결과가 이 CIDR 접두사와 일치하면 대체 DNS 결과로 변경",
    ),
    "features": MessageLookupByLibrary.simpleMessage("기능"),
    "file": MessageLookupByLibrary.simpleMessage("파일"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("프로필 파일을 직접 업로드"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "파일이 수정되었습니다. 변경 사항을 저장하시겠습니까?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("파일 이름"),
    "filter": MessageLookupByLibrary.simpleMessage("필터"),
    "filters": MessageLookupByLibrary.simpleMessage("필터"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("프로세스 찾기"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 성능이 다소 저하될 수 있습니다",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("플로팅"),
    "followProfile": MessageLookupByLibrary.simpleMessage("프로필 따르기"),
    "followSystem": MessageLookupByLibrary.simpleMessage("시스템 설정 따르기"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("글꼴"),
    "fontSize": MessageLookupByLibrary.simpleMessage("크기"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("DNS 매핑 강제"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "DNS 매핑 강제는 DNS 매핑에서 도메인을 얻은 연결도 스니핑합니다.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("강제 도메인"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "강제 도메인은 항상 스니핑합니다. 이미 도메인이 있는 다른 연결은 그대로 둡니다.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "코어를 강제로 다시 시작하시겠습니까?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("프랑스어"),
    "general": MessageLookupByLibrary.simpleMessage("일반"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("앱과 코어의 일반 설정"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Age 개인 키에서 생성",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("생성"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("자동 업데이트"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("자동 업데이트 간격"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "자동 업데이트 간격은 0보다 커야 합니다",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geo 옵션"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo 저메모리 모드"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage("저메모리 Geo 로더 사용"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP 코드"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage("고성능 Geo 일치 엔진"),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 최소 완전 해시 알고리즘을 사용하여 일치 여부 판별",
    ),
    "global": MessageLookupByLibrary.simpleMessage("전역"),
    "go": MessageLookupByLibrary.simpleMessage("이동"),
    "goDownload": MessageLookupByLibrary.simpleMessage("다운로드"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "추가한 규칙 구성으로 이동",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("스크립트 구성으로 이동"),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("고루틴"),
    "grid": MessageLookupByLibrary.simpleMessage("격자"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("개"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("변경 사항을 캐시하시겠습니까?"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("인바운드 사용자별 해시"),
    "header": MessageLookupByLibrary.simpleMessage("헤더"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("상태 확인"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "헬퍼 서비스를 사용할 수 없어 TUN 모드를 켤 수 없습니다. FlClash를 다시 설치하여 복구하세요.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("16진수"),
    "hide": MessageLookupByLibrary.simpleMessage("숨기기"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("목록에서 숨기기"),
    "hideIp": MessageLookupByLibrary.simpleMessage("IP 숨기기"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("비밀번호 숨기기"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "시간 초과된 프록시 숨기기",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "마지막 지연 테스트에서 시간 초과된 프록시를 제외합니다",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("시간 초과 숨기기"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "높은 우선순위로 자동 실행",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Windows 예약 작업을 사용하여 더 일찍 시작",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("호핑 간격"),
    "host": MessageLookupByLibrary.simpleMessage("호스트"),
    "hostname": MessageLookupByLibrary.simpleMessage("호스트 이름"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("hosts 항목 추가"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("단축키 충돌"),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "전역 단축키는 창이 숨겨져 있어도 작동합니다. 동작을 눌러 키 조합을 기록하세요.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("단축키 관리"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage("키보드로 앱 제어"),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("설정 안 됨"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "등록되지 않음: 다른 앱이 사용 중일 수 있습니다",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("시간"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("색조"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP 전달"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage("ICMP ping 활성화"),
    "icon": MessageLookupByLibrary.simpleMessage("아이콘"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("아이콘 기록"),
    "iconSets": MessageLookupByLibrary.simpleMessage("아이콘 세트"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "아이콘 세트가 아직 없습니다. 사용자 지정 프로필 리소스 → 아이콘 세트에서 추가하세요",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("아이콘 소스"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("아이콘 스타일"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("채움"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("숨김"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("기본"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("아이콘 URL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "배터리 최적화 무시",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "인증서 검증 무시",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "유효하지 않은 인증서로 HTTPS 연결을 허용합니다. 보안이 약화됩니다",
    ),
    "import": MessageLookupByLibrary.simpleMessage("가져오기"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "가져올 수 있는 구성 파일이 아닙니다",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "가져오면 이 프로필의 현재 프록시 그룹, 규칙, 설정이 대체됩니다",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("파일에서 가져오기"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("링크에서 가져오기"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URL에서 가져오기"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URL에서 가져오기"),
    "inbound": MessageLookupByLibrary.simpleMessage("인바운드"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage("모든 네트워크 포함"),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "로컬 및 셀룰러 서비스를 포함한 모든 네트워크 트래픽을 터널로 라우팅",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("모든 프록시 포함"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "프록시 그룹 외부의 모든 프록시를 가져옵니다. 아래에서 프록시 그룹을 추가할 수 있습니다",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "모든 프록시 제공자 포함",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "활성화하면 가져온 프록시 제공자를 덮어씁니다",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage("포함할 인터페이스"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "포함할 인터페이스로 들어오는 트래픽만 TUN을 거치며, 제외할 인터페이스는 더 이상 적용되지 않습니다.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("포함할 사용자 ID"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "포함할 사용자 ID의 프로세스 트래픽만 TUN을 거칩니다.",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("만료되지 않음"),
    "init": MessageLookupByLibrary.simpleMessage("초기화"),
    "initFailed": MessageLookupByLibrary.simpleMessage("시작 실패"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash를 시작하는 중 오류가 발생하여 계속할 수 없습니다. 세부 정보를 복사하여 문제를 보고하세요. 문제가 계속되면 데이터를 지우면 대개 앱이 다시 시작됩니다.",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("초기화"),
    "initiator": MessageLookupByLibrary.simpleMessage("요청자"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("출처"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "올바른 단축키를 입력하세요",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "프록시 그룹 이름을 입력하세요",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("규칙 내용을 입력하세요"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "앱 목록 권한이 거부되어 설치된 앱을 표시할 수 없습니다. 시스템 설정에서 직접 허용해 주세요.",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "이 시스템은 권한을 허용하기 전까지 설치된 앱 목록을 숨깁니다. 앱별 프록시를 구성하려면 권한을 허용하세요.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "앱 목록 권한 필요",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("설치된 글꼴"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("스마트 선택"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("인터페이스 이름"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "인터페이스 이름은 아웃바운드 연결이 사용하는 네트워크 인터페이스입니다.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage("아웃바운드 인터페이스"),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("지정 안 함"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("사용자 지정"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("구성 따르기"),
    "internet": MessageLookupByLibrary.simpleMessage("인터넷"),
    "interval": MessageLookupByLibrary.simpleMessage("간격"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("내부망 IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("올바르지 않은 백업 파일"),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "경로 구분자나 특수 문자가 없는 올바른 파일 이름을 255바이트 이내로 입력하세요.",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "192.168.0.0/16과 같은 CIDR 형식의 IP 범위를 입력하세요",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      ". 또는 .. 경로 구간, 역슬래시, 특수 문자가 없는 올바른 디렉터리를 입력하세요.",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP 마크는 63을 넘을 수 없습니다",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "도메인 또는 IP 주소를 입력하세요",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("올바른 아이콘 세트가 아닙니다"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "구독 링크 또는 프록시 공유 링크가 아닙니다",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "0.0.0.0:1053과 같은 주소와 포트를 입력하세요",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "tcp 또는 udp만 지원합니다",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "443 또는 8000-9000과 같은 포트나 범위를 입력하세요",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "이 QR 코드에는 프로필 링크가 없습니다",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "80 또는 8000-9000과 같은 숫자나 범위를 /로 구분하여 입력하세요",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP 주소"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("악용 이력"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("프록시"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("플래그"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("조직"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "IP 유형을 확인할 수 없습니다",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("양호"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("등급"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("보통"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("다시 확인"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("위험"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("품질"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("응답 출처"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("출처"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage("아웃바운드 IP가 다름"),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("유형 없음"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("요청 제한됨"),
    "ipType": MessageLookupByLibrary.simpleMessage("유형"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("기업용"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("데이터 센터"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("모바일 네트워크"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("가정용"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("알 수 없는 유형"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP 버전"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "IPv6 트래픽은 IPv6가 켜져 있을 때만 수신됩니다.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "IPv6를 켜면 VPN이 IPv6 인바운드를 허용합니다.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6 타임아웃(ms)"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("일본어"),
    "justNow": MessageLookupByLibrary.simpleMessage("방금"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP 킵얼라이브 유휴 시간"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 킵얼라이브 간격",
    ),
    "key": MessageLookupByLibrary.simpleMessage("키"),
    "ko": MessageLookupByLibrary.simpleMessage("한국어"),
    "label": MessageLookupByLibrary.simpleMessage("레이블"),
    "language": MessageLookupByLibrary.simpleMessage("언어"),
    "large": MessageLookupByLibrary.simpleMessage("크게"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("마지막 업데이트"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("시작이 완료되지 않음"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "지난번 시작하는 중에 앱이 예기치 않게 종료되었습니다. 이번 실행에서는 자동 설정을 건너뛰었으니 직접 시작하여 다시 시도하세요.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("레이아웃"),
    "level": MessageLookupByLibrary.simpleMessage("수준"),
    "light": MessageLookupByLibrary.simpleMessage("라이트"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("줄 간격"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("자동 줄 바꿈"),
    "link": MessageLookupByLibrary.simpleMessage("링크"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "구독 링크 또는 프록시 공유 링크로 프로필 가져오기",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("목록"),
    "listen": MessageLookupByLibrary.simpleMessage("수신"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("수신 라우팅 마크"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "수신 라우팅 마크는 Linux에서만 작동합니다.",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("수신 포트"),
    "liveConnections": MessageLookupByLibrary.simpleMessage("실시간 연결"),
    "loading": MessageLookupByLibrary.simpleMessage("로드 중…"),
    "local": MessageLookupByLibrary.simpleMessage("로컬"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("로컬에 데이터 백업"),
    "localImage": MessageLookupByLibrary.simpleMessage("로컬 이미지"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "로컬 네트워크 권한이 거부되었습니다. gvisor 스택을 사용하므로 LAN에 연결할 수 없습니다.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("로컬 프록시"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("위치 권한"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "위치 권한이 거부되어 현재 Wi-Fi 이름을 읽을 수 없습니다. 시스템 설정에서 위치 권한을 직접 켜 주세요.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "시스템에서 Wi-Fi 이름을 읽으려면 위치 권한이 필요합니다. Android에서는 “항상 허용”을 선택해야 하며, 그렇지 않으면 앱이 백그라운드에 있을 때 Wi-Fi 이름을 읽을 수 없습니다.",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "위치 권한 필요",
    ),
    "log": MessageLookupByLibrary.simpleMessage("로그"),
    "logLevel": MessageLookupByLibrary.simpleMessage("로그 수준"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Logcat을 끄면 로그 항목이 숨겨집니다.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("로그"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("로그 및 진단"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("수집된 로그 기록"),
    "logsTest": MessageLookupByLibrary.simpleMessage("로그 테스트"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP 루프백 예외"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWP 루프백 예외 설정에 사용"),
    "loose": MessageLookupByLibrary.simpleMessage("넓게"),
    "manual": MessageLookupByLibrary.simpleMessage("수동"),
    "matchCase": MessageLookupByLibrary.simpleMessage("대/소문자 구분"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("출발지 IP 일치"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET을 대상으로 하는 규칙의 전달 위치입니다. 기본값은 이 프로필의 마지막 MATCH 규칙 대상입니다.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("일치 대상"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("최대 실패 횟수"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("최대화"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("앱 메모리"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("상주 메모리"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("앱 및 공유"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("정리"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("유휴 힙"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("사용 중인 힙"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "코어가 실행 중이 아닙니다",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("런타임 오버헤드"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("고루틴 스택"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 상주 메모리로 추정한 값이며 시스템에 표시되는 값과 다를 수 있습니다.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "코어는 앱 프로세스 안에서 실행됩니다. 코어의 점유량은 런타임 통계로 추정하며, 나머지는 앱 및 공유 메모리로 집계합니다.",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage("메모리 풋프린트"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("GC 메타데이터"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage("보유 중인 유휴 힙"),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("힙 객체"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("운영체제에 반환됨"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage("미사용 힙 스팬"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("메모리 정보"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("앱과 코어가 사용하는 메모리"),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage("런타임 메타데이터"),
    "memoryOther": MessageLookupByLibrary.simpleMessage("기타 런타임 메모리"),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "메모리를 읽을 수 없습니다. 다시 시도하는 중…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("메모리를 해제했습니다"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("스택"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Go 메모리 사용량"),
    "messageTest": MessageLookupByLibrary.simpleMessage("메시지 테스트"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("이것은 메시지입니다."),
    "minimize": MessageLookupByLibrary.simpleMessage("최소화"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("종료 시 최소화"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "시스템의 기본 종료 동작 변경",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("분"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("혼합 포트"),
    "mode": MessageLookupByLibrary.simpleMessage("모드"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("모노크롬"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage("단색 트레이 아이콘"),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("더 보기"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU는 1에서 65535 사이의 정수여야 합니다",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "여러 값은 쉼표로 구분하세요",
    ),
    "name": MessageLookupByLibrary.simpleMessage("이름"),
    "nameserver": MessageLookupByLibrary.simpleMessage("네임서버"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("도메인 주소를 확인하는 데 사용"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("네임서버 정책"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "일치하는 도메인, geosite 분류 또는 규칙 집합에 특정 DNS 서버 지정",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("하단 바"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("로그인 필요"),
    "network": MessageLookupByLibrary.simpleMessage("네트워크"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "요청이 취소되었습니다",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "서버에 연결할 수 없습니다. 네트워크 연결이나 프록시 설정을 확인하세요",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage("네트워크 관련 설정 조정"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "네트워크 오류입니다. 연결을 확인한 후 다시 시도하세요",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage("네트워크 확장"),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "서버 주소를 확인할 수 없습니다. URL이 올바른지, DNS가 정상인지 확인하세요",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("네트워크 ID"),
    "networkName": MessageLookupByLibrary.simpleMessage("네트워크 이름"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("네트워크를 찾을 수 없습니다"),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "요청이 너무 많습니다(HTTP 429). 잠시 후 다시 시도하세요",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("네트워크 시크릿"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("네트워크 속도"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "실시간 네트워크 속도 표시",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "시스템 상태 영역에 실시간 네트워크 속도를 표시합니다. 전력 사용량이 약간 늘어날 수 있습니다",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("트래픽 가로채기"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "요청 시간이 초과되었습니다. 네트워크나 프록시를 확인한 후 다시 시도하세요",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "보안 연결에 실패했습니다. 서버 인증서가 올바르지 않거나 연결이 가로채이고 있을 수 있습니다",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("네트워크 유형"),
    "networking": MessageLookupByLibrary.simpleMessage("네트워크 연결"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage("P2P 네트워크 상태 보기"),
    "networkingError": MessageLookupByLibrary.simpleMessage("오류"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "현재 설정에 P2P 아웃바운드가 없습니다",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("새로 만들기"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage("프로필 직접 작성"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("다음 결과"),
    "no": MessageLookupByLibrary.simpleMessage("아니요"),
    "noData": MessageLookupByLibrary.simpleMessage("데이터 없음"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("하위 디렉터리가 없습니다"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage("필터 조건이 없습니다"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("등록된 단축키가 없습니다"),
    "noInfo": MessageLookupByLibrary.simpleMessage("정보 없음"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("다시 알리지 않음"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("네트워크 없음"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("네트워크 미사용 앱"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage("원격 백업이 없습니다"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IP 확인 안 함"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("호스트 이름 확인 안 함"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("일치하는 결과 없음"),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "트래픽을 읽을 수 없습니다. 다시 시도하는 중…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("노드 트래픽"),
    "nodes": MessageLookupByLibrary.simpleMessage("노드"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "이 외부 리소스는 텍스트 파일이 아닙니다",
    ),
    "none": MessageLookupByLibrary.simpleMessage("없음"),
    "notRunning": MessageLookupByLibrary.simpleMessage("실행 중 아님"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "현재 프록시 그룹은 선택할 수 없습니다",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("NTP 관련 설정 변경"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("동기화 간격(분)"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP는 시스템 시계 대신 NTP 서버에서 시간을 가져옵니다.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("프로필을 추가하여 시작하세요"),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("난독화"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("난독화 호스트"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("난독화 모드"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("난독화 매개변수"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("난독화 비밀번호"),
    "offline": MessageLookupByLibrary.simpleMessage("오프라인"),
    "onDemand": MessageLookupByLibrary.simpleMessage("필요 시 실행"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "필요 시 실행은 제외된 Wi-Fi에서 프록시를 일시 중지합니다.",
    ),
    "online": MessageLookupByLibrary.simpleMessage("온라인"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("설정만 사용"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("이모지만 사용"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("아이콘만 표시"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("프록시 트래픽만 집계"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 프록시 트래픽만 집계합니다",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("GitHub에서 열기"),
    "optional": MessageLookupByLibrary.simpleMessage("선택 사항"),
    "options": MessageLookupByLibrary.simpleMessage("옵션"),
    "other": MessageLookupByLibrary.simpleMessage("기타"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("기타 기여자"),
    "outbound": MessageLookupByLibrary.simpleMessage("아웃바운드"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("출구"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("아웃바운드 IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("아웃바운드 모드"),
    "override": MessageLookupByLibrary.simpleMessage("덮어쓰기"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("대상 덮어쓰기"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "대상 덮어쓰기는 원래 주소 대신 스니핑한 도메인으로 연결합니다.",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS 덮어쓰기"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 프로필의 DNS 옵션을 덮어씁니다",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("덮어쓰기 항목"),
    "overrideMode": MessageLookupByLibrary.simpleMessage("덮어쓰기 모드"),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("NTP 덮어쓰기"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "활성화하면 프로필의 NTP 옵션을 덮어씁니다",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage("덮어쓰기 스크립트"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("사용자 지정"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "사용자 지정 모드: 프록시 그룹과 규칙을 완전히 직접 설정",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("상위 디렉터리"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("순수 IP 분석"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "순수 IP 분석은 IP 주소만 있는 연결을 스니핑합니다.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("비밀번호"),
    "paste": MessageLookupByLibrary.simpleMessage("붙여넣기"),
    "peers": MessageLookupByLibrary.simpleMessage("피어"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("앨범에서 선택"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("창 고정"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("WebDAV를 연결하세요"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "스크립트 이름을 입력하세요",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "올바른 QR 코드를 업로드하세요",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("플러그인"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("플러그인 호스트"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("플러그인 모드"),
    "port": MessageLookupByLibrary.simpleMessage("포트"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("다른 포트를 입력하세요"),
    "portHopping": MessageLookupByLibrary.simpleMessage("포트 호핑"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("포트"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "0보다 큰 정수를 입력하세요",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("사전 공유 키"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("예측 뒤로 가기"),
    "preferH3": MessageLookupByLibrary.simpleMessage("HTTP/3 우선 사용"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DoH에 HTTP/3 우선 사용"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("사전 요건"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("키 조합을 누르세요"),
    "preview": MessageLookupByLibrary.simpleMessage("미리보기"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("이전 결과"),
    "privateKey": MessageLookupByLibrary.simpleMessage("개인 키"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("개인 키 암호"),
    "process": MessageLookupByLibrary.simpleMessage("프로세스"),
    "profile": MessageLookupByLibrary.simpleMessage("프로필"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("올바른 간격을 입력하세요"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("자동 업데이트 간격을 입력하세요"),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "프로필이 수정되었습니다. 자동 업데이트를 끄시겠습니까?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 이름을 입력하세요",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "이 프로필에만 적용되며, 추가하지 않은 항목은 기본값을 사용합니다.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "이 프로필에만 적용되며 네트워크 설정의 TUN 덮어쓰기 항목보다 우선합니다.",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "올바른 프로필 URL을 입력하세요",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 URL을 입력하세요",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("프로필"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("프로필 정렬"),
    "project": MessageLookupByLibrary.simpleMessage("프로젝트"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage("연결 종료 확인"),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "노드 변경 후 연결을 종료할지 묻기",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("프로토콜"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("프로토콜 매개변수"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("프로토콜 버전"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("원격 공급자만 지원합니다"),
    "providers": MessageLookupByLibrary.simpleMessage("외부 리소스"),
    "proxies": MessageLookupByLibrary.simpleMessage("프록시"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("프록시"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("프록시 체인"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "선택한 프록시에 문제가 있습니다",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("프록시 필터"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("프록시 그룹"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "현재 프록시 그룹에 문제가 있습니다",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("프록시 그룹이 비어 있습니다"),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "프록시 그룹 이름은 비워 둘 수 없습니다",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "코어가 시작되면 그룹이 여기에 표시됩니다",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("프록시 네임서버"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "프록시 노드의 도메인 주소를 확인하는 데 사용",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "프록시 네임서버 정책",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "프록시 노드의 네임서버 정책 지정",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("프록시 제공자"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "선택한 프록시 제공자에 문제가 있습니다",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("프록시 공급자"),
    "proxyType": MessageLookupByLibrary.simpleMessage("프록시 유형"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("캐시 정리"),
    "publicKey": MessageLookupByLibrary.simpleMessage("공개 키"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("퓨어 블랙"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("퓨어 블랙 모드"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR 코드"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QR 코드를 스캔하여 프로필 가져오기"),
    "query": MessageLookupByLibrary.simpleMessage("조회"),
    "queryDns": MessageLookupByLibrary.simpleMessage("DNS 조회"),
    "queryRule": MessageLookupByLibrary.simpleMessage("규칙 조회"),
    "quickActions": MessageLookupByLibrary.simpleMessage("빠른 작업"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("빠른 편집"),
    "quickFill": MessageLookupByLibrary.simpleMessage("빠른 입력"),
    "random": MessageLookupByLibrary.simpleMessage("무작위"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("최근 요청"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("추천"),
    "recordType": MessageLookupByLibrary.simpleMessage("레코드 유형"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("RecvMsgX 활성화"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage("Darwin에서 패킷을 일괄 수신"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir 포트"),
    "redo": MessageLookupByLibrary.simpleMessage("다시 실행"),
    "regex": MessageLookupByLibrary.simpleMessage("정규식"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("정규식 검색"),
    "relayed": MessageLookupByLibrary.simpleMessage("중계됨"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("메모리 해제"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "메모리를 해제하지 못했습니다",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("원격"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage("WebDAV에 데이터 백업"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("원격 목적지"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("원격 DNS 확인"),
    "remove": MessageLookupByLibrary.simpleMessage("제거"),
    "rename": MessageLookupByLibrary.simpleMessage("이름 변경"),
    "replace": MessageLookupByLibrary.simpleMessage("바꾸기"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("모두 바꾸기"),
    "request": MessageLookupByLibrary.simpleMessage("요청"),
    "requests": MessageLookupByLibrary.simpleMessage("요청"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("요청 및 업데이트"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("최근 요청 기록 보기"),
    "required": MessageLookupByLibrary.simpleMessage("필수"),
    "reset": MessageLookupByLibrary.simpleMessage("초기화"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "이 페이지에 변경 사항이 있습니다. 초기화하시겠습니까?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "프로필 및 스크립트",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage("애플리케이션 설정"),
    "resetTip": MessageLookupByLibrary.simpleMessage("초기화하시겠습니까?"),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "자동 업데이트 간격",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "자동 업데이트 간격은 0보다 커야 합니다",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("리소스"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("외부 리소스 정보"),
    "respectRules": MessageLookupByLibrary.simpleMessage("규칙 준수"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "규칙 준수는 DNS 연결을 규칙에 따라 라우팅하며 Proxy Server Nameserver가 필요합니다.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("응답 코드"),
    "restart": MessageLookupByLibrary.simpleMessage("다시 시작"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("코어를 다시 시작하시겠습니까?"),
    "restore": MessageLookupByLibrary.simpleMessage("복원"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("모든 데이터 복원"),
    "restoreException": MessageLookupByLibrary.simpleMessage("복원 오류"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage("파일에서 데이터 복원"),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV에서 데이터 복원",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage("숨겨진 항목 복원"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("프로필만 복원"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("복원 방식"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("호환"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("덮어쓰기"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("복원 완료"),
    "result": MessageLookupByLibrary.simpleMessage("결과"),
    "retry": MessageLookupByLibrary.simpleMessage("다시 시도"),
    "role": MessageLookupByLibrary.simpleMessage("역할"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("라우팅 주소"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("수신할 라우팅 주소 설정"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("라우팅 제외 주소"),
    "routeMode": MessageLookupByLibrary.simpleMessage("라우팅 모드"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage("사설 주소 우회"),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("설정 사용"),
    "routes": MessageLookupByLibrary.simpleMessage("경로"),
    "routingMark": MessageLookupByLibrary.simpleMessage("라우팅 마크"),
    "ru": MessageLookupByLibrary.simpleMessage("러시아어"),
    "rule": MessageLookupByLibrary.simpleMessage("규칙"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("논리 규칙 AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("전체 도메인 일치"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "도메인 키워드 일치",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "도메인 정규식 일치",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "도메인 접미사 일치",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "와일드카드 일치, *와 ?만 지원",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCP 마크 일치(tproxy UDP 인바운드 전용)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "목적지 포트 범위 일치",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("IP의 국가 코드 일치"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Geosite의 도메인 일치",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("인바운드 이름 일치"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage("인바운드 포트 일치"),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage("인바운드 유형 일치"),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "인바운드 사용자 이름 일치, 여러 사용자 이름은 /로 구분",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("IP의 ASN 일치"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IP 주소 범위 일치, IP-CIDR6는 별칭일 뿐입니다",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage("IP 주소 범위 일치"),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IP 접미사 범위 일치",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "모든 요청과 일치, 조건 불필요",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 또는 UDP 일치",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("논리 규칙 NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("논리 규칙 OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 이름으로 일치, Android에서는 패키지 이름과 일치",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 이름 정규식으로 일치, Android에서는 패키지 이름과 일치",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 이름 와일드카드로 일치, *와 ?만 지원",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "전체 프로세스 경로로 일치",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 경로 정규식으로 일치",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "프로세스 경로 와일드카드로 일치, *와 ?만 지원",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "리매치 이름 일치, 여러 이름은 /로 구분",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "규칙 세트 참조, rule-providers 필요",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "출발지 IP의 국가 코드 일치",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "출발지 IP의 ASN 일치",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "출발지 IP 주소 범위 일치",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "출발지 IP 접미사 범위 일치",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "출발지 포트 범위 일치",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "하위 규칙으로 일치, 괄호에 유의",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Linux 사용자 ID 일치",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("비활성화됨"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("규칙이 비어 있습니다"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("활성화됨"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("적중"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("마지막 적중"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage("마지막 미적중"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "규칙은 항목마다 규칙 하나인 YAML 목록이어야 합니다. 예: - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("미적중"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent 직접 연결",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "DNS over TLS 차단",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "프록시 루프백 차단",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("QUIC 차단"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("STUN 차단"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN 직접 연결"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple 및 Microsoft 직접 연결",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("규칙 공급자"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage("대상 IP"),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage("인바운드 이름"),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage("인바운드 사용자"),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "올바른 IP 주소를 입력하세요.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "일치하는 규칙이 없습니다(모드 정책 또는 DIRECT 기본 처리)",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "1에서 65535 사이의 포트를 입력하세요.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage("프로세스 경로"),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage("스니핑한 도메인"),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("출발지 포트"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage("도메인 또는 IP 주소"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("규칙 세트"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "규칙 세트에 사용할 수 있는 항목이 없습니다",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "이 mrs 파일을 읽을 수 없습니다",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "규칙 세트에 도메인과 IP 범위가 섞여 있어 유형을 판별할 수 없습니다",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("규칙 대상"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "규칙은 DOMAIN,example.com,DIRECT처럼 지원하는 유형으로 시작해야 합니다",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("규칙 유형"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "규칙을 변경할 수 없습니다. 설정이 변경되었을 수 있으니 새로 고침 후 다시 시도하세요.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("규칙"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage("규칙 및 일치 통계 보기"),
    "runTime": MessageLookupByLibrary.simpleMessage("실행 시간"),
    "running": MessageLookupByLibrary.simpleMessage("실행 중"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("런타임 구성"),
    "safeMode": MessageLookupByLibrary.simpleMessage("안전 모드"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("채도"),
    "save": MessageLookupByLibrary.simpleMessage("저장"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("변경 사항을 저장하시겠습니까?"),
    "script": MessageLookupByLibrary.simpleMessage("스크립트"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "스크립트 모드: 확장 스크립트로 프로필 전체를 다시 작성합니다",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("선택 항목으로 스크롤"),
    "search": MessageLookupByLibrary.simpleMessage("검색"),
    "seconds": MessageLookupByLibrary.simpleMessage("초"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("키"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("모두 선택"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "MATCH-TARGET 선택",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage("백업 선택"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("규칙 세트를 선택하세요"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage("분할 전략을 선택하세요"),
    "selected": MessageLookupByLibrary.simpleMessage("선택됨"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("SendMsgX 활성화"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage("Darwin에서 패킷을 일괄 송신"),
    "server": MessageLookupByLibrary.simpleMessage("서버"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("모두 사용 가능"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("사용 가능"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("차단됨"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("확인"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("모두 확인"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("출시 예정"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage("허용되지 않는 ISP"),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("확인 실패"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("서비스 관리"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("오리지널 콘텐츠만"),
    "servicePending": MessageLookupByLibrary.simpleMessage("확인 전"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("접근 제한됨"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "대시보드에 표시됨",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("서비스 상태"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("사용 불가"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "지원하지 않는 지역",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("설정"),
    "settings": MessageLookupByLibrary.simpleMessage("설정"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "링크에서 읽을 수 있는 프록시가 없습니다",
    ),
    "show": MessageLookupByLibrary.simpleMessage("표시"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("숨겨진 항목 표시"),
    "showLess": MessageLookupByLibrary.simpleMessage("접기"),
    "showMore": MessageLookupByLibrary.simpleMessage("펼치기"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "알림에 중지 버튼 표시",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "상시 알림에 중지 버튼을 표시합니다. 이 버튼 때문에 시스템에서 알림이 계속 펼쳐져 있으면 끄세요",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("비밀번호 표시"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "현재 프로필 이름 표시",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "연결되면 빠른 설정 타일에 프로필 이름 표시",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "트레이에 프록시 선택 표시",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "빠르게 전환할 수 있도록 트레이 메뉴에 프록시 그룹과 노드 표시",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("시간 초과 표시"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("사이드바 블러"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "사이드바를 통해 창 뒤의 흐릿한 바탕화면을 표시합니다",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("로그인"),
    "signOut": MessageLookupByLibrary.simpleMessage("로그아웃"),
    "signedIn": MessageLookupByLibrary.simpleMessage("로그인됨"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("백그라운드 실행"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "백그라운드 실행은 창을 표시하지 않고 시작합니다.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("개별 추가"),
    "singleImport": MessageLookupByLibrary.simpleMessage("개별 가져오기"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "여기에는 링크를 하나만 입력하세요. 여러 개는 목록의 빠른 편집에서 편집하세요",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("크기"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("인증서 검증 건너뛰기"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("건너뛸 도메인"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "건너뛸 도메인 목록에 있는 스니핑된 도메인은 사용하지 않습니다.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("건너뛸 목적지 주소"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("건너뛸 출발지 주소"),
    "slide": MessageLookupByLibrary.simpleMessage("슬라이드"),
    "sliders": MessageLookupByLibrary.simpleMessage("슬라이더"),
    "small": MessageLookupByLibrary.simpleMessage("작게"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("프로토콜"),
    "sniffer": MessageLookupByLibrary.simpleMessage("스니퍼"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "스니퍼는 TLS, HTTP, QUIC 트래픽에서 도메인을 읽어 규칙이 일치할 수 있게 합니다.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("SOCKS 포트"),
    "softStyle": MessageLookupByLibrary.simpleMessage("부드러움"),
    "sort": MessageLookupByLibrary.simpleMessage("정렬"),
    "source": MessageLookupByLibrary.simpleMessage("소스"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("출발지 IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("특수 프록시"),
    "specialRules": MessageLookupByLibrary.simpleMessage("특수 규칙"),
    "spectrum": MessageLookupByLibrary.simpleMessage("스펙트럼"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("속도 통계"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("분할 전략"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "분할 전략을 입력하세요",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSID가 비어 있습니다"),
    "stackMode": MessageLookupByLibrary.simpleMessage("스택 모드"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("스택 트레이스"),
    "standard": MessageLookupByLibrary.simpleMessage("표준"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "표준 모드: 프로필 위에 규칙을 추가합니다",
    ),
    "start": MessageLookupByLibrary.simpleMessage("시작"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("처음부터 시작"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPN 시작 중…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("시작 및 백그라운드"),
    "status": MessageLookupByLibrary.simpleMessage("상태"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "DNS를 끄면 시스템 DNS를 사용합니다.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("중지"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPN 중지 중…"),
    "stopped": MessageLookupByLibrary.simpleMessage("중지됨"),
    "strategy": MessageLookupByLibrary.simpleMessage("전략"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("엄격한 라우팅"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "엄격한 라우팅은 DNS 등의 트래픽이 TUN을 우회하지 못하게 하며, IPv6가 꺼져 있으면 이 기기의 IPv6 연결을 차단합니다.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("스타일"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("스타일 설정"),
    "submit": MessageLookupByLibrary.simpleMessage("제출"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("구독 정보"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "sudo 비밀번호를 입력하세요",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("일시 중단 지원"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "기기가 유휴 상태일 때 코어를 일시 중단하여 배터리 사용량 줄이기",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("일시 중지됨…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage("스와이프로 페이지 전환"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("프로필 전환"),
    "sync": MessageLookupByLibrary.simpleMessage("동기화"),
    "system": MessageLookupByLibrary.simpleMessage("시스템"),
    "systemApp": MessageLookupByLibrary.simpleMessage("시스템 앱"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("시스템 프록시"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("시스템 HTTP 프록시 설정"),
    "tab": MessageLookupByLibrary.simpleMessage("탭"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("탭 애니메이션"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("모바일 보기에서만 적용됩니다"),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("활성"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "현재 엔드포인트",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS 이름"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("엔드포인트"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("출구 노드"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "출구 노드 사용 가능",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("상태"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage("상태 경고"),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("키 만료됨"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("키 만료일"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage("마지막 핸드셰이크"),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("마지막 확인"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "기기 승인 필요",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("노드 키"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP 중계 서버"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("서브넷"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("태그"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("아이콘을 눌러 다시 시도"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("눌러서 허용"),
    "target": MessageLookupByLibrary.simpleMessage("대상"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP 동시 연결"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("동시 TCP 연결 허용"),
    "testInterval": MessageLookupByLibrary.simpleMessage("테스트 간격"),
    "testUrl": MessageLookupByLibrary.simpleMessage("테스트 URL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("사용할 때 테스트"),
    "textReplacement": MessageLookupByLibrary.simpleMessage("텍스트 치환:"),
    "textScale": MessageLookupByLibrary.simpleMessage("글자 크기 조절"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "앱의 글자가 이렇게 표시됩니다",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("테마"),
    "themeColor": MessageLookupByLibrary.simpleMessage("테마 색상"),
    "themeMode": MessageLookupByLibrary.simpleMessage("테마 모드"),
    "tight": MessageLookupByLibrary.simpleMessage("좁게"),
    "time": MessageLookupByLibrary.simpleMessage("시간"),
    "timeout": MessageLookupByLibrary.simpleMessage("시간 초과"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("틴트"),
    "tip": MessageLookupByLibrary.simpleMessage("안내"),
    "toggle": MessageLookupByLibrary.simpleMessage("전환"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("레이블 표시 전환"),
    "tolerance": MessageLookupByLibrary.simpleMessage("허용 오차"),
    "tools": MessageLookupByLibrary.simpleMessage("도구"),
    "torch": MessageLookupByLibrary.simpleMessage("손전등"),
    "total": MessageLookupByLibrary.simpleMessage("합계"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("다운로드량"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("전체 트래픽"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("업로드량"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxy 포트"),
    "traffic": MessageLookupByLibrary.simpleMessage("트래픽"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("모두"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("트래픽 사용량"),
    "transport": MessageLookupByLibrary.simpleMessage("전송"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN 권한을 얻지 못해 끄기로 되돌렸습니다.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("TUN은 관리자 모드에서만 작동합니다."),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("시스템 DNS 모드"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("비활성화"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("가로채기"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("네이티브"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "여기에 추가한 항목은 모든 프로필의 TUN 설정을 대체합니다. 추가하지 않은 항목은 프로필 자체 설정을 유지합니다. 사용자 지정 프로필이 직접 추가한 항목이 우선합니다.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("끄기"),
    "turnOn": MessageLookupByLibrary.simpleMessage("켜기"),
    "tvMode": MessageLookupByLibrary.simpleMessage("TV 모드"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "이 기기에서 리모컨에 적합한 레이아웃 사용",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP 릴레이 모드"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP 시간 제한"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP 시간 제한은 초 단위이며 gvisor, system, mixed 스택에서만 작동합니다.",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage("유휴 갱신 간격"),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "포커스 해제 시 유휴 모드",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "앱 창이 포커스를 잃으면 유휴 갱신 간격 사용",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage("UI 정보 갱신 간격"),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("최고"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("권한 없음"),
    "undo": MessageLookupByLibrary.simpleMessage("실행 취소"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("통합 지연"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "핸드셰이크 등의 추가 지연 제거",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("초기화되지 않음"),
    "unknown": MessageLookupByLibrary.simpleMessage("알 수 없음"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "알 수 없는 변수입니다. 아래 변수 중 하나를 선택하세요.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "알 수 없는 네트워크 오류",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("이전 크기로 복원"),
    "unnamed": MessageLookupByLibrary.simpleMessage("이름 없음"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("창 고정 해제"),
    "update": MessageLookupByLibrary.simpleMessage("업데이트"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "다운로드한 파일이 공개된 체크섬과 일치하지 않아 삭제되었습니다.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("업데이트 다운로드 중"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "설치 프로그램을 시작할 수 없습니다.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash에 앱 설치 권한이 없어 업데이트를 설치하지 못했습니다.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash가 설치 폴더에 쓸 수 없습니다. 업데이트를 직접 다운로드하세요.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("지금 업데이트"),
    "upload": MessageLookupByLibrary.simpleMessage("업로드"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("업로드 대역폭"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("업로드 속도"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("업로드 트래픽"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL에서 프로필 가져오기"),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("hosts 사용"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "상위 DNS 서버에 조회하기 전에 설정의 hosts 항목 확인",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("시스템 hosts 사용"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "도메인 주소를 확인할 때 운영체제의 hosts 파일 확인",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("사용"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("사용한 트래픽"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("사용자 이름"),
    "value": MessageLookupByLibrary.simpleMessage("값"),
    "version": MessageLookupByLibrary.simpleMessage("버전"),
    "view": MessageLookupByLibrary.simpleMessage("보기"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("가상 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("선명"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN 관련 구성 변경이 감지되었습니다",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN은 VpnService를 통해 모든 시스템 트래픽을 자동으로 라우팅합니다.",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV 구성"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("화이트리스트 모드"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("시스템에 기록"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "시스템에 기록하면 시스템 시계도 설정합니다. Android에서는 무시됩니다.",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("예"),
    "zhCN": MessageLookupByLibrary.simpleMessage("중국어 간체"),
    "zhTW": MessageLookupByLibrary.simpleMessage("중국어 번체"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage("도움말 보기"),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "개통 및 갱신 주문 보기",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage("로그인 비밀번호"),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "연결 설정",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage(
      "계정 정보와 주문을 확인하세요.",
    ),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("내 계정"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("활성화 중"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("고급 설정"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("모든 서버"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("전체 지역"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("결제 금액"),
    "zolnitAuthorizeMonthly": MessageLookupByLibrary.simpleMessage(
      "월 자동 결제 승인",
    ),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("계정 잔액"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage(
      "월 단위 결제로 부담 없이 시작",
    ),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "갱신 정보를 일시적으로 불러올 수 없습니다.",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("주문 생성"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("주문 취소"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "이 미결제 주문을 취소할까요?",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage("자동 갱신 취소"),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "향후 자동 결제가 중단됩니다. 첫 주문이 미결제 상태라면 해당 주문도 취소됩니다. 결제된 이용 권한은 서버 결과에 따릅니다.",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("취소됨"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage("비밀번호 변경"),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "이미 진행 중인 결제가 있습니다. 계정에서 상태를 확인하고 다시 제출하지 마세요.",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "결제를 준비하거나 확인하는 중입니다. 잠시 후 다시 시도하세요.",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("요금제 선택"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("완료"),
    "zolnitConnectAction": MessageLookupByLibrary.simpleMessage("연결"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "탭 한 번으로 바로 연결",
    ),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage("실행 후 자동 연결"),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "앱을 시작하면 마지막으로 사용한 서버에 자동 연결합니다.",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "요금제에 포함된 서버에 연결합니다.",
    ),
    "zolnitConnectionPageUnavailable": MessageLookupByLibrary.simpleMessage(
      "연결 페이지를 표시할 수 없습니다. 다시 시도하세요.",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("코드 복사"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("링크 복사"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "유효한 이메일과 8자 이상의 비밀번호를 입력하세요.",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("상계 완료"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("현재 요금제"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLabel": MessageLookupByLibrary.simpleMessage("현재 요금제"),
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("선택됨"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("반기"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("분기"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("3년"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("2년"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("1년"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("일"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "계정의 로그인 세션을 표시합니다. 노드의 온라인 IP 수와는 다릅니다.",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage("로그인 세션"),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "지금은 로그인 세션을 불러올 수 없습니다. 다시 시도해 주세요.",
    ),
    "zolnitDisconnectAction": MessageLookupByLibrary.simpleMessage("연결 해제"),
    "zolnitDisconnecting": MessageLookupByLibrary.simpleMessage("연결 해제 중…"),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("이메일"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage("모든 화면에서 익숙한 경험"),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "요청을 완료하지 못했습니다. 입력 내용이나 연결을 확인한 후 다시 시도하세요.",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("첫 결제"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage("이후 결제"),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage(
      "비밀번호를 잊으셨나요?",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("선물 이용 권한"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "첫 결제가 확인되면 유료 기간이 시작되고 남은 무료 기간을 대체합니다.",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage("엄선한 글로벌 회선"),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "요금제와 사용 가능한 서버를 확인하세요.",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("6개월마다"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage("도움말 및 지원"),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("초대 코드"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage(
      "초대 코드가 복사되었습니다",
    ),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "사용 가능 커미션",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "확정 커미션",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "대기 중 커미션",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage(
      "커미션 비율",
    ),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage(
      "초대 링크가 복사되었습니다",
    ),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage("초대 코드 만들기"),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "초대 코드를 만들 수 없습니다. 다시 시도해 주세요.",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage(
      "좋은 경험을 나누고 보상을 받으세요.",
    ),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage("초대 링크"),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "초대 데이터를 불러올 수 없습니다. 다시 시도해 주세요.",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage(
      "친구를 초대하여 시작하세요.",
    ),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("명"),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage("가입 완료"),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage("초대 규칙"),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage("내 초대"),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "친구가 링크로 가입하고 플랜을 구매하면 보상이 지급됩니다.",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "친구를 초대해 가입하고 구독하면 보상을 받습니다.",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("지연 시간"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage("최신 공지"),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "복잡한 설정 없이 한 번의 연결로 세상과 만나세요.",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "당신의 세상에 한 걸음 더 가까이",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "로그인하여 요금제와 연결을 관리하세요.",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage("가입 또는 비밀번호 찾기"),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("전체 모드"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage("스마트 라우팅"),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("매월"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage("매월 자동 결제"),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("내 공간"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("새 비밀번호"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage("다음 갱신일"),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "활성 요금제가 없습니다. 아래에서 하나를 선택해 시작하세요.",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage(
      "표시할 로그인 세션이 없습니다.",
    ),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "일치하는 서버가 없습니다.",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage(
      "사용 가능한 결제 수단이 없습니다",
    ),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "현재 구독에서 사용할 수 있는 노드가 없습니다.",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage("아직 공지사항이 없습니다"),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("아직 주문이 없습니다"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("활성 요금제가 없습니다"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage("자동 갱신 계약이 없습니다"),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "지연 시간은 가장 최근 실제 측정값 기준이며, 측정 전에는 —로 표시됩니다.",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("서버"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "사용 가능한 서버는 요금제에 맞춰 자동으로 업데이트됩니다.",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("서버"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "사용 가능한 서버는 계정에서 자동으로 업데이트됩니다.",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage("아직 연결되지 않았습니다"),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("공지사항"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage("현재 비밀번호"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("일회성"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage("온라인 기기"),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("주문 내역"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("결제된 이용 권한"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("결제된 이용 만료일"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "현재 비밀번호를 입력하고, 8자 이상의 다른 새 비밀번호를 사용하세요.",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "비밀번호가 변경되었습니다.",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("주문 결제"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "결제에서 돌아온 후에도 주문 상태를 확인해야 합니다.",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage("결제 상태"),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "이 결제 수단은 아직 준비되지 않았습니다.",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("결제 대기"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "처리 중인 주문이 있습니다. 주문 목록에서 결제를 이어가거나 닫은 뒤 다시 주문하세요.",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ 월"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "첫 결제 또는 기존 요금제의 잔여 가치 차감이 확인되면 새 요금제가 시작됩니다.",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage("요금제 유효 기간"),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("요금제"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage("요금제"),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "일상적인 웹 서핑부터 매끄러운 스트리밍까지, 나에게 맞는 연결을 선택하세요.",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("환경설정"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage("설정"),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "안전 모드는 설정을 유지하지만 자동으로 연결하거나 시스템 네트워크를 변경하지 않습니다.",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "시작 및 연결 설정을 관리합니다.",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "사용 가능한 서버는 계정에서 자동으로 업데이트됩니다.",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("3개월마다"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "견적을 확인한 후 자동 갱신을 승인하세요.",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "견적이 만료되었습니다. 새로고침하세요.",
    ),
    "zolnitQuoteLabel": MessageLookupByLibrary.simpleMessage("견적"),
    "zolnitQuoteUnavailable": MessageLookupByLibrary.simpleMessage(
      "견적을 불러올 수 없습니다. 다시 시도하세요.",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "요청이 너무 많습니다. 잠시 후 다시 시도하세요.",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage("추천 서버"),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "가까운 노드를 우선하여 더 빠르게 연결합니다",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage("추천"),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "표시된 첫 결제 및 갱신 조건에 따라 이 요금제의 정기 결제에 동의합니다.",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "현재 이 요금제는 월 자동 결제를 사용할 수 없습니다.",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("새로고침"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("회원가입"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "회원가입 및 비밀번호 복구는 ZolNit 웹사이트에서 이메일 및 보안 인증을 진행합니다.",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage("현재 요금제 갱신"),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("요금제 갱신"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage("자동 갱신"),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage("트래픽 초기화"),
    "zolnitRestoringSession": MessageLookupByLibrary.simpleMessage("로그인 복원 중…"),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage("자동 갱신 재개"),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "승인한 요금제에 따라 자동 결제를 재개합니다.",
    ),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage("이 세션 로그아웃"),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "로그인 세션이 종료되었습니다.",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "이 로그인 세션을 종료할까요? 해당 기기는 계정을 관리하려면 다시 로그인해야 합니다.",
    ),
    "zolnitSafeMode": MessageLookupByLibrary.simpleMessage("안전 모드"),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "보안 모드는 시스템 네트워크를 변경하지 않습니다.",
    ),
    "zolnitSavePercent": m101,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage("서버 또는 지역 검색"),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("선택"),
    "zolnitSelectServer": MessageLookupByLibrary.simpleMessage("서버 선택"),
    "zolnitSessionExpired": MessageLookupByLibrary.simpleMessage(
      "로그인이 만료되었습니다. 다시 로그인하세요.",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("로그인"),
    "zolnitSignInRejected": MessageLookupByLibrary.simpleMessage(
      "이메일 또는 비밀번호가 올바르지 않습니다. 다시 시도하세요.",
    ),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("로그아웃"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage("시작 시 ZolNit 실행"),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "기기를 켜면 ZolNit이 미리 준비됩니다.",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("이용 중"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("만료됨"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("요금제 없음"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage("요금제 선택"),
    "zolnitSync": MessageLookupByLibrary.simpleMessage("계정 데이터 동기화"),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage("계정 데이터가 동기화되었습니다"),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage("계정 데이터 동기화 중…"),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("계정 정보"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("친구 초대"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("주문 내역"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage("연결을 더 간편하게."),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("3년마다"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("남은 트래픽"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage("이번 주기 사용량"),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("2년마다"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage("로그인 세션"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage("월간 견적 보기"),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage("ZolNit 웹사이트 열기"),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("다시 오신 것을 환영합니다"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("내 작업 공간"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("매년"),
  };
}

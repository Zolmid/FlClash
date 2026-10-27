// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(count, skipped) =>
      "${count} to add, ${skipped} skipped as existing";

  static String m1(detail) => "Couldn\'t clear the data: ${detail}";

  static String m2(code) =>
      "Windows refused to run FlClashCore.exe (error ${code}). An app control policy such as Smart App Control or AppLocker blocks unsigned programs; allow FlClash in that policy or turn it off, then try again.";

  static String m3(name) =>
      "The app failed to finish launching twice in a row. To break the loop, the profile ${name} has been deselected and automatic setup was skipped. You can select it again at any time.";

  static String m4(url) => "Do you want to create a profile from ${url}?";

  static String m5(count, label) =>
      "${Intl.plural(count, one: '1 SUB-RULE rule was dropped, since custom profiles do not support sub-rules', other: '${label} SUB-RULE rules were dropped, since custom profiles do not support sub-rules')}";

  static String m6(message) => "The core cannot parse this proxy: ${message}";

  static String m7(proxy, target) =>
      "${proxy} dials through ${target}, which leads back to ${proxy}, so the dial loops";

  static String m8(name) =>
      "The name ${name} is already used by another proxy or proxy group";

  static String m9(path) =>
      "Proxy groups reference each other in a loop: ${path}";

  static String m10(name) =>
      "The empty fallback must be a proxy, but ${name} does not exist or is a proxy group";

  static String m11(name, message) =>
      "${name} is not a valid regex: ${message}";

  static String m12(name) => "The dialer proxy ${name} does not exist";

  static String m13(names) => "These proxy providers do not exist: ${names}";

  static String m14(names) =>
      "These proxies or policies do not exist: ${names}";

  static String m15(name) =>
      "${name} is a built-in policy name and cannot be used here";

  static String m16(count) =>
      "${count} items have problems, and applying this profile may fail";

  static String m17(count) =>
      "${Intl.plural(count, one: '1 day ago', other: '${count} days ago')}";

  static String m18(count) => "${Intl.plural(count, other: '${count}d ago')}";

  static String m19(label) =>
      "Are you sure you want to delete the selected ${label}?";

  static String m20(label) => "Are you sure you want to delete this ${label}?";

  static String m21(label) => "${label} details";

  static String m22(name) =>
      "Dialing through ${name} leads back to the proxy that uses it, so the connection was stopped";

  static String m23(label) => "${label} cannot be empty";

  static String m24(count) =>
      "${Intl.plural(count, one: '1 entry', other: '${count} entries')}";

  static String m25(label) => "${label} already exists";

  static String m26(count) => "${count} items failed";

  static String m27(label, message) => "${label}: ${message}";

  static String m28(name) => "${name} is already up to date";

  static String m29(name) => "${name} updated";

  static String m30(name) => "Updating ${name}...";

  static String m31(count) =>
      "${Intl.plural(count, one: '1 group', other: '${count} groups')}";

  static String m32(count) => "${count} timed out";

  static String m33(action) =>
      "Already used by “${action}”. Saving moves it here.";

  static String m34(modifiers) => "Include at least one of ${modifiers}";

  static String m35(count) =>
      "${Intl.plural(count, one: '1 hour ago', other: '${count} hours ago')}";

  static String m36(count) => "${Intl.plural(count, other: '${count}h ago')}";

  static String m37(target) => "${target} is an invalid policy";

  static String m38(proxyName) => "${proxyName} is an invalid proxy";

  static String m39(providerName) =>
      "${providerName} is an invalid proxy provider";

  static String m40(ruleSet) => "${ruleSet} is an invalid rule set";

  static String m41(subRule) => "${subRule} is an invalid SUB_RULE";

  static String m42(count) =>
      "${Intl.plural(count, one: '1 item', other: '${count} items')}";

  static String m43(line, message) => "Line ${line}: ${message}";

  static String m44(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the list\n\nWhen you are done, return to the app to continue. Thank you for your cooperation.";

  static String m45(label, max) => "${label} must be at most ${max} characters";

  static String m46(size) => "Released ${size}";

  static String m47(count) =>
      "${Intl.plural(count, one: '1 minute ago', other: '${count} minutes ago')}";

  static String m48(count) => "${Intl.plural(count, other: '${count}m ago')}";

  static String m49(count) =>
      "${Intl.plural(count, one: '1 month ago', other: '${count} months ago')}";

  static String m50(count) => "${Intl.plural(count, other: '${count}mo ago')}";

  static String m51(code) =>
      "The server denied access (HTTP ${code}). The link may have expired, or the credentials are wrong";

  static String m52(code) => "The server rejected the request (HTTP ${code})";

  static String m53(code) =>
      "Nothing was found at this address (HTTP ${code}). Check that the URL is correct";

  static String m54(detail) => "Network request failed: ${detail}";

  static String m55(code) =>
      "The server ran into a problem (HTTP ${code}). Try again later";

  static String m56(label) => "No ${label} yet";

  static String m57(label, min, max) =>
      "${label} must be between ${min} and ${max}";

  static String m58(label) => "${label} must be a number";

  static String m59(label) => "${label} must be between 1024 and 49151";

  static String m60(port) => "Port ${port}";

  static String m61(days) =>
      "${Intl.plural(days, one: '1 day left', other: '${days} days left')}";

  static String m62(date, days) =>
      "Expires ${date}, ${Intl.plural(days, one: '1 day', other: '${days} days')} left";

  static String m63(time) => "Updated ${time}";

  static String m64(label, profiles) =>
      "${label} is still used by ${profiles}, which will not work properly once it is deleted. Are you sure you want to delete it?";

  static String m65(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxies')}";

  static String m66(name, count) => "${name} and others (${count} proxies)";

  static String m67(removed) =>
      "These proxies will be deleted: ${removed}. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?";

  static String m68(removed, added) =>
      "These proxies will be deleted: ${removed}. These will be added: ${added}. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?";

  static String m69(label) =>
      "${label} is still named by rules, proxy groups, dialer proxies, DNS or NTP in this profile, which stop working once it is deleted. Are you sure you want to delete it?";

  static String m70(count, label) =>
      "${Intl.plural(count, one: '1 proxy group', other: '${label} proxy groups')}";

  static String m71(maximum) => "Enter an integer between 0 and ${maximum}.";

  static String m72(count, label) =>
      "${Intl.plural(count, one: '1 rule', other: '${label} rules')}";

  static String m73(appName) => "${appName} (Safe mode)";

  static String m74(count) =>
      "${Intl.plural(count, one: '1 second', other: '${count} seconds')}";

  static String m75(count) => "${count} in effect";

  static String m76(count) =>
      "${Intl.plural(count, one: '1 issue', other: '${count} issues')}";

  static String m77(time) => "Checked at ${time}";

  static String m78(count) =>
      "${Intl.plural(count, one: '1 setting', other: '${count} settings')}";

  static String m79(link) => "No proxy could be read from ${link}";

  static String m80(label) => "${label} must be a single item";

  static String m81(value) => "Peak ${value}";

  static String m82(value) => "Total ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · Idle ${idleInterval}";

  static String m84(interval) => "${interval} · Idle disabled";

  static String m85(label) => "${label} must be a URL";

  static String m86(count) =>
      "${Intl.plural(count, one: '1 year ago', other: '${count} years ago')}";

  static String m87(count) => "${Intl.plural(count, other: '${count}y ago')}";

  static String m88(amount, cycle) => "${amount} per ${cycle}, paid at once";

  static String m89(date) => "Expires ${date}. Upgrade or renew right here.";

  static String m90(plan) => "Current plan · ${plan}";

  static String m91(days) => "${days} days left";

  static String m92(date) => "Expires ${date}";

  static String m93(count) => "Up to ${count} devices online at once";

  static String m94(mbps) => "Speed up to ${mbps} Mbps";

  static String m95(gb) => "${gb} GB of high-speed data per month";

  static String m96(name) => "Hello, ${name}.";

  static String m97(rate) => "${rate}× metering";

  static String m98(count) => "Servers: ${count}";

  static String m99(count) => "/ ${count}";

  static String m100(days) => "Resets in ${days} days";

  static String m101(node) => "Current route: ${node}";

  static String m102(percent) => "Save ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Access control"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only selected apps go through the VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Access control picks which apps use the proxy.",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "App access control is disabled",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Selected apps are excluded from the VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Access control settings",
    ),
    "accessDenied": MessageLookupByLibrary.simpleMessage("Access denied"),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("Test all delays"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Direct mode"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Global mode"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Switch mode"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Rule mode"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Update profiles",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Add proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Add filters"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Add nodes"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Add override entry",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Add profile"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Add proxies"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("Add proxy group"),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("Add setting"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Add SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Added rules"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Additional parameters",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Name prefix"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Name suffix"),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "WebDAV server address",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Advanced configuration",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Advanced configuration holds network, DNS, added rules, and scripts.",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Encrypted profile",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Age Key Generation",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519 key pair generated, please keep it safe",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Age Private Key",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Please enter a correct Age private key first",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age Public Key"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Age secret key"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid Age secret key (must start with AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Age Secret Key (Optional)",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "This profile is encrypted with age and needs an age secret key to decrypt",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allData": MessageLookupByLibrary.simpleMessage("All data"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "All referenced proxies",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "All referenced proxy providers",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Allow apps to bypass VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "When enabled, some apps can bypass the VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Allow LAN"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage("Allow LAN access"),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "Allow access to the external controller from the LAN",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Allow proxy access over the LAN",
    ),
    "allowedIps": MessageLookupByLibrary.simpleMessage("Allowed IPs"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Always on"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "Keep VPN connected under any network conditions",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("Answers"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("App icon design"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("No local proxies"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Append system DNS",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Force-append the system DNS to the configuration",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Adjust application settings",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("Ascending"),
    "authentication": MessageLookupByLibrary.simpleMessage("Authentication"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "Authentication asks for a username and password on the local proxy port.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "The system proxy is not applied while authentication is on.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Authorize"),
    "authorized": MessageLookupByLibrary.simpleMessage("Authorized"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto check for updates",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Check for updates automatically when the app starts",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto close connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Auto close connections drops open connections when you switch proxies.",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("Auto-include"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Auto launch"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Launch automatically at system startup",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Auto run"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Auto run starts the proxy when the app opens.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto-set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto-update interval",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage(
      "Back to dashboard",
    ),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "Return to the dashboard before exiting",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Backup and restore",
    ),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "Local date (YYYY-MM-DD)",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "This backup comes from a newer version of the app. Update the app before restoring it",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "Current platform",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup successful"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "Local time (HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "Application version",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Basic configuration"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the basic configuration globally",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Basic info"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Basic strategies"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("Batch add"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Batch import"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "One link per line",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "One item per line, or separated by commas",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "One entry per line: key, a space, then value",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "One URL per line",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Ignore battery optimization keeps the app running in the background.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("Block connection"),
    "brightness": MessageLookupByLibrary.simpleMessage("Brightness"),
    "browse": MessageLookupByLibrary.simpleMessage("Browse"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass domains"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Bypass domains apply only while the system proxy is on.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Bypass private addresses",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "With Bypass private addresses on, LAN, loopback and multicast addresses skip TUN.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Cache"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("Cache algorithm"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "The cache is corrupted. Clear it?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Cache size"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Allow camera access in system settings to scan QR codes, or choose a QR code image from the album.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Camera permission required",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Camera unavailable",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Deselect all"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("Can\'t save"),
    "captureDns": MessageLookupByLibrary.simpleMessage("Capture system DNS"),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Redirect all system DNS queries to the internal DNS module",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Failed to switch proxy; the previous selection has been restored",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Breaking changes",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("New features"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Bug fixes"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("Performance"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Reverts"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Verify TLS certificates",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "With TLS verification off, subscriptions and backups are open to man-in-the-middle attacks.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "The app is already up to date",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Cipher"),
    "clear": MessageLookupByLibrary.simpleMessage("Clear"),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear data"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "This deletes all profiles, settings, and local data, then closes the app. Open it again to start fresh.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("Clear search"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Client fingerprint",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Export to clipboard",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Import from clipboard",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t copy to the clipboard. The selection may be too large",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Close all"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Close connections",
    ),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "Close connections using the previous proxy?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Collapse"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "Collapse proxy chains",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Hide middle nodes when a proxy chain has more than three nodes",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "Collapse Quick Settings panel",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "Collapse after tapping the tile",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Color style"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compact": MessageLookupByLibrary.simpleMessage("Compact"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Data detected in the configuration",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear all data?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear the selected data?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete this proxy group?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to exit the current window?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force crash the core?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "Confirming will overwrite existing data",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Congestion control",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "TCP congestion control",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP congestion control works only with the mips stack.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connected"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connecting…"),
    "connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage("Connection count"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("Connection stats"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Live connections, recent requests and DNS queries",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "View current connection data",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity: "),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Content cannot be empty",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Control global added rules",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copy environment variables",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copied successfully"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows Smart App Control blocked FlClashCore.exe because it is not signed. Open Windows Security → App & browser control → Smart App Control settings, choose Off, then start FlClash again. Smart App Control cannot be turned back on without reinstalling Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Core status"),
    "country": MessageLookupByLibrary.simpleMessage("Region"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Crash detected"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create profile"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("Creation time"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Holds the start button and can\'t be removed",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Custom"),
    "customColor": MessageLookupByLibrary.simpleMessage("Custom color"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "The name is empty",
    ),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "No proxies or proxy providers are selected, so the core rejects this group",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("Custom"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Assemble proxy groups and rules from app proxies and other profiles",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "Custom profile resources",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Custom profile resources hold proxies, rule providers, filters, and icon sets.",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Available to add",
    ),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Data changes detected. Save them?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Failed to save the change; it has been rolled back",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("Directory"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve DNS servers",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Default selection",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "The configuration must be a YAML mapping with a name and a type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Delay test"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("Descending"),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Destination GeoIP",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "Destination IP ASN",
    ),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Relies on a third-party API; for reference only",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Dialer proxy"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Dialer proxy is the outbound used to reach the NTP server.",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Disable ICMP forwarding",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "With ICMP forwarding disabled, TUN answers ping itself, so ping no longer shows the real latency.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Disable TCP keep-alive",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Disable UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Discard the changes?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "By installing, copying, or using the Software, you are deemed to have read and agreed to this entire statement. If you disagree with any of its terms, stop using and uninstall the Software immediately.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("Acceptance"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "I have read and understand this statement",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "To confirm you understand, read the following statement and check the box below:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm the statement",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "The developers may revise this statement with any release, and the revision takes effect when that release is published. Continuing to use the Software after updating means you accept the revised statement.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Changes to this statement",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Before using FlClash (\"the Software\"), please read this statement carefully and make sure you understand all of it. Tapping \"Agree\" means you have read, understood, and accept every term below. If you do not agree, tap \"Exit\" and stop using the Software.",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "To the maximum extent permitted by applicable law, neither the developers nor any contributor shall be liable for any direct, indirect, incidental, special, punitive, or consequential damages arising from the use of or inability to use the Software, including but not limited to data loss, device damage, network failures, business interruption, lost profits, or any resulting legal dispute, even if advised of the possibility of such damages.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitation of liability",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "The Software is open source under the GPL-3.0 license. You may use, modify, and distribute it freely as long as you comply with that license, which requires derivative works to be released under GPL-3.0 as well and the original copyright notices to be kept.\n\nThird-party components in the Software, including the Clash.Meta core, follow their own licenses. The original authors are not responsible for any issue arising from modified or redistributed versions.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Open-source license",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "The Software itself does not provide any proxy server, node, subscription, or network access service, and has no partnership, agency, or guarantee relationship with any provider of such services.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "The Software does not collect or upload your subscription URLs, node details, configuration content, visited websites, connection records, traffic content, or logs. This data stays on your device and the developers have no access to it.\n\nThe Software only reaches the network when you use a feature that needs it, such as fetching the subscription URL you provided when updating a profile, or contacting GitHub when checking for updates.\n\nThe Software includes no analytics or crash reporting service on any platform.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Data collection and privacy",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "You are responsible for making sure that using the Software is lawful where you live, and you alone bear the legal responsibility for everything you do with it and its consequences.\n\nThe subscriptions, nodes, and configurations you import are your own choice. Whether their source is lawful, their content is safe, and their service is reliable is a matter between you and their providers.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Your responsibility",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Enter the statement above",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Does not match the statement",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "To confirm you understand, enter the following statement in full in the field below:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Restate the statement",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "The Software is an open-source network proxy client built on the Clash.Meta (mihomo) core. It only provides local tooling such as configuration management, rule-based routing, and traffic forwarding.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Nature of the software",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Subscription links, configuration files, rule sets, scripts, external resources, and external links are all provided by third parties. The developers cannot and do not review or guarantee their legality, accuracy, security, or availability.\n\nAny data leak, financial loss, account ban, or other loss caused by third-party content is to be settled between you and the third party; the developers bear no responsibility for it.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Third-party content",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "The Software is intended only for non-commercial uses such as learning, exchange, and technical research. Using it for any commercial purpose is strictly prohibited, including but not limited to paid distribution, bundled sales, use as part of a commercial service, or doing business in the name of the Software. Any commercial activity is unrelated to the Software and its developers.\n\nUsing the Software for anything that violates the laws and regulations of your country or region is strictly prohibited, including but not limited to bypassing lawfully imposed network access restrictions, spreading illegal content, launching network attacks, or infringing the lawful rights of others.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Restrictions on use",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "The Software is provided \"as is\" and \"as available\", without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, non-infringement, uninterrupted availability, freedom from errors, or freedom from security vulnerabilities.\n\nThe developers do not guarantee that the Software will meet your needs or that it will run without interruption or error.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "No warranty",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Disconnected"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "New version found",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Update DNS-related settings",
    ),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS hijack"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Without this entry, TUN hijacks every DNS query to port 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS hijacking"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "When disabled, AAAA queries return an empty result",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Entries added here replace the DNS of every URL and file profile; anything not added keeps the profile\'s own setting. Custom profiles set their DNS in their content.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS queries"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage(
      "Core DNS resolution records",
    ),
    "docked": MessageLookupByLibrary.simpleMessage("Docked"),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "done": MessageLookupByLibrary.simpleMessage("Done"),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Download bandwidth",
    ),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage("Download speed"),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("Download traffic"),
    "duration": MessageLookupByLibrary.simpleMessage("Duration"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage(
      "Connection latency",
    ),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS zone"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage(
      "Feature flags",
    ),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("Instance ID"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "Path latency (latency first)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("Listeners"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "Local endpoint",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("Packet loss"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "Minimum direct latency",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage("Next-hop peer ID"),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "Path latency (hop-count first)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("Peer ID"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage(
      "Transport protocol",
    ),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage(
      "Public server",
    ),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "Remote endpoint",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("Route cost"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage(
      "Received packets",
    ),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage("Sent packets"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Edit dashboard"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Edit global rules",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Edit proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("Edit proxy group"),
    "editRule": MessageLookupByLibrary.simpleMessage("Edit rule"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Edit SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Editor unavailable",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Took"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("Empty fallback"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "Enable external controller",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("Enabled"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "NAT enhancement",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Optimize UDP and P2P application connectivity",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("Endpoints"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("Enforce routes"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "Ensure traffic is routed through the tunnel even when more specific routes exist",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Error details"),
    "es": MessageLookupByLibrary.simpleMessage("Spanish"),
    "exclude": MessageLookupByLibrary.simpleMessage("Hide from recent tasks"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("Exclude APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Allow Apple Push Notification traffic to bypass the tunnel",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "Exclude cellular services",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Allow cellular service traffic such as Wi-Fi Calling to bypass the tunnel",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Hide the app from recent tasks while it is in the background",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "Exclude device communication",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "Allow device-to-device traffic such as AirDrop and AirPlay to bypass the tunnel",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Excluded destination ports",
    ),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Traffic to excluded destination ports skips TUN.",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Exclude filter"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Excluded interfaces",
    ),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Traffic arriving on excluded interfaces, such as docker0, skips TUN.",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "Exclude local networks",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Allow direct access to devices on the local network",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Exclude proxy filter",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Excluded source ports",
    ),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Traffic from excluded source ports skips TUN.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to Wi-Fi with an excluded SSID, the app\'s running state switches automatically.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Exclude type"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("Excluded user IDs"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Traffic from processes of excluded user IDs skips TUN.",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("Exit full screen"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Exit nodes"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Expected status"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Expiration time"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export file"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export successful"),
    "extend": MessageLookupByLibrary.simpleMessage("Extend"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Extend mode"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Extend script"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "External controller",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "The external controller lets you control the core on port 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "External controller secret",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("External fetch"),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Extra large"),
    "fade": MessageLookupByLibrary.simpleMessage("Fade"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IP filter"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Domains matched in Fake IP mode receive real IP addresses instead of Fake IP addresses",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Fake-IP filter mode",
    ),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "In Fake-IP filter mode, blacklist excludes matches, whitelist fakes only matches, and rule matches as rules.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP range"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Fake-IP range (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Usually an overseas DNS",
    ),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Matching domains use fallback directly without querying nameserver",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Checks nameserver results against GeoIP code; results outside that region use fallback",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Domains matching these GeoSite categories use fallback directly",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Nameserver results matching these CIDR prefixes are replaced with fallback results",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Features"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Upload a profile file directly",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "The file has been modified. Save the changes?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("File name"),
    "filter": MessageLookupByLibrary.simpleMessage("Filter"),
    "filters": MessageLookupByLibrary.simpleMessage("Filters"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling causes some performance loss",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("Floating"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Follow profile"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Follow system"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Font family"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Size"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Force DNS mapping",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Force DNS mapping also sniffs connections whose domain came from a DNS mapping.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Force domains"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Force domains are sniffed too; other connections that already have a domain are left alone.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force restart the core?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("French"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "General settings for the app and core",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Generate from Age private key",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Generate"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto-update interval",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "The auto-update interval must be greater than 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geo options"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo low-memory mode",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Use the low-memory Geo loader",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP code"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage(
      "High performance Geo matcher",
    ),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling will use the minimal perfect hash algorithm for matching",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Download"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Go to added rules configuration",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Go to script configuration",
    ),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "grid": MessageLookupByLibrary.simpleMessage("Grid"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("groups"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Cache the changes?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hash by inbound user",
    ),
    "header": MessageLookupByLibrary.simpleMessage("Header"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Health check"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper service unavailable; TUN mode cannot be enabled. Reinstall FlClash to restore it.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hide": MessageLookupByLibrary.simpleMessage("Hide"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Hide from list"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Hide IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Hide password"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Hide timed-out proxies",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Leave out proxies whose last delay test timed out",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("Hide timeout"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "High priority auto launch",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Use a Windows scheduled task to start earlier",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Hop interval"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostname": MessageLookupByLibrary.simpleMessage("Hostname"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Append hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("Hotkey conflict"),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Global hotkeys work even while the window is hidden. Tap an action to record its key combination.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey management",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Control the app with the keyboard",
    ),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Not set"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Not registered, it may be taken by another app",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("hours"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("Hue"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP forwarding"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Enable ICMP ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Icon records"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Icon sets"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "No icon sets yet. Add them in Custom profile resources → Icon sets",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("Icon source"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Filled"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Hidden"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Plain"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("Icon URL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore battery optimization",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "Ignore certificate validation",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Allow HTTPS connections with invalid certificates. This reduces security",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "This file is not a config that can be imported",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Importing replaces the proxy groups, rules and settings this profile has now",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from file"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("Import from link"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "inbound": MessageLookupByLibrary.simpleMessage("Inbound"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage(
      "Include all networks",
    ),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Route all network traffic through the tunnel, including local and cellular services",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Include all proxies",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Imports all proxies outside proxy groups; extra proxy groups can be added below",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Include all proxy providers",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "When enabled, the imported proxy providers are overridden",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Included interfaces",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Only traffic arriving on included interfaces goes through TUN, and excluded interfaces no longer apply.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("Included user IDs"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Only traffic from processes of included user IDs goes through TUN.",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Never expires"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Startup failed"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash ran into an error while starting and can\'t continue. Copy the details to report the problem. If it keeps happening, clearing the data usually lets the app start again.",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("Initialize"),
    "initiator": MessageLookupByLibrary.simpleMessage("Initiator"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("From"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid hotkey",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Enter the proxy group name",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Enter the rule content",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "The app list permission was denied, so installed apps cannot be listed. Please grant it manually in system settings.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "This system hides the installed app list until the permission is granted. Authorize it to configure the per-app proxy.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "App list permission required",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("Installed fonts"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Smart selection",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Interface name"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "Interface name is the network interface outbound connections use.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Outbound interface",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Clear"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("Custom"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Follow config",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Invalid backup file",
    ),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "Enter a valid file name without path separators or special characters, within 255 bytes.",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Enter an IP range in CIDR form such as 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "Enter a valid directory without . or .. segments, backslashes, or special characters.",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "A DSCP mark cannot exceed 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Enter a domain or an IP address",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Not a valid icon set",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Not a subscription link or a proxy share link",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Enter an address and port such as 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Only tcp or udp is supported",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Enter a port or a range such as 443 or 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "This QR code doesn\'t contain a profile link",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Enter numbers or ranges such as 80 or 8000-9000, separated by /",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP address"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Abuse history"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Flags"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organization"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t determine the IP type",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Good"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Level"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normal"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("Check again"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Risky"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Quality"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Answered by"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Sources"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "Different outbound IP",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("No type"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("Rate limited"),
    "ipType": MessageLookupByLibrary.simpleMessage("Type"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Business"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Data center"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Mobile network"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Residential"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Unknown type"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP version"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "IPv6 traffic is received only while IPv6 is on.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "With IPv6 on, the VPN allows IPv6 inbound.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6 timeout (ms)"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("Japanese"),
    "justNow": MessageLookupByLibrary.simpleMessage("Just now"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "TCP keep-alive idle",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP keep-alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "ko": MessageLookupByLibrary.simpleMessage("Korean"),
    "label": MessageLookupByLibrary.simpleMessage("Label"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "large": MessageLookupByLibrary.simpleMessage("Large"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Last updated"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Launch did not finish",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "The app exited unexpectedly while it was starting up last time. Automatic setup was skipped for this launch; you can start it manually to retry.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "level": MessageLookupByLibrary.simpleMessage("Level"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("Line spacing"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Word wrap"),
    "link": MessageLookupByLibrary.simpleMessage("Link"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "Obtain a profile from a subscription link or a proxy share link",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Listen routing mark",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "Listen routing mark works only on Linux.",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("Listening port"),
    "liveConnections": MessageLookupByLibrary.simpleMessage("Live connections"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Back up data locally",
    ),
    "localImage": MessageLookupByLibrary.simpleMessage("Local image"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Local network permission denied: using the gvisor stack, LAN is unreachable.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Local proxies"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Location permission was denied, so the current Wi-Fi name cannot be read. Please enable location permission manually in system settings.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "The system requires location permission to read the Wi-Fi name. On Android choose \"Allow all the time\", otherwise the Wi-Fi name cannot be read while the app is in the background.",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location permission required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Log"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Log level"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Turning off Logcat hides the logs entry.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Logs and diagnostics",
    ),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Captured log records"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs test"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP loopback exemption"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Used for UWP loopback exemption",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "manual": MessageLookupByLibrary.simpleMessage("Manual"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Match case"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("Match source IP"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "Where rules targeting MATCH-TARGET go. Defaults to the target of the final MATCH rule in this profile.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("Match target"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Max failures"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("Maximize"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("App memory"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Resident memory",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App & shared"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("Clean up"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Heap idle"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Heap in use"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Core is not running",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Runtime overhead",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("Goroutine stacks"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimated from process resident memory; it may differ from what the system reports.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "The Core runs inside the app process. Its share is estimated from runtime stats, and the rest counts as app and shared memory.",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage("Memory footprint"),
    "memoryGC": MessageLookupByLibrary.simpleMessage("GC metadata"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Retained idle heap",
    ),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("Heap objects"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage(
      "Returned to OS",
    ),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage(
      "Unused heap spans",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Memory the app and the core use",
    ),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage("Runtime metadata"),
    "memoryOther": MessageLookupByLibrary.simpleMessage("Other runtime memory"),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "Unable to read memory. Retrying…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Memory released"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("Stacks"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Go memory usage"),
    "messageTest": MessageLookupByLibrary.simpleMessage("Message test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "minimize": MessageLookupByLibrary.simpleMessage("Minimize"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Override the default system exit behavior",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("minutes"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage(
      "Monochrome tray icon",
    ),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU must be an integer between 1 and 65535",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "Separate multiple values with commas",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve domains",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Assigns specific DNS servers to matching domains, geosite categories, or rule sets",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("Bottom bar"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("Sign-in required"),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "The request was cancelled",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t connect to the server. Check your network connection or proxy settings",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Adjust network-related settings",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Network error, please check your connection and try again",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage(
      "Network extension",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t resolve the server address. Check that the URL is correct and DNS is working",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("Network ID"),
    "networkName": MessageLookupByLibrary.simpleMessage("Network name"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage(
      "Network not found",
    ),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Too many requests (HTTP 429). Wait a moment and try again",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Network secret"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Show real-time network speed",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Show real-time network speed in the system status area; may slightly increase power usage",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("Traffic takeover"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "The request timed out. Check your network or proxy, then try again",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Secure connection failed. The server\'s certificate may be invalid, or the connection is being intercepted",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Network type"),
    "networking": MessageLookupByLibrary.simpleMessage("Networking"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage(
      "View status of P2P networks",
    ),
    "networkingError": MessageLookupByLibrary.simpleMessage("Error"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "No P2P outbound in the current configuration",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("New"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Write a profile manually",
    ),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Next match"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("No subdirectories"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage(
      "No filter conditions",
    ),
    "noHotKey": MessageLookupByLibrary.simpleMessage("No hotkeys yet"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No info"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Don\'t remind me again",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No-network apps"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "No remote backups found",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Don\'t resolve IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Don\'t resolve hostname",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "No matching results",
    ),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "Unable to read traffic. Retrying…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("Node traffic"),
    "nodes": MessageLookupByLibrary.simpleMessage("Nodes"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "This external resource is not a text file",
    ),
    "none": MessageLookupByLibrary.simpleMessage("None"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Not running"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "The current proxy group cannot be selected",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Update NTP-related settings",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Sync interval (minutes)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP takes the time from an NTP server instead of the system clock.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Add a profile to get started",
    ),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("Obfuscation"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Obfuscation host"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Obfuscation mode"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("Obfuscation parameter"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Obfuscation password",
    ),
    "offline": MessageLookupByLibrary.simpleMessage("Offline"),
    "onDemand": MessageLookupByLibrary.simpleMessage("On demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "On demand pauses the proxy on excluded Wi-Fi.",
    ),
    "online": MessageLookupByLibrary.simpleMessage("Online"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("Config only"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Emoji only"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icon only"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Only count proxy traffic",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "When enabled, only proxy traffic is counted",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("Open in GitHub"),
    "optional": MessageLookupByLibrary.simpleMessage("Optional"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other contributors",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Outbound"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Exit"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("Outbound IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Override destination",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "Override destination connects to the sniffed domain instead of the original address.",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "When enabled, the DNS options in the profile are overridden",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("Override entries"),
    "overrideMode": MessageLookupByLibrary.simpleMessage("Override mode"),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Override NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "When enabled, the NTP options in the profile are overridden",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage("Override script"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("Custom"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Custom mode: fully customize proxy groups and rules",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("Parent directory"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Parse pure IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "Parse pure IP sniffs connections that carry only an IP address.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "peers": MessageLookupByLibrary.simpleMessage("Peers"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Choose from album"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Pin window"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Plugin"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Plugin host"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Plugin mode"),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Port hopping"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("Ports"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "Please enter an integer greater than 0",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Pre-shared key"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("Predictive back"),
    "preferH3": MessageLookupByLibrary.simpleMessage("Prefer HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prefer HTTP/3 for DoH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Press a key combination",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("Previous match"),
    "privateKey": MessageLookupByLibrary.simpleMessage("Private key"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Private key passphrase",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Process"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Please enter a valid interval"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please enter the auto-update interval",
        ),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "The profile has been modified. Turn off auto update?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter the profile name",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Applies to this profile only; anything not added uses its default.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Applies to this profile only and takes precedence over the TUN override entries in the network settings.",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid profile URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter the profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Sort profiles"),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Close connections prompt",
    ),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Ask whether to close connections after changing node",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocol"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("Protocol parameter"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("Protocol version"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Only remote providers are supported",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("External resources"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Proxy chain"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "The selected proxies are abnormal",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Proxy filter"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy group"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "The current proxy group is abnormal",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group is empty",
    ),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group name cannot be empty",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Groups show up here once the core starts",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve proxy node domains",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Proxy nameserver policy",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Specify the nameserver policy for proxy nodes",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("Proxy provider"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "The selected proxy providers are abnormal",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "proxyType": MessageLookupByLibrary.simpleMessage("Proxy type"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Prune cache"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Public key"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Pure black"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan a QR code to obtain a profile",
    ),
    "query": MessageLookupByLibrary.simpleMessage("Query"),
    "queryDns": MessageLookupByLibrary.simpleMessage("Query DNS"),
    "queryRule": MessageLookupByLibrary.simpleMessage("Query rules"),
    "quickActions": MessageLookupByLibrary.simpleMessage("Quick actions"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Quick edit"),
    "quickFill": MessageLookupByLibrary.simpleMessage("Quick fill"),
    "random": MessageLookupByLibrary.simpleMessage("Random"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Recent requests"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Suggested"),
    "recordType": MessageLookupByLibrary.simpleMessage("Record type"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("Enable RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Receive packets in batches on Darwin",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir port"),
    "redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("Regex search"),
    "relayed": MessageLookupByLibrary.simpleMessage("Relayed"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Release memory"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to release memory",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Back up data to WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Remote destination",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Remote DNS resolution",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "replace": MessageLookupByLibrary.simpleMessage("Replace"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Replace all"),
    "request": MessageLookupByLibrary.simpleMessage("Request"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Requests and updates",
    ),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "View recent request records",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Required"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "This page has changes. Are you sure you want to reset?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Profiles and scripts",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage(
      "Application settings",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to reset?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto-update interval",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "The auto-update interval must be greater than 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Information about external resources",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respect rules routes DNS connections by the rules and needs a Proxy Server Nameserver.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Response code"),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to restart the core?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("Restore all data"),
    "restoreException": MessageLookupByLibrary.simpleMessage("Restore error"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Restore data from a file",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Restore data from WebDAV",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Restore hidden",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restore profiles only",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("Restore strategy"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("Override"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restore successful",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Result"),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "role": MessageLookupByLibrary.simpleMessage("Role"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route addresses"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Configure the listened route addresses",
    ),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Route exclude addresses",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Route mode"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Bypass private addresses",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage("Use config"),
    "routes": MessageLookupByLibrary.simpleMessage("Routes"),
    "routingMark": MessageLookupByLibrary.simpleMessage("Routing mark"),
    "ru": MessageLookupByLibrary.simpleMessage("Russian"),
    "rule": MessageLookupByLibrary.simpleMessage("Rule"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Match the full domain",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain keyword",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain regex",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain suffix",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Wildcard match; only * and ? are supported",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Match the DSCP mark (tproxy UDP inbound only)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the destination port range",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match the IP\'s country code",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains in Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound name",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound port",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound type",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound username; separate multiple usernames with /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match the IP\'s ASN",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Match an IP address range; IP-CIDR6 is just an alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match an IP address range",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match an IP suffix range",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Match all requests, no conditions needed",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Match TCP or UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Logical rule OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name; matches the package name on Android",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name regex; matches the package name on Android",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name wildcard; only * and ? are supported",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Match by the full process path",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process path regex",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process path wildcard; only * and ? are supported",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match the rematch name; separate multiple names with /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Reference a rule set; requires rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source IP\'s country code",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source IP\'s ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match a source IP address range",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match a source IP suffix range",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source port range",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Match into a sub-rule; mind the parentheses",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Match the Linux user ID",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Rule is empty"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("Enabled"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("Hits"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("Last hit"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage("Last miss"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "The rules must be a YAML list with one rule per item, such as - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("Misses"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent direct",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Block DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Block proxy loopback",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("Block QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("Block STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN direct"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple and Microsoft direct",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage(
      "Destination IP",
    ),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage(
      "Inbound name",
    ),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage(
      "Inbound user",
    ),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "Enter a valid IP address.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "No rule matched (mode policy or DIRECT fallback)",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "Enter a port between 1 and 65535.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage(
      "Process path",
    ),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage(
      "Sniffed domain",
    ),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("Source port"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage(
      "Domain or IP address",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Rule set"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "The rule set has no usable entries",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "This mrs file cannot be read",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "The rule set mixes domains and IP ranges, so its type cannot be told",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "The rule must start with a supported type, such as DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("Rule type"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Could not change the rule. The configuration may have changed; refresh and try again.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Rules"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage(
      "View rules and matching statistics",
    ),
    "runTime": MessageLookupByLibrary.simpleMessage("Run time"),
    "running": MessageLookupByLibrary.simpleMessage("Running"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("Runtime config"),
    "safeMode": MessageLookupByLibrary.simpleMessage("Safe mode"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturation"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Save the changes?"),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Script mode: rewrites the whole profile with an extension script",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Scroll to selected",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("seconds"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("Key"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "Select MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage(
      "Select a backup",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Please select a rule set",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Please select a split strategy",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("Enable SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Send packets in batches on Darwin",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Server"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "All available",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Available"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Blocked"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("Check"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Check all"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Coming soon"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "Disallowed ISP",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("Check failed"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("Manage services"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Originals only",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Not checked"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Access restricted",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Shown on the dashboard",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("Service status"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Unavailable"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Region not supported",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("settings"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "No proxy could be read from the links",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage("Show hidden"),
    "showLess": MessageLookupByLibrary.simpleMessage("Collapse"),
    "showMore": MessageLookupByLibrary.simpleMessage("Expand"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Stop button in notification",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "Show a stop button on the persistent notification. Turn it off if your system keeps the notification expanded because of it",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Show password"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "Show current profile name",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "Show profile name on the quick toggle when connected",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "Show proxy selection in tray",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "Show proxy groups and nodes in the tray menu for quick switching",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("Show timeout"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("Sidebar blur"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "Show the blurred desktop behind the window through the sidebar",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("Sign in"),
    "signOut": MessageLookupByLibrary.simpleMessage("Sign out"),
    "signedIn": MessageLookupByLibrary.simpleMessage("Signed in"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Silent launch"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Silent launch starts without showing the window.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("Single add"),
    "singleImport": MessageLookupByLibrary.simpleMessage("Single import"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Enter one link here; edit several from the quick edit of the list",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Skip certificate verification",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Skip domains"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "A sniffed domain on the Skip domains list is not used.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Skip destination addresses",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Skip source addresses",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Slide"),
    "sliders": MessageLookupByLibrary.simpleMessage("Sliders"),
    "small": MessageLookupByLibrary.simpleMessage("Small"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocols"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "The sniffer reads the domain from TLS, HTTP and QUIC traffic so rules can match it.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("SOCKS port"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Soft"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Special proxy"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Special rules"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Spectrum"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("Speed statistics"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("Split strategy"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Split strategy cannot be empty",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs are empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Stack trace"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Standard mode: adds rules on top of the profile",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage(
      "Start from scratch",
    ),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Startup and background",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "With DNS off, the system DNS is used.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("Stopped"),
    "strategy": MessageLookupByLibrary.simpleMessage("Strategy"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Strict route"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Strict route keeps traffic such as DNS from bypassing TUN, and with IPv6 off it blocks this device\'s IPv6 connections.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("Style settings"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Subscription info",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Enter your password for sudo",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage("Suspend support"),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "Suspend the core while the device is idle to reduce battery usage",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspended…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage(
      "Swipe to switch pages",
    ),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Switch profile"),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System apps"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Set the system HTTP proxy",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Tab animation"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Only effective in mobile view",
    ),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("Active"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "Current endpoint",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS name"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage("Endpoints"),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("Exit node"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "Exit node available",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("Health"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage(
      "Health warnings",
    ),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("Key expired"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage("Key expiry"),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage(
      "Last handshake",
    ),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage("Last seen"),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "Device approval required",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("Node key"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("DERP relay"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("Subnets"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("Tags"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Tap the icon to retry",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("Tap to authorize"),
    "target": MessageLookupByLibrary.simpleMessage("Target"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Allow concurrent TCP connections",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage("Test interval"),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test URL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Test when used"),
    "textReplacement": MessageLookupByLibrary.simpleMessage(
      "Text replacement:",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Text scaling"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Text in the app will look like this",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Tinted"),
    "tip": MessageLookupByLibrary.simpleMessage("Tip"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("Toggle labels"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolerance"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "torch": MessageLookupByLibrary.simpleMessage("Flashlight"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Downloaded"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Total traffic"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Uploaded"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxy port"),
    "traffic": MessageLookupByLibrary.simpleMessage("Traffic"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("Both"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic usage"),
    "transport": MessageLookupByLibrary.simpleMessage("Transport"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN could not be authorized, so it was turned off.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN works only in administrator mode.",
    ),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("System DNS mode"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("Hijack"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("Native"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Entries added here replace the TUN settings of every profile; anything not added keeps the profile\'s own setting. Entries a custom profile adds itself take precedence.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Turn off"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Turn on"),
    "tvMode": MessageLookupByLibrary.simpleMessage("TV mode"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "Use the remote-friendly layout on this device",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP relay mode"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP timeout"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "The UDP timeout is in seconds and works only with the gvisor, system and mixed stacks.",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage(
      "Idle update interval",
    ),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "Idle when unfocused",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "Use the idle update interval when the app window loses focus",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "UI info update interval",
    ),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("Unauthorized"),
    "undo": MessageLookupByLibrary.simpleMessage("Undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Remove extra delays such as handshakes",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("Uninitialized"),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "Unknown variable. Choose one of the variables below.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Unknown network error",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restore down"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Unpin window"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "The downloaded file does not match the published checksum and was discarded.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage(
      "Downloading update",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "The installer could not be started.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash was not allowed to install apps, so the update was not installed.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash cannot write to the folder it is installed in. Download the update manually.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("Update now"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("Upload bandwidth"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("Upload speed"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("Upload traffic"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtain a profile from a URL",
    ),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Checks the hosts entries in the configuration before querying upstream DNS servers",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Checks the operating system\'s hosts file when resolving domain names",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("used"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Used traffic"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("Virtual IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vivid"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN-related configuration change detected",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN routes all system traffic through VpnService automatically.",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV configuration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("Write to system"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Write to system also sets the system clock; Android ignores it.",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("Yes"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
    "zhTW": MessageLookupByLibrary.simpleMessage("Traditional Chinese"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage("Get help"),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "View activation and renewal orders",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage(
      "Login password",
    ),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "Connection settings",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage(
      "View account details and orders.",
    ),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("My account"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("Activating"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("Advanced settings"),
    "zolnitAiService": MessageLookupByLibrary.simpleMessage("AI services"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("All servers"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("All regions"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("Amount due"),
    "zolnitAppleAutoRenewal": MessageLookupByLibrary.simpleMessage(
      "Auto-renewing App Store subscription",
    ),
    "zolnitAppleConsent": MessageLookupByLibrary.simpleMessage(
      "The subscription renews automatically at the displayed App Store price until you cancel it in App Store subscriptions.",
    ),
    "zolnitAppleManage": MessageLookupByLibrary.simpleMessage(
      "Manage App Store subscriptions",
    ),
    "zolnitApplePending": MessageLookupByLibrary.simpleMessage(
      "Waiting for App Store or server verification.",
    ),
    "zolnitAppleRestore": MessageLookupByLibrary.simpleMessage(
      "Restore App Store purchases",
    ),
    "zolnitAppleSubscribe": MessageLookupByLibrary.simpleMessage(
      "Subscribe with App Store",
    ),
    "zolnitAppleUnavailable": MessageLookupByLibrary.simpleMessage(
      "App Store purchases are not available for this plan.",
    ),
    "zolnitAuthorizeMonthly": MessageLookupByLibrary.simpleMessage(
      "Authorize monthly billing",
    ),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("Account balance"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage(
      "Billed monthly, an easy start",
    ),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "Renewal details are temporarily unavailable.",
    ),
    "zolnitBundleAutomaticPending": MessageLookupByLibrary.simpleMessage(
      "Automatic routing is still being validated. Manual and direct choices are available.",
    ),
    "zolnitBundleExpired": MessageLookupByLibrary.simpleMessage(
      "Automatic selection information has expired. Refresh the configuration; manual and direct choices remain available.",
    ),
    "zolnitBundleFetchHint": MessageLookupByLibrary.simpleMessage(
      "Fetch connection configuration",
    ),
    "zolnitBundleForbidden": MessageLookupByLibrary.simpleMessage(
      "Connection configuration is unavailable for this account. Check the plan and traffic allowance.",
    ),
    "zolnitBundleInvalid": MessageLookupByLibrary.simpleMessage(
      "Connection configuration validation failed. Automatic selection is paused.",
    ),
    "zolnitBundleNoCandidates": MessageLookupByLibrary.simpleMessage(
      "No exit is confirmed eligible. Automatic selection is unavailable; choose manually or direct.",
    ),
    "zolnitBundleRefreshFailed": MessageLookupByLibrary.simpleMessage(
      "Could not refresh the connection configuration. Manual and direct choices remain available.",
    ),
    "zolnitBundleUnavailable": MessageLookupByLibrary.simpleMessage(
      "Connection configuration is temporarily unavailable.",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("Create order"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("Cancel order"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "Cancel this unpaid order?",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage(
      "Cancel automatic renewal",
    ),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Stop future automatic charges. An unpaid first order will also be canceled. Paid access follows the server result.",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("Canceled"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage(
      "Change password",
    ),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "A checkout is already in progress. Check its status in Account and do not submit it again.",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "The checkout is being prepared or verified. Try again shortly.",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("Choose plan"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "zolnitConnectAction": MessageLookupByLibrary.simpleMessage("Connect"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "Ready to connect",
    ),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage(
      "Connect automatically on launch",
    ),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "Connect to the server you used last time when the app starts.",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "Connect with the servers included in your plan.",
    ),
    "zolnitConnectionPageUnavailable": MessageLookupByLibrary.simpleMessage(
      "The connection page is unavailable. Try again.",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("Copy code"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "Enter a valid email and a password of at least eight characters.",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("Credited"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("Current plan"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLabel": MessageLookupByLibrary.simpleMessage(
      "Current plan",
    ),
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("Selected"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("half year"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("quarter"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage(
      "three years",
    ),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("two years"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("year"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("days"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "These are your account\'s login sessions, which differ from a node\'s online IP count.",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage(
      "Login sessions",
    ),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "Unable to load login sessions right now. Please try again.",
    ),
    "zolnitDisconnectAction": MessageLookupByLibrary.simpleMessage(
      "Disconnect",
    ),
    "zolnitDisconnecting": MessageLookupByLibrary.simpleMessage(
      "Disconnecting…",
    ),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("Email"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage(
      "Familiar on every screen",
    ),
    "zolnitExistingRenewal": MessageLookupByLibrary.simpleMessage(
      "Cancel your current plan\'s automatic renewal in Account before starting monthly billing for another plan.",
    ),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "Could not complete the request. Please try again.",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("First payment"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage(
      "Following payments",
    ),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage(
      "Forgot password?",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("Gifted access"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "Paid access starts after the first payment replaces the remaining gifted time.",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage(
      "Selected global routes",
    ),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "View your plan and available servers.",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage(
      "Every six months",
    ),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage("Help & support"),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("Invite code"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage(
      "Invite code copied",
    ),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "Available commission",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "Confirmed commission",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "Pending commission",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage(
      "Commission rate",
    ),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage(
      "Invite link copied",
    ),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage(
      "Create invite code",
    ),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "Could not create the invite code. Please try again.",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage(
      "Share the connection, earn a bonus.",
    ),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage("Invite link"),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Unable to load invite data right now. Please try again.",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage(
      "Invite your friends to get started.",
    ),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("people"),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage(
      "Registered",
    ),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage("Invite rules"),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage(
      "Share your invite",
    ),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "Friends register with your link. You earn a reward after they subscribe.",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "Invite friends to register and subscribe through your link.",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("Latency"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage(
      "Latest notices",
    ),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "Skip the complicated setup. Your world is one connection away.",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "A little closer to your world",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Sign in to manage your plan and connections.",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage(
      "Sign up or recover your password",
    ),
    "zolnitManageRenewals": MessageLookupByLibrary.simpleMessage(
      "Manage automatic renewal",
    ),
    "zolnitMediaService": MessageLookupByLibrary.simpleMessage("Streaming"),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("Global"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage("Smart routing"),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("Monthly"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage(
      "Continuous monthly billing",
    ),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("My space"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("New password"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage("Next renewal"),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "You have no active plan yet. Pick one below to get started.",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage(
      "No login sessions to show.",
    ),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "No matching servers.",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage(
      "No payment methods available",
    ),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "No servers are available with your current plan.",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage("No notices yet"),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("No orders yet"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("No active plan"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage(
      "No automatic renewal contracts",
    ),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "Latency reflects the most recent actual test; shows — if not tested.",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("Server"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "Your available servers update automatically with your plan.",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("Servers"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Servers are managed and updated from your account.",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage(
      "Not connected yet",
    ),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("Notices"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage(
      "Current password",
    ),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("One time"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage(
      "Devices online",
    ),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("Orders"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("Paid access"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("Paid through"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "Enter your current password and a different new password of at least eight characters.",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "Password updated.",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("Pay order"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "Your order still needs confirmation after returning from payment.",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Payment status",
    ),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "This payment option is not ready.",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("Awaiting payment"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "You have a pending order. Continue paying or close it in Orders before placing another.",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ month"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "The new plan starts after the first payment or remaining-value credit is confirmed.",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage("Plan validity"),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("Plans"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage("Plans"),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "From everyday browsing to smooth streaming, pick the connection that fits you.",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("Preferences"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage(
      "Settings",
    ),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "Safe mode keeps your preferences but won\'t connect automatically or change system network settings.",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Manage startup and connection settings.",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "Your servers update automatically from your account.",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("Quarterly"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "Review the quote before authorizing automatic renewal.",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "This quote has expired. Refresh to continue.",
    ),
    "zolnitQuoteLabel": MessageLookupByLibrary.simpleMessage("Quote"),
    "zolnitQuoteUnavailable": MessageLookupByLibrary.simpleMessage(
      "The quote is unavailable. Try again.",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "Too many attempts. Please try again in a moment.",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage(
      "Recommended servers",
    ),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "Servers included in your plan",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage(
      "Recommended",
    ),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "I agree to continuous payments for this plan under the displayed first-payment and renewal terms.",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "Monthly billing is not available for this plan right now.",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("Sign up"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "Sign-up and password recovery open the ZolNit website for email and security verification.",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage(
      "Renew current plan",
    ),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("Renew plan"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage("Automatic renewal"),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage("Reset traffic"),
    "zolnitRestoringSession": MessageLookupByLibrary.simpleMessage(
      "Restoring sign-in…",
    ),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage(
      "Resume automatic renewal",
    ),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Resume automatic charges under the authorized plan.",
    ),
    "zolnitReturnDirect": MessageLookupByLibrary.simpleMessage(
      "Direct to China",
    ),
    "zolnitReturnEnabled": MessageLookupByLibrary.simpleMessage(
      "Enable China routing",
    ),
    "zolnitReturnHkLite": MessageLookupByLibrary.simpleMessage(
      "Hong Kong preferred",
    ),
    "zolnitReturnHkOptimized": MessageLookupByLibrary.simpleMessage(
      "Hong Kong optimized",
    ),
    "zolnitReturnLocal": MessageLookupByLibrary.simpleMessage(
      "Local direct connection",
    ),
    "zolnitReturnRoute": MessageLookupByLibrary.simpleMessage("Return route"),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage(
      "Sign out of this session",
    ),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "Login session ended.",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "End this login session? That device must sign in again to manage the account.",
    ),
    "zolnitRouteCurrent": m101,
    "zolnitRouteUnavailable": MessageLookupByLibrary.simpleMessage(
      "Unavailable",
    ),
    "zolnitSafeMode": MessageLookupByLibrary.simpleMessage("Safe mode"),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "Safe mode never changes the system network.",
    ),
    "zolnitSavePercent": m102,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage(
      "Search servers or regions",
    ),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("Select"),
    "zolnitSelectServer": MessageLookupByLibrary.simpleMessage("Choose server"),
    "zolnitSessionExpired": MessageLookupByLibrary.simpleMessage(
      "Sign-in expired. Sign in again.",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("Sign in"),
    "zolnitSignInRejected": MessageLookupByLibrary.simpleMessage(
      "Email or password is incorrect. Try again.",
    ),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("Sign out"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage(
      "Launch ZolNit at startup",
    ),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "Have ZolNit ready as soon as your device turns on.",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("Active"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("Expired"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("No plan"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage(
      "Choose a plan",
    ),
    "zolnitSync": MessageLookupByLibrary.simpleMessage("Sync account data"),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage("Account data synced"),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage(
      "Syncing account data…",
    ),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("Account info"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("Invite & earn"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("Orders"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage(
      "Let connection feel simple.",
    ),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage(
      "Every three years",
    ),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("Traffic left"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage(
      "Used this cycle",
    ),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("Every two years"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage(
      "Login session",
    ),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage(
      "View monthly quote",
    ),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage(
      "Open ZolNit website",
    ),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("YOUR WORKSPACE"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("Yearly"),
  };
}

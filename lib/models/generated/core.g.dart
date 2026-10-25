// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CoreRulesSnapshot _$CoreRulesSnapshotFromJson(Map<String, dynamic> json) =>
    _CoreRulesSnapshot(
      generation: json['generation'] as String,
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((e) => CoreRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CoreRulesSnapshotToJson(_CoreRulesSnapshot instance) =>
    <String, dynamic>{
      'generation': instance.generation,
      'rules': instance.rules,
    };

_CoreRule _$CoreRuleFromJson(Map<String, dynamic> json) => _CoreRule(
  index: (json['index'] as num).toInt(),
  type: json['type'] as String,
  payload: json['payload'] as String? ?? '',
  proxy: json['proxy'] as String? ?? '',
  size: (json['size'] as num?)?.toInt() ?? -1,
  disabled: json['disabled'] as bool? ?? false,
  hitCount: (json['hitCount'] as num?)?.toInt() ?? 0,
  hitAt: json['hitAt'] == null ? null : DateTime.parse(json['hitAt'] as String),
  missCount: (json['missCount'] as num?)?.toInt() ?? 0,
  missAt: json['missAt'] == null
      ? null
      : DateTime.parse(json['missAt'] as String),
);

Map<String, dynamic> _$CoreRuleToJson(_CoreRule instance) => <String, dynamic>{
  'index': instance.index,
  'type': instance.type,
  'payload': instance.payload,
  'proxy': instance.proxy,
  'size': instance.size,
  'disabled': instance.disabled,
  'hitCount': instance.hitCount,
  'hitAt': instance.hitAt?.toIso8601String(),
  'missCount': instance.missCount,
  'missAt': instance.missAt?.toIso8601String(),
};

_SetRuleDisabledParams _$SetRuleDisabledParamsFromJson(
  Map<String, dynamic> json,
) => _SetRuleDisabledParams(
  generation: json['generation'] as String,
  index: (json['index'] as num).toInt(),
  type: json['type'] as String,
  payload: json['payload'] as String,
  disabled: json['disabled'] as bool,
);

Map<String, dynamic> _$SetRuleDisabledParamsToJson(
  _SetRuleDisabledParams instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'index': instance.index,
  'type': instance.type,
  'payload': instance.payload,
  'disabled': instance.disabled,
};

_CoreMemoryInfo _$CoreMemoryInfoFromJson(Map<String, dynamic> json) =>
    _CoreMemoryInfo(
      sys: (json['sys'] as num?)?.toInt() ?? 0,
      heapObjects: (json['heapObjects'] as num?)?.toInt() ?? 0,
      heapUnused: (json['heapUnused'] as num?)?.toInt() ?? 0,
      heapIdle: (json['heapIdle'] as num?)?.toInt() ?? 0,
      heapReleased: (json['heapReleased'] as num?)?.toInt() ?? 0,
      stacks: (json['stacks'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as num?)?.toInt() ?? 0,
      gc: (json['gc'] as num?)?.toInt() ?? 0,
      other: (json['other'] as num?)?.toInt() ?? 0,
      footprint: (json['footprint'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CoreMemoryInfoToJson(_CoreMemoryInfo instance) =>
    <String, dynamic>{
      'sys': instance.sys,
      'heapObjects': instance.heapObjects,
      'heapUnused': instance.heapUnused,
      'heapIdle': instance.heapIdle,
      'heapReleased': instance.heapReleased,
      'stacks': instance.stacks,
      'metadata': instance.metadata,
      'gc': instance.gc,
      'other': instance.other,
      'footprint': instance.footprint,
    };

_SetupParams _$SetupParamsFromJson(Map<String, dynamic> json) => _SetupParams(
  selectedMap: Map<String, String>.from(json['selected-map'] as Map),
  testUrl: json['test-url'] as String,
  skipCertVerify: json['skip-cert-verify'] as bool? ?? false,
  base: json['base'] == null
      ? null
      : SetupBase.fromJson(json['base'] as Map<String, dynamic>),
  routingObservation: json['routing-observation'] as bool?,
  routingLease: json['routing-lease'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$SetupParamsToJson(_SetupParams instance) =>
    <String, dynamic>{
      'selected-map': instance.selectedMap,
      'test-url': instance.testUrl,
      'skip-cert-verify': instance.skipCertVerify,
      'base': ?instance.base,
      'routing-observation': ?instance.routingObservation,
      'routing-lease': ?instance.routingLease,
    };

_SetupBase _$SetupBaseFromJson(Map<String, dynamic> json) => _SetupBase(
  path: json['path'] as String,
  overlay: json['overlay'] as String,
);

Map<String, dynamic> _$SetupBaseToJson(_SetupBase instance) =>
    <String, dynamic>{'path': instance.path, 'overlay': instance.overlay};

_ProfileBase _$ProfileBaseFromJson(Map<String, dynamic> json) => _ProfileBase(
  config: json['config'] as Map<String, dynamic>,
  digest: json['digest'] as String,
  matchRules:
      (json['match-rules'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  proxies: (json['proxies'] as num?)?.toInt() ?? 0,
  proxyGroups: (json['proxy-groups'] as num?)?.toInt() ?? 0,
  rules: (json['rules'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ProfileBaseToJson(_ProfileBase instance) =>
    <String, dynamic>{
      'config': instance.config,
      'digest': instance.digest,
      'match-rules': instance.matchRules,
      'proxies': instance.proxies,
      'proxy-groups': instance.proxyGroups,
      'rules': instance.rules,
    };

_UpdateParams _$UpdateParamsFromJson(Map<String, dynamic> json) =>
    _UpdateParams(
      tun: Tun.fromJson(json['tun'] as Map<String, dynamic>),
      mixedPort: (json['mixed-port'] as num).toInt(),
      allowLan: json['allow-lan'] as bool,
      findProcessMode: $enumDecode(
        _$FindProcessModeEnumMap,
        json['find-process-mode'],
      ),
      mode: $enumDecode(_$ModeEnumMap, json['mode']),
      logLevel: $enumDecode(_$LogLevelEnumMap, json['log-level']),
      ipv6: json['ipv6'] as bool,
      tcpConcurrent: json['tcp-concurrent'] as bool,
      externalController: $enumDecode(
        _$ExternalControllerStatusEnumMap,
        json['external-controller'],
      ),
      secret: json['secret'] as String? ?? '',
      unifiedDelay: json['unified-delay'] as bool,
      authentication:
          (json['authentication'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      geoAutoUpdate: json['geo-auto-update'] as bool? ?? false,
      geoUpdateInterval: (json['geo-update-interval'] as num?)?.toInt() ?? 24,
      geoXUrl:
          (json['geox-url'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      skipCertVerify: json['skip-cert-verify'] as bool? ?? false,
    );

Map<String, dynamic> _$UpdateParamsToJson(_UpdateParams instance) =>
    <String, dynamic>{
      'tun': _tunCoreJson(instance.tun),
      'mixed-port': instance.mixedPort,
      'allow-lan': instance.allowLan,
      'find-process-mode': _$FindProcessModeEnumMap[instance.findProcessMode]!,
      'mode': _$ModeEnumMap[instance.mode]!,
      'log-level': _$LogLevelEnumMap[instance.logLevel]!,
      'ipv6': instance.ipv6,
      'tcp-concurrent': instance.tcpConcurrent,
      'external-controller':
          _$ExternalControllerStatusEnumMap[instance.externalController]!,
      'secret': instance.secret,
      'unified-delay': instance.unifiedDelay,
      'authentication': instance.authentication,
      'geo-auto-update': instance.geoAutoUpdate,
      'geo-update-interval': instance.geoUpdateInterval,
      'geox-url': instance.geoXUrl,
      'skip-cert-verify': instance.skipCertVerify,
    };

const _$FindProcessModeEnumMap = {
  FindProcessMode.always: 'always',
  FindProcessMode.off: 'off',
};

const _$ModeEnumMap = {
  Mode.rule: 'rule',
  Mode.global: 'global',
  Mode.direct: 'direct',
};

const _$LogLevelEnumMap = {
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warning: 'warning',
  LogLevel.error: 'error',
  LogLevel.silent: 'silent',
};

const _$ExternalControllerStatusEnumMap = {
  ExternalControllerStatus.close: '',
  ExternalControllerStatus.open: '127.0.0.1:9090',
};

_VpnOptions _$VpnOptionsFromJson(Map<String, dynamic> json) => _VpnOptions(
  enable: json['enable'] as bool,
  port: (json['port'] as num).toInt(),
  ipv6: json['ipv6'] as bool,
  dnsHijacking: json['dnsHijacking'] as bool,
  accessControlProps: AccessControlProps.fromJson(
    json['accessControlProps'] as Map<String, dynamic>,
  ),
  allowBypass: json['allowBypass'] as bool,
  systemProxy: json['systemProxy'] as bool,
  bypassDomain: (json['bypassDomain'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  stack: json['stack'] as String,
  routeAddress:
      (json['routeAddress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  mtu: (json['mtu'] as num?)?.toInt() ?? 0,
  congestionController: json['congestionController'] as String? ?? '',
  disableIcmpForwarding: json['disableIcmpForwarding'] as bool? ?? false,
  endpointIndependentNat: json['endpointIndependentNat'] as bool? ?? false,
  recvMsgX: json['recvMsgX'] as bool? ?? true,
  sendMsgX: json['sendMsgX'] as bool? ?? false,
  includeAllNetworks: json['includeAllNetworks'] as bool? ?? false,
  excludeLocalNetworks: json['excludeLocalNetworks'] as bool? ?? true,
  excludeAPNs: json['excludeAPNs'] as bool? ?? true,
  excludeCellularServices: json['excludeCellularServices'] as bool? ?? true,
  enforceRoutes: json['enforceRoutes'] as bool? ?? false,
  excludeDeviceCommunication:
      json['excludeDeviceCommunication'] as bool? ?? true,
);

Map<String, dynamic> _$VpnOptionsToJson(_VpnOptions instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'port': instance.port,
      'ipv6': instance.ipv6,
      'dnsHijacking': instance.dnsHijacking,
      'accessControlProps': instance.accessControlProps,
      'allowBypass': instance.allowBypass,
      'systemProxy': instance.systemProxy,
      'bypassDomain': instance.bypassDomain,
      'stack': instance.stack,
      'routeAddress': instance.routeAddress,
      'mtu': instance.mtu,
      'congestionController': instance.congestionController,
      'disableIcmpForwarding': instance.disableIcmpForwarding,
      'endpointIndependentNat': instance.endpointIndependentNat,
      'recvMsgX': instance.recvMsgX,
      'sendMsgX': instance.sendMsgX,
      'includeAllNetworks': instance.includeAllNetworks,
      'excludeLocalNetworks': instance.excludeLocalNetworks,
      'excludeAPNs': instance.excludeAPNs,
      'excludeCellularServices': instance.excludeCellularServices,
      'enforceRoutes': instance.enforceRoutes,
      'excludeDeviceCommunication': instance.excludeDeviceCommunication,
    };

_InitParams _$InitParamsFromJson(Map<String, dynamic> json) => _InitParams(
  homeDir: json['home-dir'] as String,
  version: (json['version'] as num).toInt(),
  routingObservation: json['routing-observation'] as bool?,
);

Map<String, dynamic> _$InitParamsToJson(_InitParams instance) =>
    <String, dynamic>{
      'home-dir': instance.homeDir,
      'version': instance.version,
      'routing-observation': ?instance.routingObservation,
    };

_ChangeProxyParams _$ChangeProxyParamsFromJson(Map<String, dynamic> json) =>
    _ChangeProxyParams(
      groupName: json['group-name'] as String,
      proxyName: json['proxy-name'] as String,
      closeConnections: json['close-connections'] as bool? ?? false,
      routingLease: json['routing-lease'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ChangeProxyParamsToJson(_ChangeProxyParams instance) =>
    <String, dynamic>{
      'group-name': instance.groupName,
      'proxy-name': instance.proxyName,
      'close-connections': instance.closeConnections,
      'routing-lease': ?instance.routingLease,
    };

_ChangeProxyResult _$ChangeProxyResultFromJson(Map<String, dynamic> json) =>
    _ChangeProxyResult(
      message: json['message'] as String? ?? '',
      changed: json['changed'] as bool? ?? false,
    );

Map<String, dynamic> _$ChangeProxyResultToJson(_ChangeProxyResult instance) =>
    <String, dynamic>{'message': instance.message, 'changed': instance.changed};

_RouteSnapshot _$RouteSnapshotFromJson(Map<String, dynamic> json) =>
    _RouteSnapshot(
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      picksVersion: (json['picks-version'] as num?)?.toInt() ?? 0,
      picks:
          (json['picks'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$RouteSnapshotToJson(_RouteSnapshot instance) =>
    <String, dynamic>{
      'core-epoch': instance.coreEpoch,
      'picks-version': instance.picksVersion,
      'picks': instance.picks,
    };

_CoreEvent _$CoreEventFromJson(Map<String, dynamic> json) => _CoreEvent(
  type: $enumDecode(_$CoreEventTypeEnumMap, json['type']),
  data: json['data'],
);

Map<String, dynamic> _$CoreEventToJson(_CoreEvent instance) =>
    <String, dynamic>{
      'type': _$CoreEventTypeEnumMap[instance.type]!,
      'data': instance.data,
    };

const _$CoreEventTypeEnumMap = {
  CoreEventType.log: 'log',
  CoreEventType.delay: 'delay',
  CoreEventType.request: 'request',
  CoreEventType.requestTraffic: 'requestTraffic',
  CoreEventType.dns: 'dns',
  CoreEventType.loaded: 'loaded',
  CoreEventType.crash: 'crash',
  CoreEventType.geoUpdate: 'geoUpdate',
  CoreEventType.routeChanged: 'routeChanged',
  CoreEventType.dialerLoop: 'dialerLoop',
};

_Delay _$DelayFromJson(Map<String, dynamic> json) => _Delay(
  name: json['name'] as String,
  url: json['url'] as String,
  value: (json['value'] as num?)?.toInt(),
);

Map<String, dynamic> _$DelayToJson(_Delay instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url,
  'value': instance.value,
};

_ProbeParams _$ProbeParamsFromJson(Map<String, dynamic> json) => _ProbeParams(
  automaticRouting: json['automatic-routing'] as bool?,
  url: json['url'] as String,
  proxyName: json['proxy-name'] as String? ?? '',
  headers:
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  timeout: (json['timeout'] as num).toInt(),
  maxBody: (json['max-body'] as num?)?.toInt() ?? 0,
  followRedirects: json['follow-redirects'] as bool?,
);

Map<String, dynamic> _$ProbeParamsToJson(_ProbeParams instance) =>
    <String, dynamic>{
      'automatic-routing': ?instance.automaticRouting,
      'url': instance.url,
      'proxy-name': instance.proxyName,
      'headers': instance.headers,
      'timeout': instance.timeout,
      'max-body': instance.maxBody,
      'follow-redirects': ?instance.followRedirects,
    };

_ProbeResult _$ProbeResultFromJson(Map<String, dynamic> json) => _ProbeResult(
  retryAfter: json['retry-after'] as String?,
  statusCode: (json['status-code'] as num?)?.toInt() ?? 0,
  delay: (json['delay'] as num?)?.toInt() ?? 0,
  body: json['body'] as String? ?? '',
  url: json['url'] as String? ?? '',
  chains:
      (json['chains'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  rule: json['rule'] as String? ?? '',
  rulePayload: json['rule-payload'] as String? ?? '',
  error: json['error'] as String?,
  message: json['message'] as String?,
);

Map<String, dynamic> _$ProbeResultToJson(_ProbeResult instance) =>
    <String, dynamic>{
      'retry-after': ?instance.retryAfter,
      'status-code': instance.statusCode,
      'delay': instance.delay,
      'body': instance.body,
      'url': instance.url,
      'chains': instance.chains,
      'rule': instance.rule,
      'rule-payload': instance.rulePayload,
      'error': instance.error,
      'message': instance.message,
    };

_OutboundIpParams _$OutboundIpParamsFromJson(Map<String, dynamic> json) =>
    _OutboundIpParams(
      proxyName: json['proxy-name'] as String? ?? '',
      urls:
          (json['urls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      timeout: (json['timeout'] as num).toInt(),
    );

Map<String, dynamic> _$OutboundIpParamsToJson(_OutboundIpParams instance) =>
    <String, dynamic>{
      'proxy-name': instance.proxyName,
      'urls': instance.urls,
      'timeout': instance.timeout,
    };

_OutboundIpResult _$OutboundIpResultFromJson(Map<String, dynamic> json) =>
    _OutboundIpResult(
      url: json['url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      chains:
          (json['chains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      error: json['error'] as String?,
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      picksVersion: (json['picks-version'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OutboundIpResultToJson(_OutboundIpResult instance) =>
    <String, dynamic>{
      'url': instance.url,
      'body': instance.body,
      'delay': instance.delay,
      'chains': instance.chains,
      'error': instance.error,
      'core-epoch': instance.coreEpoch,
      'picks-version': instance.picksVersion,
    };

_ServiceCheckParams _$ServiceCheckParamsFromJson(Map<String, dynamic> json) =>
    _ServiceCheckParams(
      proxyName: json['proxy-name'] as String? ?? '',
      names:
          (json['names'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      timeout: (json['timeout'] as num).toInt(),
    );

Map<String, dynamic> _$ServiceCheckParamsToJson(_ServiceCheckParams instance) =>
    <String, dynamic>{
      'proxy-name': instance.proxyName,
      'names': instance.names,
      'timeout': instance.timeout,
    };

_ServiceCheckItem _$ServiceCheckItemFromJson(Map<String, dynamic> json) =>
    _ServiceCheckItem(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      region: json['region'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      chains:
          (json['chains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      checkedAt: (json['checked-at'] as num?)?.toInt() ?? 0,
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      picksVersion: (json['picks-version'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ServiceCheckItemToJson(_ServiceCheckItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'status': instance.status,
      'region': instance.region,
      'delay': instance.delay,
      'chains': instance.chains,
      'checked-at': instance.checkedAt,
      'core-epoch': instance.coreEpoch,
      'picks-version': instance.picksVersion,
    };

_CoreMemoryStats _$CoreMemoryStatsFromJson(Map<String, dynamic> json) =>
    _CoreMemoryStats(
      rss: (json['rss'] as num?)?.toInt() ?? 0,
      heapInuse: (json['heapInuse'] as num?)?.toInt() ?? 0,
      heapIdle: (json['heapIdle'] as num?)?.toInt() ?? 0,
      stackInuse: (json['stackInuse'] as num?)?.toInt() ?? 0,
      runtimeOther: (json['runtimeOther'] as num?)?.toInt() ?? 0,
      footprint: (json['footprint'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CoreMemoryStatsToJson(_CoreMemoryStats instance) =>
    <String, dynamic>{
      'rss': instance.rss,
      'heapInuse': instance.heapInuse,
      'heapIdle': instance.heapIdle,
      'stackInuse': instance.stackInuse,
      'runtimeOther': instance.runtimeOther,
      'footprint': instance.footprint,
    };

_ExternalProvider _$ExternalProviderFromJson(Map<String, dynamic> json) =>
    _ExternalProvider(
      name: json['name'] as String,
      type: json['type'] as String,
      path: json['path'] as String?,
      count: (json['count'] as num).toInt(),
      subscriptionInfo: subscriptionInfoFormCore(
        json['subscription-info'] as Map<String, Object?>?,
      ),
      vehicleType: json['vehicle-type'] as String,
      updateAt: DateTime.parse(json['update-at'] as String),
    );

Map<String, dynamic> _$ExternalProviderToJson(_ExternalProvider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'path': instance.path,
      'count': instance.count,
      'subscription-info': instance.subscriptionInfo,
      'vehicle-type': instance.vehicleType,
      'update-at': instance.updateAt.toIso8601String(),
    };

_ProxiesData _$ProxiesDataFromJson(Map<String, dynamic> json) => _ProxiesData(
  proxies: json['proxies'] as Map<String, dynamic>,
  all: (json['all'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$ProxiesDataToJson(_ProxiesData instance) =>
    <String, dynamic>{'proxies': instance.proxies, 'all': instance.all};

import 'routing_regions.dart';
import 'smart_routing.dart';

const routingManifestKey = 'x-zolnit-routing';

const routingProviderProbeUrls = <String, String>{
  'chatgpt': 'https://chatgpt.com/',
  'openai_api': 'https://api.openai.com/v1/models',
  'claude': 'https://claude.ai/',
  'gemini_api': 'https://generativelanguage.googleapis.com/v1beta/models',
  'gemini_web': 'https://gemini.google.com/',
  'netflix': 'https://www.netflix.com/',
  'operator': 'https://www.gstatic.com/generate_204',
};

class ManagedRouteService {
  const ManagedRouteService({
    required this.route,
    required this.groupName,
    required this.manualGroup,
    required this.providers,
  });

  final SmartRouteService route;
  final String groupName;
  final String manualGroup;
  final Set<String> providers;

  Iterable<String> get probeUrls =>
      providers.map((provider) => routingProviderProbeUrls[provider]!);
}

class SmartRoutingManifest {
  const SmartRoutingManifest({
    required this.revision,
    required this.services,
    required this.nodes,
  });

  final String revision;
  final List<ManagedRouteService> services;
  final List<SmartRouteNode> nodes;

  static SmartRoutingManifest? parse(
    Object? value, {
    required Set<String> proxyNames,
    required Set<String> groupNames,
    Map<String, String> outboundFingerprints = const {},
  }) {
    if (value is! Map ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value['authority'] != 'zolnit' ||
        !_text(value['revision'])) {
      return null;
    }
    final rawServices = value['services'];
    final rawNodes = value['nodes'];
    if (rawServices is! List ||
        rawServices.isEmpty ||
        rawServices.length > 16 ||
        rawNodes is! List ||
        rawNodes.length > 4096) {
      return null;
    }
    final services = <ManagedRouteService>[];
    final serviceIds = <String>{};
    final names = <String>{};
    for (final raw in rawServices) {
      if (raw is! Map ||
          !_identity(raw['id']) ||
          !serviceIds.add(raw['id'] as String) ||
          !{'ai', 'media', 'general', 'domestic'}.contains(raw['kind']) ||
          !_text(raw['group']) ||
          !_text(raw['automatic']) ||
          !_text(raw['manual']) ||
          !groupNames.contains(raw['group'])) {
        return null;
      }
      for (final key in ['group', 'automatic', 'manual']) {
        final name = raw[key] as String;
        if (proxyNames.contains(name) ||
            _builtins.contains(name.toUpperCase()) ||
            !names.add(name)) {
          return null;
        }
        if (key != 'group' && groupNames.contains(name)) return null;
      }
      final providers = _strings(raw['providers']);
      final declared = _strings(raw['allowed_countries']);
      if (providers == null ||
          providers.isEmpty ||
          declared == null ||
          declared.isEmpty ||
          providers.any((p) => !routingProviderProbeUrls.containsKey(p)) ||
          declared.any((c) => !routingCountryCodes.contains(c))) {
        return null;
      }
      final isAi = raw['kind'] == 'ai';
      if (!isAi &&
          (raw['group'] == 'AI 服务' ||
              providers.any(routingAiProviders.contains))) {
        return null;
      }
      if (isAi && providers.any((p) => !routingAiProviders.contains(p))) {
        return null;
      }
      services.add(
        ManagedRouteService(
          route: SmartRouteService(
            id: raw['id'] as String,
            groupName: raw['automatic'] as String,
            isAi: isAi,
            allowedCountries: supportedRoutingCountries(
              providers,
              declared,
              isAi: isAi,
            ),
          ),
          groupName: raw['group'] as String,
          manualGroup: raw['manual'] as String,
          providers: Set.unmodifiable(providers),
        ),
      );
    }
    final ids = <String>{};
    final nodeNames = <String>{};
    final nodes = <SmartRouteNode>[];
    for (final raw in rawNodes) {
      if (raw is! Map) continue;
      final id = raw['id'];
      final name = raw['proxy_name'];
      if (!_identity(id) || !_text(name)) continue;
      if (!ids.add(id as String) || !nodeNames.add(name as String)) return null;
      final egress = raw['final_egress'];
      final allow = _strings(raw['services']);
      if (!proxyNames.contains(name) ||
          _builtins.contains(name.toUpperCase()) ||
          egress is! Map ||
          !routingCountryCodes.contains(egress['country']) ||
          !_allowedSources.contains(egress['source']) ||
          egress['verified'] != true ||
          !_identity(raw['failure_domain']) ||
          raw['enabled'] is! bool ||
          !_text(raw['revision']) ||
          allow == null ||
          allow.any((s) => !serviceIds.contains(s))) {
        continue;
      }
      final source = egress['source'] as String;
      final fingerprint = egress['configuration_fingerprint'];
      if (source == 'operator_allowlist' &&
          (fingerprint is! String ||
              _fingerprintPattern.firstMatch(fingerprint)?.group(0) !=
                  fingerprint ||
              outboundFingerprints[id] != fingerprint)) {
        continue;
      }
      nodes.add(
        SmartRouteNode(
          id: id,
          proxyName: name,
          countryCode: egress['country'] as String,
          failureDomain: raw['failure_domain'] as String,
          services: Set.unmodifiable(allow),
          enabled: raw['enabled'] as bool,
          verified: true,
          revision: raw['revision'] as String,
          qualificationSource: source,
          configurationFingerprint: source == 'operator_allowlist'
              ? fingerprint as String
              : null,
        ),
      );
    }
    return SmartRoutingManifest(
      revision: value['revision'] as String,
      services: List.unmodifiable(services),
      nodes: List.unmodifiable(nodes),
    );
  }

  static final _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');

  static const _allowedSources = {
    'operator_verified',
    'egress_probe',
    'operator_allowlist',
  };

  static const _builtins = {
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
  };

  static bool _text(Object? value) =>
      value is String &&
      value.trim() == value &&
      value.isNotEmpty &&
      value.length <= 256 &&
      !value.contains(RegExp(r'[\x00-\x1f\x7f]'));

  static bool _identity(Object? value) =>
      value is String &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$').hasMatch(value);

  static Set<String>? _strings(Object? value) {
    if (value is! List || value.any((item) => !_text(item))) return null;
    final result = value.cast<String>().toSet();
    return result.length == value.length ? result : null;
  }
}

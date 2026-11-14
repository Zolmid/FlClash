import 'dart:async';

import 'package:zolnit_client/zolnit_client.dart'
    show ClientFailure, XboardClient;

import 'package.dart';

enum IosDeviceUpdateResult { handedOff, cancelled, useWebsite, throttled }

typedef IosUpdateDevice = ({String id, String? product, String? osVersion});

final _deviceId = RegExp(r'^[a-f0-9]{32}$');
final _tag = RegExp(
  r'^v(?:0|[1-9]\d{0,9})\.(?:0|[1-9]\d{0,9})\.(?:0|[1-9]\d{0,9})$',
);
final _manifestPath = RegExp(
  r'^/api/v1/zolnit/client/apple/ota/[A-Za-z0-9_-]{43}/manifest\.plist$',
);

Map<String, dynamic> _object(Object? value) => value is Map<String, dynamic>
    ? value
    : throw const ClientFailure('invalid_response');

IosUpdateDevice _device(Object? value) {
  final data = _object(value);
  final id = data['device_id'];
  if (id is! String || !_deviceId.hasMatch(id)) {
    throw const ClientFailure('invalid_response');
  }
  String? label(Object? value) =>
      value is String && value.length <= 64 ? value : null;
  return (
    id: id,
    product: label(data['product']),
    osVersion: label(data['os_version']),
  );
}

Uri? _installUri(Object? value, Uri origin) {
  const prefix = 'itms-services://?action=download-manifest&url=';
  if (value is! String || value.length > 1024 || !value.startsWith(prefix)) {
    return null;
  }
  final encoded = value.substring(prefix.length);
  final String raw;
  try {
    raw = Uri.decodeComponent(encoded);
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
  final manifest = Uri.tryParse(raw);
  if (manifest == null ||
      manifest.scheme != 'https' ||
      manifest.origin != origin.origin ||
      manifest.userInfo.isNotEmpty ||
      manifest.hasQuery ||
      manifest.hasFragment ||
      !_manifestPath.hasMatch(manifest.path) ||
      raw != '${origin.origin}${manifest.path}' ||
      encoded != Uri.encodeComponent(raw)) {
    return null;
  }
  return Uri.tryParse(value);
}

class IosDeviceUpdater {
  IosDeviceUpdater({
    required this.api,
    required this.isCurrent,
    required this.realtimeHealthy,
    required this.selectDevice,
    required this.launch,
    this.canLaunch,
    this.maximumWait = const Duration(minutes: 12),
    this.fallbackInterval = const Duration(seconds: 15),
    this.liveCheckInterval = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _base = '/api/v1/zolnit/client/apple';
  final XboardClient api;
  final bool Function() isCurrent;
  final bool Function() realtimeHealthy;
  final Future<String?> Function(List<IosUpdateDevice>) selectDevice;
  final Future<bool> Function(Uri) launch;
  final bool Function()? canLaunch;
  final Duration maximumWait;
  final Duration fallbackInterval;
  final Duration liveCheckInterval;
  final DateTime Function() _now;
  Completer<void>? _wake;
  String? _id;
  String? _release;
  bool _cancelled = false;

  void notify(String type, Map<String, dynamic> data) {
    if (type == 'apple.archive.changed' && data['release_tag'] == _release ||
        type == 'apple.device.status' &&
            data['release_tag'] == _release &&
            data['device_id'] == _id) {
      wake();
    }
  }

  void wake() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  void cancel() {
    _cancelled = true;
    wake();
  }

  Future<IosDeviceUpdateResult> install({
    required String releaseTag,
    required String installedRelease,
    required int installedBuild,
  }) async {
    final generation = api.generation;
    bool current() =>
        !_cancelled && isCurrent() && api.generation == generation;
    Future<Map<String, dynamic>> request(
      String path, {
      Map<String, String>? query,
      Map<String, dynamic>? body,
    }) async {
      if (!current()) throw const ClientFailure('superseded');
      final result = await api.request(
        '$_base/$path',
        method: body == null ? 'GET' : 'POST',
        query: query,
        body: body,
      );
      if (!current()) throw const ClientFailure('superseded');
      return _object(result);
    }

    try {
      if (!_tag.hasMatch(releaseTag) ||
          compareVersions(releaseTag, installedRelease) <= 0 ||
          installedBuild < 1) {
        return IosDeviceUpdateResult.useWebsite;
      }
      _release = releaseTag;
      final binding = await request('devices/app-binding');
      final bound = binding['device'];
      if (bound != null) {
        _id = _device(bound).id;
      } else {
        final offered = binding['devices'];
        if (offered is! List || offered.length > 16 || offered.isEmpty) {
          return IosDeviceUpdateResult.useWebsite;
        }
        final choices = offered.map(_device).toList(growable: false);
        final choice = await selectDevice(choices);
        if (!current() || choice == null) {
          return IosDeviceUpdateResult.cancelled;
        }
        if (!choices.any((device) => device.id == choice)) {
          return IosDeviceUpdateResult.useWebsite;
        }
        final saved = await request(
          'devices/app-binding',
          body: {'device_id': choice},
        );
        if (_device(saved['device']).id != choice) {
          return IosDeviceUpdateResult.useWebsite;
        }
        _id = choice;
      }

      final path = 'devices/$_id';
      final start = _now();
      final releaseBody = {'release_tag': releaseTag};
      int? build;
      String? job;
      while (current() && _now().difference(start) < maximumWait) {
        final signal = _wake = Completer<void>();
        if (build == null) {
          final config = await request('config');
          if (config['latest_published_release_tag'] != releaseTag) {
            return IosDeviceUpdateResult.useWebsite;
          }
          final available = config['build'];
          if (config['release_tag'] == releaseTag &&
              config['archive_preparing'] == false &&
              available is int &&
              available > installedBuild &&
              config['latest_published_build'] == available) {
            final started = await request('$path/builds', body: releaseBody);
            if (started['device_id'] != _id ||
                started['release_tag'] != releaseTag ||
                started['build'] != available ||
                started['job_id'] is! String) {
              return IosDeviceUpdateResult.useWebsite;
            }
            build = available;
            job = started['job_id'] as String;
          }
        }

        if (build != null) {
          final live = api.liveReads;
          bool valid(Object? value) =>
              value is Map<String, dynamic> &&
              value['device_id'] == _id &&
              value['job_id'] == job &&
              value['release_tag'] == releaseTag &&
              value['build'] == build &&
              value['status'] is String;
          final projection = live?.supports('apple.device.status') == true
              ? (await live!.read('apple.device.status', {
                  ...releaseBody,
                  'device_id': _id,
                }, valid))?.result
              : null;
          final status =
              projection ?? await request('$path/status', query: releaseBody);
          if (!current()) return IosDeviceUpdateResult.cancelled;
          if (!valid(status)) return IosDeviceUpdateResult.useWebsite;
          final state = _object(status)['status'];
          if (state == 'ready' && (canLaunch?.call() ?? true)) {
            final ticket = await request(
              '$path/install-ticket',
              body: releaseBody,
            );
            final deadline = ticket['expires_at'];
            final uri = _installUri(ticket['itms_services_url'], api.origin);
            if (ticket['device_id'] != _id ||
                ticket['job_id'] != job ||
                ticket['release_tag'] != releaseTag ||
                ticket['build'] != build ||
                deadline is! int ||
                deadline <= _now().millisecondsSinceEpoch ~/ 1000 + 15 ||
                uri == null) {
              return IosDeviceUpdateResult.useWebsite;
            }
            if (!current()) return IosDeviceUpdateResult.cancelled;
            return await launch(uri)
                ? IosDeviceUpdateResult.handedOff
                : IosDeviceUpdateResult.useWebsite;
          }
          if (state != 'queued' && state != 'leased' && state != 'ready') {
            return IosDeviceUpdateResult.useWebsite;
          }
        }
        final remaining = maximumWait - _now().difference(start);
        if (remaining <= Duration.zero) break;
        final interval = realtimeHealthy()
            ? liveCheckInterval
            : fallbackInterval;
        final timer = Timer(remaining < interval ? remaining : interval, wake);
        try {
          await signal.future;
        } finally {
          timer.cancel();
        }
      }
      return current()
          ? IosDeviceUpdateResult.useWebsite
          : IosDeviceUpdateResult.cancelled;
    } on ClientFailure catch (error) {
      if (!current() || error.code == 'superseded') {
        return IosDeviceUpdateResult.cancelled;
      }
      if (error.statusCode == 429) {
        retryAt = _now().add(error.retryAfter ?? const Duration(minutes: 1));
      }
      return error.statusCode == 429
          ? IosDeviceUpdateResult.throttled
          : IosDeviceUpdateResult.useWebsite;
    } catch (_) {
      return current()
          ? IosDeviceUpdateResult.useWebsite
          : IosDeviceUpdateResult.cancelled;
    } finally {
      _wake = null;
      _id = _release = null;
    }
  }

  DateTime? retryAt;
}

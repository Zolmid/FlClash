import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/api.dart';
import 'package:zolnit_client/src/client_bundle.dart';

const _epoch = 1792800000;
final _now = DateTime.fromMillisecondsSinceEpoch(_epoch * 1000, isUtc: true);
const _document = 'proxies: []\n# reserved example.invalid fake document\n';

Json _fixture({bool emptyNodes = false}) =>
    jsonDecode(
          jsonEncode(<String, dynamic>{
            'schema_version': 1,
            'account_id': 'example-account',
            'bundle_id': 'example-bundle',
            'issued_at': _epoch - 10,
            'expires_at': _epoch + 290,
            'connection': {
              'engine': 'mihomo',
              'format': 'yaml',
              'sha256': sha256.convert(utf8.encode(_document)).toString(),
              'document': _document,
            },
            'outbounds': [
              {
                'id': 'example:1',
                'proxy_name': 'zn.node.example.1',
                'display_name': 'Example US',
              },
            ],
            'routing': {
              'version': 1,
              'authority': 'zolnit',
              'revision': 'example-v1',
              'services': [
                {
                  'id': 'ai',
                  'kind': 'ai',
                  'group': 'zn.service.ai',
                  'automatic': 'zn.service.ai.auto',
                  'manual': 'zn.service.ai.manual',
                  'providers': ['chatgpt'],
                  'allowed_countries': ['US'],
                },
              ],
              'nodes': [
                if (!emptyNodes)
                  {
                    'id': 'example:1',
                    'proxy_name': 'zn.node.example.1',
                    'exit_id': 'example-exit:1',
                    'final_egress': {
                      'country': 'US',
                      'source': 'operator_verified',
                      'verified': true,
                    },
                    'failure_domain': 'example-domain',
                    'services': ['ai'],
                    'enabled': true,
                    'revision': 'example-v1',
                  },
              ],
            },
          }),
        )
        as Json;

Json _routing(Json raw) => raw['routing'] as Json;
Json _node(Json raw) => (_routing(raw)['nodes'] as List).first as Json;
Json _service(Json raw) => (_routing(raw)['services'] as List).first as Json;
Json _outbound(Json raw) => (raw['outbounds'] as List).first as Json;
Json _connection(Json raw) => raw['connection'] as Json;

Matcher _failure(String code) => throwsA(
  isA<ClientFailure>()
      .having((error) => error.code, 'code', code)
      .having((error) => error.serverMessage, 'serverMessage', isNull)
      .having(
        (error) => error.toString(),
        'safe message',
        'ClientFailure($code)',
      ),
);

void _invalid(Json raw, {bool allowExpired = false}) {
  expect(
    () => ZolnitClientBundle.parse(raw, now: _now, allowExpired: allowExpired),
    _failure('invalid_client_bundle'),
  );
}

void main() {
  test('valid exact hash, maximum TTL and canonical data round trip', () {
    final raw = _fixture()..['unknown_envelope_field'] = 'discard';
    _connection(raw)['unknown_connection_field'] = 'discard';
    _outbound(raw)['unknown_outbound_field'] = 'discard';
    final bundle = ZolnitClientBundle.parse(
      raw,
      now: _now,
      expectedAccountId: 'example-account',
    );
    expect(bundle.accountId, 'example-account');
    expect(bundle.bundleId, 'example-bundle');
    expect(bundle.document == _document, isTrue);
    expect(bundle.connectionSha256, _connection(raw)['sha256']);
    expect(bundle.issuedAt.isUtc, isTrue);
    expect(bundle.expiresAt.isUtc, isTrue);
    expect(bundle.expiresAt.difference(bundle.issuedAt).inSeconds, 300);
    expect(bundle.isFresh(_now), isTrue);
    expect(bundle.isFresh(bundle.issuedAt), isTrue);
    expect(bundle.isFresh(bundle.expiresAt), isFalse);
    expect(
      bundle.isFresh(bundle.issuedAt.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(bundle.outbounds.single.id, 'example:1');
    expect(bundle.outbounds.single.proxyName, 'zn.node.example.1');
    expect(bundle.outbounds.single.displayName, 'Example US');
    expect(bundle.routingManifest.nodes.single.id, 'example:1');
    expect(bundle.exitIds, {'example:1': 'example-exit:1'});
    final encoded = bundle.toJson();
    expect(encoded, _fixture());
    expect(encoded.containsKey('data'), isFalse);
    final decoded = jsonDecode(jsonEncode(encoded)) as Json;
    expect(ZolnitClientBundle.parse(decoded, now: _now).toJson(), encoded);
    expect(bundle.toString().contains(_document), isFalse);
  });

  test('empty routing candidates remain valid with declared services', () {
    final bundle = ZolnitClientBundle.parse(
      _fixture(emptyNodes: true),
      now: _now,
    );
    expect(bundle.routingManifest.nodes, isEmpty);
    expect(bundle.routingManifest.services, hasLength(1));
    expect(bundle.exitIds, isEmpty);
  });

  test('expiry is strict including subsecond now and allowExpired', () {
    final raw = _fixture()..['expires_at'] = _epoch;
    expect(
      () => ZolnitClientBundle.parse(raw, now: _now),
      _failure('client_bundle_expired'),
    );
    final bundle = ZolnitClientBundle.parse(raw, now: _now, allowExpired: true);
    expect(bundle.isFresh(_now), isFalse);
    final fresh = _fixture();
    final expiry = DateTime.fromMillisecondsSinceEpoch((_epoch + 290) * 1000);
    expect(
      ZolnitClientBundle.parse(
        fresh,
        now: expiry.subtract(const Duration(microseconds: 1)),
      ).isFresh(expiry),
      isFalse,
    );
    expect(
      () => ZolnitClientBundle.parse(
        fresh,
        now: expiry.add(const Duration(microseconds: 1)),
      ),
      _failure('client_bundle_expired'),
    );
  });

  test('account binding is exact even when expiration is allowed', () {
    for (final expected in [
      'Example-account',
      'example-account ',
      'other',
      '',
    ]) {
      expect(
        () => ZolnitClientBundle.parse(
          _fixture(),
          now: _now,
          expectedAccountId: expected,
          allowExpired: true,
        ),
        _failure('client_bundle_binding_mismatch'),
      );
    }
  });

  test('types, version, timestamps, future issuance and TTL fail closed', () {
    for (final field in ['schema_version', 'issued_at', 'expires_at']) {
      final valid = _fixture()[field] as int;
      for (final value in [valid.toDouble(), '$valid', null, true]) {
        _invalid(_fixture()..[field] = value, allowExpired: true);
      }
    }
    for (final patch in <Json>[
      {'schema_version': 2},
      {'issued_at': _epoch + 1},
      {'issued_at': _epoch, 'expires_at': _epoch},
      {'expires_at': _epoch - 11},
      {'expires_at': _epoch + 291},
      {'issued_at': 8640000000001},
      {'issued_at': -8640000000001},
    ]) {
      _invalid(_fixture()..addAll(patch), allowExpired: true);
    }
  });

  test('identity and label text are nonempty bounded and control free', () {
    for (final value in [
      '',
      ' padded',
      'padded ',
      'bad\nlabel',
      'bad\u007f',
      List.filled(257, 'a').join(),
      null,
      1,
    ]) {
      for (final field in ['account_id', 'bundle_id']) {
        _invalid(_fixture()..[field] = value);
      }
      final raw = _fixture();
      _outbound(raw)['display_name'] = value;
      _invalid(raw);
    }
    final raw = _fixture();
    _outbound(raw)['display_name'] = '示例 US';
    expect(ZolnitClientBundle.parse(raw, now: _now).outbounds, hasLength(1));
  });

  test('digest checks exact UTF8 including trailing newline and BOM', () {
    for (final document in [
      _document.trimRight(),
      '$_document\n',
      '\ufeff$_document',
      _document.replaceAll('\n', '\r\n'),
      '',
      null,
    ]) {
      final raw = _fixture();
      _connection(raw)['document'] = document;
      _invalid(raw, allowExpired: true);
    }
    for (final field in ['engine', 'format', 'sha256']) {
      final raw = _fixture();
      _connection(raw)[field] = 'invalid';
      _invalid(raw);
    }
    final upper = _fixture();
    _connection(upper)['sha256'] = (_connection(upper)['sha256'] as String)
        .toUpperCase();
    _invalid(upper);
    final unicode = _fixture();
    const document = '\ufeff# 示例 example.invalid\r\n';
    _connection(unicode).addAll({
      'document': document,
      'sha256': sha256.convert(utf8.encode(document)).toString(),
    });
    expect(
      ZolnitClientBundle.parse(unicode, now: _now).document == document,
      isTrue,
    );
  });

  test('outbound identities, exact names, duplicates and list bounds', () {
    for (final id in [
      'Example:1',
      'example:0',
      'example:01',
      'example',
      'example:1\n',
    ]) {
      final raw = _fixture();
      _outbound(raw)['id'] = id;
      _invalid(raw);
    }
    final mismatch = _fixture();
    _outbound(mismatch)['proxy_name'] = 'display alias';
    _invalid(mismatch);
    final duplicate = _fixture();
    (duplicate['outbounds'] as List).add({..._outbound(duplicate)});
    _invalid(duplicate);
    for (final value in [null, {}, [], List.filled(4097, {})]) {
      _invalid(_fixture()..['outbounds'] = value);
    }
  });

  test('unknown routing nodes, name mismatch and duplicate nodes reject', () {
    for (final patch in <Json>[
      {'id': 'unknown:2'},
      {'proxy_name': 'zn.node.other.1'},
      {'id': 'unknown:2', 'proxy_name': 'zn.node.example.1'},
    ]) {
      final raw = _fixture();
      _node(raw).addAll(patch);
      _invalid(raw);
    }
    final raw = _fixture();
    (_routing(raw)['nodes'] as List).add({..._node(raw)});
    _invalid(raw);
  });

  test(
    'routing is a subset and rejects identities the shared parser drops',
    () {
      final subset = _fixture();
      (subset['outbounds'] as List).add({
        'id': 'example:2',
        'proxy_name': 'zn.node.example.2',
        'display_name': 'Example spare',
      });
      final bundle = ZolnitClientBundle.parse(subset, now: _now);
      expect(bundle.outbounds, hasLength(2));
      expect(bundle.routingManifest.nodes, hasLength(1));
      final oversized = _fixture();
      final id = '${List.filled(127, 'a').join()}:1';
      final proxyName = 'zn.node.${id.replaceFirst(':', '.')}';
      _outbound(oversized).addAll({'id': id, 'proxy_name': proxyName});
      _node(oversized).addAll({'id': id, 'proxy_name': proxyName});
      _invalid(oversized);
    },
  );

  test('exit identity is required and preserves valid punctuation', () {
    for (final exit in [
      null,
      '',
      'bad exit',
      '-bad',
      'bad\n',
      List.filled(129, 'a').join(),
      1,
    ]) {
      final raw = _fixture();
      _node(raw)['exit_id'] = exit;
      _invalid(raw);
    }
    final raw = _fixture();
    _node(raw).remove('exit_id');
    _invalid(raw);
    _node(raw)['exit_id'] = 'US:example.exit_1-v2';
    expect(
      ZolnitClientBundle.parse(raw, now: _now).exitIds['example:1'],
      'US:example.exit_1-v2',
    );
  });

  test('every routing node must survive the shared parser', () {
    for (final field in [
      'final_egress',
      'failure_domain',
      'services',
      'enabled',
      'revision',
    ]) {
      final raw = _fixture();
      _node(raw).remove(field);
      _invalid(raw);
    }
    for (final patch in <Json>[
      {'failure_domain': 'bad domain'},
      {'enabled': 'true'},
      {'revision': List.filled(257, 'r').join()},
      {
        'services': ['unknown'],
      },
      {
        'services': ['ai', 'ai'],
      },
      {
        'final_egress': {
          'country': 'US',
          'verified': false,
          'source': 'operator_verified',
        },
      },
      {
        'final_egress': {
          'country': 'ZZ',
          'verified': true,
          'source': 'operator_verified',
        },
      },
      {
        'final_egress': {
          'country': 'US',
          'verified': true,
          'source': 'untrusted',
        },
      },
    ]) {
      final raw = _fixture();
      _node(raw).addAll(patch);
      _invalid(raw, allowExpired: true);
    }
  });

  test(
    'routing version authority services bounds and Core IDs are enforced',
    () {
      for (final patch in <Json>[
        {'version': 1.0},
        {'authority': 'other'},
        {'revision': ''},
        {'services': []},
        {'services': List.filled(17, {})},
        {'nodes': List.filled(4097, {})},
      ]) {
        final raw = _fixture();
        _routing(raw).addAll(patch);
        _invalid(raw);
      }
      for (final field in ['group', 'automatic', 'manual']) {
        final raw = _fixture();
        _service(raw)[field] = 'legacy-alias';
        _invalid(raw);
      }
      final raw = _fixture();
      _service(raw)['providers'] = ['operator'];
      _invalid(raw);
    },
  );

  test('containers are deeply immutable and detached from caller input', () {
    final raw = _fixture();
    final bundle = ZolnitClientBundle.parse(raw, now: _now);
    final canonical = bundle.toJson();
    for (final mutation in <void Function()>[
      () => bundle.outbounds.clear(),
      () => bundle.exitIds.clear(),
      () => bundle.routingJson.clear(),
      () => (bundle.routingJson['nodes'] as List).clear(),
      () => ((bundle.routingJson['nodes'] as List).first as Map).clear(),
      () =>
          (((bundle.routingJson['nodes'] as List).first as Map)['final_egress']
                  as Map)
              .clear(),
      () =>
          (((bundle.routingJson['services'] as List).first as Map)['providers']
                  as List)
              .clear(),
      () => bundle.routingManifest.nodes.clear(),
      () => bundle.routingManifest.services.clear(),
      () => bundle.routingManifest.nodes.single.services.clear(),
      () => bundle.routingManifest.services.single.providers.clear(),
      () =>
          bundle.routingManifest.services.single.route.allowedCountries.clear(),
      () => canonical.clear(),
      () => (canonical['connection'] as Map).clear(),
      () => (canonical['outbounds'] as List).clear(),
      () => ((canonical['outbounds'] as List).first as Map).clear(),
    ]) {
      expect(mutation, throwsUnsupportedError);
    }
    _node(raw)['exit_id'] = 'changed';
    _service(raw)['providers'] = ['claude'];
    _outbound(raw)['display_name'] = 'changed';
    expect(bundle.exitIds['example:1'], 'example-exit:1');
    expect(
      (bundle.routingJson['nodes'] as List).first['exit_id'],
      'example-exit:1',
    );
    expect(bundle.outbounds.single.displayName, 'Example US');
    expect(bundle.routingManifest.services.single.providers, {'chatgpt'});
  });

  test('invalid errors reveal neither document nor arbitrary input', () {
    final raw = _fixture();
    _connection(raw)['document'] = '# example.invalid sensitive marker';
    _invalid(raw);
    raw['account_id'] = 'example.invalid\nprivate marker';
    _invalid(raw);
  });
}

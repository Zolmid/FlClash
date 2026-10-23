import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zolnit_client/zolnit_client.dart';

final zolnitSessionVaultProvider = Provider<ZolnitSessionVault>(
  (ref) => SecureZolnitSessionVault(),
);

class SecureZolnitSessionVault implements ZolnitSessionVault {
  SecureZolnitSessionVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _key = 'zolnit.session.authorization.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<void> deleteAuthorization() => _storage.delete(key: _key);

  @override
  Future<String?> readAuthorization() => _storage.read(key: _key);

  @override
  Future<void> writeAuthorization(String authorization) =>
      _storage.write(key: _key, value: authorization);
}

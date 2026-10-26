import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zolnit_client/zolnit_client.dart';
import 'zolnit_native_renewal.dart';

final zolnitSessionVaultProvider = Provider<ZolnitSessionVault>((ref) {
  final native = ref.read(zolnitNativeRenewalClientProvider);
  return SecureZolnitSessionVault(
    storage: ref.read(zolnitSecureStorageProvider),
    beforeDelete: native.logout,
    allowsRestore: native.allowsRestoration,
  );
});

class SecureZolnitSessionVault implements ZolnitSessionVault {
  SecureZolnitSessionVault({
    FlutterSecureStorage? storage,
    this.beforeDelete,
    this.allowsRestore,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           );

  static const _key = 'zolnit.session.authorization.v1';
  final FlutterSecureStorage _storage;
  final Future<void> Function()? beforeDelete;
  final Future<bool> Function(String authorization)? allowsRestore;

  @override
  Future<void> deleteAuthorization() async {
    await beforeDelete?.call();
    await _storage.delete(key: _key);
  }

  @override
  Future<String?> readAuthorization() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final allowed = await allowsRestore?.call(value) ?? true;
    return allowed ? value : null;
  }

  @override
  Future<void> writeAuthorization(String authorization) =>
      _storage.write(key: _key, value: authorization);
}

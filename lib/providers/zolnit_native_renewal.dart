import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/common/zolnit_native_renewal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final zolnitSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  ),
);

final zolnitNativeRenewalSupportedProvider = Provider<bool>(
  (ref) => system.isAndroid || system.isIOS,
);

final zolnitNativeRenewalClientProvider = Provider<ZolnitNativeRenewalClient>((
  ref,
) {
  final client = ZolnitNativeRenewalClient(
    journal: _SecureRenewalJournal(ref.read(zolnitSecureStorageProvider)),
  );
  ref.onDispose(client.dispose);
  return client;
});

class _SecureRenewalJournal implements ZolnitRenewalJournal {
  _SecureRenewalJournal(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'zolnit.renewal.journal.v1';

  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String value) => storage.write(key: _key, value: value);
  @override
  Future<void> clear() => storage.delete(key: _key);
}

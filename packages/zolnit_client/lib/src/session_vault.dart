abstract interface class ZolnitSessionVault {
  Future<String?> readAuthorization();

  Future<void> writeAuthorization(String authorization);

  Future<void> deleteAuthorization();
}

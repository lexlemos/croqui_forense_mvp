abstract class KeyStorageInterface {
  Future<void> save({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}
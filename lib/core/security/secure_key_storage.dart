
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';

class SecureKeyStorage implements IKeyStorage {
  final FlutterSecureStorage _storage;

  const SecureKeyStorage({FlutterSecureStorage? storage}) 
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
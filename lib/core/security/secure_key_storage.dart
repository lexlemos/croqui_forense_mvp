import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';

class SecureKeyStorage implements KeyStorageInterface {
  final FlutterSecureStorage _storage;

  SecureKeyStorage({FlutterSecureStorage? storage}) 
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> save({required String key, required String value}) => 
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
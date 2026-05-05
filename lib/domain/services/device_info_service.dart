import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoService {
  static const String _key = 'device_unique_id';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? stored = await _storage.read(key: _key);
    if (stored == null || stored.isEmpty) {
      stored = const Uuid().v4();
      await _storage.write(key: _key, value: stored);
    }
    _cachedDeviceId = stored;
    return stored;
  }
}

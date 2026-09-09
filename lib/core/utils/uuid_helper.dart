import 'package:uuid/uuid.dart';

/// Gera um UUID determinístico com a mesma representação V4 usada pelo app.
String deterministicUuidV4(String namespace, String name) {
  final uuidV5 = const Uuid().v5(namespace, name);
  return '${uuidV5.substring(0, 14)}4${uuidV5.substring(15, 19)}a${uuidV5.substring(20)}';
}

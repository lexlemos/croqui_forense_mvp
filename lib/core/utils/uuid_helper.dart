import 'package:uuid/uuid.dart';

/// Gera um UUID determinístico com a mesma representação V4 usada pelo app.
String deterministicUuidV4(String namespace, String name) {
  final cleanNs = namespace.trim().toLowerCase();
  final cleanName = name.trim();
  if (cleanNs.isEmpty || cleanName.isEmpty) return '';

  try {
    final uuidV5 = const Uuid().v5(cleanNs, cleanName);
    return '${uuidV5.substring(0, 14)}4${uuidV5.substring(15, 19)}a${uuidV5.substring(20)}';
  } catch (_) {
    return '';
  }
}

/// Gera um UUIDv5 determinístico puro usando Uuid.NAMESPACE_URL.
String deterministicUuidV5(String sourceUuid, String namespaceName) {
  const uuid = Uuid();
  try {
    return uuid.v5(
      Uuid.NAMESPACE_URL,
      '${sourceUuid.trim().toLowerCase()}-${namespaceName.trim().toLowerCase()}',
    );
  } catch (e) {
    return uuid.v4(); // Fallback seguro
  }
}


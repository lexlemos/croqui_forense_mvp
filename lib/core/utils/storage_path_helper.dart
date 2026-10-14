import 'dart:io';

/// Utilitário puro de domínio encarregado da discriminação e validação semântica
/// de identificadores de armazenamento (chaves de bucket MinIO/S3 e URLs assinadas)
/// versus caminhos de arquivos físicos locais gravados no disco do dispositivo.
///
/// Protege a **Invariante 3**: assegura que referências remotas nunca poluam
/// a coluna de arquivos locais do SQLite para não disparar expurgo acidental pelo GC.
class StoragePathHelper {
  /// Determina se [pathOrUrl] corresponde a uma URL HTTP/HTTPS ou a uma chave de storage no bucket.
  static bool isRemoteKeyOrUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return false;
    final trimmed = pathOrUrl.trim();

    // 1. URLs remotas explícitas
    if (isHttpUrl(trimmed)) {
      return true;
    }

    // 2. Chaves de objeto de bucket (ex: "2026/10/caso/foto.jpg" ou identificadores UUID de objeto)
    // No Windows, caminhos locais contêm "\\" ou letra de drive "C:\". No Linux/Android, começam com "/data" ou "/storage".
    if (Platform.isWindows) {
      final isWindowsLocal =
          trimmed.contains('\\') || RegExp(r'^[a-zA-Z]:').hasMatch(trimmed);
      return !isWindowsLocal;
    } else {
      final isUnixLocal =
          trimmed.startsWith('/data/') ||
          trimmed.startsWith('/storage/') ||
          trimmed.startsWith('/data_mirror/') ||
          trimmed.startsWith('/mnt/') ||
          trimmed.startsWith('/sdcard/');
      return !isUnixLocal;
    }
  }

  /// Determina se [pathOrUrl] corresponde a um caminho de arquivo físico local existente no sistema de arquivos.
  static bool isLocalFilePath(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return false;
    return !isRemoteKeyOrUrl(pathOrUrl);
  }

  /// Determina se [pathOrUrl] é uma URL HTTP ou HTTPS.
  static bool isHttpUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return false;
    final trimmed = pathOrUrl.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }
}

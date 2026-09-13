import 'dart:io';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';

class ImageResolver {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.15.88:8000/api/v1/',
  );

  static String get _serverBaseUrl {
    var url = _defaultBaseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - 7);
    }
    return url;
  }

  /// Constrói um Widget de Imagem inteligente tratando arquivos locais reais,
  /// vazamentos de caminhos locais de outros dispositivos, URLs relativas e URLs remotas,
  /// anexando automaticamente o Token Bearer JWT em requisições de rede.
  static Widget buildImage(
    String? path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    debugPrint('[ImageResolver] Tentando carregar imagem: $path');

    if (path == null || path.trim().isEmpty) {
      return errorWidget ?? _buildDefaultError(width, height);
    }

    final trimmedPath = path.trim();

    // Cenário A: Arquivo Local Real (O arquivo existe no sistema de arquivos do dispositivo)
    final isAbsoluteLocalPath = trimmedPath.startsWith('/data/user/') ||
        trimmedPath.startsWith('/data/data/') ||
        trimmedPath.startsWith('/storage/') ||
        trimmedPath.startsWith('file://') ||
        RegExp(r'^[a-zA-Z]:\\').hasMatch(trimmedPath);

    if (isAbsoluteLocalPath) {
      final cleanLocalPath = trimmedPath.replaceFirst('file://', '');
      final localFile = File(cleanLocalPath);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: 400,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? _buildDefaultError(width, height),
        );
      }
    }

    // Cenário B: URL Completa, URL Relativa ou Path Local Vazado de outro dispositivo
    final fullUrl = _resolveFullUrl(trimmedPath);
    debugPrint('[ImageResolver] URL remota resolvida: $fullUrl');

    return FutureBuilder<String?>(
      future: SecureKeyStorage().read(key: 'access_token'),
      builder: (context, snapshot) {
        final token = snapshot.data;
        final headers = (token != null && token.isNotEmpty)
            ? {'Authorization': 'Bearer $token'}
            : <String, String>{};

        return Image.network(
          fullUrl,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: 400,
          headers: headers,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[ImageResolver] ❌ Erro ao carregar imagem via rede: $fullUrl | Error: $error');
            return errorWidget ?? _buildDefaultError(width, height);
          },
        );
      },
    );
  }

  static String _resolveFullUrl(String inputPath) {
    if (inputPath.startsWith('http://') || inputPath.startsWith('https://')) {
      return inputPath;
    }

    final serverBase = _serverBaseUrl;

    final isAbsoluteLocalPath = inputPath.startsWith('/data/user/') ||
        inputPath.startsWith('/data/data/') ||
        inputPath.startsWith('/storage/') ||
        inputPath.startsWith('file://') ||
        RegExp(r'^[a-zA-Z]:\\').hasMatch(inputPath);

    if (isAbsoluteLocalPath) {
      // Path leakage de outro dispositivo: tentar fallback pelo nome simples do arquivo
      final fileName = inputPath.split('/').last.split('\\').last;
      return _joinUrl(serverBase, 'media/$fileName');
    }

    if (inputPath.startsWith('/media/')) {
      return _joinUrl(serverBase, inputPath);
    }
    if (inputPath.startsWith('media/')) {
      return _joinUrl(serverBase, inputPath);
    }

    if (inputPath.startsWith('/')) {
      return _joinUrl(serverBase, inputPath);
    }

    // Caminho relativo preservando estrutura de subpastas (ex: evidencias_multimidia/casos/123/foto.jpg)
    return _joinUrl(serverBase, 'media/$inputPath');
  }

  static String _joinUrl(String base, String relativePath) {
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanRelative = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    return '$cleanBase/$cleanRelative';
  }

  static Widget _buildDefaultError(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
      ),
    );
  }
}

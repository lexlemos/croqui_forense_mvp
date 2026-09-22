import 'dart:io';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

/// Utilitário central de resolução e renderização de imagens no aplicativo.
///
/// Trata arquivos locais no dispositivo, caminhos remotos públicos ou via Signed URL,
/// e realiza o cruzamento de [Achado] com sua respectiva [EvidenciaMultimidia]
/// para garantir que requisições de rede utilizem o UUID oficial cadastrado no backend.
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

  /// Constrói um Widget de imagem com suporte a arquivo local físico,
  /// rota proxy remota `/media/{evidenciaUuid}.jpg` ou caminhos relativos/legados.
  static Widget buildImage(
    String? path, {
    String? evidenciaUuid,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    debugPrint(
      '[ImageResolver] Tentando carregar imagem: $path (evidenciaUuid: $evidenciaUuid)',
    );

    if ((path == null || path.trim().isEmpty) &&
        (evidenciaUuid == null || evidenciaUuid.trim().isEmpty)) {
      return errorWidget ?? _buildDefaultError(width, height);
    }

    final trimmedPath = path?.trim() ?? '';

    if (trimmedPath.isNotEmpty) {
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
    }

    final fullUrl = (evidenciaUuid != null && evidenciaUuid.trim().isNotEmpty)
        ? _joinUrl(_serverBaseUrl, 'media/${evidenciaUuid.trim()}.jpg')
        : _resolveFullUrl(trimmedPath);

    debugPrint('[ImageResolver] URL remota resolvida: $fullUrl');

    return Image.network(
      fullUrl,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: 400,
      headers: const <String, String>{},
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[ImageResolver] ❌ Erro ao carregar imagem via rede: $fullUrl | Error: $error',
        );
        return errorWidget ?? _buildDefaultError(width, height);
      },
    );
  }

  /// Resolve e constrói a imagem para um [Achado], priorizando a [EvidenciaMultimidia] oficial
  /// vinculada ao [achado.uuid], com verificação de integridade de arquivo local e
  /// fallback seguro para a rota remota `/media/{evidencia.uuid}.jpg` ou photo_path legado.
  static Widget buildAchadoImage({
    required Achado achado,
    List<EvidenciaMultimidia>? evidencias,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    EvidenciaMultimidia? evidencia;
    if (evidencias != null && evidencias.isNotEmpty) {
      try {
        evidencia = evidencias.firstWhere(
          (ev) => ev.achadoUuid == achado.uuid && !ev.removido,
        );
      } catch (_) {
        evidencia = null;
      }
    }

    if (evidencia != null) {
      final localPath = evidencia.caminhoArquivoEncriptado;
      if (localPath != null && localPath.trim().isNotEmpty) {
        final cleanPath = localPath.trim().replaceFirst('file://', '');
        final file = File(cleanPath);
        if (file.existsSync()) {
          return buildImage(
            cleanPath,
            evidenciaUuid: evidencia.uuid,
            fit: fit,
            width: width,
            height: height,
            errorWidget: errorWidget,
          );
        }
      }

      return buildImage(
        null,
        evidenciaUuid: evidencia.uuid,
        fit: fit,
        width: width,
        height: height,
        errorWidget: errorWidget,
      );
    }

    if (evidencias == null) {
      return FutureBuilder<Map<String, String>?>(
        future: _buscarEvidenciaNoBanco(achado.uuid),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data != null && data['uuid'] != null && data['uuid']!.isNotEmpty) {
            final localPath = data['caminho'];
            if (localPath != null && localPath.trim().isNotEmpty) {
              final cleanPath = localPath.trim().replaceFirst('file://', '');
              if (File(cleanPath).existsSync()) {
                return buildImage(
                  cleanPath,
                  evidenciaUuid: data['uuid'],
                  fit: fit,
                  width: width,
                  height: height,
                  errorWidget: errorWidget,
                );
              }
            }
            return buildImage(
              null,
              evidenciaUuid: data['uuid'],
              fit: fit,
              width: width,
              height: height,
              errorWidget: errorWidget,
            );
          }

          final fallbackPath = achado.photoPath;
          return buildImage(
            fallbackPath,
            fit: fit,
            width: width,
            height: height,
            errorWidget: errorWidget,
          );
        },
      );
    }

    final fallbackPath = achado.photoPath;
    return buildImage(
      fallbackPath,
      fit: fit,
      width: width,
      height: height,
      errorWidget: errorWidget,
    );
  }

  static Future<Map<String, String>?> _buscarEvidenciaNoBanco(
    String achadoUuid,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'evidencias_multimidia',
        columns: ['uuid', 'caminho_arquivo_encriptado'],
        where: 'achado_uuid = ? AND removido = 0',
        whereArgs: [achadoUuid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return {
          'uuid': rows.first['uuid']?.toString() ?? '',
          'caminho': rows.first['caminho_arquivo_encriptado']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('[ImageResolver] Falha ao consultar evidência no SQLite: $e');
    }
    return null;
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

    return _joinUrl(serverBase, 'media/$inputPath');
  }

  static String _joinUrl(String base, String relativePath) {
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanRelative = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
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

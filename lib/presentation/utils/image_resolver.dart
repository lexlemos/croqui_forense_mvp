import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

/// Utilitário central de resolução e renderização de imagens no aplicativo.
///
/// Trata arquivos locais no dispositivo, caminhos remotos públicos ou via Signed URL,
/// e realiza o cruzamento de [Achado] com sua respectiva [EvidenciaMultimidia]
/// para garantir que requisições de rede utilizem o UUID oficial cadastrado no backend.
class ImageResolver {
  static String get _defaultBaseUrl =>
      dotenv.env['API_BASE_URL'] ??
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://cadeia-de-custodia-iml-back.vercel.app/api/v1/',
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
      final isAbsoluteLocalPath =
          trimmedPath.startsWith('/data/user/') ||
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
  /// Seleciona a melhor evidência disponível para um achado na coleção fornecida.
  ///
  /// Regras de Prioridade (Strict Offline-First & Resiliência Pós-Reinstalação):
  /// 1. Evidência com arquivo físico local que de fato existe em disco (`File.existsSync()`).
  /// 2. Evidência que possui caminho de arquivo / chave de storage ou URL válida preenchida,
  ///    selecionando a mais recente (`versao DESC`, `criadoEm DESC`).
  /// 3. Se nenhuma possuir caminho gravado, seleciona a evidência mais recente por segurança.
  static EvidenciaMultimidia? selecionarMelhorEvidenciaParaAchado(
    String achadoUuid,
    List<EvidenciaMultimidia> evidencias,
  ) {
    final candidatas = evidencias
        .where((ev) => ev.achadoUuid == achadoUuid && !ev.removido)
        .toList();
    if (candidatas.isEmpty) return null;

    // 1. Prioriza arquivo local físico que exista no sistema de arquivos
    for (final ev in candidatas) {
      final localPath = ev.caminhoArquivoEncriptado;
      if (localPath != null && localPath.trim().isNotEmpty) {
        final cleanPath = localPath.trim().replaceFirst('file://', '');
        if (File(cleanPath).existsSync()) {
          return ev;
        }
      }
    }

    // 2. Prioriza evidências com chave remota / storage válida (cenário de pós-reinstalação)
    final comArquivo = candidatas.where((ev) {
      final p = ev.caminhoArquivoEncriptado?.trim();
      final c = ev.chaveStorage?.trim();
      final u = ev.urlStorage?.trim();
      return (p != null && p.isNotEmpty) ||
          (c != null && c.isNotEmpty) ||
          (u != null && u.isNotEmpty);
    }).toList();

    if (comArquivo.isNotEmpty) {
      comArquivo.sort((a, b) {
        final compVersao = b.versao.compareTo(a.versao);
        if (compVersao != 0) return compVersao;
        return b.criadoEm.compareTo(a.criadoEm);
      });
      return comArquivo.first;
    }

    // 3. Fallback: seleciona a evidência mais recente
    candidatas.sort((a, b) {
      final compVersao = b.versao.compareTo(a.versao);
      if (compVersao != 0) return compVersao;
      return b.criadoEm.compareTo(a.criadoEm);
    });
    return candidatas.first;
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
      evidencia = selecionarMelhorEvidenciaParaAchado(achado.uuid, evidencias);
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
        evidencia.urlStorage ?? evidencia.caminhoArquivoEncriptado,
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
          if (data != null &&
              data['uuid'] != null &&
              data['uuid']!.isNotEmpty) {
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
              localPath,
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
        columns: [
          'uuid',
          'caminho_arquivo_encriptado',
          'chave_storage',
          'url_storage',
          'versao',
          'criado_em',
        ],
        where: 'achado_uuid = ? AND removido = 0',
        whereArgs: [achadoUuid],
        orderBy: 'versao DESC, criado_em DESC',
      );
      if (rows.isNotEmpty) {
        // 1. Procura arquivo local que de fato exista no disco
        for (final r in rows) {
          final localPath = r['caminho_arquivo_encriptado']?.toString();
          if (localPath != null && localPath.trim().isNotEmpty) {
            final cleanPath = localPath.trim().replaceFirst('file://', '');
            if (File(cleanPath).existsSync()) {
              return {
                'uuid': r['uuid']?.toString() ?? '',
                'caminho': cleanPath,
              };
            }
          }
        }

        // 2. Prioriza registros com caminho remoto / storage preenchido
        final comArquivo = rows.where((r) {
          final p = r['caminho_arquivo_encriptado']?.toString().trim();
          final c = r['chave_storage']?.toString().trim();
          final u = r['url_storage']?.toString().trim();
          return (p != null && p.isNotEmpty) ||
              (c != null && c.isNotEmpty) ||
              (u != null && u.isNotEmpty);
        }).toList();

        final escolhida = comArquivo.isNotEmpty ? comArquivo.first : rows.first;
        final caminhoEscolhido =
            escolhida['url_storage']?.toString() ??
            escolhida['caminho_arquivo_encriptado']?.toString() ??
            escolhida['chave_storage']?.toString() ??
            '';

        return {
          'uuid': escolhida['uuid']?.toString() ?? '',
          'caminho': caminhoEscolhido,
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

    final isAbsoluteLocalPath =
        inputPath.startsWith('/data/user/') ||
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
    final cleanBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
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

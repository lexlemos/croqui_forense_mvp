import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

/// Contrato do módulo profundo de armazenamento, cacheamento e resolução de mídia forense.
///
/// Encapsula a persistência em disco local (`app_flutter/evidencias/`), requisições de rede
/// para o backend (`/media/{uuid}.jpg`), normalização de URIs (`file://`) e atualização
/// de metadados no SQLite por trás de uma interface estreita.
abstract interface class IMediaStorageService {
  /// Obtém o arquivo físico local de uma mídia pericial.
  ///
  /// Se o arquivo já existir no sistema de arquivos local, retorna-o imediatamente.
  /// Caso contrário, se houver [evidenciaUuid] ou [fallbackUrl], efetua o download via rede,
  /// salva no sandbox de evidências e atualiza o caminho no SQLite.
  Future<File?> getLocalMediaFile({
    String? localPath,
    String? evidenciaUuid,
    String? fallbackUrl,
  });

  /// Resolve e decodifica os bytes binários da fotografia pericial em memória.
  ///
  /// Utilizado tanto pela compilação gráfica do relatório em PDF quanto por widgets visuais.
  Future<Uint8List?> resolveImageBytes({
    String? localPath,
    String? evidenciaUuid,
    String? fallbackUrl,
  });

  /// Grava fisicamente no sandbox local uma fotografia recém-capturada pela câmera ou galeria.
  Future<File> saveCapturedImage(File sourceFile, String evidenciaUuid);
}

/// Implementação padrão e profunda de [IMediaStorageService].
///
/// Implementa a estratégia estrita de Offline-First:
/// 1. Prioriza sempre arquivos locais já persistidos.
/// 2. Se um arquivo estiver ausente no disco local e o dispositivo possuir conexão,
///    realiza o download transparente via API, grava no disco em `evidencias/` e
///    registra o novo caminho no banco SQLite local.
/// 3. Mantém compatibilidade total com o ciclo de Garbage Collection ([LocalStorageGcService]).
class MediaStorageService implements IMediaStorageService {
  final ApiClient? _apiClient;
  final DatabaseHelper? _dbHelper;
  final Directory? _baseDirectoryOverride;

  MediaStorageService({
    ApiClient? apiClient,
    DatabaseHelper? dbHelper,
    Directory? baseDirectoryOverride,
  }) : _apiClient = apiClient,
       _dbHelper = dbHelper,
       _baseDirectoryOverride = baseDirectoryOverride;

  Future<Directory> _getEvidenciasDirectory() async {
    if (_baseDirectoryOverride != null) {
      final dir = Directory(p.join(_baseDirectoryOverride.path, 'evidencias'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'evidencias'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File? _normalizarArquivoLocal(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    var clean = rawPath.trim();
    if (clean.startsWith('file://')) {
      clean = clean.substring(7);
    }
    try {
      clean = Uri.decodeFull(clean);
    } catch (_) {}

    final file = File(clean);
    if (file.existsSync()) return file;
    return null;
  }

  String _getServerBaseUrl() {
    String? raw;
    try {
      raw = _apiClient?.dio.options.baseUrl;
    } catch (_) {}
    raw ??= const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.15.88:8000/api/v1/',
    );
    var url = raw.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - 7);
    }
    return url;
  }

  @override
  Future<File?> getLocalMediaFile({
    String? localPath,
    String? evidenciaUuid,
    String? fallbackUrl,
  }) async {
    // 1. Tenta carregar do caminho local especificado
    final localFile = _normalizarArquivoLocal(localPath);
    if (localFile != null) {
      return localFile;
    }

    final evidenciasDir = await _getEvidenciasDirectory();

    // 2. Extrai UUID potencial do caminho local (se for ex: /.../evidencias/<uuid>.jpg)
    String? extractedUuidFromPath;
    if (localPath != null && localPath.trim().isNotEmpty) {
      final nameWithoutExt = p.basenameWithoutExtension(localPath.trim());
      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(nameWithoutExt)) {
        extractedUuidFromPath = nameWithoutExt;
      }
    }

    String? effectiveUuid =
        (evidenciaUuid != null && evidenciaUuid.trim().isNotEmpty)
        ? evidenciaUuid.trim()
        : extractedUuidFromPath;

    // 3. Cruzamento SQLite: verifica por uuid de evidência ou achado_uuid
    if (_dbHelper != null && effectiveUuid != null) {
      try {
        final db = await _dbHelper.database;
        final rows = await db.query(
          'evidencias_multimidia',
          columns: ['uuid', 'caminho_arquivo_encriptado'],
          where: '(uuid = ? OR achado_uuid = ?) AND removido = 0',
          whereArgs: [effectiveUuid, effectiveUuid],
          orderBy: 'atualizado_em DESC, criado_em DESC',
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          final dbPath = row['caminho_arquivo_encriptado']?.toString();
          final dbFile = _normalizarArquivoLocal(dbPath);
          if (dbFile != null) return dbFile;

          final rowUuid = row['uuid']?.toString();
          if (rowUuid != null && rowUuid.isNotEmpty) {
            effectiveUuid = rowUuid;
          }
        }
      } catch (e) {
        debugPrint('[MediaStorageService] Consulta SQLite por evidência: $e');
      }
    }

    // 4. Se temos UUID identificado, verifica se o arquivo já existe na pasta evidencias/{uuid}.jpg
    if (effectiveUuid != null && effectiveUuid.isNotEmpty) {
      final targetFile = File(p.join(evidenciasDir.path, '$effectiveUuid.jpg'));
      if (targetFile.existsSync()) {
        return targetFile;
      }

      // 5. Se não existe no disco local, faz o download via API de mídia
      final downloaded = await _downloadArquivoRemoto(
        'media/$effectiveUuid.jpg',
        targetFile,
        evidenciaUuid: effectiveUuid,
      );
      if (downloaded != null) return downloaded;
    }

    // 6. Fallback se fornecido fallbackUrl
    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      final String fallbackName =
          effectiveUuid != null && effectiveUuid.isNotEmpty
          ? '$effectiveUuid.jpg'
          : p.basename(fallbackUrl.trim());
      final targetFile = File(p.join(evidenciasDir.path, fallbackName));
      final downloaded = await _downloadArquivoRemoto(
        fallbackUrl.trim(),
        targetFile,
        evidenciaUuid: effectiveUuid,
      );
      if (downloaded != null) return downloaded;
    }

    return null;
  }

  Future<File?> _downloadArquivoRemoto(
    String endpointOuUrl,
    File destinationFile, {
    String? evidenciaUuid,
  }) async {
    try {
      final dio = _apiClient?.dio ?? Dio();
      final String fullUrl;
      if (endpointOuUrl.startsWith('http://') ||
          endpointOuUrl.startsWith('https://')) {
        fullUrl = endpointOuUrl;
      } else {
        final cleanPath = endpointOuUrl.startsWith('/')
            ? endpointOuUrl.substring(1)
            : endpointOuUrl;
        final serverBase = _getServerBaseUrl();
        fullUrl = '$serverBase/$cleanPath';
      }

      final response = await dio.get<List<int>>(
        fullUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (!destinationFile.parent.existsSync()) {
          destinationFile.parent.createSync(recursive: true);
        }
        await destinationFile.writeAsBytes(response.data!, flush: true);

        // Atualiza no SQLite para manter a consistência da referência local
        if (evidenciaUuid != null && _dbHelper != null) {
          try {
            final db = await _dbHelper.database;
            await db.update(
              'evidencias_multimidia',
              {
                'caminho_arquivo_encriptado': destinationFile.path,
                'foto_sincronizada': 1,
                'atualizado_em': DateTime.now().toUtc().toIso8601String(),
              },
              where: 'uuid = ?',
              whereArgs: [evidenciaUuid],
            );
          } catch (e) {
            debugPrint('[MediaStorageService] Aviso ao atualizar SQLite: $e');
          }
        }

        return destinationFile;
      }
    } catch (e) {
      debugPrint(
        '[MediaStorageService] ⚠️ Falha ao baixar mídia $endpointOuUrl: $e',
      );
    }
    return null;
  }

  @override
  Future<Uint8List?> resolveImageBytes({
    String? localPath,
    String? evidenciaUuid,
    String? fallbackUrl,
  }) async {
    final file = await getLocalMediaFile(
      localPath: localPath,
      evidenciaUuid: evidenciaUuid,
      fallbackUrl: fallbackUrl,
    );

    if (file != null && file.existsSync()) {
      try {
        return await file.readAsBytes();
      } catch (e) {
        debugPrint(
          '[MediaStorageService] Erro ao ler bytes do arquivo ${file.path}: $e',
        );
      }
    }
    return null;
  }

  @override
  Future<File> saveCapturedImage(File sourceFile, String evidenciaUuid) async {
    final evidenciasDir = await _getEvidenciasDirectory();
    final targetFile = File(
      p.join(evidenciasDir.path, '${evidenciaUuid.trim()}.jpg'),
    );

    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }

    final bytes = await sourceFile.readAsBytes();
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile;
  }
}

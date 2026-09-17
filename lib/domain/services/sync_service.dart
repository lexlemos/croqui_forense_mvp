import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/parsed_sync_payload.dart';
import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';
import 'package:croqui_forense_mvp/core/utils/sentry_helper.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';

/// Contrato de repositório local responsável pelas operações de leitura e atualização
/// de integridade dos [Caso]s (Laudos) e seus respectivos [Achado]s durante o processo de sincronização.
abstract interface class ISyncRepository {
  /// Obtém todos os [Caso]s (Laudos) finalizados do usuário que ainda não foram sincronizados com o servidor central.
  Future<List<Caso>> getCasosNaoSincronizados(String usuarioId);

  /// Obtém todos os [Caso]s em rascunho do usuário com `is_draft_synced = 0` pendentes de envio.
  Future<List<Caso>> getRascunhosNaoSincronizados(String usuarioId);

  /// Recupera todas as lesões corporais ([Achado]s) associadas a um determinado [Caso] pelo seu identificador único.
  Future<List<Achado>> getAchadosPorCaso(String casoUuid);

  /// Recupera em lote todos os [Achado]s pertencentes aos identificadores de [Caso]s informados.
  Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids);

  /// Retorna as lesões que possuem [Evidência Fotográfica] capturada no tablet mas que ainda não foram sincronizadas com o servidor.
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(
    List<String> casoUuids,
  );

  /// Atualiza o status local do [Caso] (Laudo) para marcado como sincronizado no banco de dados.
  Future<void> marcarCasoComoSincronizado(Caso caso);

  /// Marca localmente a cadeia de custódia como comprometida após falha na evidência.
  Future<void> marcarCasoComErroDeSincronizacao(String casoUuid);

  /// Atualiza a marcação local de um rascunho como sincronizado no SQLite (`is_draft_synced = 1`).
  Future<void> marcarRascunhoComoSincronizado(String casoUuid);

  /// Atualiza o status local da [Evidência Fotográfica] de um [Achado] para marcado como sincronizada.
  Future<void> marcarFotoComoSincronizada(Achado achado);

  /// Recupera as lesões com fotos pendentes de sincronização para um caso específico.
  Future<List<Achado>> getEvidenciasPendentesPorCaso(String casoUuid);

  /// Motor de Upsert (Sincronização Pull). Resolve conflitos e insere/atualiza casos, achados e evidências.
  Future<void> upsertCasoTransaction(ParsedSyncPayload payload);
}

/// Exceção lançada quando o push dos dados textuais de sincronização dos laudos é rejeitado pelo servidor central.
class SyncPushTextualException implements Exception {
  final String message;
  final int? statusCode;

  const SyncPushTextualException(this.message, {this.statusCode});

  @override
  String toString() =>
      'SyncPushTextualException(status: $statusCode): $message';
}

/// Exceção lançada quando ocorre uma falha no upload de uma [Evidência Fotográfica] de um achado para a central.
class SyncUploadEvidenciaException implements Exception {
  final String message;
  final String casoUuid;
  final String? achadoUuid;
  final int? statusCode;

  const SyncUploadEvidenciaException(
    this.message, {
    required this.casoUuid,
    this.achadoUuid,
    this.statusCode,
  });

  @override
  String toString() =>
      'SyncUploadEvidenciaException(caso: $casoUuid, achado: $achadoUuid, '
      'status: $statusCode): $message';
}

/// Indica que a evidência esperada não está disponível no armazenamento local.
class EvidenceNotFoundException implements Exception {
  final String casoUuid;
  final String? achadoUuid;
  final String? filePath;

  const EvidenceNotFoundException({
    required this.casoUuid,
    this.achadoUuid,
    this.filePath,
  });

  @override
  String toString() =>
      'EvidenceNotFoundException(caso: $casoUuid, achado: $achadoUuid, '
      'arquivo: $filePath)';
}

/// Serviço de domínio encarregado da [Sincronização] e conformidade dos dados periciais do IML.
///
/// Ele garante que a [Cadeia de Custódia] dos [Caso]s (Laudos) e suas respectivas [Evidência Fotográfica]s
/// seja mantida íntegra, realizando o envio em lote de dados textuais e arquivos de imagem binários
/// para o servidor central através do [IRemoteDataSource].
class SyncService {
  final IRemoteDataSource _remoteDataSource;
  final ISyncRepository _repository;
  final AuthService? _authService;

  SyncService({
    required IRemoteDataSource remoteDataSource,
    required ISyncRepository repository,
    AuthService? authService,
  }) : _remoteDataSource = remoteDataSource,
       _repository = repository,
       _authService = authService;

  final Set<String> _uuidsEmTransito = {};
  bool _isSyncing = false;

  /// Executa o fluxo completo de sincronização pericial do dispositivo com a central.
  ///
  /// Busca todos os laudos locais e rascunhos pendentes de envio, faz o push textual agregado de toda a carga de dados,
  /// e então executa o upload em lote de cada [Evidência Fotográfica] associada. Ao fim do envio bem-sucedido
  /// das fotos e dos dados textuais, atualiza a marcação no repositório local.
  bool _isSessionExpiredError(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403 ||
          error.error is SessionExpiredException) {
        return true;
      }
    }
    if (error is SessionExpiredException) return true;
    return false;
  }

  /// Executa o fluxo completo de sincronização pericial do dispositivo com a central.
  ///
  /// Busca todos os laudos locais e rascunhos pendentes de envio, faz o push textual agregado de toda a carga de dados,
  /// e então executa o upload em lote de cada [Evidência Fotográfica] associada. Ao fim do envio bem-sucedido
  /// das fotos e dos dados textuais, atualiza a marcação no repositório local.
  Future<void> execute() async {
    if (_isSyncing) {
      debugPrint(
        '[SyncService] ⏭️ Sincronização já em andamento. Abortando duplo-clique.',
      );
      return;
    }
    _isSyncing = true;
    try {
      debugPrint('[SyncService] Iniciando sincronização...');

      try {
        await pullCasos();
      } on DioException catch (e) {
        if (_isSessionExpiredError(e)) {
          debugPrint(
            '[SyncService] 🛑 Sessão expirada (401) no pull de casos. Abortando ciclo.',
          );
          rethrow;
        }
        debugPrint('[SyncService] ⚠️ Falha no pull de casos: $e');
      } catch (e) {
        debugPrint('[SyncService] ⚠️ Falha no pull de casos: $e');
      }

      final usuarioId = _authService?.usuario?.id;
      if (usuarioId == null || usuarioId.isEmpty) {
        debugPrint(
          '[SyncService] 🛑 Nenhum usuário logado. Abortando envio de casos pendentes.',
        );
        return;
      }

      final casosFinalizados = await _repository.getCasosNaoSincronizados(
        usuarioId,
      );
      final rascunhosPendentes = await _repository.getRascunhosNaoSincronizados(
        usuarioId,
      );

      final List<Caso> casosParaEnviar = [
        ...casosFinalizados,
        ...rascunhosPendentes,
      ];

      if (casosParaEnviar.isEmpty) {
        debugPrint(
          '[SyncService] Nenhum caso (finalizado ou rascunho) pendente de sincronização.',
        );
        return;
      }

      debugPrint(
        '[SyncService] Preparando push de ${casosFinalizados.length} casos finalizados e ${rascunhosPendentes.length} rascunhos.',
      );

      int totalFotosFalhas = 0;
      int totalCasosConflito = 0;

      try {
        debugPrint(
          '[SyncService] 📦 Fazendo push textual (Bulk) de ${casosParaEnviar.length} casos...',
        );

        final syncResult = await _pushTextual(casosParaEnviar);
        final conflitosUuids = Set<String>.from(
          syncResult['conflitos'] ?? const <String>[],
        );
        final salvosUuids = Set<String>.from(
          syncResult['casos_salvos'] ?? const <String>[],
        );

        totalCasosConflito += conflitosUuids.length;

        for (final caso in casosParaEnviar) {
          if (_authService != null && !_authService.isLogged) {
            debugPrint(
              '[SyncService] 🛑 Sessão nula. Abortando fila de fotos prematuramente.',
            );
            return;
          }

          if (conflitosUuids.contains(caso.uuid) ||
              !salvosUuids.contains(caso.uuid)) {
            debugPrint(
              '[SyncService] ⚠️ Caso ${caso.uuid} em conflito ou rejeitado. Pulando envio de fotos.',
            );
            continue;
          }

          try {
            await Sentry.captureMessage(
              'Iniciando ciclo de upload de mídia para o caso salvo ${caso.uuid}',
              level: SentryLevel.info,
            );
            final fotos = await _repository.getEvidenciasPendentesPorCaso(
              caso.uuid,
            );
            final falhasNoCaso = await _processarCaso(caso, fotos);
            totalFotosFalhas += falhasNoCaso;
          } on DioException catch (e, stackTrace) {
            if (_isSessionExpiredError(e)) {
              debugPrint(
                '[SyncService] 🛑 Sessão expirada no envio de fotos do caso ${caso.uuid}.',
              );
              return;
            }
            debugPrint(
              '[SyncService] ⚠️ Falha de rede ao enviar fotos do caso ${caso.uuid}: $e',
            );
            SentryHelper.setSyncErrorTag(caso.uuid);
            await Sentry.captureException(e, stackTrace: stackTrace);
            totalFotosFalhas++;
          } catch (e, stackTrace) {
            debugPrint(
              '[SyncService] ⚠️ Erro inesperado nas fotos do caso ${caso.uuid}: $e',
            );
            SentryHelper.setSyncErrorTag(caso.uuid);
            await Sentry.captureException(e, stackTrace: stackTrace);
            totalFotosFalhas++;
          }
        }
      } on DioException catch (e, stackTrace) {
        if (_isSessionExpiredError(e)) {
          debugPrint(
            '[SyncService] 🛑 Sessão expirada (401/403) no envio (Bulk).',
          );
          return;
        }
        debugPrint('[SyncService] ⚠️ Falha na rede no Bulk Push: $e');
        await Sentry.captureException(e, stackTrace: stackTrace);
        totalFotosFalhas++; // Falhou tudo
      } catch (e, stackTrace) {
        debugPrint('[SyncService] ⚠️ Erro inesperado no Bulk Push: $e');
        await Sentry.captureException(e, stackTrace: stackTrace);
        totalFotosFalhas++;
      }

      debugPrint('[SyncService] Ciclo concluído.');

      if (totalCasosConflito > 0 || totalFotosFalhas > 0) {
        final List<String> erros = [];
        if (totalCasosConflito > 0) {
          erros.add(
            '$totalCasosConflito caso(s) em conflito no servidor central.',
          );
        }
        if (totalFotosFalhas > 0) {
          erros.add('falha ao enviar $totalFotosFalhas item(ns).');
        }
        throw Exception('Sincronização parcial: ${erros.join(" e ")}');
      }
    } finally {
      _isSyncing = false;
    }
  }

  VoidCallback? onPullCompleted;

  /// Baixa casos da base central e sincroniza localmente através de Upsert com resolução de conflito.
  Future<void> pullCasos() async {
    debugPrint('[SyncService] Iniciando Pull Synchronization...');
    try {
      final secureStorage = SecureKeyStorage();
      final lastSync = await secureStorage.read(key: 'last_sync_timestamp');

      final casosRemotos = await _remoteDataSource.pullCasos(
        lastSyncTimestamp: lastSync,
      );

      if (casosRemotos.isEmpty) {
        debugPrint('[SyncService] Nenhum caso recebido no pull.');
        return;
      }

      debugPrint(
        '[SyncService] Recebidos ${casosRemotos.length} caso(s) remoto(s) para sincronização local.',
      );
      String? lastSuccessfulSyncTimestamp;

      /// A conversão da carga massiva de JSON para entidades de domínio ocorre em uma Background Isolate
      /// para garantir que a Main Thread não sofra bloqueios (UI Jank).
      final payloads = await compute(_parseCasosEmBackground, casosRemotos);

      for (final payload in payloads) {
        try {
          await _repository.upsertCasoTransaction(payload);
          final atualizadoEm = payload.rawJson['atualizado_em']?.toString();
          if (atualizadoEm != null && atualizadoEm.isNotEmpty) {
            lastSuccessfulSyncTimestamp = atualizadoEm;
          }
        } catch (e, stackTrace) {
          debugPrint(
            '[SyncService] Erro ao sincronizar (upsert) o caso ${payload.caso.uuid}: $e\n$stackTrace',
          );
          final casoUuid = payload.caso.uuid;
          if (casoUuid.isNotEmpty) {
            try {
              await _repository.marcarCasoComErroDeSincronizacao(casoUuid);
            } catch (markError, markStackTrace) {
              debugPrint(
                '[SyncService] Não foi possível registrar sync_error para '
                '$casoUuid: $markError\n$markStackTrace',
              );
            }
          }
          continue;
        }
      }

      if (lastSuccessfulSyncTimestamp != null) {
        await secureStorage.save(
          key: 'last_sync_timestamp',
          value: lastSuccessfulSyncTimestamp,
        );
      }

      debugPrint(
        '[SyncService] Pull Synchronization concluído com sucesso parcial.',
      );
      onPullCompleted?.call();
    } on DioException catch (e, stackTrace) {
      if (_isSessionExpiredError(e)) {
        debugPrint(
          '[SyncService] 🛑 Sessão expirada (401) no Pull. Abortando.',
        );
        rethrow;
      }
      debugPrint(
        '[SyncService] ⚠️ Falha na rede durante o Pull: $e\n$stackTrace',
      );
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[SyncService] ⚠️ Erro inesperado no Pull: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Dispara a sincronização silenciosa de um novo rascunho de caso para rastreamento no backend.
  /// Não bloqueia a interface. Caso falhe por queda de rede, a marcação `is_draft_synced = 0` no SQLite
  /// garante o reenvio automático assim que a conectividade retornar.
  Future<void> pushCasoRascunho(Caso caso) async {
    if (_uuidsEmTransito.contains(caso.uuid)) {
      debugPrint(
        '[SyncService] ⏭️ Caso ${caso.uuid} já em trânsito. Ignorando push duplicado.',
      );
      return;
    }
    _uuidsEmTransito.add(caso.uuid);

    try {
      debugPrint(
        '[SyncService] 🚀 Disparando push silencioso de rascunho para o caso ${caso.uuid}...',
      );
      await Sentry.captureMessage(
        'Iniciando ciclo de sincronização para o caso ${caso.uuid}',
        level: SentryLevel.info,
      );

      final casoProcessado = await _sincronizarPdfCaso(caso);

      final achados = await _repository.getAchadosPorCaso(casoProcessado.uuid);
      final casoJson = await _casoParaJson(casoProcessado, achados);
      final deviceId = await DeviceInfoService.getDeviceId();

      final payload = {
        'device_id': deviceId,
        'timestamp_sincronizacao': DateTime.now().toUtc().toIso8601String(),
        'casos': [casoJson],
      };

      await _remoteDataSource.pushTextual(payload);
      await _repository.marcarRascunhoComoSincronizado(caso.uuid);
      debugPrint(
        '[SyncService] ✅ Push silencioso do rascunho ${caso.uuid} concluído e marcado como sincronizado.',
      );
    } catch (e, stackTrace) {
      if (_isSessionExpiredError(e)) {
        debugPrint(
          '[SyncService] 🛑 Sessão expirada (401/403) no push silencioso do rascunho. Abortando.',
        );
        rethrow;
      }
      debugPrint(
        '[SyncService] ⚠️ Push silencioso do rascunho falhou (dispositivo offline ou servidor indisponível): $e',
      );
      SentryHelper.setSyncErrorTag(caso.uuid);
      await Sentry.captureException(e, stackTrace: stackTrace);
    } finally {
      _uuidsEmTransito.remove(caso.uuid);
    }
  }

  Future<Map<String, dynamic>> _pushTextual(List<Caso> casos) async {
    final achadosPorCaso = await _repository.getAchadosEmLote(
      casos.map((c) => c.uuid).toList(),
    );

    final List<Map<String, dynamic>> casosJson = [];
    for (final caso in casos) {
      debugPrint(
        '🔍 [AUDITORIA 2 - SQLITE] Caso ${caso.uuid} carregado do SQLite. Exames encontrados: ${caso.exames.length}',
      );
      final casoProcessado = await _sincronizarPdfCaso(caso);
      final achados = achadosPorCaso[casoProcessado.uuid] ?? [];
      casosJson.add(await _casoParaJson(casoProcessado, achados));
    }

    final deviceId = await DeviceInfoService.getDeviceId();
    final payload = {
      'device_id': deviceId,
      'timestamp_sincronizacao': DateTime.now().toUtc().toIso8601String(),
      'casos': casosJson,
    };

    return await _remoteDataSource.pushTextual(payload);
  }

  /// Processa a sincronização de fotos de um caso.
  /// Retorna o número de fotos que falharam no envio.
  Future<int> _processarCaso(Caso caso, List<Achado> achadosComFotos) async {
    if (achadosComFotos.isEmpty) {
      await _confirmarCaso(caso);
      return 0;
    }

    final List<Achado> achadosSincronizados = [];
    final List<Object> erros = [];

    for (final achado in achadosComFotos) {
      if (_authService != null && !_authService.isLogged) {
        debugPrint(
          '[SyncService] 🛑 Sessão nula. Abortando upload de fotos prematuramente.',
        );
        throw SessionExpiredException();
      }
      try {
        await _uploadEvidencia(caso, achado);
        achadosSincronizados.add(achado);
        await _repository.marcarFotoComoSincronizada(achado);
      } on EvidenceNotFoundException catch (e, stackTrace) {
        debugPrint(
          '[SyncService] 🛑 Evidência ausente no caso ${caso.uuid}; '
          'upload do caso abortado: $e',
        );
        await _repository.marcarCasoComErroDeSincronizacao(caso.uuid);
        SentryHelper.setSyncErrorTag(caso.uuid);
        await Sentry.captureException(e, stackTrace: stackTrace);
        return 1;
      } catch (e, stackTrace) {
        if (_isSessionExpiredError(e)) {
          debugPrint(
            '[SyncService] 🛑 Sessão expirada (401/403) no upload de foto. Abortando.',
          );
          rethrow;
        }
        erros.add(e);
        debugPrint(
          '[SyncService] Upload falhou para o achado ${achado.uuid} no caso ${caso.uuid}: $e',
        );
        SentryHelper.setSyncErrorTag(caso.uuid);
        await Sentry.captureException(e, stackTrace: stackTrace);
      }
    }

    if (erros.isEmpty) {
      await _confirmarCaso(caso);
      return 0;
    } else {
      debugPrint(
        '[SyncService] Caso ${caso.uuid}: ${erros.length} foto(s) falharam. O status permanecerá pendente.',
      );
      return erros.length;
    }
  }

  Future<void> _uploadEvidencia(Caso caso, Achado achado) async {
    final String? caminhoFoto = achado.photoPath;
    if (caminhoFoto == null || caminhoFoto.isEmpty) {
      throw EvidenceNotFoundException(
        casoUuid: caso.uuid,
        achadoUuid: achado.uuid,
        filePath: caminhoFoto,
      );
    }

    final File arquivoOriginal = File(caminhoFoto);
    if (!arquivoOriginal.existsSync()) {
      throw EvidenceNotFoundException(
        casoUuid: caso.uuid,
        achadoUuid: achado.uuid,
        filePath: caminhoFoto,
      );
    }

    final bytes = await arquivoOriginal.readAsBytes();
    final String hashOriginal = sha256.convert(bytes).toString();

    final String evidenciaUuid =
        achado.dadosPreenchidos['_evidencia_uuid']?.toString() ?? achado.uuid;

    final bool isFotoGeral =
        achado.tipoAchadoId == 'FOTO_GERAL' || achado.diagramaNome == 'GERAL';

    await _remoteDataSource.uploadEvidencia(
      casoUuid: caso.uuid,
      achadoUuid: isFotoGeral ? null : achado.uuid,
      evidenciaUuid: evidenciaUuid,
      hash: hashOriginal,
      filePath: arquivoOriginal.path,
    );
  }

  Future<void> _confirmarCaso(Caso caso) async {
    await _repository.marcarCasoComoSincronizado(caso);
  }

  /// Sincroniza o PDF fisicamente usando a nova rota multipart.
  /// Retorna um [Caso] atualizado contendo a `pdfUrl` gerada pelo backend.
  Future<Caso> _sincronizarPdfCaso(Caso caso) async {
    final localPath = caso.pdfLocalPath;
    if (localPath != null && localPath.isNotEmpty) {
      final pdfFile = File(localPath);
      if (pdfFile.existsSync()) {
        try {
          debugPrint(
            '[SyncService] 📄 Fazendo upload físico do Laudo PDF: ${caso.pdfLocalPath}',
          );
          final pdfUrl = await _remoteDataSource.uploadLaudoPdf(
            casoUuid: caso.uuid,
            filePath: pdfFile.path,
          );
          await Sentry.captureMessage(
            'Upload do Laudo concluído com sucesso: ${caso.uuid}',
            level: SentryLevel.info,
          );
          return caso.copyWith(pdfUrl: pdfUrl);
        } catch (e, stackTrace) {
          debugPrint(
            '[SyncService] ⚠️ Erro ao fazer upload do PDF para o caso ${caso.uuid}: $e',
          );
          SentryHelper.setSyncErrorTag(caso.uuid);
          await Sentry.captureException(e, stackTrace: stackTrace);
          rethrow;
        }
      }
    }
    return caso;
  }

  String _toDeterministicUuidV4(String namespace, String name) {
    final String uuidV5 = const Uuid().v5(namespace, name);
    return '${uuidV5.substring(0, 14)}4${uuidV5.substring(15, 19)}a${uuidV5.substring(20)}';
  }

  Future<Map<String, dynamic>> _casoParaJson(
    Caso caso,
    List<Achado> achados,
  ) async {
    final uniqueDiagramNames = achados.map((a) => a.diagramaNome).toSet();

    final List<Map<String, dynamic>> diagramasJson = [];
    for (final diagName in uniqueDiagramNames) {
      final String diagramaUuid = _toDeterministicUuidV4(caso.uuid, diagName);

      diagramasJson.add({
        'uuid': diagramaUuid,
        'caso_uuid': caso.uuid,
        'nome_diagrama': diagName,
        'versao': 1,
        'removido': false,
        'criado_em': caso.criadoEmDispositivo.toUtc().toIso8601String(),
        'atualizado_em': (caso.atualizadoEm ?? caso.criadoEmDispositivo)
            .toUtc()
            .toIso8601String(),
      });
    }

    final payload = caso.toSyncMap();
    debugPrint(
      '🔍 [AUDITORIA 3 - JSON DART] Nó exames_solicitados gerado: ${jsonEncode(payload['exames_solicitados'])}',
    );
    payload['diagramas'] = diagramasJson;
    payload['achados'] = achados.map(_achadoParaJson).toList();

    return payload;
  }

  Map<String, dynamic> _achadoParaJson(Achado achado) {
    return achado.toSyncMap();
  }
}

/// Função pura e estática executada em uma Isolate secundária (Background Thread).
///
/// Otimiza a ingestão massiva de dados do servidor central (GET /pull), transferindo o parsing
/// e a alocação de memória (jsonDecode, factory instantiations) para fora da Main Thread,
/// evitando cenários severos de 'UI Jank' ou travamentos durante a sincronização Offline-First.
List<ParsedSyncPayload> _parseCasosEmBackground(
  List<Map<String, Object?>> payload,
) {
  final result = <ParsedSyncPayload>[];

  for (final jsonCaso in payload) {
    try {
      final casoBackend = Caso.fromMap(jsonCaso);
      final atualizadoEm = jsonCaso['atualizado_em']?.toString();

      final List<dynamic> rawEvidenciasList = [];
      if (jsonCaso['evidencias_multimidia'] is List) {
        rawEvidenciasList.addAll(jsonCaso['evidencias_multimidia'] as List);
      }
      if (jsonCaso['evidencias'] is List) {
        rawEvidenciasList.addAll(jsonCaso['evidencias'] as List);
      }

      if (jsonCaso['achados'] is List) {
        final achadosList = jsonCaso['achados'] as List;
        for (final achadoJson in achadosList) {
          if (achadoJson is Map) {
            final aMap = Map<String, dynamic>.from(achadoJson);
            if (aMap['evidencias_multimidia'] is List) {
              rawEvidenciasList.addAll(aMap['evidencias_multimidia'] as List);
            }
            if (aMap['evidencias'] is List) {
              rawEvidenciasList.addAll(aMap['evidencias'] as List);
            }
          }
        }
      }

      final evidencias = <EvidenciaMultimidia>[];
      final achadosComEvidenciaExplicita = <String>{};

      for (final evJson in rawEvidenciasList) {
        if (evJson is! Map) continue;
        final evMap = Map<String, dynamic>.from(evJson);
        final evBackend = EvidenciaMultimidia.fromMap(evMap);
        if (evBackend.uuid.isEmpty) continue;

        final bool isRemovido =
            evJson['removido'] == true || evJson['removido'] == 1;
        evidencias.add(
          evBackend.copyWith(
            fotoSincronizada: true,
            removido: isRemovido || evBackend.removido,
          ),
        );

        if (evBackend.achadoUuid != null && evBackend.achadoUuid!.isNotEmpty) {
          achadosComEvidenciaExplicita.add(evBackend.achadoUuid!);
        }
      }

      final achados = <Achado>[];
      if (jsonCaso['achados'] is List) {
        final achadosList = jsonCaso['achados'] as List;
        for (final achadoJson in achadosList) {
          if (achadoJson is! Map) continue;
          final aMap = Map<String, dynamic>.from(achadoJson);

          if (aMap['caso_uuid'] == null ||
              aMap['caso_uuid'].toString().isEmpty) {
            aMap['caso_uuid'] = casoBackend.uuid;
          }

          if (aMap['diagrama_nome'] == null ||
              aMap['diagrama_nome'].toString().isEmpty) {
            final vistaRaw = aMap['vista_anatomica']?.toString();
            if (vistaRaw != null && vistaRaw.isNotEmpty) {
              aMap['diagrama_nome'] = vistaRaw;
            } else {
              try {
                final dpRaw = aMap['dados_preenchidos_json'];
                final dpMap = dpRaw is Map
                    ? dpRaw
                    : (dpRaw is String ? jsonDecode(dpRaw) as Map? : null);
                final viewVal = dpMap?['view']?.toString();
                aMap['diagrama_nome'] = (viewVal != null && viewVal.isNotEmpty)
                    ? viewVal
                    : 'GERAL';
              } catch (_) {
                aMap['diagrama_nome'] = 'GERAL';
              }
            }
          }

          if (aMap['diagrama_caso_uuid'] == null ||
              aMap['diagrama_caso_uuid'].toString().isEmpty) {
            aMap['diagrama_caso_uuid'] = casoBackend.uuid;
          }

          final achadoBackend = Achado.fromMap(aMap);
          if (achadoBackend.uuid.isEmpty) continue;

          final bool isRemovido =
              achadoJson['removido'] == true || achadoJson['removido'] == 1;
          achados.add(
            achadoBackend.copyWith(
              removido: isRemovido || achadoBackend.removido,
            ),
          );

          if (achadoBackend.photoPath != null &&
              achadoBackend.photoPath!.isNotEmpty &&
              !achadosComEvidenciaExplicita.contains(achadoBackend.uuid)) {
            final evidenciaUuid = const Uuid().v5(
              casoBackend.uuid,
              'achado-evidencia-${achadoBackend.uuid}',
            );

            evidencias.add(
              EvidenciaMultimidia(
                uuid: evidenciaUuid,
                casoUuid: casoBackend.uuid,
                achadoUuid: achadoBackend.uuid,
                tipo: 'ACHADO',
                caminhoArquivoEncriptado: achadoBackend.photoPath,
                fotoSincronizada: true,
                removido: achadoBackend.removido,
                versao: achadoBackend.versao,
                criadoEm: achadoBackend.criadoEm.toUtc(),
              ),
            );
          }
        }
      }

      final bool casoRemovido =
          jsonCaso['removido'] == true || jsonCaso['removido'] == 1;

      result.add(
        ParsedSyncPayload(
          caso: casoBackend.copyWith(
            removido: casoRemovido || casoBackend.removido,
          ),
          achados: achados,
          evidencias: evidencias,
          rawJson: jsonCaso,
        ),
      );
    } catch (e) {
      debugPrint('[Background Isolate] Erro no parseamento do caso: $e');
    }
  }

  return result;
}

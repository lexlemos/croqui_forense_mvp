import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/balistica_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/parsed_sync_payload.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';
import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';
import 'package:croqui_forense_mvp/core/utils/sentry_helper.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';

/// Contrato de repositório local responsável pelas operações de leitura e atualização
/// de integridade dos [Caso]s (Laudos) e seus respectivos [Achado]s durante o processo de sincronização.
abstract interface class ISyncRepository {
  /// Instância do banco de dados SQLite (SQLCipher) para auditoria e operações de baixo nível.
  Future<Database> get database;

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

  /// Recupera as evidências multimídia pendentes de sincronização para um caso específico.
  Future<List<Map<String, dynamic>>> getEvidenciasPendentesPorCaso(
    String casoUuid,
  );

  /// Motor de Upsert (Sincronização Pull). Resolve conflitos e insere/atualiza casos, achados e evidências.
  Future<void> upsertCasoTransaction(ParsedSyncPayload payload);

  /// Obtém todas as evidências pendentes globalmente (desacopladas do status do Caso).
  Future<List<Map<String, dynamic>>> getTodasEvidenciasPendentesGlobais();

  /// Marca uma Evidência Multimídia como sincronizada.
  Future<void> marcarEvidenciaComoSincronizada(String uuid);
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
              '[SyncService] 🛑 Sessão nula. Abortando fila de casos prematuramente.',
            );
            return;
          }

          if (conflitosUuids.contains(caso.uuid) ||
              !salvosUuids.contains(caso.uuid)) {
            debugPrint(
              '[SyncService] ⚠️ Caso ${caso.uuid} em conflito ou rejeitado. Pulando confirmação.',
            );
            continue;
          }

          final List<Map<String, dynamic>> evidenciasPendentes =
              await _repository.getEvidenciasPendentesPorCaso(caso.uuid);
          bool todasFotosSincronizadas = true;

          for (final ev in evidenciasPendentes) {
            try {
              final filePath =
                  ev['caminho_arquivo_encriptado'] as String? ?? '';
              if (filePath.isEmpty) continue;

              final file = File(filePath);
              if (!await file.exists()) {
                debugPrint(
                  '[SyncService] ⚠️ Arquivo de evidência não encontrado em disco: $filePath',
                );
                todasFotosSincronizadas = false;
                totalFotosFalhas++;
                continue;
              }

              var hash = (ev['hash_arquivo'] as String?) ?? '';
              if (hash.isEmpty) {
                final bytes = await file.readAsBytes();
                hash = sha256.convert(bytes).toString();
              }

              await _remoteDataSource.uploadEvidencia(
                casoUuid: caso.uuid,
                achadoUuid: ev['achado_uuid'] as String?,
                evidenciaUuid: ev['evidencia_uuid'] as String,
                hash: hash,
                filePath: filePath,
              );

              await _repository.marcarEvidenciaComoSincronizada(
                ev['evidencia_uuid'] as String,
              );
            } on DioException catch (e, stackTrace) {
              todasFotosSincronizadas = false;
              totalFotosFalhas++;
              if (_isSessionExpiredError(e)) {
                debugPrint(
                  '[SyncService] 🛑 Sessão expirada no upload da evidência ${ev['evidencia_uuid']}. Abortando.',
                );
                rethrow;
              }
              debugPrint(
                '[SyncService] ❌ Falha de rede ao subir mídia ${ev['evidencia_uuid']}: $e',
              );
              await Sentry.captureException(e, stackTrace: stackTrace);
            } catch (e, stackTrace) {
              todasFotosSincronizadas = false;
              totalFotosFalhas++;
              debugPrint(
                '[SyncService] ❌ Falha inesperada ao subir mídia ${ev['evidencia_uuid']}: $e',
              );
              await Sentry.captureException(e, stackTrace: stackTrace);
            }
          }

          if (todasFotosSincronizadas) {
            try {
              await _confirmarCaso(caso);
            } catch (e, stackTrace) {
              debugPrint(
                '[SyncService] ⚠️ Erro inesperado ao confirmar caso ${caso.uuid}: $e',
              );
              SentryHelper.setSyncErrorTag(caso.uuid);
              await Sentry.captureException(e, stackTrace: stackTrace);
            }
          } else {
            await _repository.marcarCasoComErroDeSincronizacao(caso.uuid);
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
      } catch (e, stackTrace) {
        debugPrint('[SyncService] ⚠️ Erro inesperado no Bulk Push: $e');
        await Sentry.captureException(e, stackTrace: stackTrace);
      }

      debugPrint('[SyncService] Ciclo concluído.');

      if (totalCasosConflito > 0 || totalFotosFalhas > 0) {
        throw Exception(
          'Sincronização com pendências: $totalCasosConflito caso(s) em conflito e $totalFotosFalhas foto(s) com falha no envio.',
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  VoidCallback? onPullCompleted;

  /// Baixa casos da base central e sincroniza localmente através de Upsert com resolução de conflito.
  Future<void> pullCasos() async {
    if (_isSyncing) {
      debugPrint('[SyncService] ⏭️ Sincronização já em andamento. Abortando pullCasos.');
      return;
    }
    _isSyncing = true;
    try {
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
    } finally {
      _isSyncing = false;
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

  // TODO (Next Sprint): Alterar Push em lote para toler�ncia a falhas. Implementar suporte a HTTP 207 Partial Success do backend para evitar a Falha da P�lula Venenosa (onde 1 caso corrompido trava toda a fila).
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
    return deterministicUuidV4(namespace, name);
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
      final List<BalisticaModel> todasBalisticas = [];
      todasBalisticas.addAll(casoBackend.balisticas);

      if (jsonCaso['balisticas'] is List) {
        for (final rawB in (jsonCaso['balisticas'] as List)) {
          if (rawB is! Map) continue;
          final bMap = Map<String, dynamic>.from(rawB);
          final bModel = BalisticaModel.fromMap(bMap);
          if (bModel.id.isNotEmpty &&
              !todasBalisticas.any((b) => b.id.trim().toLowerCase() == bModel.id.trim().toLowerCase())) {
            todasBalisticas.add(bModel);
          }
        }
      }

      final Map<String, BalisticaModel> balisticasById = {};
      final Map<String, BalisticaModel> balisticasByAchadoUuid = {};
      final Map<String, BalisticaModel> balisticasByExameId = {};

      for (final b in todasBalisticas) {
        final bId = b.id.trim().toLowerCase();
        if (bId.isNotEmpty) {
          balisticasById[bId] = b;
        }
        if (b.achadoUuid != null && b.achadoUuid!.trim().isNotEmpty) {
          balisticasByAchadoUuid[b.achadoUuid!.trim().toLowerCase()] = b;
        }
        final bExameId = b.exameId.trim().toLowerCase();
        if (bExameId.isNotEmpty) {
          balisticasByExameId[bExameId] = b;
        }
      }

      if (jsonCaso['balisticas'] is List) {
        for (final rawB in (jsonCaso['balisticas'] as List)) {
          if (rawB is! Map) continue;
          final achadoId =
              rawB['achado_uuid']?.toString() ?? rawB['achado_id']?.toString();
          final bId = (rawB['id']?.toString() ?? rawB['uuid']?.toString())
              ?.trim()
              .toLowerCase();
          if (achadoId != null && achadoId.trim().isNotEmpty && bId != null) {
            final bModel = balisticasById[bId];
            if (bModel != null) {
              balisticasByAchadoUuid[achadoId.trim().toLowerCase()] = bModel;
            }
          }
        }
      }

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

          final achadoUuidLower = achadoBackend.uuid.trim().toLowerCase();
          final detBalisticaId =
              deterministicUuidV5(achadoBackend.uuid, 'balistica')
                  .toLowerCase();
          final legacyDetBalisticaId =
              deterministicUuidV4(achadoBackend.uuid, 'balistica')
                  .toLowerCase();

          // Heurística de match:
          // 1. ID determinístico V5 (e fallback V4 legado)
          // 2. achado_uuid / achado_id vínculo
          // 3. exame_id == achado.uuid
          // 4. ID direto da balística == achado.uuid
          BalisticaModel? matchedBalistica =
              (detBalisticaId.isNotEmpty ? balisticasById[detBalisticaId] : null) ??
              (legacyDetBalisticaId.isNotEmpty ? balisticasById[legacyDetBalisticaId] : null);
          matchedBalistica ??= balisticasByAchadoUuid[achadoUuidLower];
          matchedBalistica ??= balisticasByExameId[achadoUuidLower];
          matchedBalistica ??= balisticasById[achadoUuidLower];
          if (matchedBalistica == null) {
            for (final b in todasBalisticas) {
              final bId = b.id.trim().toLowerCase();
              final bAchado = b.achadoUuid?.trim().toLowerCase();
              final bExame = b.exameId.trim().toLowerCase();
              if ((detBalisticaId.isNotEmpty && bId == detBalisticaId) ||
                  (legacyDetBalisticaId.isNotEmpty && bId == legacyDetBalisticaId) ||
                  (bAchado != null && bAchado == achadoUuidLower) ||
                  bExame == achadoUuidLower ||
                  bId == achadoUuidLower) {
                matchedBalistica = b;
                break;
              }
            }
          }

          final achadoReconciliado = matchedBalistica != null
              ? achadoBackend.copyWith(
                  tipoFerimento:
                      matchedBalistica.tipoFerimento ??
                      achadoBackend.tipoFerimento,
                  tipoObjeto:
                      matchedBalistica.tipoObjeto ?? achadoBackend.tipoObjeto,
                  numeroLacre:
                      matchedBalistica.numeroLacre ??
                      achadoBackend.numeroLacre,
                  comentarioAdicional:
                      matchedBalistica.comentarioAdicional ??
                      achadoBackend.comentarioAdicional,
                )
              : achadoBackend;

          final bool isRemovido =
              achadoJson['removido'] == true || achadoJson['removido'] == 1;
          achados.add(
            achadoReconciliado.copyWith(
              removido: isRemovido || achadoReconciliado.removido,
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
            balisticas: todasBalisticas,
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

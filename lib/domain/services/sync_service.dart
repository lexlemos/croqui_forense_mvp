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
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';

/// Contrato de repositÃ³rio local responsÃ¡vel pelas operaÃ§Ãµes de leitura e atualizaÃ§Ã£o
/// de integridade dos [Caso]s (Laudos) e seus respectivos [Achado]s durante o processo de sincronizaÃ§Ã£o.
abstract interface class ISyncRepository {
  /// InstÃ¢ncia do banco de dados SQLite (SQLCipher) para auditoria e operaÃ§Ãµes de baixo nÃ­vel.
  Future<Database> get database;

  /// Obtém todos os [Caso]s (Laudos) pendentes de sincronização do usuário (EM_ANDAMENTO, RASCUNHO, LAUDO_PENDENTE ou FINALIZADO) com is_draft_synced = 0.
  Future<List<Caso>> getCasosPendentesSync(String usuarioId);

  /// Obtém todos os [Caso]s (Laudos) finalizados do usuário que ainda não foram sincronizados com o servidor central.
  Future<List<Caso>> getCasosNaoSincronizados(String usuarioId);

  /// Obtém todos os [Caso]s em rascunho do usuário com `is_draft_synced = 0` pendentes de envio.
  Future<List<Caso>> getRascunhosNaoSincronizados(String usuarioId);

  /// Recupera todas as lesÃµes corporais ([Achado]s) associadas a um determinado [Caso] pelo seu identificador Ãºnico.
  Future<List<Achado>> getAchadosPorCaso(String casoUuid);

  /// Recupera em lote todos os [Achado]s pertencentes aos identificadores de [Caso]s informados.
  Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids);

  /// Retorna as lesÃµes que possuem [EvidÃªncia FotogrÃ¡fica] capturada no tablet mas que ainda nÃ£o foram sincronizadas com o servidor.
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(
    List<String> casoUuids,
  );

  /// Atualiza o status local do [Caso] (Laudo) para marcado como sincronizado no banco de dados.
  Future<void> marcarCasoComoSincronizado(Caso caso);

  /// Marca localmente a cadeia de custÃ³dia como comprometida apÃ³s falha na evidÃªncia.
  Future<void> marcarCasoComErroDeSincronizacao(String casoUuid);

  /// Atualiza a marcaÃ§Ã£o local de um rascunho como sincronizado no SQLite (`is_draft_synced = 1`).
  Future<void> marcarRascunhoComoSincronizado(String casoUuid);

  /// Atualiza o status local da [EvidÃªncia FotogrÃ¡fica] de um [Achado] para marcado como sincronizada.
  Future<void> marcarFotoComoSincronizada(Achado achado);

  /// Recupera as evidÃªncias multimÃ­dia pendentes de sincronizaÃ§Ã£o para um caso especÃ­fico.
  Future<List<Map<String, dynamic>>> getEvidenciasPendentesPorCaso(
    String casoUuid,
  );

  /// Motor de Upsert (SincronizaÃ§Ã£o Pull). Resolve conflitos e insere/atualiza casos, achados e evidÃªncias.
  Future<void> upsertCasoTransaction(ParsedSyncPayload payload);

  /// ObtÃ©m todas as evidÃªncias pendentes globalmente (desacopladas do status do Caso).
  Future<List<Map<String, dynamic>>> getTodasEvidenciasPendentesGlobais();

  /// Marca uma Evidência Multimídia como sincronizada.
  Future<void> marcarEvidenciaComoSincronizada(String uuid);

  /// Atualiza o `pdf_url` remoto do caso no SQLite após upload bem-sucedido.
  Future<void> atualizarPdfUrl(String casoUuid, String pdfUrl);
}

/// Exceção lançada quando a comunicação com a API central falha devido à indisponibilidade do backend ou problemas de conectividade.
class SyncNetworkException implements Exception {
  /// Mensagem descritiva da falha de rede.
  final String message;

  /// Código de status HTTP, quando disponível.
  final int? statusCode;

  const SyncNetworkException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Exceção lançada quando o push dos dados textuais de sincronização dos laudos é rejeitado pelo servidor central.
class SyncPushTextualException implements Exception {
  /// Mensagem retornada pelo servidor ou camada de transporte.
  final String message;

  /// Código de resposta HTTP.
  final int? statusCode;

  const SyncPushTextualException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Exceção lançada quando ocorre uma falha no upload de uma Evidência Fotográfica de um achado para a central.
class SyncUploadEvidenciaException implements Exception {
  /// Mensagem detalhada da falha.
  final String message;

  /// Identificador único do caso relacionado.
  final String casoUuid;

  /// Identificador do achado pericial, se houver vínculo direto.
  final String? achadoUuid;

  /// Código HTTP associado à falha.
  final int? statusCode;

  const SyncUploadEvidenciaException(
    this.message, {
    required this.casoUuid,
    this.achadoUuid,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Indica que a evidência esperada não está disponível no armazenamento local.
class EvidenceNotFoundException implements Exception {
  /// Identificador único do caso.
  final String casoUuid;

  /// Identificador do achado pericial.
  final String? achadoUuid;

  /// Caminho do arquivo em disco não localizado.
  final String? filePath;

  const EvidenceNotFoundException({
    required this.casoUuid,
    this.achadoUuid,
    this.filePath,
  });

  @override
  String toString() =>
      'EvidenceNotFoundException(caso: $casoUuid, achado: $achadoUuid, arquivo: $filePath)';
}

/// Exceção geral lançada para falhas na integridade ou processamento da sincronização pericial.
class SyncException implements Exception {
  /// Descrição da inconsistência ou falha no ciclo de sincronização.
  final String message;

  const SyncException(this.message);

  @override
  String toString() => message;
}

/// Representa o resultado estruturado de um ciclo de sincronização pericial.
class SyncResult {
  /// Quantidade de laudos periciais enviados com sucesso nesta execução.
  final int casosEnviados;

  /// Quantidade de laudos periciais recebidos da base central nesta execução.
  final int casosRecebidos;

  /// Quantidade de evidências multimídia transmitidas com sucesso.
  final int fotosEnviadas;

  /// Quantidade de laudos que sofreram divergência ou conflito de concorrência.
  final int casosConflito;

  /// Quantidade de evidências multimídia que falharam durante a transmissão binária.
  final int fotosFalhas;

  /// Indica se a operação concluiu com pendências parciais.
  final bool temPendencias;

  /// Mensagem textual de feedback semântico para exibição ao perito legista.
  final String mensagem;

  const SyncResult({
    required this.casosEnviados,
    required this.casosRecebidos,
    required this.fotosEnviadas,
    required this.casosConflito,
    required this.fotosFalhas,
    required this.temPendencias,
    required this.mensagem,
  });

  /// Instancia um resultado de sucesso total ou ausência de pendências.
  factory SyncResult.sucesso({
    int casosEnviados = 0,
    int casosRecebidos = 0,
    int fotosEnviadas = 0,
  }) {
    final String msg;
    if (casosEnviados == 0 && casosRecebidos == 0) {
      msg = 'Tudo atualizado. Nenhum laudo pendente de sincronização.';
    } else if (casosEnviados > 0 && casosRecebidos > 0) {
      msg =
          '$casosEnviados laudo(s) sincronizado(s) e $casosRecebidos recebido(s).';
    } else if (casosEnviados > 0) {
      msg = casosEnviados == 1
          ? '1 laudo sincronizado com sucesso!'
          : '$casosEnviados laudos sincronizados com sucesso!';
    } else {
      msg = casosRecebidos == 1
          ? '1 laudo atualizado da central.'
          : '$casosRecebidos laudos atualizados da central.';
    }

    return SyncResult(
      casosEnviados: casosEnviados,
      casosRecebidos: casosRecebidos,
      fotosEnviadas: fotosEnviadas,
      casosConflito: 0,
      fotosFalhas: 0,
      temPendencias: false,
      mensagem: msg,
    );
  }

  /// Instancia um resultado com falhas parciais ou conflitos identificados.
  factory SyncResult.parcial({
    required int casosEnviados,
    required int casosRecebidos,
    required int fotosEnviadas,
    required int casosConflito,
    required int fotosFalhas,
  }) {
    final partes = <String>[];
    if (casosEnviados > 0) {
      partes.add('$casosEnviados enviado(s)');
    }
    if (casosConflito > 0) {
      partes.add('$casosConflito em conflito');
    }
    if (fotosFalhas > 0) {
      partes.add('$fotosFalhas foto(s) pendente(s)');
    }

    final resumo = partes.join(', ');
    return SyncResult(
      casosEnviados: casosEnviados,
      casosRecebidos: casosRecebidos,
      fotosEnviadas: fotosEnviadas,
      casosConflito: casosConflito,
      fotosFalhas: fotosFalhas,
      temPendencias: true,
      mensagem: 'Sincronização parcial: $resumo.',
    );
  }
}

/// ServiÃ§o de domÃ­nio encarregado da [SincronizaÃ§Ã£o] e conformidade dos dados periciais do IML.
///
/// Ele garante que a [Cadeia de CustÃ³dia] dos [Caso]s (Laudos) e suas respectivas [EvidÃªncia FotogrÃ¡fica]s
/// seja mantida Ã­ntegra, realizando o envio em lote de dados textuais e arquivos de imagem binÃ¡rios
/// para o servidor central atravÃ©s do [IRemoteDataSource].
class SyncService {
  final IRemoteDataSource _remoteDataSource;
  final ISyncRepository _repository;
  final AuthService? _authService;
  final KeyStorageInterface _keyStorage;

  SyncService({
    required IRemoteDataSource remoteDataSource,
    required ISyncRepository repository,
    AuthService? authService,
    KeyStorageInterface? keyStorage,
  }) : _remoteDataSource = remoteDataSource,
       _repository = repository,
       _authService = authService,
       _keyStorage = keyStorage ?? SecureKeyStorage();

  final Set<String> _uuidsEmTransito = {};
  bool _isSyncing = false;

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
  /// Valida a conectividade real através de health check preliminar para evitar falsos positivos
  /// quando o backend estiver inoperante. Realiza o pull dos casos remotos atualizados e o push
  /// em lote dos laudos pendentes (JSON, mídias e relatórios PDF).
  Future<SyncResult> execute() async {
    if (_isSyncing) {
      debugPrint(
        '[SyncService] Sincronização já em andamento. Abortando duplo-clique.',
      );
      return const SyncResult(
        casosEnviados: 0,
        casosRecebidos: 0,
        fotosEnviadas: 0,
        casosConflito: 0,
        fotosFalhas: 0,
        temPendencias: false,
        mensagem: 'Sincronização em processamento.',
      );
    }
    _isSyncing = true;
    try {
      debugPrint('[SyncService] Iniciando sincronização...');

      final isServerAlive = await _remoteDataSource.checkHealth();
      if (!isServerAlive) {
        throw const SyncNetworkException(
          'Servidor central indisponível. Verifique se o backend está ativo e acessível na rede.',
        );
      }

      final usuarioId = _authService?.usuario?.id;
      if (usuarioId == null || usuarioId.isEmpty) {
        throw const AuthException(
          'Nenhum perito autenticado para sincronizar laudos.',
        );
      }

      final int casosRecebidos = await _pullCasosInternal();

      final List<Caso> casosParaEnviar = await _repository
          .getCasosPendentesSync(usuarioId);

      if (casosParaEnviar.isEmpty) {
        debugPrint(
          '[SyncService] Nenhum caso pendente de sincronização para envio.',
        );
        return SyncResult.sucesso(casosRecebidos: casosRecebidos);
      }

      debugPrint(
        '[SyncService] Preparando push sequencial de ${casosParaEnviar.length} casos pendentes.',
      );

      final Map<String, dynamic> syncResult;
      try {
        debugPrint(
          '[SyncService] Fazendo push textual (Bulk) de ${casosParaEnviar.length} casos...',
        );
        syncResult = await _pushTextual(casosParaEnviar);
      } on DioException catch (e, stackTrace) {
        if (_isSessionExpiredError(e)) {
          rethrow;
        }
        await Sentry.captureException(e, stackTrace: stackTrace);
        throw SyncNetworkException(
          'Falha de rede ao transmitir laudos para a central: ${e.message ?? 'conexão interrompida'}',
          statusCode: e.response?.statusCode,
        );
      } on SyncPushTextualException catch (e, stackTrace) {
        await Sentry.captureException(e, stackTrace: stackTrace);
        rethrow;
      } catch (e, stackTrace) {
        await Sentry.captureException(e, stackTrace: stackTrace);
        throw SyncException('Erro inesperado na transmissão dos laudos: $e');
      }

      final conflitosUuids = Set<String>.from(
        syncResult['conflitos'] ?? const <String>[],
      );
      final salvosUuids = Set<String>.from(
        syncResult['casos_salvos'] ?? const <String>[],
      );

      int totalCasosConflito = conflitosUuids.length;
      int totalFotosFalhas = 0;
      int totalFotosEnviadas = 0;
      int casosEnviadosComSucesso = 0;

      for (final caso in casosParaEnviar) {
        if (_authService != null && !_authService.isLogged) {
          throw const AuthException(
            'Sessão expirada durante o ciclo de envio.',
          );
        }

        if (conflitosUuids.contains(caso.uuid) ||
            !salvosUuids.contains(caso.uuid)) {
          debugPrint(
            '[SyncService] Caso ${caso.uuid} em conflito ou rejeitado no Passo 1 (JSON). Pulando mídias e PDFs (Fail-Fast).',
          );
          await _repository.marcarCasoComErroDeSincronizacao(caso.uuid);
          continue;
        }

        bool falhaNoCaso = false;

        final List<Map<String, dynamic>> evidenciasPendentes = await _repository
            .getEvidenciasPendentesPorCaso(caso.uuid);

        for (final ev in evidenciasPendentes) {
          try {
            final filePath = ev['caminho_arquivo_encriptado'] as String? ?? '';
            if (filePath.isEmpty) continue;

            final file = File(filePath);
            if (!await file.exists()) {
              debugPrint(
                '[SyncService] Arquivo de evidência não encontrado em disco: $filePath',
              );
              falhaNoCaso = true;
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
            totalFotosEnviadas++;
          } on DioException catch (e, stackTrace) {
            falhaNoCaso = true;
            totalFotosFalhas++;
            if (_isSessionExpiredError(e)) {
              rethrow;
            }
            debugPrint(
              '[SyncService] Falha de rede ao subir mídia ${ev['evidencia_uuid']}: $e',
            );
            await Sentry.captureException(e, stackTrace: stackTrace);
          } catch (e, stackTrace) {
            falhaNoCaso = true;
            totalFotosFalhas++;
            debugPrint(
              '[SyncService] Falha inesperada ao subir mídia ${ev['evidencia_uuid']}: $e',
            );
            await Sentry.captureException(e, stackTrace: stackTrace);
          }
        }

        Caso casoAtualizado = caso;
        if (!falhaNoCaso) {
          try {
            casoAtualizado = await _sincronizarPdfCaso(caso);
          } on DioException catch (e, stackTrace) {
            falhaNoCaso = true;
            if (_isSessionExpiredError(e)) rethrow;
            debugPrint(
              '[SyncService] Falha de rede ao enviar PDF do caso ${caso.uuid}: $e',
            );
            await Sentry.captureException(e, stackTrace: stackTrace);
          } catch (e, stackTrace) {
            falhaNoCaso = true;
            debugPrint(
              '[SyncService] Falha inesperada ao enviar PDF do caso ${caso.uuid}: $e',
            );
            await Sentry.captureException(e, stackTrace: stackTrace);
          }
        }

        if (!falhaNoCaso) {
          try {
            if (caso.status == StatusCaso.finalizado) {
              await _confirmarCaso(casoAtualizado);
            } else {
              await _repository.marcarRascunhoComoSincronizado(caso.uuid);
            }
            casosEnviadosComSucesso++;
          } catch (e, stackTrace) {
            debugPrint(
              '[SyncService] Erro inesperado ao confirmar caso ${caso.uuid}: $e',
            );
            SentryHelper.setSyncErrorTag(caso.uuid);
            await Sentry.captureException(e, stackTrace: stackTrace);
            await _repository.marcarCasoComErroDeSincronizacao(caso.uuid);
          }
        } else {
          await _repository.marcarCasoComErroDeSincronizacao(caso.uuid);
        }
      }

      debugPrint('[SyncService] Ciclo concluído.');

      if (totalCasosConflito > 0 || totalFotosFalhas > 0) {
        if (casosEnviadosComSucesso == 0) {
          throw SyncException(
            'Falha na sincronização: nenhum laudo pôde ser concluído ($totalCasosConflito conflito(s), $totalFotosFalhas falha(s) de mídia).',
          );
        }
        return SyncResult.parcial(
          casosEnviados: casosEnviadosComSucesso,
          casosRecebidos: casosRecebidos,
          fotosEnviadas: totalFotosEnviadas,
          casosConflito: totalCasosConflito,
          fotosFalhas: totalFotosFalhas,
        );
      }

      return SyncResult.sucesso(
        casosEnviados: casosEnviadosComSucesso,
        casosRecebidos: casosRecebidos,
        fotosEnviadas: totalFotosEnviadas,
      );
    } finally {
      _isSyncing = false;
    }
  }

  VoidCallback? onPullCompleted;

  /// Baixa casos da base central e sincroniza localmente através de Upsert com resolução de conflito.
  Future<void> pullCasos() async {
    if (_isSyncing) {
      debugPrint(
        '[SyncService] Sincronização já em andamento. Abortando pullCasos.',
      );
      return;
    }
    _isSyncing = true;
    try {
      await _pullCasosInternal();
    } finally {
      _isSyncing = false;
    }
  }

  /// Executa internamente o procedimento de Pull garantindo reutilização de thread sem conflito de locks.
  Future<int> _pullCasosInternal() async {
    debugPrint('[SyncService] Iniciando Pull Synchronization...');
    try {
      final lastSync = await _keyStorage.read(key: 'last_sync_timestamp');

      final casosRemotos = await _remoteDataSource.pullCasos(
        lastSyncTimestamp: lastSync,
      );

      if (casosRemotos.isEmpty) {
        debugPrint('[SyncService] Nenhum caso recebido no pull.');
        return 0;
      }

      debugPrint(
        '[SyncService] Recebidos ${casosRemotos.length} caso(s) remoto(s) para sincronização local.',
      );
      String? lastSuccessfulSyncTimestamp;

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
                '[SyncService] Não foi possível registrar sync_error para $casoUuid: $markError\n$markStackTrace',
              );
            }
          }
          continue;
        }
      }

      if (lastSuccessfulSyncTimestamp != null) {
        await _keyStorage.save(
          key: 'last_sync_timestamp',
          value: lastSuccessfulSyncTimestamp,
        );
      }

      debugPrint('[SyncService] Pull Synchronization concluído com sucesso.');
      onPullCompleted?.call();
      return casosRemotos.length;
    } on DioException catch (e, stackTrace) {
      if (_isSessionExpiredError(e)) {
        debugPrint('[SyncService] Sessão expirada (401) no Pull. Abortando.');
        rethrow;
      }
      debugPrint('[SyncService] Falha na rede durante o Pull: $e\n$stackTrace');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[SyncService] Erro inesperado no Pull: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Dispara a sincronizaÃ§Ã£o silenciosa de um novo rascunho de caso para rastreamento no backend.
  /// NÃ£o bloqueia a interface. Caso falhe por queda de rede, a marcaÃ§Ã£o `is_draft_synced = 0` no SQLite
  /// garante o reenvio automÃ¡tico assim que a conectividade retornar.
  Future<void> pushCasoRascunho(Caso caso) async {
    if (_uuidsEmTransito.contains(caso.uuid)) {
      debugPrint(
        '[SyncService] ⏸️ Caso ${caso.uuid} já em trânsito. Ignorando push duplicado.',
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

      final achados = await _repository.getAchadosPorCaso(caso.uuid);
      final casoJson = await _casoParaJson(caso, achados);
      final deviceId = await DeviceInfoService.getDeviceId();

      final payload = {
        'device_id': deviceId,
        'timestamp_sincronizacao': DateTime.now().toUtc().toIso8601String(),
        'casos': [casoJson],
      };

      final response = await _remoteDataSource.pushTextual(payload);

      final salvosUuids = Set<String>.from(
        response['casos_salvos'] ?? const <String>[],
      );
      final conflitosUuids = Set<String>.from(
        response['conflitos'] ?? const <String>[],
      );

      if (!salvosUuids.contains(caso.uuid) ||
          conflitosUuids.contains(caso.uuid)) {
        debugPrint(
          '[SyncService] ⚠️ Caso ${caso.uuid} em conflito ou rejeitado no Passo 1 (JSON). Pulando mídias e PDFs (Fail-Fast).',
        );
        return;
      }

      final evidenciasPendentes = await _repository
          .getEvidenciasPendentesPorCaso(caso.uuid);
      for (final ev in evidenciasPendentes) {
        try {
          final filePath = ev['caminho_arquivo_encriptado'] as String? ?? '';
          if (filePath.isEmpty) continue;

          final file = File(filePath);
          if (!await file.exists()) continue;

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
        } catch (e, stackTrace) {
          debugPrint(
            '[SyncService] ⚠️ Erro no upload de mídia de rascunho ${ev['evidencia_uuid']}: $e',
          );
          await Sentry.captureException(e, stackTrace: stackTrace);
        }
      }

      await _sincronizarPdfCaso(caso);

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
      final achados = achadosPorCaso[caso.uuid] ?? [];
      casosJson.add(await _casoParaJson(caso, achados));
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
            '[SyncService] ðŸ“„ Fazendo upload fÃ­sico do Laudo PDF: ${caso.pdfLocalPath}',
          );
          final pdfUrl = await _remoteDataSource.uploadLaudoPdf(
            casoUuid: caso.uuid,
            filePath: pdfFile.path,
          );
          await _repository.atualizarPdfUrl(caso.uuid, pdfUrl);
          await Sentry.captureMessage(
            'Upload do Laudo concluÃ­do com sucesso: ${caso.uuid}',
            level: SentryLevel.info,
          );
          return caso.copyWith(pdfUrl: pdfUrl);
        } catch (e, stackTrace) {
          debugPrint(
            '[SyncService] âš ï¸ Erro ao fazer upload do PDF para o caso ${caso.uuid}: $e',
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
      'ðŸ” [AUDITORIA 3 - JSON DART] NÃ³ exames_solicitados gerado: ${jsonEncode(payload['exames_solicitados'])}',
    );
    payload['diagramas'] = diagramasJson;
    payload['achados'] = achados.map(_achadoParaJson).toList();

    return payload;
  }

  Map<String, dynamic> _achadoParaJson(Achado achado) {
    return achado.toSyncMap();
  }
}

/// FunÃ§Ã£o pura e estÃ¡tica executada em uma Isolate secundÃ¡ria (Background Thread).
///
/// Otimiza a ingestÃ£o massiva de dados do servidor central (GET /pull), transferindo o parsing
/// e a alocaÃ§Ã£o de memÃ³ria (jsonDecode, factory instantiations) para fora da Main Thread,
/// evitando cenÃ¡rios severos de 'UI Jank' ou travamentos durante a sincronizaÃ§Ã£o Offline-First.
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
              !todasBalisticas.any(
                (b) =>
                    b.id.trim().toLowerCase() == bModel.id.trim().toLowerCase(),
              )) {
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
          final detBalisticaId = deterministicUuidV5(
            achadoBackend.uuid,
            'balistica',
          ).toLowerCase();
          final legacyDetBalisticaId = deterministicUuidV4(
            achadoBackend.uuid,
            'balistica',
          ).toLowerCase();

          BalisticaModel? matchedBalistica =
              (detBalisticaId.isNotEmpty
                  ? balisticasById[detBalisticaId]
                  : null) ??
              (legacyDetBalisticaId.isNotEmpty
                  ? balisticasById[legacyDetBalisticaId]
                  : null);
          matchedBalistica ??= balisticasByAchadoUuid[achadoUuidLower];
          matchedBalistica ??= balisticasByExameId[achadoUuidLower];
          matchedBalistica ??= balisticasById[achadoUuidLower];
          if (matchedBalistica == null) {
            for (final b in todasBalisticas) {
              final bId = b.id.trim().toLowerCase();
              final bAchado = b.achadoUuid?.trim().toLowerCase();
              final bExame = b.exameId.trim().toLowerCase();
              if ((detBalisticaId.isNotEmpty && bId == detBalisticaId) ||
                  (legacyDetBalisticaId.isNotEmpty &&
                      bId == legacyDetBalisticaId) ||
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
                      matchedBalistica.numeroLacre ?? achadoBackend.numeroLacre,
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

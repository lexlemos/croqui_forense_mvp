import 'dart:io';


import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:dio/dio.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';
import 'package:croqui_forense_mvp/domain/services/domain_sync_service.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';

/// Contrato de repositório local responsável pelas operações de leitura e atualização
/// de integridade dos [Caso]s (Laudos) e seus respectivos [Achado]s durante o processo de sincronização.
abstract interface class ISyncRepository {
  /// Obtém todos os [Caso]s (Laudos) finalizados que ainda não foram sincronizados com o servidor central.
  Future<List<Caso>> getCasosNaoSincronizados();

  /// Obtém todos os [Caso]s em rascunho com `is_draft_synced = 0` pendentes de envio.
  Future<List<Caso>> getRascunhosNaoSincronizados();

  /// Recupera todas as lesões corporais ([Achado]s) associadas a um determinado [Caso] pelo seu identificador único.
  Future<List<Achado>> getAchadosPorCaso(String casoUuid);

  /// Recupera em lote todos os [Achado]s pertencentes aos identificadores de [Caso]s informados.
  Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids);

  /// Retorna as lesões que possuem [Evidência Fotográfica] capturada no tablet mas que ainda não foram sincronizadas com o servidor.
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(List<String> casoUuids);

  /// Atualiza o status local do [Caso] (Laudo) para marcado como sincronizado no banco de dados.
  Future<void> marcarCasoComoSincronizado(Caso caso);

  /// Atualiza a marcação local de um rascunho como sincronizado no SQLite (`is_draft_synced = 1`).
  Future<void> marcarRascunhoComoSincronizado(String casoUuid);

  /// Atualiza o status local da [Evidência Fotográfica] de um [Achado] para marcado como sincronizada.
  Future<void> marcarFotoComoSincronizada(Achado achado);

  /// Recupera as lesões com fotos pendentes de sincronização para um caso específico.
  Future<List<Achado>> getEvidenciasPendentesPorCaso(String casoUuid);

  /// Motor de Upsert (Sincronização Pull). Resolve conflitos e insere/atualiza casos, achados e evidências.
  Future<void> upsertCasoTransaction(Map<String, dynamic> jsonCaso);
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

// Função utilitária removida: _readAndEncodePdfBase64 (agora o PDF é enviado como arquivo físico)

/// Serviço de domínio encarregado da [Sincronização] e conformidade dos dados periciais do IML.
///
/// Ele garante que a [Cadeia de Custódia] dos [Caso]s (Laudos) e suas respectivas [Evidência Fotográfica]s
/// seja mantida íntegra, realizando o envio em lote de dados textuais e arquivos de imagem binários
/// para o servidor central através do [IRemoteDataSource].
class SyncService {
  final IRemoteDataSource _remoteDataSource;
  final ISyncRepository _repository;
  final DomainSyncService? _domainSyncService;
  final AuthService? _authService;

  SyncService({
    required IRemoteDataSource remoteDataSource,
    required ISyncRepository repository,
    DomainSyncService? domainSyncService,
    AuthService? authService,
  })  : _remoteDataSource = remoteDataSource,
        _repository = repository,
        _domainSyncService = domainSyncService,
        _authService = authService;

  final Set<String> _uuidsEmTransito = {};

  /// Executa o fluxo completo de sincronização pericial do dispositivo com a central.
  ///
  /// Busca todos os laudos locais e rascunhos pendentes de envio, faz o push textual agregado de toda a carga de dados,
  /// e então executa o upload em lote de cada [Evidência Fotográfica] associada. Ao fim do envio bem-sucedido
  /// das fotos e dos dados textuais, atualiza a marcação no repositório local.
  bool _isSessionExpiredError(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403 || error.error is SessionExpiredException) {
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
    debugPrint('[SyncService] Iniciando sincronização...');

    // Fase 0: Atualização periódica de referência dos A.T.N.s do backend (resiliente offline)
    try {
      await _domainSyncService?.syncAtns();
    } on DioException catch (e) {
      if (_isSessionExpiredError(e)) {
        debugPrint('[SyncService] 🛑 Sessão expirada (401) ao sincronizar ATNs. Abortando ciclo de sincronização.');
        rethrow;
      }
      debugPrint('[SyncService] ⚠️ Falha na atualização periódica de ATNs: $e');
    } catch (e) {
      debugPrint('[SyncService] ⚠️ Falha na atualização periódica de ATNs: $e');
    }

    // Fase 0.05: Pull de Casos Remotos para evitar conflitos
    try {
      await pullCasos();
    } on DioException catch (e) {
      if (_isSessionExpiredError(e)) {
        debugPrint('[SyncService] 🛑 Sessão expirada (401) no pull de casos. Abortando ciclo.');
        rethrow;
      }
      debugPrint('[SyncService] ⚠️ Falha no pull de casos: $e');
    } catch (e) {
      debugPrint('[SyncService] ⚠️ Falha no pull de casos: $e');
    }

    // Fase 0.1: Push textual de rascunhos não sincronizados pendentes
    final rascunhosPendentes = await _repository.getRascunhosNaoSincronizados();
    if (rascunhosPendentes.isNotEmpty) {
      debugPrint('[SyncService] 🔄 Encontrados ${rascunhosPendentes.length} rascunho(s) pendente(s) de envio. Processando...');
      for (final rascunho in rascunhosPendentes) {
        if (_authService != null && !_authService.isLogged) {
          debugPrint('[SyncService] 🛑 Sessão nula. Abortando fila de rascunhos prematuramente.');
          return;
        }
        try {
          await pushCasoRascunho(rascunho);
        } on DioException catch (e) {
          if (_isSessionExpiredError(e)) {
            debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no push de rascunho. Abortando ciclo de sincronização.');
            return;
          }
        } catch (e) {
          if (_isSessionExpiredError(e)) {
            debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no push de rascunho. Abortando ciclo de sincronização.');
            return;
          }
        }
      }
    }

    final List<Caso> casosPendentes = await _repository.getCasosNaoSincronizados();

    if (casosPendentes.isEmpty) {
      debugPrint('[SyncService] Nenhum caso finalizado pendente de sincronização.');
      return;
    }

    debugPrint('[SyncService] ${casosPendentes.length} caso(s) finalizado(s) pendente(s).');

    int totalFotosFalhas = 0;
    int totalCasosConflito = 0;

    // Fila FIFO Segura: Processa os casos finalizados UM POR UM sequencialmente (evita sobrecarga de rede 3G/4G).
    for (final caso in casosPendentes) {
      if (_authService != null && !_authService.isLogged) {
        debugPrint('[SyncService] 🛑 Sessão nula. Abortando fila de casos finalizados prematuramente.');
        return;
      }
      try {
        debugPrint('[SyncService] 📦 Processando sincronização do caso ${caso.uuid}...');

        // Fase 1: Push textual de metadados (JSON) para o caso específico
        final syncResult = await _pushTextual([caso]);
        final conflitosUuids = List<String>.from(syncResult['conflitos'] ?? []);
        if (conflitosUuids.contains(caso.uuid)) {
          debugPrint('[SyncService] ⚠️ Caso ${caso.uuid} em conflito no servidor central.');
          totalCasosConflito++;
          continue;
        }

        // Fase 2: Upload das evidências fotográficas do caso
        final fotos = await _repository.getEvidenciasPendentesPorCaso(caso.uuid);
        final falhasNoCaso = await _processarCaso(caso, fotos);
        totalFotosFalhas += falhasNoCaso;

      } on DioException catch (e) {
        if (_isSessionExpiredError(e)) {
          debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no envio do caso ${caso.uuid}. Abortando fila.');
          return;
        }
        debugPrint('[SyncService] ⚠️ Falha na rede ao enviar o caso ${caso.uuid}: $e');
        totalFotosFalhas++;
      } catch (e) {
        if (_isSessionExpiredError(e)) {
          debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no envio do caso ${caso.uuid}. Abortando fila.');
          return;
        }
        debugPrint('[SyncService] ⚠️ Erro inesperado no caso ${caso.uuid}: $e');
        totalFotosFalhas++;
      }
    }

    debugPrint('[SyncService] Ciclo concluído.');

    if (totalCasosConflito > 0 || totalFotosFalhas > 0) {
      final List<String> erros = [];
      if (totalCasosConflito > 0) {
        erros.add('$totalCasosConflito caso(s) em conflito no servidor central.');
      }
      if (totalFotosFalhas > 0) {
        erros.add('falha ao enviar $totalFotosFalhas item(ns).');
      }
      throw Exception('Sincronização parcial: ${erros.join(" e ")}');
    }
  }

  /// Baixa casos da base central e sincroniza localmente através de Upsert com resolução de conflito.
  Future<void> pullCasos() async {
    debugPrint('[SyncService] Iniciando Pull Synchronization...');
    try {
      final casosRemotos = await _remoteDataSource.pullCasos();
      
      if (casosRemotos.isEmpty) {
        debugPrint('[SyncService] Nenhum caso recebido no pull.');
        return;
      }
      
      debugPrint('[SyncService] Recebidos ${casosRemotos.length} caso(s) remoto(s) para sincronização local.');
      
      for (final casoJson in casosRemotos) {
        try {
          await _repository.upsertCasoTransaction(casoJson);
        } catch (e) {
          debugPrint('[SyncService] Erro ao sincronizar (upsert) o caso ${casoJson['uuid']}: $e');
          // Continua para o próximo caso
        }
      }
      debugPrint('[SyncService] Pull Synchronization concluído com sucesso.');
    } on DioException catch (e) {
      if (_isSessionExpiredError(e)) {
        debugPrint('[SyncService] 🛑 Sessão expirada (401) no Pull. Abortando.');
        rethrow;
      }
      debugPrint('[SyncService] ⚠️ Falha na rede durante o Pull: $e');
      rethrow;
    } catch (e) {
      debugPrint('[SyncService] ⚠️ Erro inesperado no Pull: $e');
      rethrow;
    }
  }

  /// Dispara a sincronização silenciosa de um novo rascunho de caso para rastreamento no backend.
  /// Não bloqueia a interface. Caso falhe por queda de rede, a marcação `is_draft_synced = 0` no SQLite
  /// garante o reenvio automático assim que a conectividade retornar.
  Future<void> pushCasoRascunho(Caso caso) async {
    if (_uuidsEmTransito.contains(caso.uuid)) {
      debugPrint('[SyncService] ⏭️ Caso ${caso.uuid} já em trânsito. Ignorando push duplicado.');
      return;
    }
    _uuidsEmTransito.add(caso.uuid);

    try {
      debugPrint('[SyncService] 🚀 Disparando push silencioso de rascunho para o caso ${caso.uuid}...');
      
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
      debugPrint('[SyncService] ✅ Push silencioso do rascunho ${caso.uuid} concluído e marcado como sincronizado.');
    } catch (e) {
      if (_isSessionExpiredError(e)) {
        debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no push silencioso do rascunho. Abortando.');
        rethrow;
      }
      debugPrint('[SyncService] ⚠️ Push silencioso do rascunho falhou (dispositivo offline ou servidor indisponível): $e');
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
        debugPrint('[SyncService] 🛑 Sessão nula. Abortando upload de fotos prematuramente.');
        throw SessionExpiredException();
      }
      try {
        // Envio individual (loop) via multipart/form-data
        await _uploadEvidencia(caso, achado);
        achadosSincronizados.add(achado);
        // Idempotência Local: Marcar a foto como sincronizada imediatamente após sucesso individual
        await _repository.marcarFotoComoSincronizada(achado);
      } catch (e) {
        if (_isSessionExpiredError(e)) {
          debugPrint('[SyncService] 🛑 Sessão expirada (401/403) no upload de foto. Abortando.');
          rethrow;
        }
        // Captura timeouts de rede (como DioExceptionType.connectionTimeout) e erros de rede gerais
        erros.add(e);
        debugPrint('[SyncService] Upload falhou para o achado ${achado.uuid} no caso ${caso.uuid}: $e');
      }
    }

    if (erros.isEmpty) {
      // Sincronização atômica: Só confirma o caso se JSON (Fase 1) e todas as fotos (Fase 2) subiram
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
    if (caminhoFoto == null || caminhoFoto.isEmpty) return;

    final File arquivoOriginal = File(caminhoFoto);
    if (!arquivoOriginal.existsSync()) return;

    final bytes = await arquivoOriginal.readAsBytes();
    final String hashOriginal = sha256.convert(bytes).toString();

    // Extração do uuid da evidência
    final String evidenciaUuid =
        achado.dadosPreenchidos['_evidencia_uuid']?.toString() ?? achado.uuid;

    final bool isFotoGeral = achado.tipoAchadoId == 'FOTO_GERAL' || achado.diagramaNome == 'GERAL';

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
    if (caso.pdfLocalPath != null && caso.pdfLocalPath!.isNotEmpty) {
      final pdfFile = File(caso.pdfLocalPath!);
      if (pdfFile.existsSync()) {
        try {
          debugPrint('[SyncService] 📄 Fazendo upload físico do Laudo PDF: ${caso.pdfLocalPath}');
          final pdfUrl = await _remoteDataSource.uploadLaudoPdf(
            casoUuid: caso.uuid,
            filePath: pdfFile.path,
          );
          return caso.copyWith(pdfUrl: pdfUrl);
        } catch (e) {
          debugPrint('[SyncService] ⚠️ Erro ao fazer upload do PDF para o caso ${caso.uuid}: $e');
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

  Future<Map<String, dynamic>> _casoParaJson(Caso caso, List<Achado> achados) async {
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
        'atualizado_em': (caso.atualizadoEm ?? caso.criadoEmDispositivo).toUtc().toIso8601String(),
      });
    }

    // Remoção da leitura em Base64 do PDF.
    // A propriedade pdfUrl já estará preenchida no caso se o upload físico ocorreu com sucesso antes dessa serialização.

    return {
      'uuid': caso.uuid,
      'id_usuario_criador': caso.idUsuarioCriador,
      'versao': caso.versao,
      'removido': caso.removido,
      'status': caso.status.name.toUpperCase(),
      'numero_laudo_externo': caso.numeroLaudoExterno,
      'dados_laudo_json': caso.dadosLaudo,
      'device_id': caso.deviceId,
      'criado_em_dispositivo': caso.criadoEmDispositivo.toUtc().toIso8601String(),
      'atualizado_em': (caso.atualizadoEm ?? caso.criadoEmDispositivo).toUtc().toIso8601String(),
      'finalizado_em': caso.finalizadoEm?.toUtc().toIso8601String(),
      'numero_pic': caso.numeroPic,
      'numero_bo': caso.numeroBo,
      'numero_requisicao': caso.numeroRequisicao,
      'nome_vitima': caso.nomeVitima,
      'destino': caso.destino,
      'requisitante': caso.requisitante,
      'atn_id': caso.atnId,
      'atn_responsavel': caso.atnResponsavel,
      'pdf_local_path': caso.pdfLocalPath,
      'pdf_url': caso.pdfUrl,
      'diagramas': diagramasJson,
      'achados': achados.map(_achadoParaJson).toList(),
    };
  }

  Map<String, dynamic> _achadoParaJson(Achado achado) {
    return achado.toSyncMap();
  }
}

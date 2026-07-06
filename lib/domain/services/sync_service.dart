import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

/// Contrato de repositório local responsável pelas operações de leitura e atualização
/// de integridade dos [Caso]s (Laudos) e seus respectivos [Achado]s durante o processo de sincronização.
abstract interface class ISyncRepository {
  /// Obtém todos os [Caso]s (Laudos) finalizados ou rascunhos que ainda não foram sincronizados com o servidor central.
  Future<List<Caso>> getCasosNaoSincronizados();

  /// Recupera todas as lesões corporais ([Achado]s) associadas a um determinado [Caso] pelo seu identificador único.
  Future<List<Achado>> getAchadosPorCaso(String casoUuid);

  /// Recupera em lote todos os [Achado]s pertencentes aos identificadores de [Caso]s informados.
  Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids);

  /// Retorna as lesões que possuem [Evidência Fotográfica] capturada no tablet mas que ainda não foram sincronizadas com o servidor.
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(List<String> casoUuids);

  /// Atualiza o status local do [Caso] (Laudo) para marcado como sincronizado no banco de dados.
  Future<void> marcarCasoComoSincronizado(Caso caso);

  /// Atualiza o status local da [Evidência Fotográfica] de um [Achado] para marcado como sincronizada.
  Future<void> marcarFotoComoSincronizada(Achado achado);

  /// Recupera as lesões com fotos pendentes de sincronização para um caso específico.
  Future<List<Achado>> getEvidenciasPendentesPorCaso(String casoUuid);
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
  final String achadoUuid;
  final int? statusCode;

  const SyncUploadEvidenciaException(
    this.message, {
    required this.casoUuid,
    required this.achadoUuid,
    this.statusCode,
  });

  @override
  String toString() =>
      'SyncUploadEvidenciaException(caso: $casoUuid, achado: $achadoUuid, '
      'status: $statusCode): $message';
}

/// Serviço de domínio encarregado da [Sincronização] e conformidade dos dados periciais do IML.
///
/// Ele garante que a [Cadeia de Custódia] dos [Caso]s (Laudos) e suas respectivas [Evidência Fotográfica]s
/// seja mantida íntegra, realizando o envio em lote de dados textuais e arquivos de imagem binários
/// para o servidor central através do [IRemoteDataSource].
class SyncService {
  final IRemoteDataSource _remoteDataSource;
  final ISyncRepository _repository;

  SyncService({
    required IRemoteDataSource remoteDataSource,
    required ISyncRepository repository,
  })  : _remoteDataSource = remoteDataSource,
        _repository = repository;

  /// Executa o fluxo completo de sincronização pericial do dispositivo com a central.
  ///
  /// Busca todos os laudos locais pendentes de envio, faz o push textual agregado de toda a carga de dados,
  /// e então executa o upload em lote de cada [Evidência Fotográfica] associada. Ao fim do envio bem-sucedido
  /// das fotos e dos dados textuais, atualiza a marcação no repositório local.
  ///
  /// @throws [SyncPushTextualException] se o envio inicial dos dados dos laudos falhar ou for recusado no servidor.
  /// @throws [SyncUploadEvidenciaException] se o upload de alguma evidência fotográfica falhar durante a transmissão.
  Future<void> execute() async {
    debugPrint('[SyncService] Iniciando sincronização...');

    final List<Caso> casosPendentes =
        await _repository.getCasosNaoSincronizados();

    if (casosPendentes.isEmpty) return;

    debugPrint('[SyncService] ${casosPendentes.length} caso(s) pendente(s).');

    // Fase 1: Push textual de metadados (JSON)
    await _pushTextual(casosPendentes);

    int totalFotosFalhas = 0;

    // Fase 2: Upload individual das evidências fotográficas (idempotência local)
    for (final caso in casosPendentes) {
      final fotos = await _repository.getEvidenciasPendentesPorCaso(caso.uuid);
      final falhasNoCaso = await _processarCaso(caso, fotos);
      totalFotosFalhas += falhasNoCaso;
    }

    debugPrint('[SyncService] Ciclo concluído.');

    if (totalFotosFalhas > 0) {
      throw Exception('Metadados enviados, mas falha ao enviar $totalFotosFalhas fotos.');
    }
  }

  Future<void> _pushTextual(List<Caso> casos) async {
    final achadosPorCaso = await _repository.getAchadosEmLote(
      casos.map((c) => c.uuid).toList(),
    );

    final List<Map<String, dynamic>> casosJson = [];
    for (final caso in casos) {
      final achados = achadosPorCaso[caso.uuid] ?? [];
      casosJson.add(_casoParaJson(caso, achados));
    }

    final deviceId = await DeviceInfoService.getDeviceId();
    final payload = {
      'device_id': deviceId,
      'timestamp_sincronizacao': DateTime.now().toUtc().toIso8601String(),
      'casos': casosJson,
    };

    await _remoteDataSource.pushTextual(payload);
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
      try {
        // Envio individual (loop) via multipart/form-data
        await _uploadEvidencia(caso, achado);
        achadosSincronizados.add(achado);
        // Idempotência Local: Marcar a foto como sincronizada imediatamente após sucesso individual
        await _repository.marcarFotoComoSincronizada(achado);
      } catch (e) {
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

    // Null check na extração do uuid da evidência
    final String evidenciaUuid = (achado.dadosPreenchidos != null
        ? achado.dadosPreenchidos['_evidencia_uuid']?.toString()
        : null) ?? achado.uuid;

    await _remoteDataSource.uploadEvidencia(
      casoUuid: caso.uuid,
      achadoUuid: achado.uuid,
      evidenciaUuid: evidenciaUuid,
      hash: hashOriginal,
      filePath: arquivoOriginal.path,
    );
  }

  Future<void> _confirmarCaso(Caso caso) async {
    await _repository.marcarCasoComoSincronizado(caso);
  }

  Map<String, dynamic> _casoParaJson(Caso caso, List<Achado> achados) {
    return {
      'uuid': caso.uuid,
      'id_usuario_criador': caso.idUsuarioCriador,
      'numero_laudo_externo': caso.numeroLaudoExterno,
      'status': caso.status.name.toUpperCase(),
      'dados_laudo_json': caso.dadosLaudo,
      'versao': caso.versao,
      'criado_em_dispositivo': caso.criadoEmDispositivo.toUtc().toIso8601String(),
      'device_id': caso.deviceId,
      'removido': caso.removido,
      'atualizado_em': (caso.atualizadoEm ?? caso.criadoEmDispositivo).toUtc().toIso8601String(),
      'criado_em_rede_confiavel': caso.criadoEmRedeConfiavel?.toUtc().toIso8601String(),
      'proveniencia': caso.proveniencia,
      'achados': achados.map(_achadoParaJson).toList(),
    };
  }

  Map<String, dynamic> _achadoParaJson(Achado achado) {
    return {
      'uuid': achado.uuid,
      'caso_uuid': achado.casoUuid,
      'diagrama_nome': achado.diagramaNome,
      'tipo_achado_id': achado.tipoAchadoId,
      'numero_sequencial': achado.numeroSequencial,
      'pos_x': achado.posX.toDouble(),
      'pos_y': achado.posY.toDouble(),
      'is_interno': achado.isInterno,
      'dados_preenchidos_json': achado.dadosPreenchidos,
      'observacoes_texto': achado.observacoesTexto,
      'versao': achado.versao,
      'criado_em': achado.criadoEm.toUtc().toIso8601String(),
      'device_id': achado.deviceId,
      'removido': achado.removido, 
      'atualizado_em': (achado.atualizadoEm ?? achado.criadoEm).toUtc().toIso8601String(),
    };
  }
}

  // lib/domain/services/sync_service.dart

  import 'dart:io';

  import 'package:crypto/crypto.dart';
  import 'package:dio/dio.dart';
  import 'package:flutter/foundation.dart';
  import 'package:http_parser/http_parser.dart';
  import 'package:path/path.dart' as p;

  import 'package:croqui_forense_mvp/core/network/api_client.dart';
  import 'package:croqui_forense_mvp/data/models/caso_model.dart';
  import 'package:croqui_forense_mvp/data/models/achado_model.dart';
  import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';

  abstract interface class ISyncRepository {
    Future<List<Caso>> getCasosNaoSincronizados();
    Future<List<Achado>> getAchadosPorCaso(String casoUuid);
    Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids);
    Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(List<String> casoUuids);
    Future<void> marcarCasoComoSincronizado(Caso caso);
    Future<void> marcarFotoComoSincronizada(Achado achado);
  }

  class SyncPushTextualException implements Exception {
    final String message;
    final int? statusCode;

    const SyncPushTextualException(this.message, {this.statusCode});

    @override
    String toString() =>
        'SyncPushTextualException(status: $statusCode): $message';
  }

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

  class SyncService {
    final ApiClient _apiClient;
    final ISyncRepository _repository;

    // Rotas do backend FastAPI
    static const String _routeSyncPush = '/croqui/sync/push';
    static const String _routeSyncEvidencias = '/croqui/sync/evidencias';

    SyncService({
      required ApiClient apiClient,
      required ISyncRepository repository,
    })  : _apiClient = apiClient,
          _repository = repository;

    Future<void> execute() async {
      debugPrint('[SyncService] Iniciando sincronização...');

      final List<Caso> casosPendentes =
          await _repository.getCasosNaoSincronizados();

      if (casosPendentes.isEmpty) return;

      debugPrint('[SyncService] ${casosPendentes.length} caso(s) pendente(s).');

      await _pushTextual(casosPendentes);

      final fotosPendentesPorCaso = await _repository.getAchadosComFotosPendentesEmLote(
        casosPendentes.map((c) => c.uuid).toList(),
      );

      for (final caso in casosPendentes) {
        await _processarCaso(caso, fotosPendentesPorCaso[caso.uuid] ?? []);
      }

      debugPrint('[SyncService] Ciclo concluído.');
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

      try {
        final response = await _apiClient.dio.post(
          _routeSyncPush,
          data: payload,
        );

        if (response.statusCode != 200) {
          throw SyncPushTextualException(
            'Backend retornou status inesperado: ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
      } on DioException catch (e) {
        throw SyncPushTextualException(
          'Falha de rede no push textual: ${e.message}',
          statusCode: e.response?.statusCode,
        );
      }
    }

    Future<void> _processarCaso(Caso caso, List<Achado> achadosComFotos) async {
      if (achadosComFotos.isEmpty) {
        await _confirmarCaso(caso);
        return;
      }

      final List<Achado> achadosSincronizados = [];
      final List<SyncUploadEvidenciaException> erros = [];

      for (final achado in achadosComFotos) {
        try {
          await _uploadEvidencia(caso, achado);
          achadosSincronizados.add(achado);
        } on SyncUploadEvidenciaException catch (e) {
          erros.add(e);
          debugPrint('[SyncService] Upload falhou: ${achado.uuid} — $e');
        }
      }

      for (final achado in achadosSincronizados) {
        await _repository.marcarFotoComoSincronizada(achado);
      }

      if (erros.isEmpty) {
        await _confirmarCaso(caso);
      } else {
        debugPrint(
          '[SyncService] Caso ${caso.uuid}: ${erros.length} foto(s) falharam.',
        );
      }
    }

    Future<void> _uploadEvidencia(Caso caso, Achado achado) async {
      final String? caminhoFoto = achado.photoPath;
      if (caminhoFoto == null || caminhoFoto.isEmpty) return;

      final File arquivoOriginal = File(caminhoFoto);
      if (!arquivoOriginal.existsSync()) return;

      try {
        final bytes = await arquivoOriginal.readAsBytes();
        final String hashOriginal = sha256.convert(bytes).toString();

        final formData = FormData.fromMap({
          'caso_uuid': caso.uuid,
          'achado_uuid': achado.uuid,
          'hash_arquivo': hashOriginal,
          'hash_cifrado': hashOriginal,
          'salt_base64': '',
          'chave_cifrada_base64': '',
          'item_file': await MultipartFile.fromFile(
            arquivoOriginal.path,
            filename: p.basename(arquivoOriginal.path),
            contentType: MediaType('image', 'jpeg'),
          ),
        });

        final response = await _apiClient.dio.post(
          _routeSyncEvidencias,
          data: formData,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw SyncUploadEvidenciaException(
            'Backend retornou status inesperado: ${response.statusCode}',
            casoUuid: caso.uuid,
            achadoUuid: achado.uuid,
            statusCode: response.statusCode,
          );
        }

        await _repository.marcarFotoComoSincronizada(achado);
      } on DioException catch (e) {
        throw SyncUploadEvidenciaException(
          'Falha de rede: ${e.message}',
          casoUuid: caso.uuid,
          achadoUuid: achado.uuid,
          statusCode: e.response?.statusCode,
        );
      }
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
        'template_diagrama_id': achado.templateDiagramaId,
        'tipo_achado_id': achado.tipoAchadoId,
        'numero_sequencial': achado.numeroSequencial,
        'pos_x': achado.posX.toDouble(),
        'pos_y': achado.posY.toDouble(),
        'is_interno': achado.isInterno,
        'esta_pendente': achado.estaPendente,
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

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/data/models/protocolo_lookup_model.dart';

/// Implementação da fonte de dados remota encarregada da comunicação HTTP REST com a API central do IML.
///
/// Utiliza a biblioteca [Dio] gerenciada pelo [ApiClient], fornecendo:
/// - Interceptação e renovação de tokens JWT (Bearer).
/// - Envio de dados estruturados em lote (Bulk JSON) e upload multipart de arquivos binários (fotos e PDFs).
/// - Mapeamento defensivo de timeouts de rede e respostas HTTP para exceções de domínio especializadas.
class RemoteDataSourceImpl implements IRemoteDataSource {
  final ApiClient _apiClient;

  RemoteDataSourceImpl(this._apiClient);

  /// Executa a autenticação de credenciais periciais no endpoint `POST /auth/login`.
  ///
  /// Throws [AuthException] se as credenciais forem inválidas (401/403) ou se houver erro de rede/timeout.
  @override
  Future<Map<String, dynamic>> login(String login, String senha) async {
    try {
      final response = await _apiClient.dio.post(
        'auth/login',
        data: {'login': login, 'senha': senha},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const AuthException('Resposta inesperada do servidor.');
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        final data = e.response?.data;
        final msg = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Credenciais inválidas.';
        throw AuthException(msg);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const AuthException(
          'Dispositivo offline. Conecte-se para o primeiro acesso.',
        );
      }
      throw AuthException(
        e.message != null && e.message!.isNotEmpty
            ? 'Falha na comunicação: ${e.message}'
            : 'Falha na comunicação com o servidor.',
      );
    }
  }

  /// Verifica a saúde operacional do servidor central no endpoint `GET /health/`.
  ///
  /// Retorna `true` se a API responder com status 200 em até 4 segundos; caso contrário, `false`.
  @override
  Future<bool> checkHealth() async {
    try {
      final response = await _apiClient.dio.get(
        'health/',
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Recupera o catálogo oficial de tipos de lesões/achados no endpoint `GET /croqui/tipos-achados`.
  @override
  Future<List<Map<String, dynamic>>> getTiposAchados() async {
    try {
      final response = await _apiClient.dio.get('croqui/tipos-achados');
      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Resposta inesperada do servidor.');
      }
      if (response.data is! List) {
        throw Exception('Resposta inválida do servidor.');
      }
      final list = response.data as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw Exception('Falha ao sincronizar tipos de achados: ${e.message}');
    }
  }

  /// Realiza a consulta rápida de dados burocráticos e policiais de um laudo pelo número de PIC.
  ///
  /// Endpoint: `GET /exames/protocolo/{pic}`.
  /// Retorna o modelo [ProtocoloLookupModel] ou `null` caso o número não seja localizado ou a rede falhe.
  @override
  Future<ProtocoloLookupModel?> getDadosPorPic(String pic) async {
    try {
      final response = await _apiClient.dio.get(
        'exames/protocolo/$pic',
        options: Options(
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final map = Map<String, dynamic>.from(response.data as Map);
        return ProtocoloLookupModel.fromMap(map);
      }
      return null;
    } catch (e) {
      debugPrint(
        '[RemoteDataSourceImpl] Falha tolerada ao buscar dados por PIC ($pic): $e',
      );
      return null;
    }
  }

  /// Recupera a lista de Auxiliares Técnicos de Necrópsia (ATNs) no endpoint `GET /croqui/atns`.
  @override
  Future<List<Map<String, dynamic>>> getAtns() async {
    try {
      final response = await _apiClient.dio.get('croqui/atns');
      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Resposta inesperada do servidor.');
      }
      if (response.data is! List) {
        throw Exception('Resposta inválida do servidor.');
      }
      final list = response.data as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw Exception('Falha ao buscar ATNs: ${e.message}');
    }
  }

  /// Envia o pacote textual de laudos e achados (Bulk JSON) no endpoint `POST /croqui/sync/push`.
  ///
  /// Throws [SyncPushTextualException] em caso de rejeição pelo servidor ou erro na camada de transporte.
  @override
  Future<Map<String, dynamic>> pushTextual(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post(
        'croqui/sync/push',
        data: payload,
      );
      if (response.statusCode != 200) {
        throw SyncPushTextualException(
          'Backend retornou status inesperado: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw SyncPushTextualException(
        'Falha de rede no push textual: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Baixa casos e atualizações cadastrais do servidor central a partir de [lastSyncTimestamp].
  ///
  /// Endpoint: `GET /croqui/sync/pull?last_sync=...`.
  /// Throws [AuthException] se o token estiver expirado (401/403).
  /// Throws [SyncNetworkException] em caso de falha de conexão ou resposta HTTP inesperada.
  @override
  Future<List<Map<String, dynamic>>> pullCasos({
    String? lastSyncTimestamp,
  }) async {
    try {
      final queryParams = lastSyncTimestamp != null
          ? {'last_sync': lastSyncTimestamp}
          : null;
      final response = await _apiClient.dio.get(
        'croqui/sync/pull',
        queryParameters: queryParams,
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const SyncNetworkException(
          'Resposta inesperada do servidor ao tentar puxar os casos.',
        );
      }

      final data = response.data;
      if (data is Map && data.containsKey('casos')) {
        final list = data['casos'] as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const AuthException('Sessão expirada. Autentique-se novamente.');
      }
      throw SyncNetworkException(
        'Falha na rede ao sincronizar casos (pull): ${e.message ?? 'conexão recusada'}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Realiza o upload binário de uma fotografia pericial ([EvidenciaMultimidia]) via Multipart/form-data.
  ///
  /// Endpoint: `POST /croqui/sync/evidencias`.
  /// Constrói a payload contendo o arquivo em imagem JPEG, identificadores UUID e hash SHA-256 de integridade.
  /// Timeout estendido de 120 segundos para suportar transmissão em redes móveis de baixa velocidade.
  /// Throws [SyncUploadEvidenciaException] em caso de falha na transmissão.
  @override
  Future<void> uploadEvidencia({
    required String casoUuid,
    required String? achadoUuid,
    required String evidenciaUuid,
    required String hash,
    required String filePath,
  }) async {
    try {
      final Map<String, dynamic> formDataMap = {
        'uuid': evidenciaUuid,
        'caso_uuid': casoUuid,
        'hash_arquivo': hash,
        'hash_cifrado': hash,
        'salt_base64': '',
        'chave_cifrada_base64': '',
        'tipo': achadoUuid == null ? 'GERAL' : 'ACHADO',
        'item_file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
          contentType: MediaType('image', 'jpeg'),
        ),
      };

      if (achadoUuid != null && achadoUuid.isNotEmpty) {
        formDataMap['achado_uuid'] = achadoUuid;
      }

      final formData = FormData.fromMap(formDataMap);

      developer.log(
        "[DEBUG FOTO] Despachando foto $evidenciaUuid do Achado $achadoUuid vinculado ao Caso: $casoUuid",
      );

      final response = await _apiClient.dio.post(
        'croqui/sync/evidencias',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw SyncUploadEvidenciaException(
          'Backend retornou status inesperado: ${response.statusCode}',
          casoUuid: casoUuid,
          achadoUuid: achadoUuid,
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw SyncUploadEvidenciaException(
        'Falha de rede: ${e.message}',
        casoUuid: casoUuid,
        achadoUuid: achadoUuid,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw SyncUploadEvidenciaException(
        'Erro inesperado: $e',
        casoUuid: casoUuid,
        achadoUuid: achadoUuid,
      );
    }
  }

  /// Realiza o upload do documento pericial compilado em formato PDF via Multipart/form-data.
  ///
  /// Endpoint: `POST /croqui/sync/laudo-pdf`.
  /// Retorna a URL remota de acesso ao documento gerada pelo backend (`pdf_url`).
  @override
  Future<String> uploadLaudoPdf({
    required String casoUuid,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'caso_uuid': casoUuid,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
          contentType: MediaType('application', 'pdf'),
        ),
      });

      developer.log("[DEBUG PDF] Fazendo upload do PDF para o Caso: $casoUuid");

      final response = await _apiClient.dio.post(
        'croqui/sync/laudo-pdf',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Backend retornou status inesperado no upload do PDF: ${response.statusCode}',
        );
      }

      return response.data['pdf_url']?.toString() ?? '';
    } on DioException catch (e) {
      throw Exception('Falha de rede no upload do PDF: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado no upload do PDF: $e');
    }
  }

  /// Atualiza o status de conferência/aceite de um exame complementar pelo ATN no backend.
  ///
  /// Endpoint: `PATCH /croqui/web/casos/exames-solicitados/{id}/confirmacao-atn`.
  /// Throws [ArgumentError] se o status for [StatusConfirmacaoATN.RECUSADO] e a justificativa for omitida.
  @override
  Future<void> atualizarConfirmacaoAtnExameSolicitado({
    required String exameSolicitadoId,
    required StatusConfirmacaoATN status,
    String? justificativaRecusa,
  }) async {
    if (status == StatusConfirmacaoATN.RECUSADO &&
        (justificativaRecusa == null || justificativaRecusa.trim().isEmpty)) {
      throw ArgumentError(
        'A justificativa de recusa é obrigatória quando o status for RECUSADO.',
      );
    }

    try {
      final response = await _apiClient.dio.patch(
        'croqui/web/casos/exames-solicitados/$exameSolicitadoId/confirmacao-atn',
        data: {
          'status_confirmacao_atn': status.name,
          'justificativa_recusa': justificativaRecusa,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Backend retornou status inesperado ao atualizar confirmação do exame: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Falha de rede ao atualizar confirmação do exame: ${e.message}',
      );
    }
  }

  /// Atualiza o status de conferência/aceite de um vestígio balístico pelo ATN no backend.
  ///
  /// Endpoint: `PATCH /croqui/web/casos/balistica/{id}/confirmacao-atn`.
  /// Throws [ArgumentError] se o status for [StatusConfirmacaoATN.RECUSADO] e a justificativa for omitida.
  @override
  Future<void> atualizarConfirmacaoAtnBalistica({
    required String balisticaId,
    required StatusConfirmacaoATN status,
    String? justificativaRecusa,
  }) async {
    if (status == StatusConfirmacaoATN.RECUSADO &&
        (justificativaRecusa == null || justificativaRecusa.trim().isEmpty)) {
      throw ArgumentError(
        'A justificativa de recusa é obrigatória quando o status for RECUSADO.',
      );
    }

    try {
      final response = await _apiClient.dio.patch(
        'croqui/web/casos/balistica/$balisticaId/confirmacao-atn',
        data: {
          'status_confirmacao_atn': status.name,
          'justificativa_recusa': justificativaRecusa,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Backend retornou status inesperado ao atualizar confirmação da balística: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Falha de rede ao atualizar confirmação da balística: ${e.message}',
      );
    }
  }

  /// Injeta o token JWT de autorização Bearer nas requisições do cliente Dio.
  @override
  void setBearerToken(String token) {
    _apiClient.setBearerToken(token);
  }
}


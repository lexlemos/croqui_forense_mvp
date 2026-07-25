import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

class RemoteDataSourceImpl implements IRemoteDataSource {
  final ApiClient _apiClient;

  RemoteDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> login(String matricula, String pin) async {
    try {
      final response = await _apiClient.dio.post(
        'croqui/auth/login',
        data: {'matricula': matricula, 'senha': pin},
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const AuthException('Resposta inesperada do servidor.');
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw const AuthException(
          'Dispositivo offline. Conecte-se para o primeiro acesso.',
        );
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const AuthException('Credenciais inválidas.');
      }
      throw const AuthException('Falha na comunicação com o servidor.');
    }
  }

  @override
  Future<void> trocarPin(String usuarioId, String novoPin) async {
    try {
      await _apiClient.dio.put(
        'croqui/auth/$usuarioId/senha',
        data: {'nova_senha': novoPin},
      );
    } on DioException catch (e) {
      throw AuthException(
        'Não foi possível alterar a senha no servidor. '
        'Verifique sua conexão e tente novamente. (${e.type.name})',
      );
    }
  }

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
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';

class DomainSyncService {
  final ApiClient _apiClient;
  final InjuryTypeRepository _injuryTypeRepository;

  static const String _routeTiposAchados = '/croqui/tipos-achados';

  DomainSyncService({
    required ApiClient apiClient,
    required InjuryTypeRepository injuryTypeRepository,
  })  : _apiClient = apiClient,
        _injuryTypeRepository = injuryTypeRepository;

  Future<void> syncTiposAchados() async {
    try {
      final response = await _apiClient.dio.get(_routeTiposAchados);

      if (response.statusCode != 200 || response.data == null) return;

      if (response.data is! List) {
        debugPrint('[DomainSync] ❌ Resposta inválida do servidor (esperava List, recebeu ${response.data.runtimeType}).');
        return;
      }

      final List<dynamic> jsonList = response.data as List<dynamic>;
      final types = jsonList
          .map((e) => InjuryType.fromJson(e as Map<String, dynamic>))
          .toList();

      if (types.isNotEmpty) {
        await _injuryTypeRepository.upsertAll(types);
      }

      debugPrint('[DomainSync] tipos_achados sincronizados: ${types.length}');
    } on DioException catch (e) {
      debugPrint('[DomainSync] Falha ao sincronizar tipos_achados: ${e.type}');
    }
  }
}

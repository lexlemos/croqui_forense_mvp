import 'package:flutter/foundation.dart';

import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

/// Serviço de domínio encarregado da sincronização de templates, metadados e tabelas de referência.
///
/// Este serviço é responsável pela "Sincronização de Templates Anatômicos" e pelo recebimento dos
/// "Esquemas de Formulários Dinâmicos" e tabelas oficiais de referência (ex: A.T.N.s), garantindo que
/// o tablet ou dispositivo portátil do Perito tenha sempre as atualizações mais recentes da central.
class DomainSyncService {
  final IRemoteDataSource _remoteDataSource;
  final InjuryTypeRepository _injuryTypeRepository;
  final AtnRepository? _atnRepository;

  /// Cria uma nova instância de [DomainSyncService].
  DomainSyncService({
    required IRemoteDataSource remoteDataSource,
    required InjuryTypeRepository injuryTypeRepository,
    AtnRepository? atnRepository,
  })  : _remoteDataSource = remoteDataSource,
        _injuryTypeRepository = injuryTypeRepository,
        _atnRepository = atnRepository;

  /// Sincroniza e atualiza localmente as definições e "Esquemas de Formulários Dinâmicos"
  /// para o mapeamento e tipificação dos achados periciais.
  Future<void> syncTiposAchados() async {
    List<InjuryType> types = [];
    Object? remoteError;
    try {
      final jsonList = await _remoteDataSource.getTiposAchados();
      types = jsonList.map((e) => InjuryType.fromJson(e)).toList();

      if (types.isNotEmpty) {
        await _injuryTypeRepository.upsertAll(types);
      }
      debugPrint('[DomainSync] tipos_achados sincronizados: ${types.length}');
    } catch (e) {
      remoteError = e;
      debugPrint('[DomainSync] Falha ao sincronizar tipos_achados: $e');
    }

    if (types.isEmpty || remoteError != null) {
      final localTypes = await _injuryTypeRepository.getAllTypes();
      if (localTypes.isEmpty) {
        if (remoteError != null) {
          throw Exception('Não foi possível sincronizar os achados com o servidor e a base local está vazia: $remoteError');
        } else {
          throw Exception('Nenhum tipo de achado foi retornado pelo servidor e a base local está vazia.');
        }
      }
    }
  }

  /// Sincroniza em lote a lista oficial de A.T.N.s do backend.
  /// 
  /// Caso o dispositivo esteja offline ou ocorra um erro de rede, a requisição falha silenciosamente
  /// mantendo a integridade dos A.T.N.s prévios já armazenados no SQLite local.
  Future<void> syncAtns() async {
    final repo = _atnRepository;
    if (repo == null) return;
    try {
      final jsonList = await _remoteDataSource.getAtns();
      final atnsList = jsonList.map((e) => AtnModel.fromMap(e)).toList();
      await repo.sincronizarAtns(atnsList);
      debugPrint('[DomainSync] ATNs sincronizados com sucesso: ${atnsList.length}');
    } catch (e) {
      debugPrint('[DomainSync] ⚠️ Falha ao sincronizar ATNs (dispositivo offline ou erro remoto): $e');
    }
  }
}


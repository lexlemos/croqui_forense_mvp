import 'package:flutter/foundation.dart';

import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
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
  }) : _remoteDataSource = remoteDataSource,
       _injuryTypeRepository = injuryTypeRepository,
       _atnRepository = atnRepository;

  /// Sincroniza e atualiza localmente as definições e "Esquemas de Formulários Dinâmicos"
  /// para o mapeamento e tipificação dos achados periciais.
  Future<void> syncTiposAchados() async {
    final jsonList = await _remoteDataSource.getTiposAchados();
    final types = jsonList.map((e) => InjuryType.fromJson(e)).toList();

    if (types.isNotEmpty) {
      await _injuryTypeRepository.upsertAll(types);
    }
    debugPrint('[DomainSync] tipos_achados sincronizados: ${types.length}');
  }

  /// Sincroniza em lote a lista de A.T.N.s do banco local.
  ///
  /// Consulta a API central via [_remoteDataSource.getAtns()] e atualiza
  /// o cache SQLite via [_atnRepository.sincronizarAtns()].
  /// Em caso de falha de rede ou lista vazia, mantém os dados locais.
  Future<void> syncAtns() async {
    final repo = _atnRepository;
    if (repo == null) return;

    try {
      final jsonList = await _remoteDataSource.getAtns();
      final atns = jsonList.map((e) => AtnModel.fromMap(e)).toList();
      if (atns.isNotEmpty) {
        await repo.sincronizarAtns(atns);
        debugPrint('[DomainSync] ATNs sincronizados da API: ${atns.length}');
      } else {
        await repo.semearMocksSeNecessario();
      }
    } catch (e) {
      debugPrint('[DomainSync] Falha ao sincronizar ATNs da API ($e). Mantendo dados locais.');
      await repo.semearMocksSeNecessario();
    }
  }
}

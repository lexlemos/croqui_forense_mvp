import 'package:flutter/foundation.dart';

import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

/// Serviço de domínio encarregado da sincronização de templates, metadados e tabelas de referência.
///
/// Este serviço é responsável pela "Sincronização de Templates Anatômicos" e pelo recebimento dos
/// "Esquemas de Formulários Dinâmicos", garantindo que o tablet ou dispositivo portátil do Perito
/// tenha sempre as atualizações mais recentes dos SVGs de contornos anatômicos do corpo humano e
/// as regras de preenchimento oficiais homologadas pela central pericial.
class DomainSyncService {
  final IRemoteDataSource _remoteDataSource;
  final InjuryTypeRepository _injuryTypeRepository;

  /// Cria uma nova instância de [DomainSyncService].
  ///
  /// Requer a interface de dados remota [_remoteDataSource] e o repositório local [_injuryTypeRepository].
  DomainSyncService({
    required IRemoteDataSource remoteDataSource,
    required InjuryTypeRepository injuryTypeRepository,
  })  : _remoteDataSource = remoteDataSource,
        _injuryTypeRepository = injuryTypeRepository;

  /// Sincroniza e atualiza localmente as definições e "Esquemas de Formulários Dinâmicos"
  /// para o mapeamento e tipificação dos achados periciais.
  ///
  /// Solicita à API central a lista atualizada de nomenclaturas e restrições de lesões e,
  /// caso bem-sucedido, armazena de forma persistente no banco de dados local para uso offline.
  ///
  /// @throws Exception Se houver falha de rede na comunicação com a API central ao buscar os templates
  /// ou caso ocorra um erro de integridade de dados na gravação local no repositório.
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
}


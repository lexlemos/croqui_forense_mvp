import '../../data/models/achado_model.dart';
import '../../data/repositories/achado_repository.dart';

/// Serviço de domínio encarregado de gerenciar o registro das lesões corporais, orifícios anatômicos
/// e evidências físicas mapeadas graficamente no croqui pelo médico legista ou perito.
///
/// Coordena as rotinas de inclusão, atualização, listagem e exclusão das marcações e dados
/// clínico-forenses coletados durante o exame cadavérico, aplicando a barreira de imutabilidade
/// jurídica caso o laudo já tenha sido finalizado.
class AchadoService {
  final AchadoRepository _repository;

  AchadoService(this._repository);

  /// Registra uma nova lesão ou orifício anatômico ([Achado]) vinculado a um laudo pericial.
  ///
  /// Valida preliminarmente se o laudo matriz não está finalizado antes de persistir o achado.
  ///
  /// Throws [Exception] se o laudo associado já estiver finalizado e assinado (bloqueio por segurança jurídica).
  Future<void> salvarAchado(Achado achado) async {
    if (await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception(
        'Segurança Jurídica: Este laudo já está finalizado e é imutável.',
      );
    }
    await _repository.insertAchado(achado);
  }

  /// Atualiza os dados descritivos, as dimensões ou a posição de uma lesão ([Achado]) já registrada.
  ///
  /// Throws [Exception] se o laudo correspondente estiver finalizado, impedindo modificações
  /// retroativas sem a devida reabertura formal e auditoria do caso.
  Future<void> atualizarAchado(Achado achado) async {
    if (await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception(
        'Segurança Jurídica: Este laudo já está finalizado e é imutável.',
      );
    }
    await _repository.updateAchado(achado);
  }

  /// Lista todas as lesões e orifícios ([Achado]s) vinculados a um determinado caso ([casoUuid]).
  Future<List<Achado>> listarAchados(String casoUuid) async {
    return await _repository.getAchadosPorCaso(casoUuid);
  }

  /// Remove o registro de uma lesão ou orifício anatômico ([Achado]) pelo seu identificador único ([uuid]).
  ///
  /// Throws [Exception] se o laudo associado já estiver finalizado e assinado pelo perito.
  Future<void> removerAchado(String uuid) async {
    final achado = await _repository.getAchadoByUuid(uuid);
    if (achado != null && await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception(
        'Segurança Jurídica: Este laudo já está finalizado e é imutável.',
      );
    }
    await _repository.deleteAchado(uuid);
  }
}


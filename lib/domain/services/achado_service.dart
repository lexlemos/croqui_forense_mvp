import '../../data/models/achado_model.dart';
import '../../data/repositories/achado_repository.dart';

/// Serviço de domínio encarregado de gerenciar o registro das lesões corporais, orifícios anatômicos
/// e evidências físicas mapeadas graficamente no croqui pelo [Perito].
///
/// Coordena as rotinas de inclusão, atualização, listagem e exclusão das marcações e dados
/// clínico-forenses coletados durante o exame cadavérico.
class AchadoService {
  final AchadoRepository _repository;

  AchadoService(this._repository);

  /// Registra uma nova lesão ou orifício anatômico ([Achado]) vinculado a um laudo.
  ///
  /// @throws [Exception] se o laudo associado já estiver finalizado e assinado (bloqueado para edições).
  Future<void> salvarAchado(Achado achado) async {
    if (await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception('Segurança Jurídica: Este laudo já está finalizado e é imutável.');
    }
    await _repository.insertAchado(achado);
  }

  /// Atualiza os dados descritivos, as dimensões ou a posição de uma lesão ([Achado]) já registrada.
  ///
  /// @throws [Exception] se o laudo correspondente estiver finalizado, impedindo modificações
  /// retroativas sem a devida reabertura formal e auditoria do caso.
  Future<void> atualizarAchado(Achado achado) async {
    if (await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception('Segurança Jurídica: Este laudo já está finalizado e é imutável.');
    }
    await _repository.updateAchado(achado);
  }

  /// Lista todas as lesões e orifícios ([Achado]s) vinculados a um determinado caso ([casoUuid]).
  Future<List<Achado>> listarAchados(String casoUuid) async {
    return await _repository.getAchadosPorCaso(casoUuid);
  }

  /// Remove o registro de uma lesão ou orifício anatômico ([Achado]) pelo seu identificador único.
  ///
  /// @throws [Exception] se o laudo associado já estiver finalizado e assinado pelo [Perito].
  Future<void> removerAchado(String uuid) async {
    final achado = await _repository.getAchadoByUuid(uuid);
    if (achado != null && await _repository.isCasoFinalizado(achado.casoUuid)) {
      throw Exception('Segurança Jurídica: Este laudo já está finalizado e é imutável.');
    }
    await _repository.deleteAchado(uuid);
  }
}
import '../../data/models/achado_model.dart';
import '../../data/repositories/achado_repository.dart';

class AchadoService {
  final AchadoRepository _repository;

  AchadoService(this._repository);

  Future<void> salvarAchado(Achado achado) async {
    await _repository.insertAchado(achado);
  }

  Future<void> atualizarAchado(Achado achado) async {
    final achadoAtualizado = achado.copyWith(
      versao: achado.versao + 1,
      atualizadoEm: DateTime.now(),
    );
    await _repository.updateAchado(achadoAtualizado);
  }

  Future<List<Achado>> listarAchados(String casoUuid) async {
    return await _repository.getAchadosPorCaso(casoUuid);
  }

  Future<void> removerAchado(String uuid) async {
    await _repository.deleteAchado(uuid);
  }
}
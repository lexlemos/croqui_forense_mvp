import '../../data/models/achado_model.dart';
import '../../data/repositories/achado_repository.dart';
import '../../data/repositories/diagrama_repository.dart';

class AchadoService {
  final AchadoRepository _repository;
  final DiagramaRepository _diagramaRepository;

  

  AchadoService(this._repository, this._diagramaRepository);

  static final AchadoService instance = AchadoService(AchadoRepository(), DiagramaRepository());

  Future<void> salvarAchado(Achado achado) async {
    final casoUuid = achado.diagramaCasoUuid;
    await _diagramaRepository.garantirExistencia(casoUuid, achado.diagramaCasoUuid);
    
    await _repository.insertAchado(achado);
  }

  Future<void> atualizarAchado(Achado achado) async {
    final achadoAtualizado = Achado(
      uuid: achado.uuid,
      diagramaCasoUuid: achado.diagramaCasoUuid,
      tipoAchadoId: achado.tipoAchadoId,
      numeroSequencial: achado.numeroSequencial,
      posX: achado.posX,
      posY: achado.posY,
      estaPendente: achado.estaPendente,
      dadosPreenchidos: achado.dadosPreenchidos,
      observacoesTexto: achado.observacoesTexto,
      removido: achado.removido,
      versao: achado.versao + 1, 
      criadoEm: achado.criadoEm,
      atualizadoEm: DateTime.now(),
      deviceId: achado.deviceId,
      proveniencia: achado.proveniencia,
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
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class CaseService {
  final CasoRepository _repository;

  CaseService(this._repository);

  Future<Caso> createNewCase({
    required Usuario criador, 
    required String numeroLaudo
  }) async {
    
    final novoCaso = Caso.novo(
      idUsuarioCriador: criador.id,
      numeroLaudoExterno: numeroLaudo,
      proveniencia: 'APP_TABLET',
    );
    await _repository.insertCase(novoCaso);
    
    return novoCaso;
  }

  Future<List<Caso>> listarCasos() async {
    return await _repository.getAllCases();
  }

  Future<Map<String, dynamic>> montarLaudoCompleto(Caso caso) async {
    final List<Achado> listaAchados = await _repository.getAchadosPorCaso(caso.uuid);
    final Map<String, dynamic> laudoFinal = Map<String, dynamic>.from(caso.dadosLaudo);
    laudoFinal['achados'] = listaAchados.map((a) => a.toMap()).toList();
    return laudoFinal;
  }
}
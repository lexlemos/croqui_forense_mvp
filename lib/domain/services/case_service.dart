import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class CaseService {
  final CasoRepository _repository;

  CaseService(this._repository);

  Future<Caso> createNewCase({
    required Usuario criador, 
    required String numeroLaudo,
    Map<String, dynamic> dadosIniciais = const {}, 
  }) async {
    
    final novoCaso = Caso.novo(
      idUsuarioCriador: criador.id, 
      numeroLaudoExterno: numeroLaudo,
      proveniencia: 'APP_TABLET',
      dadosLaudo: dadosIniciais, 
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

    laudoFinal['meta_info'] = {
      'uuid_caso': caso.uuid,
      'numero_laudo': caso.numeroLaudoExterno,
      'criado_em': caso.criadoEmDispositivo.toIso8601String(),
      'responsavel_id': caso.idUsuarioCriador,
      'status': caso.status.name,
      'versao_schema': caso.versao,
    };
    laudoFinal['achados'] = listaAchados.map((a) => a.toMap()).toList();

    return laudoFinal;
  }
}
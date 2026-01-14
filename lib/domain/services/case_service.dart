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
    Map<String, dynamic> dadosIniciais = const   {}, 
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

  Future<void> finalizarCaso(String casoUuid, Map<String, dynamic> dadosConclusao) async {
    final casos = await _repository.getAllCases();
    final casoAtual = casos.firstWhere((c) => c.uuid == casoUuid);

    final Map<String, dynamic> dadosAtualizados = Map.from(casoAtual.dadosLaudo);
    dadosAtualizados.addAll(dadosConclusao);

    final casoFinalizado = Caso(
      uuid: casoAtual.uuid,
      idUsuarioCriador: casoAtual.idUsuarioCriador,
      numeroLaudoExterno: casoAtual.numeroLaudoExterno,
      status: StatusCaso.finalizado, 
      hashIntegridade: casoAtual.hashIntegridade,
      removido: casoAtual.removido,
      versao: casoAtual.versao + 1,
      criadoEmDispositivo: casoAtual.criadoEmDispositivo,
      criadoEmRedeConfiavel: casoAtual.criadoEmRedeConfiavel,
      atualizadoEm: DateTime.now(),
      deviceId: casoAtual.deviceId,
      dadosLaudo: dadosAtualizados,
      proveniencia: casoAtual.proveniencia,
    );

    await _repository.updateCase(casoFinalizado);
  }

  Future<void> reabrirCaso(String casoUuid) async {
    final casos = await _repository.getAllCases();
    final casoAtual = casos.firstWhere((c) => c.uuid == casoUuid);

    final casoReaberto = Caso(
      uuid: casoAtual.uuid,
      idUsuarioCriador: casoAtual.idUsuarioCriador,
      numeroLaudoExterno: casoAtual.numeroLaudoExterno,
      
      status: StatusCaso.rascunho, 
      
      hashIntegridade: null, 
      removido: casoAtual.removido,
      versao: casoAtual.versao + 1,
      criadoEmDispositivo: casoAtual.criadoEmDispositivo,
      criadoEmRedeConfiavel: casoAtual.criadoEmRedeConfiavel,
      atualizadoEm: DateTime.now(),
      deviceId: casoAtual.deviceId,
      dadosLaudo: casoAtual.dadosLaudo, 
      proveniencia: casoAtual.proveniencia,
    );

    await _repository.updateCase(casoReaberto);
  }

  Future<Map<String, dynamic>> gerarJsonExportacao(
    String casoUuid, 
    String nomeCriador, 
    String nomeExportador 
  ) async {
    final casos = await _repository.getAllCases();
    final caso = casos.firstWhere((c) => c.uuid == casoUuid);
    final achados = await _repository.getAchadosPorCaso(casoUuid);

    final dados = caso.dadosLaudo;
    final cabecalho = dados['cabecalho'] ?? {};
    final identificacao = dados['identificacao'] ?? {};
    final conclusao = dados['conclusao'] ?? {};

    final Map<String, dynamic> secaoInicial = {
      'meta_info': {
        'uuid': caso.uuid,
        'data_criacao': caso.criadoEmDispositivo.toIso8601String(),
        'data_exportacao': DateTime.now().toIso8601String(),
        'perito_responsavel': nomeCriador, 
        'numero_laudo': caso.numeroLaudoExterno,
      },
      'dados_requisicao': {
        'requisicao': cabecalho['requisicao'] ?? '',
        'requisitante': cabecalho['requisitante'] ?? '',
        'destino': cabecalho['destino'] ?? '',
        'vitima': cabecalho['vitima'] ?? 'Não Identificado',
      },
      'dados_identificacao': {
        'vestes': identificacao['vestes'] ?? '',
        'caracteristicas': identificacao['caracteristicas'] ?? '',
        'tanatologia': identificacao['dados_tanatologicos'] ?? '',
      }
    };

    List<Map<String, dynamic>> listaAchadosTexto = achados.map((a) {
      final d = a.dadosPreenchidos;
      return {
        'sequencial': a.numeroSequencial,
        'tipo': d['type_label'] ?? 'Não especificado',
        'local': d['local_anatomico_nome'] ?? 'Local desconhecido',
        'tamanho': d['size'] ?? '-',
        'profundidade': d['depth'] ?? '-',
        'descricao': a.observacoesTexto ?? '',
        'posicao_croqui': d['view'] ?? 'geral',
      };
    }).toList();

    final Map<String, dynamic> secaoConclusao = {
      'quesito_1_morte': conclusao['pergunta_1'] ?? '',
      'quesito_2_causa': conclusao['pergunta_2'] ?? '',
      'quesito_3_instrumento': conclusao['pergunta_3'] ?? '',
      'quesito_4_meio': conclusao['pergunta_4'] ?? '',
      'data_encerramento': conclusao['data_finalizacao'] ?? '',
    };

    List<Map<String, String>> galeriaFotos = [];

    if (identificacao['fotos'] != null && identificacao['fotos'] is List) {
      List<dynamic> fotosId = identificacao['fotos'];
      for (int i = 0; i < fotosId.length; i++) {
        galeriaFotos.add({
          'ordem': 'ID_${i + 1}',
          'contexto': 'IDENTIFICACAO',
          'titulo': 'Foto de Identificação ${i + 1}',
          'descricao': 'Registro geral ou de vestes.',
          'caminho_arquivo': fotosId[i].toString(),
        });
      }
    }

    for (var a in achados) {
      final d = a.dadosPreenchidos;
      if (d['photo_path'] != null && d['photo_path'].toString().isNotEmpty) {
        galeriaFotos.add({
          'ordem': 'ACHADO_${a.numeroSequencial}',
          'contexto': 'LESÃO',
          'titulo': 'Foto do Achado #${a.numeroSequencial} - ${d['type_label']}',
          'descricao': 'Local: ${d['local_anatomico_nome']}. Obs: ${a.observacoesTexto}',
          'caminho_arquivo': d['photo_path'].toString(),
        });
      }
    }
    return {
      'documento': {
        'titulo': 'Laudo Pericial Cadavérico',
        'versao_schema': '1.0',
      },
      '1_cabecalho': secaoInicial,
      '2_descritivo_lesoes': listaAchadosTexto,
      '3_conclusao': secaoConclusao,
      '4_anexos_fotograficos': galeriaFotos,
      '5_auditoria_exportacao': {
        'responsavel_pela_exportacao': nomeExportador, 
        'data_hora_evento': DateTime.now().toIso8601String(),
        'software_origem': 'Croqui Forense App v1.0',
        'hash_integridade_calculado': null 
      }
    };
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
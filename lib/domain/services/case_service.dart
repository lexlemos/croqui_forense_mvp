import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

Future<Map<String, dynamic>> _gerarJsonBase64Background(Map<String, dynamic> params) async {
  final Map<String, dynamic> dadosBase = params['dados_json'];
  
  List<dynamic> anexosOriginais = dadosBase['6_anexos_fotograficos'] ?? [];
  List<Map<String, dynamic>> anexosComImagem = [];

  for (var anexo in anexosOriginais) {
    String path = anexo['caminho_arquivo'];
    File file = File(path);

    if (file.existsSync()) {
      try {
        List<int> imageBytes = await file.readAsBytes();
        String base64String = base64Encode(imageBytes);
        
        Map<String, dynamic> novoAnexo = Map.from(anexo);
        novoAnexo.remove('caminho_arquivo'); 
        novoAnexo['mime_type'] = 'image/jpeg';
        novoAnexo['conteudo_base64'] = base64String;
        
        anexosComImagem.add(novoAnexo);
      } catch (e) {
        Map<String, dynamic> anexoErro = Map.from(anexo);
        anexoErro['erro_exportacao'] = "Falha ao ler arquivo: $e";
        anexosComImagem.add(anexoErro);
      }
    }
  }
  dadosBase['6_anexos_fotograficos'] = anexosComImagem;
  return dadosBase;
}

class CaseService {
  final CasoRepository _repository;

  CaseService(this._repository);

  Future<Caso> createNewCase({required Usuario criador, required String numeroLaudo, Map<String, dynamic> dadosIniciais = const {}}) async {
    final novoCaso = Caso.novo(idUsuarioCriador: criador.id, numeroLaudoExterno: numeroLaudo, proveniencia: 'APP_TABLET', dadosLaudo: dadosIniciais);
    await _repository.insertCase(novoCaso);
    return novoCaso;
  }

  Future<List<Caso>> listarCasos() async => await _repository.getAllCases();

  Future<void> finalizarCaso(String casoUuid, Map<String, dynamic> dadosConclusao) async {
    final casos = await _repository.getAllCases();
    final casoAtual = casos.firstWhere((c) => c.uuid == casoUuid);
    
    final Map<String, dynamic> dadosAtualizados = Map<String, dynamic>.from(casoAtual.dadosLaudo);
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
  
  Future<Map<String, dynamic>> gerarJsonExportacao(String casoUuid, String nomeCriador, String nomeExportador) async {
    return {}; 
  }

  Future<void> salvarRascunho(Caso caso) async {
    final casoAtualizado = Caso(
      uuid: caso.uuid,
      idUsuarioCriador: caso.idUsuarioCriador,
      numeroLaudoExterno: caso.numeroLaudoExterno,
      status: caso.status,
      hashIntegridade: caso.hashIntegridade,
      removido: caso.removido,
      versao: caso.versao,
      criadoEmDispositivo: caso.criadoEmDispositivo,
      criadoEmRedeConfiavel: caso.criadoEmRedeConfiavel,
      atualizadoEm: DateTime.now(),
      deviceId: caso.deviceId,
      dadosLaudo: caso.dadosLaudo,
      proveniencia: caso.proveniencia,
    );
    await _repository.updateCase(casoAtualizado);
  }

  Future<File> exportarJsonUnicoComBase64({
    required String casoUuid,
    required String nomeCriador,
    required String nomeExportador,
    required String diretorioTemp,
  }) async {
    final casos = await _repository.getAllCases();
    final caso = casos.firstWhere((c) => c.uuid == casoUuid);
    final achados = await _repository.getAchadosPorCaso(casoUuid);

    final Map<String, dynamic> dadosBase = _montarMapaBase(caso, achados, nomeCriador, nomeExportador);

    final Map<String, dynamic> jsonFinalMap = await compute(_gerarJsonBase64Background, {'dados_json': dadosBase});

    final String safeLaudoNum = (caso.numeroLaudoExterno ?? 'sem_numero').replaceAll('/', '-');
    final String fileName = 'laudo_completo_$safeLaudoNum.json';
    final File file = File('$diretorioTemp/$fileName');

    final String jsonString = const JsonEncoder.withIndent('  ').convert(jsonFinalMap);
    await file.writeAsString(jsonString, flush: true);

    return file; 
  }

  Map<String, dynamic> _montarMapaBase(Caso caso, List<Achado> achados, String nomeCriador, String nomeExportador) {
     final dados = caso.dadosLaudo;
     final cabecalho = dados['cabecalho'] ?? {};
     final identificacao = dados['identificacao'] ?? {};
     
     final exames = dados['exames_complementares'] ?? {};
     final conclusao = dados['conclusao'] ?? {};

     final Map<String, dynamic> secaoInicial = {
       'meta_info': {
         'uuid': caso.uuid,
         'data_criacao': caso.criadoEmDispositivo.toIso8601String(),
         'data_exportacao': DateTime.now().toIso8601String(),
         'perito_responsavel': nomeCriador, 
         'numero_laudo': caso.numeroLaudoExterno,
         'versao_app': '1.1.0'
       },
       'dados_requisicao': cabecalho,
       'dados_identificacao': identificacao
     };

     List<Map<String, dynamic>> listaAchadosTexto = achados.map((a) {
       final d = a.dadosPreenchidos;
       return {
         'sequencial': a.numeroSequencial,
         'tipo': d['type_label'],
         'local': d['local_anatomico_nome'],
         'tamanho': d['size'],
         'profundidade': d['depth'],
         'descricao': a.observacoesTexto,
         'posicao_croqui': d['view'],
       };
     }).toList();
     final Map<String, dynamic> secaoExames = {
        'anatomo_patologico': exames['anatomo'],
        'toxicologico': exames['toxicologico'],
        'outros_exames': exames['outros'],
     };

     final Map<String, dynamic> secaoAnalise = {
        'discussao_do_caso': conclusao['discussao'],
        'conclusao_texto': conclusao['conclusao_texto'],
     };

     final Map<String, dynamic> secaoQuesitos = {
        '1_houve_morte': conclusao['quesito_1_morte'],
        '2_qual_causa': conclusao['quesito_2_causa'],
        '3_qual_instrumento': conclusao['quesito_3_instrumento'],
        '4_qual_meio': conclusao['quesito_4_meio'],
     };

     List<Map<String, String>> galeriaFotos = [];
     
     if (identificacao['fotos'] != null && identificacao['fotos'] is List) {
       List<dynamic> fotosId = identificacao['fotos'];
       for (int i = 0; i < fotosId.length; i++) {
         galeriaFotos.add({
           'contexto': 'IDENTIFICACAO',
           'ordem': 'ID_${i+1}',
           'titulo': 'Foto Identificação ${i + 1}',
           'caminho_arquivo': fotosId[i].toString(),
         });
       }
     }

     for (var a in achados) {
        final d = a.dadosPreenchidos;
        List<String> fotos = [];
        if (d['photos'] != null) {
          fotos = List<String>.from(d['photos']);
        } else if (d['photo_path'] != null) {
          fotos.add(d['photo_path']);
        }

        for (int i=0; i<fotos.length; i++) {
          galeriaFotos.add({
            'contexto': 'LESÃO',
            'ordem': 'ACHADO_${a.numeroSequencial}',
            'titulo': "Foto do Achado #${a.numeroSequencial} - ${d['type_label']}",
            'descricao': "Local: ${d['local_anatomico_nome']}. Obs: ${a.observacoesTexto ?? ''}",
            'caminho_arquivo': fotos[i]
          });
        }
     }
     return {
       'documento': {'titulo': 'Laudo Pericial Cadavérico', 'versao_schema': '2.0'},
       '1_cabecalho': secaoInicial,
       '2_descritivo_lesoes': listaAchadosTexto,
       '3_exames_complementares': secaoExames, 
       '4_analise_medico_legal': secaoAnalise, 
       '5_respostas_quesitos': secaoQuesitos, 
       '6_anexos_fotograficos': galeriaFotos, 
       '7_auditoria_exportacao': {
          'responsavel_pela_exportacao': nomeExportador, 
          'data_hora_exportado': DateTime.now().toIso8601String(), 
          'software_origem': 'Croqui Forense App v1.1'
       }
     };
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';

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

/// Serviço de domínio encarregado de gerenciar o ciclo de vida do [Caso] (Laudo Pericial Oficial).
///
/// Coordena a criação, o salvamento de rascunhos, a finalização e o congelamento de laudos
/// para fins de auditoria e assinatura, garantindo a integridade digital de todos os dados do exame pericial.
class CaseService {
  final CasoRepository _repository;
  final UsuarioRepository _usuarioRepository;

  CaseService(this._repository, this._usuarioRepository);

  /// Inicializa e registra um novo [Caso] (Laudo Pericial Oficial) no repositório do dispositivo.
  ///
  /// Vincula o laudo ao [Perito] criador através de seu identificador funcional.
  ///
  /// @throws [Exception] caso o repositório falhe na persistência inicial dos dados do laudo.
  Future<Caso> createNewCase({
    required Usuario criador, 
    required String numeroLaudo, 
    Map<String, dynamic> dadosIniciais = const {},
    String numeroPic = '',
    String numeroBo = '',
    String numeroRequisicao = '',
    String nomeVitima = '',
    String destino = '',
    String requisitante = '',
  }) async {
    final novoCaso = Caso.novo(
      idUsuarioCriador: criador.id, 
      numeroLaudoExterno: numeroLaudo, 
      dadosLaudo: dadosIniciais,
      numeroPic: numeroPic,
      numeroBo: numeroBo,
      numeroRequisicao: numeroRequisicao,
      nomeVitima: nomeVitima,
      destino: destino,
      requisitante: requisitante,
    );
    await _repository.insertCase(novoCaso);
    return novoCaso;
  }

  Future<void> salvarCasoComEvidenciasLote(Caso caso, List<EvidenciaMultimidia> evidencias) async {
    await _repository.insertCaseComEvidenciasLote(caso, evidencias);
  }

  /// Retorna todos os [Caso]s (Laudos) gravados no repositório local.
  Future<List<Caso>> listarCasos() async => await _repository.getAllCases();

  /// Localiza um [Caso] (Laudo) específico com base em seu identificador universal único ([uuid]).
  Future<Caso?> buscarCasoPorUuid(String uuid) async => _repository.getCaseByUuid(uuid);

  /// Finaliza e congela o [Caso] (Laudo) para auditoria e assinatura eletrônica do [Perito].
  ///
  /// Altera o status do caso para `StatusCaso.finalizado`, bloqueando modificações diretas
  /// em lesões e fotos associadas a fim de manter a inalterabilidade da prova técnica.
  ///
  /// @throws [Exception] se o laudo com o [casoUuid] fornecido não for localizado no banco local.
  Future<void> finalizarCaso(String casoUuid, Map<String, dynamic> dadosConclusao) async {
    final casoAtual = await _repository.getCaseByUuid(casoUuid);
    if (casoAtual == null) throw Exception('Caso não encontrado: $casoUuid');

    final Map<String, dynamic> dadosAtualizados = Map<String, dynamic>.from(casoAtual.dadosLaudo);
    dadosAtualizados.addAll(dadosConclusao);

    final casoFinalizado = casoAtual.copyWith(
      status: StatusCaso.finalizado,
      dadosLaudo: dadosAtualizados,
      versao: casoAtual.versao + 1,
      atualizadoEm: DateTime.now(),
    );
    await _repository.updateCase(casoFinalizado);
  }

  // Métodos de delegação para fotos gerais e exames solicitados

  Future<List<EvidenciaMultimidia>> getEvidenciasGerais(String casoUuid) =>
      _repository.getEvidenciasGerais(casoUuid);

  Future<void> salvarEvidenciaGeral(EvidenciaMultimidia ev) =>
      _repository.insertEvidenciaGeral(ev);

  Future<void> removerEvidenciaGeral(String uuid) =>
      _repository.deleteEvidenciaGeral(uuid);

  Future<List<ExameSolicitado>> getExamesSolicitados(String casoUuid) =>
      _repository.getExamesSolicitados(casoUuid);

  Future<void> salvarExamesSolicitados({
    required String casoUuid,
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) =>
      _repository.salvarExamesSolicitados(
        casoUuid: casoUuid,
        anatomoLacre: anatomoLacre,
        toxicologicoLacre: toxicologicoLacre,
        geneticaLacre: geneticaLacre,
        outrosLacre: outrosLacre,
      );

  /// Reabre um [Caso] (Laudo) finalizado, restaurando seu status para rascunho.
  ///
  /// Limpa as assinaturas de integridade e incrementa a versão do documento, permitindo
  /// que o [Perito] altere ou insira novas marcações de lesões antes do fechamento oficial definitivo.
  ///
  /// @throws [Exception] se o laudo com o [casoUuid] fornecido não for localizado.
  Future<void> reabrirCaso(String casoUuid) async {
    final casoAtual = await _repository.getCaseByUuid(casoUuid);
    if (casoAtual == null) throw Exception('Caso não encontrado: $casoUuid');

    final casoReaberto = casoAtual.copyWith(
      status: StatusCaso.rascunho,
      hashIntegridade: null,
      versao: casoAtual.versao + 1,
      atualizadoEm: DateTime.now(),
    );
    await _repository.updateCase(casoReaberto);
  }

  /// Persiste as atualizações em modo rascunho de um [Caso] (Laudo).
  ///
  /// @throws [Exception] caso o laudo já tenha sido finalizado (bloqueado para edição) e
  /// o perito tente salvar alterações sem antes realizar a reabertura formal.
  Future<void> salvarRascunho(Caso caso) async {
    final casoAtualizado = caso.copyWith(
      atualizadoEm: DateTime.now(),
      isDraftSynced: false,
    );
    await _repository.updateCase(casoAtualizado);
  }

  /// Exporta o [Caso] (Laudo) em um arquivo JSON consolidado para auditoria externa.
  ///
  /// Realiza a conversão de todas as [Evidência Fotográfica]s cadastradas para codificação Base64.
  /// A leitura e codificação de imagens são processadas em segundo plano (background thread/isolate)
  /// para evitar o travamento da interface visual no tablet do [Perito].
  ///
  /// @throws [Exception] caso o laudo com [casoUuid] não exista ou ocorra um erro de leitura
  /// dos arquivos físicos das evidências de imagem.
  Future<File> exportarJsonUnicoComBase64({
    required String casoUuid,
    required String nomeExportador,
    required String diretorioTemp,
  }) async {
    final caso = await _repository.getCaseByUuid(casoUuid);
    if (caso == null) throw Exception('Caso não encontrado: $casoUuid');
    final achados = await _repository.getAchadosPorCaso(casoUuid);

    final usuarioCriador = await _usuarioRepository.getUsuarioById(caso.idUsuarioCriador);
    final String nomeRealCriador = usuarioCriador?.nomeCompleto ?? "Perito Desconhecido (ID: ${caso.idUsuarioCriador})";
    final Map<String, dynamic> dadosBase = _montarMapaBase(
      caso, 
      achados, 
      nomeRealCriador, 
      nomeExportador
    );

    final Map<String, dynamic> jsonFinalMap = await compute(_gerarJsonBase64Background, {'dados_json': dadosBase});

    final String safeLaudoNum = (caso.numeroLaudoExterno ?? 'sem_numero').replaceAll('/', '-');
    final String fileName = 'laudo_completo_$safeLaudoNum.json';
    final File file = File('$diretorioTemp/$fileName');
    final String jsonString = const JsonEncoder.withIndent('  ').convert(jsonFinalMap);
    await file.writeAsString(jsonString, flush: true);

    return file; 
  }

  Map<String, dynamic> _montarMapaBase(Caso caso, List<Achado> achados, String nomeCriador, String nomeExportador) {
    return {
      'documento': {'titulo': 'Laudo Pericial Cadavérico', 'versao_schema': '2.0'},
      '1_cabecalho': _buildCabecalho(caso, nomeCriador),
      '2_descritivo_lesoes': _buildListaAchados(achados),
      '3_exames_complementares': _buildExamesComplementares(caso.dadosLaudo),
      '4_analise_medico_legal': _buildAnaliseMedicoLegal(caso.dadosLaudo),
      '5_respostas_quesitos': _buildRespostasQuesitos(caso.dadosLaudo),
      '6_anexos_fotograficos': _buildGaleriaFotos(caso.dadosLaudo, achados),
      '7_auditoria_exportacao': _buildAuditoria(nomeExportador)
    };
  }

  Map<String, dynamic> _buildCabecalho(Caso caso, String nomeCriador) {
    final cabecalho = caso.dadosLaudo['cabecalho'] ?? {};
    final identificacao = caso.dadosLaudo['identificacao'] ?? {};
    
    return {
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
  }

  List<Map<String, dynamic>> _buildListaAchados(List<Achado> achados) {
    return achados.map((a) {
      final d = a.dadosPreenchidos;
      return {
        'sequencial': a.numeroSequencial,
        'tipo': d['type_label'],
        'local': d['local_anatomico_nome'],
        'tamanho': a.tamanho,
        'profundidade': a.profundidade,
        'descricao': a.observacoesTexto,
        'posicao_croqui': d['view'],
      };
    }).toList();
  }

  Map<String, dynamic> _buildExamesComplementares(Map<String, dynamic> dados) {
    final exames = dados['exames_complementares'] ?? {};
    return {
      'anatomo_patologico': exames['anatomo'],
      'toxicologico': exames['toxicologico'],
      'outros_exames': exames['outros'],
    };
  }

  Map<String, dynamic> _buildAnaliseMedicoLegal(Map<String, dynamic> dados) {
    final conclusao = dados['conclusao'] ?? {};
    return {
      'discussao_do_caso': conclusao['discussao'],
      'conclusao_texto': conclusao['conclusao_texto'],
    };
  }

  Map<String, dynamic> _buildRespostasQuesitos(Map<String, dynamic> dados) {
    final conclusao = dados['conclusao'] ?? {};
    return {
      '1_houve_morte': conclusao['quesito_1_morte'],
      '2_qual_causa': conclusao['quesito_2_causa'],
      '3_qual_instrumento': conclusao['quesito_3_instrumento'],
      '4_qual_meio': conclusao['quesito_4_meio'],
    };
  }

  List<Map<String, dynamic>> _buildGaleriaFotos(Map<String, dynamic> dados, List<Achado> achados) {
    List<Map<String, dynamic>> galeria = [];
    final identificacao = dados['identificacao'] ?? {};
    
    if (identificacao['fotos'] != null && identificacao['fotos'] is List) {
      List<dynamic> fotosId = identificacao['fotos'];
      for (int i = 0; i < fotosId.length; i++) {
        galeria.add({
          'contexto': 'IDENTIFICACAO',
          'ordem': 'ID_${i + 1}',
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

      for (int i = 0; i < fotos.length; i++) {
        galeria.add({
          'contexto': 'LESÃO',
          'ordem': 'ACHADO_${a.numeroSequencial}',
          'titulo': "Foto do Achado #${a.numeroSequencial} - ${d['type_label']}",
          'descricao': "Local: ${d['local_anatomico_nome']}. Obs: ${a.observacoesTexto ?? ''}",
          'caminho_arquivo': fotos[i]
        });
      }
    }
    return galeria;
  }

  Map<String, dynamic> _buildAuditoria(String nomeExportador) {
    return {
      'responsavel_pela_exportacao': nomeExportador, 
      'data_hora_exportado': DateTime.now().toIso8601String(), 
      'software_origem': 'Necropsia Digital App v1.1'
    };
  }
}
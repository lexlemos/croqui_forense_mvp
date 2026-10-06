/// Modelo de transferência de dados (DTO) imutável que encapsula a resposta
/// da consulta prévia de exame/protocolo realizada no servidor central do IML.
///
/// Segue a Lei de Postel e os princípios de Robustness do DDD, mapeando os blocos
/// estruturados do backend (`documento`, `deslocamento`, `vitima`, `ocorrencia`)
/// com fallbacks defensivos para estruturas legadas e blindagem contra tipos inválidos.
class ProtocoloLookupModel {
  /// Código do procedimento externo (PIC).
  final String? numeroPic;

  /// Código digital do exame / requisição interna (CD).
  final String? numeroRequisicao;

  /// Número do Boletim de Ocorrência policial.
  final String? numeroBo;

  /// Autoridade requisitante (Delegado / Juiz).
  final String? requisitante;

  /// Delegacia de polícia solicitante.
  final String? delegaciaSolicitante;

  /// Destino judicial ou administrativo para encaminhamento do laudo.
  final String? destinoLaudo;

  /// Nome civil da vítima identificada (nulo caso a vítima seja não identificada).
  final String? nomeVitima;

  /// Sexo biológico estimado (`MASCULINO`, `FEMININO` ou `INDETERMINADO`).
  final String? sexoBiologicoEstimado;

  /// Data em que o fato/óbito ocorreu (formato `YYYY-MM-DD`).
  final String? dataFato;

  /// Hora em que o fato/óbito ocorreu (formato `HH:MM:SS`).
  final String? horaFato;

  /// Número da Declaração de Óbito (D.O.), se preenchido previamente.
  final String? numeroDeclaracaoObito;

  const ProtocoloLookupModel({
    this.numeroPic,
    this.numeroRequisicao,
    this.numeroBo,
    this.requisitante,
    this.delegaciaSolicitante,
    this.destinoLaudo,
    this.nomeVitima,
    this.sexoBiologicoEstimado,
    this.dataFato,
    this.horaFato,
    this.numeroDeclaracaoObito,
  });

  /// Instancia o modelo a partir do mapa de resposta da API REST.
  ///
  /// Extrai dados dos nós hierárquicos modernos com fallback defensivo
  /// para campos em nível de raiz.
  factory ProtocoloLookupModel.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic>? documento = map['documento'] is Map
        ? Map<String, dynamic>.from(map['documento'] as Map)
        : null;

    final Map<String, dynamic>? deslocamento = map['deslocamento'] is Map
        ? Map<String, dynamic>.from(map['deslocamento'] as Map)
        : null;

    final Map<String, dynamic>? vitima = map['vitima'] is Map
        ? Map<String, dynamic>.from(map['vitima'] as Map)
        : null;

    final Map<String, dynamic>? ocorrencia = map['ocorrencia'] is Map
        ? Map<String, dynamic>.from(map['ocorrencia'] as Map)
        : null;

    final picVal = documento?['protocolo_externo'] ??
        map['protocolo_externo'] ??
        map['pic'] ??
        map['numero_pic'];

    final reqVal = documento?['protocolo_interno'] ??
        deslocamento?['numero_requisicao'] ??
        map['protocolo_interno'] ??
        map['numero_requisicao'] ??
        map['requisicao'] ??
        map['cd'] ??
        map['numero_laudo'];

    final boVal = deslocamento?['numero_boletim_ocorrencia'] ??
        map['numero_boletim_ocorrencia'] ??
        map['numero_bo'] ??
        map['bo'];

    final requisitanteVal = deslocamento?['requisitante'] ??
        map['requisitante'] ??
        map['autoridade'] ??
        map['autoridade_requisitante'];

    final delegaciaVal = deslocamento?['delegacia_solicitante'] ??
        map['delegacia_solicitante'] ??
        map['delegacia'] ??
        map['delegacia_origem'];

    final destinoVal = deslocamento?['destino_laudo'] ??
        map['destino_laudo'] ??
        map['destino'];

    String? parsedNomeVitima;
    final rawNome = vitima?['nome_completo']?.toString();
    if (rawNome != null &&
        rawNome.trim().isNotEmpty &&
        rawNome.toUpperCase() != 'NAO_IDENTIFICADO' &&
        rawNome.toUpperCase() != 'NÃO IDENTIFICADO') {
      parsedNomeVitima = rawNome.trim();
    } else if (map['nome_vitima'] is String &&
        (map['nome_vitima'] as String).trim().isNotEmpty) {
      parsedNomeVitima = (map['nome_vitima'] as String).trim();
    }

    final sexoVal = vitima?['sexo_biologico_estimado'] ??
        map['sexo_biologico_estimado'] ??
        map['sexo'];

    final dataFatoVal = ocorrencia?['data_fato'] ??
        map['data_fato'] ??
        map['data_obito'];

    final horaFatoVal = ocorrencia?['hora_fato'] ??
        map['hora_fato'] ??
        map['hora_obito'];

    final declaracaoVal = map['numero_declaracao_obito'] ??
        map['declaracao_obito'] ??
        map['numero_do'];

    return ProtocoloLookupModel(
      numeroPic: _asNonEmptyString(picVal),
      numeroRequisicao: _asNonEmptyString(reqVal),
      numeroBo: _asNonEmptyString(boVal),
      requisitante: _asNonEmptyString(requisitanteVal),
      delegaciaSolicitante: _asNonEmptyString(delegaciaVal),
      destinoLaudo: _asNonEmptyString(destinoVal),
      nomeVitima: parsedNomeVitima,
      sexoBiologicoEstimado: _asNonEmptyString(sexoVal),
      dataFato: _asNonEmptyString(dataFatoVal),
      horaFato: _asNonEmptyString(horaFatoVal),
      numeroDeclaracaoObito: _asNonEmptyString(declaracaoVal),
    );
  }

  static String? _asNonEmptyString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }
}

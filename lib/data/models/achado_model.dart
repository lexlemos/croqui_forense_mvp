import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Entidade central que representa uma lesão, orifício ou vestígio anatômico mapeado no croqui pericial.
///
/// Unifica as coordenadas geométricas relativas ([posX], [posY]) no diagrama anatômico ([diagramaNome]),
/// a vista corporal examinada ([vistaAnatomica], [localAnatomico]), metadados da cadeia de custódia balística
/// ([tipoFerimento], [numeroLacre], [tipoObjeto]), o caminho da evidência fotográfica anexada
/// e os campos dinâmicos da lesão ([dadosPreenchidos]).
///
/// ### Vínculo com o Laudo e Diagrama (Chaves UUID)
/// - [uuid]: Identificador universal único da lesão gerado localmente no dispositivo.
/// - [casoUuid]: Chave estrangeira que vincula o achado ao [Caso] mestre.
/// - [diagramaCasoUuid]: Chave de identificação da vista específica do croqui dentro do caso.
/// - [achadoRelacionadoUuid]: Chave opcional que conecta ferimentos correlacionados (ex: Entrada ↔ Saída de PAF).
class Achado {
  /// Identificador universal único do achado (UUID v4).
  final String uuid;

  /// Identificador universal do laudo pericial ([Caso]) ao qual esta lesão pertence.
  final String casoUuid;

  /// Identificador do diagrama específico associado ao caso.
  final String diagramaCasoUuid;

  /// Nome do template de diagrama anatômico utilizado (ex: "FRENTE", "COSTAS", "LATERAL_DIREITA").
  final String diagramaNome;

  /// Identificador do tipo de lesão (ex: "PAF_ENTRADA", "ESCORIACAO", "EQUIMOSE").
  final String tipoAchadoId;

  /// Número sequencial da lesão no laudo pericial (ex: Lesão nº 1, Lesão nº 2).
  final int numeroSequencial;

  /// Coordenada horizontal normalizada (percentual de 0.0 a 1.0) no croqui SVG.
  final double posX;

  /// Coordenada vertical normalizada (percentual de 0.0 a 1.0) no croqui SVG.
  final double posY;

  /// Sinaliza se a lesão afeta cavidades/órgãos internos ou se é estritamente externa.
  final bool isInterno;

  /// UUID do achado relacionado (utilizado para correlacionar orifícios de entrada e saída).
  final String? achadoRelacionadoUuid;

  /// Mapa flexível contendo atributos dinâmicos do formulário pericial (dimensões, profundidade, caminho da foto, etc.).
  final Map<String, dynamic> dadosPreenchidos;

  /// Descrição livre e observações médico-legais detalhadas sobre a lesão.
  final String? observacoesTexto;

  /// Indicador de exclusão lógica (*tombstone*) para integridade do ciclo de sincronização.
  final bool removido;

  /// Versão sequencial da entidade para controle de concorrência otimista (OCC).
  final int versao;

  /// Timestamp UTC de registro da lesão no tablet do perito.
  final DateTime criadoEm;

  /// Timestamp UTC da última edição realizada no registro do achado.
  final DateTime? atualizadoEm;

  /// Identificador do dispositivo físico que realizou a última alteração.
  final String? deviceId;

  /// Dimensões da lesão registradas pelo perito (ex: "2x1 cm", "3 cm").
  final String tamanho;

  /// Vista anatômica de visualização da lesão (ex: "Frente", "Costas", "Face Direita").
  final String vistaAnatomica;

  /// Nome da região anatômica delimitada onde a lesão se localiza (ex: "Tórax Anterior", "Região Frontal").
  final String localAnatomico;

  /// Especifica a natureza balística da lesão (ex: Entrada, Saída, Raspão).
  /// Fundamental para determinar a trajetória do projétil na dinâmica do crime.
  final String? tipoFerimento;

  /// Número do lacre de segurança utilizado para acondicionar o vestígio físico (projétil, estojo, etc).
  /// Elemento crucial para garantir a rastreabilidade e a validade jurídica da cadeia de custódia.
  final String? numeroLacre;

  /// Descreve a natureza do vestígio físico recolhido (ex: Projétil, Estojo, Fragmento, Roupa).
  /// Atua em conjunto com o [numeroLacre] para individualizar o objeto na cadeia de custódia.
  final String? tipoObjeto;

  /// Observações pormenorizadas exclusivas sobre o vestígio recolhido e seu acondicionamento.
  /// Complementa as evidências materiais garantindo que peculiaridades do objeto sejam registradas.
  final String? comentarioAdicional;

  /// Cria uma instância de [Achado] com todos os parâmetros fornecidos.
  Achado({
    required this.uuid,
    required this.casoUuid,
    required this.diagramaCasoUuid,
    required this.diagramaNome,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
    required this.isInterno,
    this.achadoRelacionadoUuid,
    required this.dadosPreenchidos,
    this.observacoesTexto,
    required this.removido,
    required this.versao,
    required this.criadoEm,
    this.atualizadoEm,
    this.deviceId,
    required this.tamanho,
    required this.vistaAnatomica,
    required this.localAnatomico,
    this.tipoFerimento,
    this.numeroLacre,
    this.tipoObjeto,
    this.comentarioAdicional,
  });

  /// Profundidade da lesão extraída dos atributos dinâmicos do formulário.
  String get profundidade {
    return dadosPreenchidos['depth']?.toString() ??
        dadosPreenchidos['profundidade']?.toString() ??
        '';
  }

  /// Instancia um novo achado gerando um [uuid] v4 inédito e configurando versão inicial `1`.
  Achado.novo({
    required this.casoUuid,
    required this.diagramaCasoUuid,
    required this.diagramaNome,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
    required this.isInterno,
    required this.tamanho,
    required this.vistaAnatomica,
    required this.localAnatomico,
    this.achadoRelacionadoUuid,
    this.tipoFerimento,
    this.numeroLacre,
    this.tipoObjeto,
    this.comentarioAdicional,
  }) : uuid = const Uuid().v4(),
       dadosPreenchidos = const {},
       observacoesTexto = null,
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null,
       deviceId = null;

  /// Reconstrói um [Achado] a partir do mapa relacional SQLite ou payload de sincronização REST.
  ///
  /// Aplica tolerância e extração polimórfica de fotografias anexas (`photo_path`, `evidencias_multimidia`),
  /// decodificando com segurança o JSON de campos dinâmicos (`dados_preenchidos_json`).
  factory Achado.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> dados = map['dados_preenchidos_json'] != null
        ? (map['dados_preenchidos_json'] is Map
              ? Map<String, dynamic>.from(map['dados_preenchidos_json'] as Map)
              : Map<String, dynamic>.from(
                  (() {
                    try {
                      return jsonDecode(
                                map['dados_preenchidos_json'].toString(),
                              )
                              as Map? ??
                          {};
                    } catch (_) {
                      return {};
                    }
                  })(),
                ))
        : <String, dynamic>{};

    if (!dados.containsKey('photo_path') ||
        dados['photo_path'] == null ||
        dados['photo_path'].toString().isEmpty) {
      final rawEvidencias = map['evidencias_multimidia'] ?? map['evidencias'];
      if (rawEvidencias is List && rawEvidencias.isNotEmpty) {
        final firstEv = rawEvidencias.first;
        if (firstEv is Map) {
          final photoUrl =
              firstEv['caminho_arquivo_encriptado']?.toString() ??
              firstEv['url']?.toString() ??
              firstEv['path']?.toString();
          if (photoUrl != null && photoUrl.isNotEmpty) {
            dados['photo_path'] = photoUrl;
          }
        }
      } else {
        final photoDirect =
            map['photo_path']?.toString() ??
            map['caminho_arquivo_encriptado']?.toString() ??
            map['url']?.toString();
        if (photoDirect != null && photoDirect.isNotEmpty) {
          dados['photo_path'] = photoDirect;
        }
      }
    }

    return Achado(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid:
          map['caso_uuid']?.toString() ?? map['exame_id']?.toString() ?? '',
      diagramaCasoUuid:
          map['diagrama_caso_uuid']?.toString() ??
          map['diagrama_uuid']?.toString() ??
          '',
      diagramaNome: map['diagrama_nome']?.toString() ?? '',
      tipoAchadoId: map['tipo_achado_id']?.toString() ?? '',
      achadoRelacionadoUuid: map['achado_relacionado_uuid']?.toString(),
      numeroSequencial: map['numero_sequencial'] as int? ?? 0,
      posX: (map['pos_x'] as num?)?.toDouble() ?? 0.0,
      posY: (map['pos_y'] as num?)?.toDouble() ?? 0.0,
      isInterno: map['is_interno'] is bool
          ? map['is_interno'] as bool
          : (map['is_interno'] as int? ?? 0) == 1,
      dadosPreenchidos: dados,
      observacoesTexto: map['observacoes_texto']?.toString(),
      removido: map['removido'] is bool
          ? map['removido'] as bool
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm:
          DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null
          ? DateTime.tryParse(map['atualizado_em'].toString())
          : null,
      deviceId: map['device_id']?.toString(),
      tamanho: map['tamanho']?.toString() ?? '',
      vistaAnatomica: map['vista_anatomica']?.toString() ?? '',
      localAnatomico: map['local_anatomico']?.toString() ?? '',
      tipoFerimento:
          map['tipo_ferimento']?.toString() ??
          map['tipoFerimento']?.toString() ??
          dados['tipo_ferimento']?.toString() ??
          dados['tipoFerimento']?.toString(),
      numeroLacre:
          map['numero_lacre']?.toString() ??
          map['numeroLacre']?.toString() ??
          dados['numero_lacre']?.toString() ??
          dados['numeroLacre']?.toString(),
      tipoObjeto:
          map['tipo_objeto']?.toString() ??
          map['tipoObjeto']?.toString() ??
          dados['tipo_objeto']?.toString() ??
          dados['tipoObjeto']?.toString(),
      comentarioAdicional:
          map['comentario_adicional']?.toString() ??
          map['comentarioAdicional']?.toString() ??
          dados['comentario_adicional']?.toString() ??
          dados['comentarioAdicional']?.toString(),
    );
  }

  /// Retorna uma nova instância de [Achado] aplicando mutações seletivas nos campos especificados.
  Achado copyWith({
    String? uuid,
    String? casoUuid,
    String? diagramaCasoUuid,
    String? diagramaNome,
    String? tipoAchadoId,
    String? achadoRelacionadoUuid,
    int? numeroSequencial,
    double? posX,
    double? posY,
    bool? isInterno,
    Map<String, dynamic>? dadosPreenchidos,
    String? observacoesTexto,
    bool? removido,
    int? versao,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    String? deviceId,
    String? tamanho,
    String? vistaAnatomica,
    String? localAnatomico,
    String? tipoFerimento,
    String? numeroLacre,
    String? tipoObjeto,
    String? comentarioAdicional,
  }) {
    return Achado(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      diagramaCasoUuid: diagramaCasoUuid ?? this.diagramaCasoUuid,
      diagramaNome: diagramaNome ?? this.diagramaNome,
      tipoAchadoId: tipoAchadoId ?? this.tipoAchadoId,
      achadoRelacionadoUuid:
          achadoRelacionadoUuid ?? this.achadoRelacionadoUuid,
      numeroSequencial: numeroSequencial ?? this.numeroSequencial,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      isInterno: isInterno ?? this.isInterno,
      dadosPreenchidos: dadosPreenchidos ?? this.dadosPreenchidos,
      observacoesTexto: observacoesTexto ?? this.observacoesTexto,
      removido: removido ?? this.removido,
      versao: versao ?? this.versao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      deviceId: deviceId ?? this.deviceId,
      tamanho: tamanho ?? this.tamanho,
      vistaAnatomica: vistaAnatomica ?? this.vistaAnatomica,
      localAnatomico: localAnatomico ?? this.localAnatomico,
      tipoFerimento: tipoFerimento ?? this.tipoFerimento,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      tipoObjeto: tipoObjeto ?? this.tipoObjeto,
      comentarioAdicional: comentarioAdicional ?? this.comentarioAdicional,
    );
  }

  /// Serializa a entidade [Achado] para persistência relacional plana na tabela `achados` do SQLite.
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'diagrama_caso_uuid': diagramaCasoUuid,
      'diagrama_nome': diagramaNome,
      'tipo_achado_id': tipoAchadoId,
      'achado_relacionado_uuid': achadoRelacionadoUuid,
      'numero_sequencial': numeroSequencial,
      'pos_x': posX,
      'pos_y': posY,
      'is_interno': isInterno ? 1 : 0,
      'dados_preenchidos_json': jsonEncode(dadosPreenchidos),
      'observacoes_texto': observacoesTexto,
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
      'device_id': deviceId,
      'tamanho': tamanho,
      'vista_anatomica': vistaAnatomica,
      'local_anatomico': localAnatomico,
      'tipo_ferimento': tipoFerimento,
      'numero_lacre': numeroLacre,
      'tipo_objeto': tipoObjeto,
      'comentario_adicional': comentarioAdicional,
    };
  }

  /// Converte o [Achado] no payload de sincronização REST formatado para envio (push) à API central.
  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'diagrama_caso_uuid': diagramaCasoUuid,
      'tipo_achado_id': tipoAchadoId,
      'versao': versao,
      'removido': removido,
      'numero_sequencial': numeroSequencial,
      'pos_x': posX.toDouble(),
      'pos_y': posY.toDouble(),
      'dados_preenchidos_json': dadosPreenchidos,
      'observacoes_texto': observacoesTexto,
      'tamanho': tamanho,
      'vista_anatomica': vistaAnatomica,
      'local_anatomico': localAnatomico,
      'tipo_ferimento': tipoFerimento,
      'numero_lacre': numeroLacre,
      'tipo_objeto': tipoObjeto,
      'comentario_adicional': comentarioAdicional,
      'criado_em': criadoEm.toUtc().toIso8601String(),
      'atualizado_em': (atualizadoEm ?? criadoEm).toUtc().toIso8601String(),
    };
  }

  /// Rótulo legível do tipo da lesão (ex: "Entrada de PAF", "Equimose").
  String get type {
    return dadosPreenchidos['type_label']?.toString() ?? 'Não definido';
  }

  /// Caminho do arquivo físico da foto associada a este achado.
  String? get photoPath {
    return dadosPreenchidos['photo_path']?.toString();
  }

  /// Descrição textual observada da lesão.
  String get description {
    return observacoesTexto ?? '';
  }
}

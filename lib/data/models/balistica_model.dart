import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';

/// Classificação médico-legal da natureza do ferimento causado por projétil de arma de fogo (PAF).
enum TipoFerimento {
  /// Orifício ou lesão de entrada de projétil no corpo.
  entrada('Entrada'),

  /// Orifício ou lesão de saída de projétil do corpo.
  saida('Saída'),

  /// Lesão tangencial provocada pelo atrito do projétil na superfície corporal.
  raspao('Raspão'),

  /// Classificação indeterminada ou inconclusiva no momento do exame externo.
  indeterminado('Indeterminado');

  /// Rótulo legível para apresentação na interface e impressão no laudo.
  final String valor;
  const TipoFerimento(this.valor);

  /// Converte uma string ou rótulo textual no respectivo [TipoFerimento].
  static TipoFerimento? fromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final norm = value.trim().toLowerCase();
    for (final v in TipoFerimento.values) {
      if (v.valor.toLowerCase() == norm || v.name.toLowerCase() == norm) {
        return v;
      }
    }
    return TipoFerimento.indeterminado;
  }

  /// Lista de todos os rótulos textuais disponíveis.
  static List<String> get valores =>
      TipoFerimento.values.map((e) => e.valor).toList();
}

/// Tipologia do elemento balístico ou vestígio de munição recolhido durante o exame necroscópico.
enum TipoObjeto {
  /// Projétil íntegro ou substancialmente preservado.
  projetil('Projétil'),

  /// Estojo deflagrado recolhido junto às vestes ou ao cadáver.
  estojo('Estojo'),

  /// Fragmento metálico, jaqueta ou núcleo desprendido de projétil.
  fragmento('Fragmento'),

  /// Balote de arma de alma lisa (espingarda).
  balote('Balote'),

  /// Chumbo grosso de munição de caça ou espingarda (ex: balins SG, 3T).
  chumboGrosso('Chumbo Grosso'),

  /// Chumbo fino de munição de espingarda (ex: múltiplos balins finos).
  chumboFino('Chumbo Fino'),

  /// Outro vestígio ou corpo estranho balístico não categorizado nas opções anteriores.
  outro('Outro');

  /// Rótulo legível para apresentação na interface e impressão no laudo.
  final String valor;
  const TipoObjeto(this.valor);

  /// Converte uma string ou rótulo textual no respectivo [TipoObjeto].
  static TipoObjeto? fromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final norm = value.trim().toLowerCase();
    for (final v in TipoObjeto.values) {
      if (v.valor.toLowerCase() == norm || v.name.toLowerCase() == norm) {
        return v;
      }
    }
    return TipoObjeto.outro;
  }

  /// Lista de todos os rótulos textuais disponíveis.
  static List<String> get valores =>
      TipoObjeto.values.map((e) => e.valor).toList();
}

/// Entidade de representação dos vestígios balísticos e projéteis recolhidos no exame cadavérico.
///
/// Associa o vestígio físico recolhido (PAF, fragmento, estojo) ao achado/ferimento corporal mapeado
/// no croqui ([achadoUuid]) e ao número do lacre de custódia, suportando o fluxo de auditoria
/// e confirmação pelo Auxiliar Técnico de Necrópsia (ATN).
class BalisticaModel {
  /// Identificador único UUID v4 do registro balístico.
  final String id;

  /// Chave estrangeira UUID do laudo/exame pericial matriz.
  final String exameId;

  /// Chave estrangeira UUID do [Achado] correspondente ao ferimento onde o vestígio foi coletado.
  final String? achadoUuid;

  /// Natureza do ferimento (Entrada, Saída, Raspão, etc.).
  final String? tipoFerimento;

  /// Classificação do vestígio (Projétil, Estojo, Fragmento, etc.).
  final String? tipoObjeto;

  /// Número do lacre individualizado da embalagem de custódia balística.
  final String? numeroLacre;

  /// Comentários e anotações descritivas do perito sobre o vestígio (deformações, marcas, localização anatômica profunda).
  final String? comentarioAdicional;

  /// Estado de confirmação física e custódia pelo ATN ([StatusConfirmacaoATN]).
  ///
  /// Reflete o fluxo de auditoria do backend para rastreamento de cadeia de custódia.
  final StatusConfirmacaoATN statusConfirmacaoAtn;

  /// Justificativa formal registrada pelo ATN caso a conferência do vestígio tenha sido recusada.
  final String? justificativaRecusa;

  BalisticaModel({
    String? id,
    required this.exameId,
    this.achadoUuid,
    this.tipoFerimento,
    this.tipoObjeto,
    this.numeroLacre,
    this.comentarioAdicional,
    this.statusConfirmacaoAtn = StatusConfirmacaoATN.PENDENTE,
    this.justificativaRecusa,
  }) : id = id ?? const Uuid().v4();

  /// Cria uma cópia imutável de [BalisticaModel] com campos atualizados.
  BalisticaModel copyWith({
    String? id,
    String? exameId,
    String? achadoUuid,
    String? tipoFerimento,
    String? tipoObjeto,
    String? numeroLacre,
    String? comentarioAdicional,
    StatusConfirmacaoATN? statusConfirmacaoAtn,
    String? justificativaRecusa,
  }) {
    return BalisticaModel(
      id: id ?? this.id,
      exameId: exameId ?? this.exameId,
      achadoUuid: achadoUuid ?? this.achadoUuid,
      tipoFerimento: tipoFerimento ?? this.tipoFerimento,
      tipoObjeto: tipoObjeto ?? this.tipoObjeto,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      comentarioAdicional: comentarioAdicional ?? this.comentarioAdicional,
      statusConfirmacaoAtn: statusConfirmacaoAtn ?? this.statusConfirmacaoAtn,
      justificativaRecusa: justificativaRecusa ?? this.justificativaRecusa,
    );
  }

  /// Serializa o registro balístico para armazenamento no SQLite e sincronização com a API.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exame_id': exameId,
      if (achadoUuid != null) 'achado_uuid': achadoUuid,
      if (tipoFerimento != null) 'tipo_ferimento': tipoFerimento,
      if (tipoObjeto != null) 'tipo_objeto': tipoObjeto,
      if (numeroLacre != null) 'numero_lacre': numeroLacre,
      if (comentarioAdicional != null)
        'comentario_adicional': comentarioAdicional,
      'status_confirmacao_atn': statusConfirmacaoAtn.toBackendString(),
      if (justificativaRecusa != null)
        'justificativa_recusa': justificativaRecusa,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  /// Desserializa um mapa em [BalisticaModel] tolerando diferentes convenções de chaves da API e do SQLite.
  factory BalisticaModel.fromMap(Map<String, dynamic> map) {
    return BalisticaModel(
      id: map['id']?.toString() ?? map['uuid']?.toString(),
      exameId:
          map['exame_id']?.toString() ?? map['caso_uuid']?.toString() ?? '',
      achadoUuid: (map['achado_uuid'] ?? map['achado_id'] ?? map['achadoUuid'])
          ?.toString(),
      tipoFerimento: (map['tipo_ferimento'] ?? map['tipoFerimento'])
          ?.toString(),
      tipoObjeto: (map['tipo_objeto'] ?? map['tipoObjeto'])?.toString(),
      numeroLacre: (map['numero_lacre'] ?? map['numeroLacre'])?.toString(),
      comentarioAdicional:
          (map['comentario_adicional'] ?? map['comentarioAdicional'])
              ?.toString(),
      statusConfirmacaoAtn: StatusConfirmacaoATN.fromString(
        map['status_confirmacao_atn']?.toString(),
      ),
      justificativaRecusa:
          (map['justificativa_recusa'] ?? map['justificativaRecusa'])
              ?.toString(),
    );
  }

  factory BalisticaModel.fromJson(Map<String, dynamic> json) =>
      BalisticaModel.fromMap(json);
}


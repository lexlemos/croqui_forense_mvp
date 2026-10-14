import 'laudo_documento.dart';
import 'laudo_foto.dart';
import 'laudo_croqui_ref.dart';

/// Metadados de procedência e geração do pacote de laudo.
class LaudoProcedencia {
  final String origem; // 'APP'
  final String deviceId;

  const LaudoProcedencia({required this.origem, required this.deviceId});

  Map<String, dynamic> toJson() => {'origem': origem, 'device_id': deviceId};

  factory LaudoProcedencia.fromJson(Map<String, dynamic> json) =>
      LaudoProcedencia(
        origem: json['origem'] as String,
        deviceId: json['device_id'] as String,
      );
}

/// Identificação institucional do perito médico-legista responsável pelo laudo.
class LaudoPerito {
  final String id;
  final String nome;
  final String crm;
  final String classe;

  const LaudoPerito({
    required this.id,
    required this.nome,
    required this.crm,
    required this.classe,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'crm': crm,
    'classe': classe,
  };

  factory LaudoPerito.fromJson(Map<String, dynamic> json) => LaudoPerito(
    id: json['id'] as String,
    nome: json['nome'] as String,
    crm: json['crm'] as String,
    classe: json['classe'] as String,
  );
}

/// Auxiliar Técnico de Necrópsia (ATN) participante do exame.
class LaudoAtn {
  final String id;
  final String nome;

  const LaudoAtn({required this.id, required this.nome});

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome};

  factory LaudoAtn.fromJson(Map<String, dynamic> json) =>
      LaudoAtn(id: json['id'] as String, nome: json['nome'] as String);
}

/// Pacote completo e oficial de laudo (`laudo_pacote`) para sincronização e exportação.
///
/// Segue rigorosamente a especificação do contrato `laudo-pacote/1`.
class LaudoPacote {
  final String schema;
  final int versaoLaudo;
  final DateTime geradoEm;
  final LaudoProcedencia procedencia;
  final LaudoPerito perito;
  final List<LaudoAtn> atns;
  final LaudoDocumento documento;
  final List<LaudoFoto> fotografias;
  final List<LaudoCroquiRef> croquis;

  const LaudoPacote({
    this.schema = 'laudo-pacote/1',
    required this.versaoLaudo,
    required this.geradoEm,
    required this.procedencia,
    required this.perito,
    this.atns = const [],
    required this.documento,
    this.fotografias = const [],
    this.croquis = const [],
  });

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'versao_laudo': versaoLaudo,
    'gerado_em': geradoEm.toUtc().toIso8601String(),
    'procedencia': procedencia.toJson(),
    'perito': perito.toJson(),
    'atns': atns.map((a) => a.toJson()).toList(),
    'documento': documento.toJson(),
    'fotografias': fotografias.map((f) => f.toJson()).toList(),
    'croquis': croquis.map((c) => c.toJson()).toList(),
  };

  Map<String, dynamic> toMap() => toJson();

  factory LaudoPacote.fromJson(Map<String, dynamic> json) => LaudoPacote(
    schema: json['schema'] as String? ?? 'laudo-pacote/1',
    versaoLaudo: (json['versao_laudo'] as num).toInt(),
    geradoEm: DateTime.parse(json['gerado_em'] as String),
    procedencia: LaudoProcedencia.fromJson(
      json['procedencia'] as Map<String, dynamic>,
    ),
    perito: LaudoPerito.fromJson(json['perito'] as Map<String, dynamic>),
    atns:
        (json['atns'] as List<dynamic>?)
            ?.map((a) => LaudoAtn.fromJson(a as Map<String, dynamic>))
            .toList() ??
        const [],
    documento: LaudoDocumento.fromJson(
      json['documento'] as Map<String, dynamic>,
    ),
    fotografias:
        (json['fotografias'] as List<dynamic>?)
            ?.map((f) => LaudoFoto.fromJson(f as Map<String, dynamic>))
            .toList() ??
        const [],
    croquis:
        (json['croquis'] as List<dynamic>?)
            ?.map((c) => LaudoCroquiRef.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

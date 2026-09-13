import 'package:uuid/uuid.dart';

/// Modelo de amostras para exames genéticos (DNA / Semen).
/// Cada amostra carrega seu próprio [numeroLacre] para rastreabilidade
/// individual do envelope/saco de segurança (Lei 13.964/19).
class AmostraGeneticaModel {
  final String uuid;
  final String exameUuid;
  final String tipoAmostra;
  final String? descricaoOutro;
  final bool pesquisaSemen;
  final bool pesquisaDna;
  final int quantidadeSwabs;
  final String? numeroLacre;

  AmostraGeneticaModel({
    required this.uuid,
    required this.exameUuid,
    required this.tipoAmostra,
    this.descricaoOutro,
    this.pesquisaSemen = false,
    this.pesquisaDna = false,
    this.quantidadeSwabs = 1,
    this.numeroLacre,
  });

  AmostraGeneticaModel.novo({
    required this.exameUuid,
    required this.tipoAmostra,
    this.descricaoOutro,
    this.pesquisaSemen = false,
    this.pesquisaDna = false,
    this.quantidadeSwabs = 1,
    this.numeroLacre,
  }) : uuid = const Uuid().v4();

  factory AmostraGeneticaModel.fromMap(Map<String, dynamic> map) {
    bool boolFromMap(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return false;
    }

    return AmostraGeneticaModel(
      uuid: map['uuid']?.toString() ?? '',
      exameUuid: map['exame_uuid']?.toString() ?? '',
      tipoAmostra: map['tipo_amostra']?.toString() ?? '',
      descricaoOutro: map['descricao_outro']?.toString(),
      pesquisaSemen: boolFromMap(map['pesquisa_semen']),
      pesquisaDna: boolFromMap(map['pesquisa_dna']),
      quantidadeSwabs: map['quantidade_swabs'] as int? ?? 1,
      numeroLacre: map['numero_lacre']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'exame_uuid': exameUuid,
      'tipo_amostra': tipoAmostra,
      'descricao_outro': descricaoOutro,
      'pesquisa_semen': pesquisaSemen ? 1 : 0,
      'pesquisa_dna': pesquisaDna ? 1 : 0,
      'quantidade_swabs': quantidadeSwabs,
      'numero_lacre': numeroLacre,
    };
  }

  AmostraGeneticaModel copyWith({
    String? uuid,
    String? exameUuid,
    String? tipoAmostra,
    String? descricaoOutro,
    bool? pesquisaSemen,
    bool? pesquisaDna,
    int? quantidadeSwabs,
    String? numeroLacre,
  }) {
    return AmostraGeneticaModel(
      uuid: uuid ?? this.uuid,
      exameUuid: exameUuid ?? this.exameUuid,
      tipoAmostra: tipoAmostra ?? this.tipoAmostra,
      descricaoOutro: descricaoOutro ?? this.descricaoOutro,
      pesquisaSemen: pesquisaSemen ?? this.pesquisaSemen,
      pesquisaDna: pesquisaDna ?? this.pesquisaDna,
      quantidadeSwabs: quantidadeSwabs ?? this.quantidadeSwabs,
      numeroLacre: numeroLacre ?? this.numeroLacre,
    );
  }
}

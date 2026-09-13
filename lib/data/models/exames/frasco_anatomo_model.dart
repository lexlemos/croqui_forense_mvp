import 'package:uuid/uuid.dart';

/// Modelo para frascos de exames histopatológicos / anatomopatológicos.
/// Cada frasco carrega seu próprio [numeroLacre] para rastreabilidade
/// individual do recipiente lacrado (cadeia de custódia — Lei 13.964/19).
class FrascoAnatomoModel {
  final String uuid;
  final String exameUuid;
  final int numeroFrasco;
  final String? numeroLacre;
  final bool coracao;
  final bool figado;
  final bool baco;
  final bool encefalo;
  final bool pulmaoDLsd;
  final bool pulmaoDLmd;
  final bool pulmaoDLid;
  final bool pulmaoELse;
  final bool pulmaoELie;
  final bool rimD;
  final bool rimE;
  final String? peleRegiao;
  final String? partesMolesRegiao;
  final String? outrasRegiao;

  FrascoAnatomoModel({
    required this.uuid,
    required this.exameUuid,
    required this.numeroFrasco,
    this.numeroLacre,
    this.coracao = false,
    this.figado = false,
    this.baco = false,
    this.encefalo = false,
    this.pulmaoDLsd = false,
    this.pulmaoDLmd = false,
    this.pulmaoDLid = false,
    this.pulmaoELse = false,
    this.pulmaoELie = false,
    this.rimD = false,
    this.rimE = false,
    this.peleRegiao,
    this.partesMolesRegiao,
    this.outrasRegiao,
  });

  FrascoAnatomoModel.novo({
    required this.exameUuid,
    required this.numeroFrasco,
    this.numeroLacre,
    this.coracao = false,
    this.figado = false,
    this.baco = false,
    this.encefalo = false,
    this.pulmaoDLsd = false,
    this.pulmaoDLmd = false,
    this.pulmaoDLid = false,
    this.pulmaoELse = false,
    this.pulmaoELie = false,
    this.rimD = false,
    this.rimE = false,
    this.peleRegiao,
    this.partesMolesRegiao,
    this.outrasRegiao,
  }) : uuid = const Uuid().v4();

  factory FrascoAnatomoModel.fromMap(Map<String, dynamic> map) {
    bool boolFromMap(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return false;
    }

    return FrascoAnatomoModel(
      uuid: map['uuid']?.toString() ?? '',
      exameUuid: map['exame_uuid']?.toString() ?? '',
      numeroFrasco: map['numero_frasco'] as int? ?? 1,
      numeroLacre: map['numero_lacre']?.toString(),
      coracao: boolFromMap(map['coracao']),
      figado: boolFromMap(map['figado']),
      baco: boolFromMap(map['baco']),
      encefalo: boolFromMap(map['encefalo']),
      pulmaoDLsd: boolFromMap(map['pulmao_d_lsd']),
      pulmaoDLmd: boolFromMap(map['pulmao_d_lmd']),
      pulmaoDLid: boolFromMap(map['pulmao_d_lid']),
      pulmaoELse: boolFromMap(map['pulmao_e_lse']),
      pulmaoELie: boolFromMap(map['pulmao_e_lie']),
      rimD: boolFromMap(map['rim_d']),
      rimE: boolFromMap(map['rim_e']),
      peleRegiao: map['pele_regiao']?.toString(),
      partesMolesRegiao: map['partes_moles_regiao']?.toString(),
      outrasRegiao: map['outras_regiao']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'exame_uuid': exameUuid,
      'numero_frasco': numeroFrasco,
      'numero_lacre': numeroLacre,
      'coracao': coracao ? 1 : 0,
      'figado': figado ? 1 : 0,
      'baco': baco ? 1 : 0,
      'encefalo': encefalo ? 1 : 0,
      'pulmao_d_lsd': pulmaoDLsd ? 1 : 0,
      'pulmao_d_lmd': pulmaoDLmd ? 1 : 0,
      'pulmao_d_lid': pulmaoDLid ? 1 : 0,
      'pulmao_e_lse': pulmaoELse ? 1 : 0,
      'pulmao_e_lie': pulmaoELie ? 1 : 0,
      'rim_d': rimD ? 1 : 0,
      'rim_e': rimE ? 1 : 0,
      'pele_regiao': peleRegiao,
      'partes_moles_regiao': partesMolesRegiao,
      'outras_regiao': outrasRegiao,
    };
  }

  FrascoAnatomoModel copyWith({
    String? uuid,
    String? exameUuid,
    int? numeroFrasco,
    String? numeroLacre,
    bool? coracao,
    bool? figado,
    bool? baco,
    bool? encefalo,
    bool? pulmaoDLsd,
    bool? pulmaoDLmd,
    bool? pulmaoDLid,
    bool? pulmaoELse,
    bool? pulmaoELie,
    bool? rimD,
    bool? rimE,
    String? peleRegiao,
    String? partesMolesRegiao,
    String? outrasRegiao,
  }) {
    return FrascoAnatomoModel(
      uuid: uuid ?? this.uuid,
      exameUuid: exameUuid ?? this.exameUuid,
      numeroFrasco: numeroFrasco ?? this.numeroFrasco,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      coracao: coracao ?? this.coracao,
      figado: figado ?? this.figado,
      baco: baco ?? this.baco,
      encefalo: encefalo ?? this.encefalo,
      pulmaoDLsd: pulmaoDLsd ?? this.pulmaoDLsd,
      pulmaoDLmd: pulmaoDLmd ?? this.pulmaoDLmd,
      pulmaoDLid: pulmaoDLid ?? this.pulmaoDLid,
      pulmaoELse: pulmaoELse ?? this.pulmaoELse,
      pulmaoELie: pulmaoELie ?? this.pulmaoELie,
      rimD: rimD ?? this.rimD,
      rimE: rimE ?? this.rimE,
      peleRegiao: peleRegiao ?? this.peleRegiao,
      partesMolesRegiao: partesMolesRegiao ?? this.partesMolesRegiao,
      outrasRegiao: outrasRegiao ?? this.outrasRegiao,
    );
  }
}

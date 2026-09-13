import 'package:uuid/uuid.dart';

/// Modelo de detalhes específicos para exames toxicológicos.
/// Cada material coletado carrega seu próprio [numeroLacre*] para
/// rastreabilidade individual do recipiente lacrado (Lei 13.964/19).
class DetalhesToxicologicoModel {
  final String uuid;
  final String exameUuid;
  final String? historicoOcorrencia;
  final String? historicoOutro;

  // Material SG Sangue
  final bool materialSgFemoral;
  final bool materialSgCardiaca;
  final String? materialSgOutro;
  final String? numeroLacreSg;

  // Material UR Urina
  final bool materialUrina;
  final String? numeroLacreUr;

  // Material HV Humor Vítreo
  final bool materialHumorVitreo;
  final String? numeroLacreHv;

  // Material CE Conteúdo Estomacal
  final bool materialEstomago;
  final String? numeroLacreCe;

  // Material PM Pulmão
  final bool materialPulmao;
  final String? numeroLacrePm;

  final bool quantificacaoDrogas;

  DetalhesToxicologicoModel({
    required this.uuid,
    required this.exameUuid,
    this.historicoOcorrencia,
    this.historicoOutro,
    this.materialSgFemoral = false,
    this.materialSgCardiaca = false,
    this.materialSgOutro,
    this.numeroLacreSg,
    this.materialUrina = false,
    this.numeroLacreUr,
    this.materialHumorVitreo = false,
    this.numeroLacreHv,
    this.materialEstomago = false,
    this.numeroLacreCe,
    this.materialPulmao = false,
    this.numeroLacrePm,
    this.quantificacaoDrogas = false,
  });

  DetalhesToxicologicoModel.novo({
    required this.exameUuid,
    this.historicoOcorrencia,
    this.historicoOutro,
    this.materialSgFemoral = false,
    this.materialSgCardiaca = false,
    this.materialSgOutro,
    this.numeroLacreSg,
    this.materialUrina = false,
    this.numeroLacreUr,
    this.materialHumorVitreo = false,
    this.numeroLacreHv,
    this.materialEstomago = false,
    this.numeroLacreCe,
    this.materialPulmao = false,
    this.numeroLacrePm,
    this.quantificacaoDrogas = false,
  }) : uuid = const Uuid().v4();

  factory DetalhesToxicologicoModel.fromMap(Map<String, dynamic> map) {
    bool boolFromMap(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return false;
    }

    return DetalhesToxicologicoModel(
      uuid: map['uuid']?.toString() ?? '',
      exameUuid: map['exame_uuid']?.toString() ?? '',
      historicoOcorrencia: map['historico_ocorrencia']?.toString(),
      historicoOutro: map['historico_outro']?.toString(),
      materialSgFemoral: boolFromMap(map['material_sg_femoral']),
      materialSgCardiaca: boolFromMap(map['material_sg_cardiaca']),
      materialSgOutro: map['material_sg_outro']?.toString(),
      numeroLacreSg: map['numero_lacre_sg']?.toString(),
      materialUrina: boolFromMap(map['material_urina']),
      numeroLacreUr: map['numero_lacre_ur']?.toString(),
      materialHumorVitreo: boolFromMap(map['material_humor_vitreo']),
      numeroLacreHv: map['numero_lacre_hv']?.toString(),
      materialEstomago: boolFromMap(map['material_estomago']),
      numeroLacreCe: map['numero_lacre_ce']?.toString(),
      materialPulmao: boolFromMap(map['material_pulmao']),
      numeroLacrePm: map['numero_lacre_pm']?.toString(),
      quantificacaoDrogas: boolFromMap(map['quantificacao_drogas']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'exame_uuid': exameUuid,
      'historico_ocorrencia': historicoOcorrencia,
      'historico_outro': historicoOutro,
      'material_sg_femoral': materialSgFemoral ? 1 : 0,
      'material_sg_cardiaca': materialSgCardiaca ? 1 : 0,
      'material_sg_outro': materialSgOutro,
      'numero_lacre_sg': numeroLacreSg,
      'material_urina': materialUrina ? 1 : 0,
      'numero_lacre_ur': numeroLacreUr,
      'material_humor_vitreo': materialHumorVitreo ? 1 : 0,
      'numero_lacre_hv': numeroLacreHv,
      'material_estomago': materialEstomago ? 1 : 0,
      'numero_lacre_ce': numeroLacreCe,
      'material_pulmao': materialPulmao ? 1 : 0,
      'numero_lacre_pm': numeroLacrePm,
      'quantificacao_drogas': quantificacaoDrogas ? 1 : 0,
    };
  }

  DetalhesToxicologicoModel copyWith({
    String? uuid,
    String? exameUuid,
    String? historicoOcorrencia,
    String? historicoOutro,
    bool? materialSgFemoral,
    bool? materialSgCardiaca,
    String? materialSgOutro,
    String? numeroLacreSg,
    bool? materialUrina,
    String? numeroLacreUr,
    bool? materialHumorVitreo,
    String? numeroLacreHv,
    bool? materialEstomago,
    String? numeroLacreCe,
    bool? materialPulmao,
    String? numeroLacrePm,
    bool? quantificacaoDrogas,
  }) {
    return DetalhesToxicologicoModel(
      uuid: uuid ?? this.uuid,
      exameUuid: exameUuid ?? this.exameUuid,
      historicoOcorrencia: historicoOcorrencia ?? this.historicoOcorrencia,
      historicoOutro: historicoOutro ?? this.historicoOutro,
      materialSgFemoral: materialSgFemoral ?? this.materialSgFemoral,
      materialSgCardiaca: materialSgCardiaca ?? this.materialSgCardiaca,
      materialSgOutro: materialSgOutro ?? this.materialSgOutro,
      numeroLacreSg: numeroLacreSg ?? this.numeroLacreSg,
      materialUrina: materialUrina ?? this.materialUrina,
      numeroLacreUr: numeroLacreUr ?? this.numeroLacreUr,
      materialHumorVitreo: materialHumorVitreo ?? this.materialHumorVitreo,
      numeroLacreHv: numeroLacreHv ?? this.numeroLacreHv,
      materialEstomago: materialEstomago ?? this.materialEstomago,
      numeroLacreCe: numeroLacreCe ?? this.numeroLacreCe,
      materialPulmao: materialPulmao ?? this.materialPulmao,
      numeroLacrePm: numeroLacrePm ?? this.numeroLacrePm,
      quantificacaoDrogas: quantificacaoDrogas ?? this.quantificacaoDrogas,
    );
  }
}

import 'dart:convert';
import 'package:croqui_forense_mvp/data/models/auditoria_model.dart';

/// Abstrai os dados dinâmicos do laudo em um objeto estritamente tipado.
/// Substitui o antigo Map<String, dynamic> para garantir a blindagem do 
/// motor Offline-First e a previsibilidade das assinaturas JSON.
class DadosLaudoModel {
  final IdentificacaoModel identificacao;
  final CaracteristicasModel caracteristicas;
  final ConclusaoModel conclusao;
  final CabecalhoModel cabecalho;
  final AuditoriaModel auditoria;

  DadosLaudoModel({
    required this.identificacao,
    required this.caracteristicas,
    required this.conclusao,
    required this.cabecalho,
    required this.auditoria,
  });

  factory DadosLaudoModel.novo() {
    return DadosLaudoModel(
      identificacao: IdentificacaoModel(),
      caracteristicas: CaracteristicasModel(),
      conclusao: ConclusaoModel(),
      cabecalho: CabecalhoModel(),
      auditoria: AuditoriaModel(),
    );
  }

  factory DadosLaudoModel.fromMap(Map<String, dynamic> map) {
    return DadosLaudoModel(
      identificacao: IdentificacaoModel.fromMap(map['identificacao'] is Map ? Map<String, dynamic>.from(map['identificacao']) : {}),
      caracteristicas: CaracteristicasModel.fromMap(map['caracteristicas'] is Map ? Map<String, dynamic>.from(map['caracteristicas']) : {}),
      conclusao: ConclusaoModel.fromMap(map['conclusao'] is Map ? Map<String, dynamic>.from(map['conclusao']) : {}),
      cabecalho: CabecalhoModel.fromMap(map['cabecalho'] is Map ? Map<String, dynamic>.from(map['cabecalho']) : {}),
      auditoria: map['auditoria'] is Map ? AuditoriaModel.fromJson(Map<String, dynamic>.from(map['auditoria'])) : AuditoriaModel(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'identificacao': identificacao.toMap(),
      'caracteristicas': caracteristicas.toMap(),
      'conclusao': conclusao.toMap(),
      'cabecalho': cabecalho.toMap(),
      'auditoria': auditoria.toJson(),
    };
  }

  DadosLaudoModel copyWith({
    IdentificacaoModel? identificacao,
    CaracteristicasModel? caracteristicas,
    ConclusaoModel? conclusao,
    CabecalhoModel? cabecalho,
    AuditoriaModel? auditoria,
  }) {
    return DadosLaudoModel(
      identificacao: identificacao ?? this.identificacao,
      caracteristicas: caracteristicas ?? this.caracteristicas,
      conclusao: conclusao ?? this.conclusao,
      cabecalho: cabecalho ?? this.cabecalho,
      auditoria: auditoria ?? this.auditoria,
    );
  }
}

/// Representa a seção de identificação do cadáver e histórico.
class IdentificacaoModel {
  final String historico;
  final String vestes;
  final String sexo;
  final List<String> fotos;

  IdentificacaoModel({
    this.historico = '',
    this.vestes = '',
    this.sexo = '',
    this.fotos = const [],
  });

  factory IdentificacaoModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedFotos = [];
    if (map['fotos'] is List) {
      parsedFotos = List<String>.from((map['fotos'] as List).map((e) => e.toString()));
    }
    return IdentificacaoModel(
      historico: map['historico']?.toString() ?? '',
      vestes: map['vestes']?.toString() ?? '',
      sexo: map['sexo']?.toString() ?? '',
      fotos: parsedFotos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'historico': historico,
      'vestes': vestes,
      'sexo': sexo,
      'fotos': fotos,
    };
  }

  IdentificacaoModel copyWith({
    String? historico,
    String? vestes,
    String? sexo,
    List<String>? fotos,
  }) {
    return IdentificacaoModel(
      historico: historico ?? this.historico,
      vestes: vestes ?? this.vestes,
      sexo: sexo ?? this.sexo,
      fotos: fotos ?? this.fotos,
    );
  }
}

/// Representa a seção de características físicas e estado tanatológico.
class CaracteristicasModel {
  final String identificacao;
  final String tanatoImediato;
  final String tanatoConsecutivo;
  final String tanatoObservacao;

  CaracteristicasModel({
    this.identificacao = '',
    this.tanatoImediato = '',
    this.tanatoConsecutivo = '',
    this.tanatoObservacao = '',
  });

  factory CaracteristicasModel.fromMap(Map<String, dynamic> map) {
    return CaracteristicasModel(
      identificacao: map['identificacao']?.toString() ?? '',
      tanatoImediato: map['tanato_imediato']?.toString() ?? '',
      tanatoConsecutivo: map['tanato_consecutivo']?.toString() ?? '',
      tanatoObservacao: map['tanato_observacao']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'identificacao': identificacao,
      'tanato_imediato': tanatoImediato,
      'tanato_consecutivo': tanatoConsecutivo,
      'tanato_observacao': tanatoObservacao,
    };
  }

  CaracteristicasModel copyWith({
    String? identificacao,
    String? tanatoImediato,
    String? tanatoConsecutivo,
    String? tanatoObservacao,
  }) {
    return CaracteristicasModel(
      identificacao: identificacao ?? this.identificacao,
      tanatoImediato: tanatoImediato ?? this.tanatoImediato,
      tanatoConsecutivo: tanatoConsecutivo ?? this.tanatoConsecutivo,
      tanatoObservacao: tanatoObservacao ?? this.tanatoObservacao,
    );
  }
}

/// Representa a seção de conclusão do laudo.
class ConclusaoModel {
  final String discussao;
  final String conclusaoTexto;
  final String quesito1Morte;
  final String quesito2Causa;
  final String quesito3Instrumento;
  final String quesito4Meio;

  ConclusaoModel({
    this.discussao = '',
    this.conclusaoTexto = '',
    this.quesito1Morte = '',
    this.quesito2Causa = '',
    this.quesito3Instrumento = '',
    this.quesito4Meio = '',
  });

  factory ConclusaoModel.fromMap(Map<String, dynamic> map) {
    return ConclusaoModel(
      discussao: map['discussao']?.toString() ?? '',
      conclusaoTexto: map['conclusao_texto']?.toString() ?? '',
      quesito1Morte: map['quesito_1_morte']?.toString() ?? '',
      quesito2Causa: map['quesito_2_causa']?.toString() ?? '',
      quesito3Instrumento: map['quesito_3_instrumento']?.toString() ?? '',
      quesito4Meio: map['quesito_4_meio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'discussao': discussao,
      'conclusao_texto': conclusaoTexto,
      'quesito_1_morte': quesito1Morte,
      'quesito_2_causa': quesito2Causa,
      'quesito_3_instrumento': quesito3Instrumento,
      'quesito_4_meio': quesito4Meio,
    };
  }

  ConclusaoModel copyWith({
    String? discussao,
    String? conclusaoTexto,
    String? quesito1Morte,
    String? quesito2Causa,
    String? quesito3Instrumento,
    String? quesito4Meio,
  }) {
    return ConclusaoModel(
      discussao: discussao ?? this.discussao,
      conclusaoTexto: conclusaoTexto ?? this.conclusaoTexto,
      quesito1Morte: quesito1Morte ?? this.quesito1Morte,
      quesito2Causa: quesito2Causa ?? this.quesito2Causa,
      quesito3Instrumento: quesito3Instrumento ?? this.quesito3Instrumento,
      quesito4Meio: quesito4Meio ?? this.quesito4Meio,
    );
  }
}

/// Representa o cabeçalho descritivo.
class CabecalhoModel {
  final String descricao;

  CabecalhoModel({
    this.descricao = '',
  });

  factory CabecalhoModel.fromMap(Map<String, dynamic> map) {
    return CabecalhoModel(
      descricao: map['descricao']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
    };
  }

  CabecalhoModel copyWith({
    String? descricao,
  }) {
    return CabecalhoModel(
      descricao: descricao ?? this.descricao,
    );
  }
}

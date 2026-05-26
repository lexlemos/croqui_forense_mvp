import 'dart:convert'; 
import 'package:uuid/uuid.dart';

class Achado {
  final String uuid;
  final String casoUuid;
  final String diagramaNome; // Substituiu o templateDiagramaId
  final String tipoAchadoId;

  final int numeroSequencial;
  final double posX;
  final double posY;

  final bool isInterno;

  final String? achadoRelacionadoUuid;
  final Map<String, dynamic> dadosPreenchidos;
  final String? observacoesTexto;

  final bool removido;
  final int versao;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;
  final String? deviceId;
  final String? proveniencia;

  Achado({
    required this.uuid,
    required this.casoUuid,
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
    this.proveniencia,
  });

  String get tamanho {
    return dadosPreenchidos['size']?.toString() ??
           dadosPreenchidos['tamanho']?.toString() ??
           dadosPreenchidos['altura']?.toString() ?? '';
  }

  String get profundidade {
    return dadosPreenchidos['depth']?.toString() ??
           dadosPreenchidos['profundidade']?.toString() ?? '';
  }

  Achado.novo({
    required this.casoUuid,
    required this.diagramaNome,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
    required this.isInterno,
    this.achadoRelacionadoUuid,
  }) : uuid = const Uuid().v4(),
       dadosPreenchidos = const {},
       observacoesTexto = null,
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null,
       deviceId = null,
       proveniencia = 'APP';


  factory Achado.fromMap(Map<String, dynamic> map) {
    return Achado(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      diagramaNome: map['diagrama_nome']?.toString() ?? '',
      tipoAchadoId: map['tipo_achado_id']?.toString() ?? '',
      achadoRelacionadoUuid: map['achado_relacionado_uuid']?.toString(),
      numeroSequencial: map['numero_sequencial'] as int? ?? 0,
      posX: (map['pos_x'] as num?)?.toDouble() ?? 0.0,
      posY: (map['pos_y'] as num?)?.toDouble() ?? 0.0,
      isInterno: (map['is_interno'] as int? ?? 0) == 1,
      dadosPreenchidos: map['dados_preenchidos_json'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['dados_preenchidos_json'].toString()) as Map? ?? {})
          : const {},
      observacoesTexto: map['observacoes_texto']?.toString(),
      removido: (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.tryParse(map['atualizado_em'].toString()) : null,
      deviceId: map['device_id']?.toString(),
      proveniencia: map['proveniencia']?.toString(),
    );
  }

  Achado copyWith({
    String? uuid,
    String? casoUuid,
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
    String? proveniencia,
  }) {
    return Achado(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      diagramaNome: diagramaNome ?? this.diagramaNome,
      tipoAchadoId: tipoAchadoId ?? this.tipoAchadoId,
      achadoRelacionadoUuid: achadoRelacionadoUuid ?? this.achadoRelacionadoUuid,
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
      proveniencia: proveniencia ?? this.proveniencia,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
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
      'proveniencia': proveniencia,
    };
  }

  String get type {
    return dadosPreenchidos['type_label']?.toString() ?? 'Não definido';
  }

  String? get photoPath {
    return dadosPreenchidos['photo_path']?.toString();
  }

  String get description {
    return observacoesTexto ?? '';
  }
}
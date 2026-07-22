import 'package:uuid/uuid.dart';

class DiagramaCaso {
  final String uuid;
  final String casoUuid;
  final String nomeDiagrama; 
  
  final bool removido;
  final int versao;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;

  DiagramaCaso({
    required this.uuid,
    required this.casoUuid,
    required this.nomeDiagrama,
    required this.removido,
    required this.versao,
    required this.criadoEm,
    this.atualizadoEm,
  });

  DiagramaCaso.novo({
    required this.casoUuid,
    required this.nomeDiagrama,
  }) : uuid = const Uuid().v4(),
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null;

  factory DiagramaCaso.fromMap(Map<String, dynamic> map) {
    return DiagramaCaso(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      nomeDiagrama: map['nome_diagrama']?.toString() ?? '',
      removido: map['removido'] is bool 
          ? map['removido'] as bool 
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.tryParse(map['atualizado_em'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'nome_diagrama': nomeDiagrama,
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'nome_diagrama': nomeDiagrama,
      'removido': removido,
      'versao': versao,
      'criado_em': criadoEm.toUtc().toIso8601String(),
      'atualizado_em': (atualizadoEm ?? criadoEm).toUtc().toIso8601String(),
    };
  }

  DiagramaCaso copyWith({
    String? uuid,
    String? casoUuid,
    String? nomeDiagrama,
    bool? removido,
    int? versao,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return DiagramaCaso(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      nomeDiagrama: nomeDiagrama ?? this.nomeDiagrama,
      removido: removido ?? this.removido,
      versao: versao ?? this.versao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}

import 'package:uuid/uuid.dart';

class DiagramaCaso {
  final String uuid;
  final String casoUuid;
  final String templateId; 
  
  final bool removido;
  final int versao;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;
  final String? deviceId;

  DiagramaCaso({
    required this.uuid,
    required this.casoUuid,
    required this.templateId,
    required this.removido,
    required this.versao,
    required this.criadoEm,
    this.atualizadoEm,
    this.deviceId,
  });

  DiagramaCaso.novo({
    required this.casoUuid,
    required this.templateId,
  }) : uuid = const Uuid().v4(),
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null,
       deviceId = null;

  factory DiagramaCaso.fromMap(Map<String, dynamic> map) {
    return DiagramaCaso(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      templateId: map['template_id']?.toString() ?? '',
      
      removido: (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.tryParse(map['atualizado_em'].toString()) : null,
      deviceId: map['device_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'template_id': templateId,
      
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
      'device_id': deviceId,
    };
  }
}
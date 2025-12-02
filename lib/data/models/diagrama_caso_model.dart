import 'package:uuid/uuid.dart';

class DiagramaCaso {
  // --- Chaves ---
  final String uuid;
  final String casoUuid; // FK para a tabela 'casos'
  final String templateId; // FK para a tabela 'templates_diagrama'
  
  // --- Controle ---
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

  // Construtor para NOVO DIAGRAMA
  DiagramaCaso.novo({
    required this.casoUuid,
    required this.templateId,
  }) : uuid = const Uuid().v4(),
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null,
       deviceId = null;

  // Factory Method: DB (Map) -> Dart (Objeto)
  factory DiagramaCaso.fromMap(Map<String, dynamic> map) {
    return DiagramaCaso(
      uuid: map['uuid'] as String,
      casoUuid: map['caso_uuid'] as String,
      templateId: map['template_id'] as String,
      
      removido: (map['removido'] as int) == 1,
      versao: map['versao'] as int,
      
      criadoEm: DateTime.parse(map['criado_em'] as String),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.parse(map['atualizado_em'] as String) : null,
      deviceId: map['device_id'] as String?,
    );
  }

  // Método: Dart (Objeto) -> DB (Map)
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
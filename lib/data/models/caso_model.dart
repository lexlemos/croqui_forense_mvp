import 'package:uuid/uuid.dart';

enum StatusCaso {
  rascunho,
  finalizado,
  sincronizado,
}

class Caso {
  // --- Identificadores e Relações ---
  final String uuid;
  final int idUsuarioCriador; // FK para a tabela 'usuarios'
  
  // --- Dados do Negócio ---
  final String? numeroLaudoExterno;
  final StatusCaso status;
  
  // --- Rastreabilidade e Segurança ---
  final String? hashIntegridade; // Hash do caso finalizado [RF.SC.04]
  final bool removido; // Soft Delete
  final int versao;
  final String? deviceId;
  final String? proveniencia; // APP, ADMIN, SCRIPT
  
  // --- Timestamps ---
  final DateTime criadoEmDispositivo;
  final DateTime? criadoEmRedeConfiavel; // Trusted Timestamp [RF.SC.05]
  final DateTime? atualizadoEm;

  Caso({
    required this.uuid,
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    this.status = StatusCaso.rascunho,
    this.hashIntegridade,
    required this.removido,
    required this.versao,
    required this.criadoEmDispositivo,
    this.criadoEmRedeConfiavel,
    this.atualizadoEm,
    this.deviceId,
    this.proveniencia,
  });
  
  // Construtor para NOVO CASO (facilita o Repository)
  Caso.novo({
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    String? deviceId,
    String? proveniencia,
  }) : uuid = const Uuid().v4(),
       status = StatusCaso.rascunho,
       hashIntegridade = null,
       removido = false,
       versao = 1,
       criadoEmDispositivo = DateTime.now(),
       criadoEmRedeConfiavel = null,
       atualizadoEm = null,
       deviceId = deviceId,
       proveniencia = proveniencia ?? 'APP';

  // Factory Method: DB (Map) -> Dart (Objeto)
  factory Caso.fromMap(Map<String, dynamic> map) {
    return Caso(
      uuid: map['uuid'] as String,
      idUsuarioCriador: map['id_usuario_criador'] as int,
      numeroLaudoExterno: map['numero_laudo_externo'] as String?,
      status: StatusCaso.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['status'] as String).toUpperCase(),
        orElse: () => StatusCaso.rascunho,
      ),
      
      hashIntegridade: map['hash_integridade'] as String?,
      removido: (map['removido'] as int) == 1,
      versao: map['versao'] as int,
      
      // Conversão de TEXT para DateTime
      criadoEmDispositivo: DateTime.parse(map['criado_em_dispositivo'] as String),
      criadoEmRedeConfiavel: map['criado_em_rede_confiavel'] != null ? DateTime.parse(map['criado_em_rede_confiavel'] as String) : null,
      atualizadoEm: map['atualizado_em'] != null ? DateTime.parse(map['atualizado_em'] as String) : null,
      
      deviceId: map['device_id'] as String?,
      proveniencia: map['proveniencia'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id_usuario_criador': idUsuarioCriador,
      'numero_laudo_externo': numeroLaudoExterno,
      'status': status.name.toUpperCase(),
      
      'hash_integridade': hashIntegridade,
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em_dispositivo': criadoEmDispositivo.toIso8601String(),
      'criado_em_rede_confiavel': criadoEmRedeConfiavel?.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
      
      'device_id': deviceId,
      'proveniencia': proveniencia,
    };
  }
}


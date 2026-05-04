import 'package:uuid/uuid.dart';
import 'dart:convert';

enum SortCriteria { numero, data }
enum SortOrder { asc, desc }

enum StatusCaso {
  rascunho,
  finalizado,
  sincronizado,
  arquivado
}

class Caso {
  final String uuid;
  final String idUsuarioCriador; 
  final String? numeroLaudoExterno;
  final StatusCaso status;
  final Map<String, dynamic> dadosLaudo; 
  final String? hashIntegridade;
  final bool removido;
  final int versao;
  final String? deviceId;
  final String? proveniencia; 
  final DateTime criadoEmDispositivo;
  final DateTime? criadoEmRedeConfiavel; 
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
    required this.dadosLaudo,
    this.proveniencia,
  });
  
  Caso.novo({
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    this.deviceId,
    String? proveniencia,
    this.dadosLaudo = const {},
  }) : uuid = const Uuid().v4(), 
       status = StatusCaso.rascunho,
       hashIntegridade = null,
       removido = false,
       versao = 1,
       criadoEmDispositivo = DateTime.now(),
       criadoEmRedeConfiavel = null,
       atualizadoEm = null,
       proveniencia = proveniencia ?? 'APP_TABLET';

  factory Caso.fromMap(Map<String, dynamic> map) {
    return Caso(
      uuid: map['uuid']?.toString() ?? '',
      idUsuarioCriador: map['id_usuario_criador']?.toString() ?? '',
      numeroLaudoExterno: map['numero_laudo_externo']?.toString(),
      status: StatusCaso.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['status']?.toString() ?? '').toUpperCase(),
        orElse: () => StatusCaso.rascunho,
      ),
      dadosLaudo: map['dados_laudo_json'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['dados_laudo_json'].toString()) as Map? ?? {}) 
          : const {},
      
      hashIntegridade: map['hash_integridade']?.toString(),
      removido: (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,

      criadoEmDispositivo: DateTime.tryParse(map['criado_em_dispositivo']?.toString() ?? '') ?? DateTime.now(),
      criadoEmRedeConfiavel: map['criado_em_rede_confiavel'] != null 
          ? DateTime.tryParse(map['criado_em_rede_confiavel'].toString()) 
          : null,
      atualizadoEm: map['atualizado_em'] != null 
          ? DateTime.tryParse(map['atualizado_em'].toString()) 
          : null,
      
      deviceId: map['device_id']?.toString(),
      proveniencia: map['proveniencia']?.toString(),
    );
  }

  Caso copyWith({
    String? uuid,
    String? idUsuarioCriador,
    String? numeroLaudoExterno,
    StatusCaso? status,
    Map<String, dynamic>? dadosLaudo,
    String? hashIntegridade,
    bool? removido,
    int? versao,
    String? deviceId,
    String? proveniencia,
    DateTime? criadoEmDispositivo,
    DateTime? criadoEmRedeConfiavel,
    DateTime? atualizadoEm,
  }) {
    return Caso(
      uuid: uuid ?? this.uuid,
      idUsuarioCriador: idUsuarioCriador ?? this.idUsuarioCriador,
      numeroLaudoExterno: numeroLaudoExterno ?? this.numeroLaudoExterno,
      status: status ?? this.status,
      dadosLaudo: dadosLaudo ?? this.dadosLaudo,
      hashIntegridade: hashIntegridade ?? this.hashIntegridade,
      removido: removido ?? this.removido,
      versao: versao ?? this.versao,
      deviceId: deviceId ?? this.deviceId,
      proveniencia: proveniencia ?? this.proveniencia,
      criadoEmDispositivo: criadoEmDispositivo ?? this.criadoEmDispositivo,
      criadoEmRedeConfiavel: criadoEmRedeConfiavel ?? this.criadoEmRedeConfiavel,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id_usuario_criador': idUsuarioCriador,
      'numero_laudo_externo': numeroLaudoExterno,
      'status': status.name.toUpperCase(),
      'dados_laudo_json': jsonEncode(dadosLaudo),
      
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
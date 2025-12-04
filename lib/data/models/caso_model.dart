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
  final int idUsuarioCriador;
  
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
    String? deviceId,
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
       deviceId = deviceId,
       proveniencia = proveniencia ?? 'APP';
       

  factory Caso.fromMap(Map<String, dynamic> map) {
    return Caso(
      uuid: map['uuid'] as String,
      idUsuarioCriador: map['id_usuario_criador'] as int,
      numeroLaudoExterno: map['numero_laudo_externo'] as String?,
      status: StatusCaso.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['status'] as String).toUpperCase(),
        orElse: () => StatusCaso.rascunho,
      ),
      dadosLaudo: map['dados_laudo_json'] != null ? jsonDecode(map['dados_laudo_json']) : {},
      
      hashIntegridade: map['hash_integridade'] as String?,
      removido: (map['removido'] as int) == 1,
      versao: map['versao'] as int,

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


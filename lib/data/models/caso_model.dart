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
  final DateTime criadoEmDispositivo;
  final DateTime? atualizadoEm;
  final String numeroPic;
  final String numeroBo;
  final String numeroRequisicao;
  final String nomeVitima;
  final String destino;
  final String requisitante;

  Caso({
    required this.uuid,
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    this.status = StatusCaso.rascunho,
    this.hashIntegridade,
    required this.removido,
    required this.versao,
    required this.criadoEmDispositivo,
    this.atualizadoEm,
    this.deviceId,
    required this.dadosLaudo,
    required this.numeroPic,
    required this.numeroBo,
    required this.numeroRequisicao,
    required this.nomeVitima,
    required this.destino,
    required this.requisitante,
  });
  
  Caso.novo({
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    this.deviceId,
    this.dadosLaudo = const {},
    this.numeroPic = '',
    this.numeroBo = '',
    this.numeroRequisicao = '',
    this.nomeVitima = '',
    this.destino = '',
    this.requisitante = '',
  }) : uuid = const Uuid().v4(), 
       status = StatusCaso.rascunho,
       hashIntegridade = null,
       removido = false,
       versao = 1,
       criadoEmDispositivo = DateTime.now(),
       atualizadoEm = DateTime.now();

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
          ? (map['dados_laudo_json'] is Map
              ? Map<String, dynamic>.from(map['dados_laudo_json'] as Map)
              : Map<String, dynamic>.from(jsonDecode(map['dados_laudo_json'].toString()) as Map? ?? {}))
          : const {},
      
      hashIntegridade: map['hash_integridade']?.toString(),
      removido: map['removido'] is bool 
          ? map['removido'] as bool 
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,

      criadoEmDispositivo: DateTime.tryParse(map['criado_em_dispositivo']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null 
          ? DateTime.tryParse(map['atualizado_em'].toString()) 
          : null,
      
      deviceId: map['device_id']?.toString(),
      numeroPic: map['numero_pic']?.toString() ?? '',
      numeroBo: map['numero_bo']?.toString() ?? '',
      numeroRequisicao: map['numero_requisicao']?.toString() ?? '',
      nomeVitima: map['nome_vitima']?.toString() ?? '',
      destino: map['destino']?.toString() ?? '',
      requisitante: map['requisitante']?.toString() ?? '',
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
    DateTime? criadoEmDispositivo,
    DateTime? atualizadoEm,
    String? numeroPic,
    String? numeroBo,
    String? numeroRequisicao,
    String? nomeVitima,
    String? destino,
    String? requisitante,
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
      criadoEmDispositivo: criadoEmDispositivo ?? this.criadoEmDispositivo,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      numeroPic: numeroPic ?? this.numeroPic,
      numeroBo: numeroBo ?? this.numeroBo,
      numeroRequisicao: numeroRequisicao ?? this.numeroRequisicao,
      nomeVitima: nomeVitima ?? this.nomeVitima,
      destino: destino ?? this.destino,
      requisitante: requisitante ?? this.requisitante,
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
      'atualizado_em': atualizadoEm?.toIso8601String(),
      'device_id': deviceId,
      'numero_pic': numeroPic,
      'numero_bo': numeroBo,
      'numero_requisicao': numeroRequisicao,
      'nome_vitima': nomeVitima,
      'destino': destino,
      'requisitante': requisitante,
    };
  }

  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'id_usuario_criador': idUsuarioCriador,
      'numero_laudo_externo': numeroLaudoExterno,
      'status': status.name.toUpperCase(),
      'dados_laudo_json': dadosLaudo,
      'hash_integridade': hashIntegridade,
      'removido': removido,
      'versao': versao,
      'criado_em_dispositivo': criadoEmDispositivo.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
      'device_id': deviceId,
      'numero_pic': numeroPic,
      'numero_bo': numeroBo,
      'numero_requisicao': numeroRequisicao,
      'nome_vitima': nomeVitima,
      'destino': destino,
      'requisitante': requisitante,
    };
  }
}
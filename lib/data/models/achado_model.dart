import 'dart:convert'; // Necessário para jsonDecode/jsonEncode
import 'package:uuid/uuid.dart';

class Achado {
  final String uuid;
  final String diagramaCasoUuid; 
  final String tipoAchadoId; 
  
  final int numeroSequencial;
  final double posX; 
  final double posY;
  final bool estaPendente;
  

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
    required this.diagramaCasoUuid,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
    required this.estaPendente,
    required this.dadosPreenchidos,
    this.observacoesTexto,
    required this.removido,
    required this.versao,
    required this.criadoEm,
    this.atualizadoEm,
    this.deviceId,
    this.proveniencia,
  });

  Achado.novo({
    required this.diagramaCasoUuid,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
  }) : uuid = const Uuid().v4(),
       estaPendente = true, 
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
      uuid: map['uuid'] as String,
      diagramaCasoUuid: map['diagrama_caso_uuid'] as String,
      tipoAchadoId: map['tipo_achado_id'] as String,
      numeroSequencial: map['numero_sequencial'] as int,
      posX: map['pos_x'] as double,
      posY: map['pos_y'] as double,
      
      estaPendente: (map['esta_pendente'] as int) == 1,
    
      dadosPreenchidos: map['dados_preenchidos_json'] != null ? jsonDecode(map['dados_preenchidos_json'] as String) : const {},
      observacoesTexto: map['observacoes_texto'] as String?,
      
      removido: (map['removido'] as int) == 1,
      versao: map['versao'] as int,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.parse(map['atualizado_em'] as String) : null,
      deviceId: map['device_id'] as String?,
      proveniencia: map['proveniencia'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'diagrama_caso_uuid': diagramaCasoUuid,
      'tipo_achado_id': tipoAchadoId,
      'numero_sequencial': numeroSequencial,
      'pos_x': posX,
      'pos_y': posY,
      
      'esta_pendente': estaPendente ? 1 : 0,
      
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
}
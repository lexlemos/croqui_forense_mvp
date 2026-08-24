import 'dart:convert'; 
import 'package:uuid/uuid.dart';

class Achado {
  final String uuid;
  final String casoUuid;
  final String diagramaCasoUuid;
  final String diagramaNome;
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

  final String tamanho;
  final String vistaAnatomica;
  final String localAnatomico;

  Achado({
    required this.uuid,
    required this.casoUuid,
    required this.diagramaCasoUuid,
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
    required this.tamanho,
    required this.vistaAnatomica,
    required this.localAnatomico,
  });

  String get profundidade {
    return dadosPreenchidos['depth']?.toString() ??
           dadosPreenchidos['profundidade']?.toString() ?? '';
  }

  Achado.novo({
    required this.casoUuid,
    required this.diagramaCasoUuid,
    required this.diagramaNome,
    required this.tipoAchadoId,
    required this.numeroSequencial,
    required this.posX,
    required this.posY,
    required this.isInterno,
    required this.tamanho,
    required this.vistaAnatomica,
    required this.localAnatomico,
    this.achadoRelacionadoUuid,
  }) : uuid = const Uuid().v4(),
       dadosPreenchidos = const {},
       observacoesTexto = null,
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null,
       deviceId = null;

  factory Achado.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> dados = map['dados_preenchidos_json'] != null
        ? (map['dados_preenchidos_json'] is Map
            ? Map<String, dynamic>.from(map['dados_preenchidos_json'] as Map)
            : Map<String, dynamic>.from((() {
                try {
                  return jsonDecode(map['dados_preenchidos_json'].toString()) as Map? ?? {};
                } catch (_) {
                  return {};
                }
              })()))
        : <String, dynamic>{};

    if (!dados.containsKey('photo_path') || dados['photo_path'] == null || dados['photo_path'].toString().isEmpty) {
      final rawEvidencias = map['evidencias_multimidia'] ?? map['evidencias'];
      if (rawEvidencias is List && rawEvidencias.isNotEmpty) {
        final firstEv = rawEvidencias.first;
        if (firstEv is Map) {
          final photoUrl = firstEv['caminho_arquivo_encriptado']?.toString() ??
              firstEv['url']?.toString() ??
              firstEv['path']?.toString();
          if (photoUrl != null && photoUrl.isNotEmpty) {
            dados['photo_path'] = photoUrl;
          }
        }
      } else {
        final photoDirect = map['photo_path']?.toString() ??
            map['caminho_arquivo_encriptado']?.toString() ??
            map['url']?.toString();
        if (photoDirect != null && photoDirect.isNotEmpty) {
          dados['photo_path'] = photoDirect;
        }
      }
    }

    return Achado(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      diagramaCasoUuid: map['diagrama_caso_uuid']?.toString() ?? '',
      diagramaNome: map['diagrama_nome']?.toString() ?? '',
      tipoAchadoId: map['tipo_achado_id']?.toString() ?? '',
      achadoRelacionadoUuid: map['achado_relacionado_uuid']?.toString(),
      numeroSequencial: map['numero_sequencial'] as int? ?? 0,
      posX: (map['pos_x'] as num?)?.toDouble() ?? 0.0,
      posY: (map['pos_y'] as num?)?.toDouble() ?? 0.0,
      isInterno: map['is_interno'] is bool 
          ? map['is_interno'] as bool 
          : (map['is_interno'] as int? ?? 0) == 1,
      dadosPreenchidos: dados,
      observacoesTexto: map['observacoes_texto']?.toString(),
      removido: map['removido'] is bool 
          ? map['removido'] as bool 
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.tryParse(map['atualizado_em'].toString()) : null,
      deviceId: map['device_id']?.toString(),
      tamanho: map['tamanho']?.toString() ?? '',
      vistaAnatomica: map['vista_anatomica']?.toString() ?? '',
      localAnatomico: map['local_anatomico']?.toString() ?? '',
    );
  }

  Achado copyWith({
    String? uuid,
    String? casoUuid,
    String? diagramaCasoUuid,
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
    String? tamanho,
    String? vistaAnatomica,
    String? localAnatomico,
  }) {
    return Achado(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      diagramaCasoUuid: diagramaCasoUuid ?? this.diagramaCasoUuid,
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
      tamanho: tamanho ?? this.tamanho,
      vistaAnatomica: vistaAnatomica ?? this.vistaAnatomica,
      localAnatomico: localAnatomico ?? this.localAnatomico,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'diagrama_caso_uuid': diagramaCasoUuid,
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
      'tamanho': tamanho,
      'vista_anatomica': vistaAnatomica,
      'local_anatomico': localAnatomico,
    };
  }

  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'diagrama_caso_uuid': diagramaCasoUuid,
      'tipo_achado_id': tipoAchadoId,
      'versao': versao,
      'removido': removido,
      'numero_sequencial': numeroSequencial,
      'pos_x': posX.toDouble(),
      'pos_y': posY.toDouble(),
      'dados_preenchidos_json': dadosPreenchidos,
      'observacoes_texto': observacoesTexto,
      'tamanho': tamanho,
      'vista_anatomica': vistaAnatomica,
      'local_anatomico': localAnatomico,
      'criado_em': criadoEm.toUtc().toIso8601String(),
      'atualizado_em': (atualizadoEm ?? criadoEm).toUtc().toIso8601String(),
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
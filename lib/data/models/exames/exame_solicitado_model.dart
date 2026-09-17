import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';

/// Modelo mestre para requisições de exames complementares periciais.
/// Suporta associação polimórfica com os detalhes específicos em memória via [detalhes].
class ExameSolicitadoModel {
  final String uuid;
  final String casoUuid;
  final String tipoExame; // 'TOXICOLOGICO', 'GENETICA', 'ANATOMO'
  final String? numeroLacre;
  final DateTime criadoEm;
  final String status;

  /// Objeto filho em memória para gerenciar detalhes específicos na UI.
  /// NÃO é serializado no [toMap].
  final dynamic detalhes;

  ExameSolicitadoModel({
    required this.uuid,
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    required this.criadoEm,
    this.status = 'aguardando',
    this.detalhes,
  });

  ExameSolicitadoModel.novo({
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    this.status = 'aguardando',
    this.detalhes,
  }) : uuid = const Uuid().v4(),
       criadoEm = DateTime.now();

  factory ExameSolicitadoModel.fromMap(
    Map<String, dynamic> map, {
    dynamic detalhes,
  }) {
    dynamic parsedDetalhes = detalhes;

    try {
      final tipo = map['tipo_exame']?.toString().toUpperCase() ?? '';

      // Helper para decodificar string JSON se necessário
      List<dynamic>? getList(String key) {
        final raw = map[key];
        if (raw == null) return null;
        if (raw is List) return raw;
        if (raw is String && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return decoded;
          } catch (_) {}
        }
        return null;
      }

      if (tipo == 'TOXICOLOGICO') {
        final listData = getList('detalhes_toxicologico');
        if (listData != null && listData.isNotEmpty) {
          final firstItem = Map<String, dynamic>.from(listData.first as Map);
          parsedDetalhes = DetalhesToxicologicoModel.fromMap(firstItem);
        }
      } else if (tipo == 'GENETICA') {
        final listData = getList('amostras_genetica');
        if (listData != null && listData.isNotEmpty) {
          parsedDetalhes = listData
              .map((e) => AmostraGeneticaModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } else if (tipo == 'ANATOMO') {
        final listData = getList('frascos_anatomo');
        if (listData != null && listData.isNotEmpty) {
          parsedDetalhes = listData
              .map((e) => FrascoAnatomoModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('🚨 ERRO AO LER DETALHES DO EXAME: $e');
    }

    return ExameSolicitadoModel(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? map['exame_id']?.toString() ?? '',
      tipoExame: map['tipo_exame']?.toString() ?? '',
      numeroLacre: map['numero_lacre']?.toString(),
      status: map['status']?.toString() ?? 'aguardando',
      criadoEm: map['criado_em'] != null ? (DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now()) : DateTime.now(),
      detalhes: parsedDetalhes,
    );
  }

  int get quantidadeAmostras {
    if (detalhes == null) return 1;
    if (detalhes is List && (detalhes as List).isNotEmpty) return (detalhes as List).length;
    return 1;
  }

  /// Para persistência no SQLite (via caso_repository), o repositório filtra
  /// as chaves polimórficas antes de inserir na tabela exames_solicitados.
  Map<String, dynamic> toMap() => toSyncMap();

  Map<String, dynamic> toSyncMap() {
    final map = <String, dynamic>{
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'tipo_exame': tipoExame,
      'numero_lacre': numeroLacre,
      'status': status,
      'quantidade_amostras': quantidadeAmostras,
    };

    if (detalhes != null) {
      // Normalização agressiva: remove espaços e garante uppercase
      final tipoNormalizado = tipoExame.trim().toUpperCase();

      final List detalhesList = detalhes is List ? detalhes as List : [detalhes];
      final mappedDetalhes = detalhesList.map((e) => e.toMap()).toList();

      if (tipoNormalizado == 'TOXICOLOGICO') {
        map['detalhes_toxicologico'] = mappedDetalhes;
      } else if (tipoNormalizado == 'GENETICA') {
        map['amostras_genetica'] = mappedDetalhes;
      } else if (tipoNormalizado == 'ANATOMO') {
        map['frascos_anatomo'] = mappedDetalhes;
      } else {
        // FALLBACK EXPLORATÓRIO: tipo_exame está com valor inesperado.
        map['debug_unmatched_detalhes'] = mappedDetalhes;
        map['debug_tipo_recebido'] = tipoNormalizado;
        debugPrint('🚨 [toSyncMap] tipo_exame não reconhecido: "$tipoNormalizado"');
      }
    }
    return map;
  }

  ExameSolicitadoModel copyWith({
    String? uuid,
    String? casoUuid,
    String? tipoExame,
    String? numeroLacre,
    DateTime? criadoEm,
    String? status,
    dynamic detalhes,
  }) {
    return ExameSolicitadoModel(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      tipoExame: tipoExame ?? this.tipoExame,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      criadoEm: criadoEm ?? this.criadoEm,
      status: status ?? this.status,
      detalhes: detalhes ?? this.detalhes,
    );
  }
}

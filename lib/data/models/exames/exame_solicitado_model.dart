import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';

/// Modelo mestre para requisições de exames laboratoriais complementares no laudo pericial.
///
/// Representa solicitações de exames especializados como:
/// - **Toxicológico** (`TOXICOLOGICO`): pesquisa de entorpecentes, venenos e substâncias farmacológicas.
/// - **Genético/Biológico** (`GENETICA`): pesquisa de perfil genético (DNA), vestígios biológicos e swabs.
/// - **Anátomo-patológico** (`ANATOMO`): estudo histopatológico de tecidos e órgãos fixados em formol.
///
/// Suporta associação polimórfica em tempo de execução através da propriedade [detalhes],
/// garantindo tipagem forte nos formulários especializados sem duplicar tabelas de junção no SQLite.
class ExameSolicitadoModel {
  /// Identificador único UUID v4 do exame solicitado.
  final String uuid;

  /// Chave estrangeira UUID vinculada ao laudo pericial ([Caso]).
  final String casoUuid;

  /// Categoria do exame solicitado (`TOXICOLOGICO`, `GENETICA`, `ANATOMO`).
  final String tipoExame;

  /// Identificador do lacre de segurança principal ou do envelope de custódia.
  final String? numeroLacre;

  /// Data e hora de inclusão da solicitação no laudo.
  final DateTime criadoEm;

  /// Status processual da realização do exame laboratorial (ex: 'aguardando', 'concluido').
  final String status;

  /// Estado de confirmação física e aceite de custódia pelo Auxiliar Técnico de Necrópsia (ATN).
  ///
  /// Integrado diretamente com o fluxo do backend/API para rastreabilidade e auditoria da cadeia de custódia.
  final StatusConfirmacaoATN statusConfirmacaoAtn;

  /// Justificativa formal registrada pelo ATN caso a custódia das amostras tenha sido recusada.
  ///
  /// Reflete a auditoria registrada no backend caso haja inconformidades físicas (lacres violados, frascos inadequados).
  final String? justificativaRecusa;

  /// Objeto filho em memória contendo as especificações detalhadas do exame:
  /// - Para `TOXICOLOGICO`: [DetalhesToxicologicoModel].
  /// - Para `GENETICA`: `List<AmostraGeneticaModel>`.
  /// - Para `ANATOMO`: `List<FrascoAnatomoModel>`.
  ///
  /// NÃO é persistido em coluna direta no SQLite; no banco local é serializado em backup JSON via repositório.
  final dynamic detalhes;

  ExameSolicitadoModel({
    required this.uuid,
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    required this.criadoEm,
    this.status = 'aguardando',
    this.statusConfirmacaoAtn = StatusConfirmacaoATN.PENDENTE,
    this.justificativaRecusa,
    this.detalhes,
  });

  /// Construtor de conveniência para instanciar novas requisições com UUID e data/hora automáticos.
  ExameSolicitadoModel.novo({
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    this.status = 'aguardando',
    this.statusConfirmacaoAtn = StatusConfirmacaoATN.PENDENTE,
    this.justificativaRecusa,
    this.detalhes,
  }) : uuid = const Uuid().v4(),
       criadoEm = DateTime.now();

  /// Desserializa um mapa em [ExameSolicitadoModel], realizando extração polimórfica defensiva dos [detalhes].
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
              .map(
                (e) => AmostraGeneticaModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } else if (tipo == 'ANATOMO') {
        final listData = getList('frascos_anatomo');
        if (listData != null && listData.isNotEmpty) {
          parsedDetalhes = listData
              .map(
                (e) => FrascoAnatomoModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('🚨 ERRO AO LER DETALHES DO EXAME: $e');
    }

    return ExameSolicitadoModel(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid:
          map['caso_uuid']?.toString() ?? map['exame_id']?.toString() ?? '',
      tipoExame: map['tipo_exame']?.toString() ?? '',
      numeroLacre: map['numero_lacre']?.toString(),
      status: map['status']?.toString() ?? 'aguardando',
      statusConfirmacaoAtn: StatusConfirmacaoATN.fromString(
        map['status_confirmacao_atn']?.toString(),
      ),
      justificativaRecusa: map['justificativa_recusa']?.toString(),
      criadoEm: map['criado_em'] != null
          ? (DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now())
          : DateTime.now(),
      detalhes: parsedDetalhes,
    );
  }

  factory ExameSolicitadoModel.fromJson(
    Map<String, dynamic> json, {
    dynamic detalhes,
  }) => ExameSolicitadoModel.fromMap(json, detalhes: detalhes);

  /// Computa o total de amostras/frascos associados a esta requisição.
  int get quantidadeAmostras {
    if (detalhes == null) return 1;
    if (detalhes is List && (detalhes as List).isNotEmpty) {
      return (detalhes as List).length;
    }
    return 1;
  }

  /// Serializa os campos para persistência na tabela `exames_solicitados` do SQLite.
  Map<String, dynamic> toMap() {
    final map = toSyncMap();
    map['criado_em'] = criadoEm.toIso8601String();
    return map;
  }

  Map<String, dynamic> toJson() => toSyncMap();

  /// Constrói o payload estruturado para envio de sincronização com a API REST.
  ///
  /// Mapeia o objeto polimórfico [detalhes] para as respectivas chaves da API:
  /// - `detalhes_toxicologico`
  /// - `amostras_genetica`
  /// - `frascos_anatomo`
  Map<String, dynamic> toSyncMap() {
    final map = <String, dynamic>{
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'tipo_exame': tipoExame,
      'numero_lacre': numeroLacre,
      'status': status,
      'status_confirmacao_atn': statusConfirmacaoAtn.toBackendString(),
      'justificativa_recusa': justificativaRecusa,
      'quantidade_amostras': quantidadeAmostras,
    };

    if (detalhes != null) {
      // Normalização agressiva: remove espaços e garante uppercase
      final tipoNormalizado = tipoExame.trim().toUpperCase();

      final List detalhesList = detalhes is List
          ? detalhes as List
          : [detalhes];
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
        debugPrint(
          '🚨 [toSyncMap] tipo_exame não reconhecido: "$tipoNormalizado"',
        );
      }
    }
    return map;
  }

  /// Cria uma cópia imutável de [ExameSolicitadoModel] com os campos fornecidos substituídos.
  ExameSolicitadoModel copyWith({
    String? uuid,
    String? casoUuid,
    String? tipoExame,
    String? numeroLacre,
    DateTime? criadoEm,
    String? status,
    StatusConfirmacaoATN? statusConfirmacaoAtn,
    String? justificativaRecusa,
    dynamic detalhes,
  }) {
    return ExameSolicitadoModel(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      tipoExame: tipoExame ?? this.tipoExame,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      criadoEm: criadoEm ?? this.criadoEm,
      status: status ?? this.status,
      statusConfirmacaoAtn: statusConfirmacaoAtn ?? this.statusConfirmacaoAtn,
      justificativaRecusa: justificativaRecusa ?? this.justificativaRecusa,
      detalhes: detalhes ?? this.detalhes,
    );
  }
}


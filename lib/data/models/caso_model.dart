import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/data/models/auditoria_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/dados_laudo_model.dart';
import 'package:croqui_forense_mvp/data/models/causa_morte_model.dart';
import 'package:croqui_forense_mvp/data/models/balistica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';

enum SortCriteria { numero, data }

enum SortOrder { asc, desc }

enum StatusCaso {
  rascunho,
  laudo_pendente,
  finalizado,
  sincronizado,
  arquivado,
}

/// Entidade central do domínio de Necrópsia Digital, representando um Laudo Pericial completo.
///
/// Agrupa metadados do defunto, ocorrência (PIC/BO), hierarquia de [Achado]s,
/// cadeia de custódia da [AuditoriaModel] e a estrutura de [EvidenciaMultimidia].
class Caso {
  final String uuid;
  final String idUsuarioCriador;
  final String? numeroLaudoExterno;
  final StatusCaso status;
  final DadosLaudoModel dadosLaudo;
  final String? hashIntegridade;
  final bool removido;
  final int versao;
  final String? deviceId;
  final DateTime criadoEmDispositivo;
  final DateTime? atualizadoEm;
  final DateTime? finalizadoEm;
  final String numeroPic;
  final String numeroBo;
  final String numeroRequisicao;
  final String nomeVitima;
  final String destino;
  final String requisitante;
  final List<String> atnsIds;
  final String? pdfLocalPath;
  final String? pdfUrl;
  final bool isDraftSynced;
  final bool syncError;
  final List<EvidenciaMultimidia> evidenciasMultimidia;

  final String? corpoEstado;
  final String? corpoEstadoOutros;
  final String? sexoBiologicoEstimado;
  final String? dataObito;
  final String? horaObito;
  final String? tipoEstimativaHoraObito;

  /// Armazena a estrutura hierárquica das causas da morte.
  /// Tipado estritamente como Lista para garantir a integridade da árvore
  /// de dados no ciclo de persistência bidirecional (SQLite ↔ API REST).
  final List<CausaMorteModel>? causaMorte;
  final bool? examesSolicitados;
  final String? descricaoExames;
  final List<BalisticaModel> balisticas;
  final List<ExameSolicitadoModel> exames;
  final String? dataNecropsia;
  final String? horaNecropsia;
  final String? numeroDeclaracaoObito;
  final String? delegaciaSolicitante;

  AuditoriaModel get auditoria {
    return dadosLaudo.auditoria;
  }

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
    this.finalizadoEm,
    this.deviceId,
    required this.dadosLaudo,
    required this.numeroPic,
    required this.numeroBo,
    required this.numeroRequisicao,
    required this.nomeVitima,
    required this.destino,
    required this.requisitante,
    this.atnsIds = const [],
    this.pdfLocalPath,
    this.pdfUrl,
    this.isDraftSynced = false,
    this.syncError = false,
    this.evidenciasMultimidia = const [],
    this.corpoEstado,
    this.corpoEstadoOutros,
    this.sexoBiologicoEstimado,
    this.dataObito,
    this.horaObito,
    this.tipoEstimativaHoraObito,
    this.causaMorte,
    this.examesSolicitados,
    this.descricaoExames,
    this.balisticas = const [],
    this.exames = const [],
    this.dataNecropsia,
    this.horaNecropsia,
    this.numeroDeclaracaoObito,
    this.delegaciaSolicitante,
  });

  Caso.novo({
    required this.idUsuarioCriador,
    this.numeroLaudoExterno,
    this.deviceId,
    DadosLaudoModel? dadosLaudo,
    this.numeroPic = '',
    this.numeroBo = '',
    this.numeroRequisicao = '',
    this.nomeVitima = '',
    this.destino = '',
    this.requisitante = '',
    this.atnsIds = const [],
    this.pdfLocalPath,
    this.pdfUrl,
    this.isDraftSynced = false,
    this.syncError = false,
    this.evidenciasMultimidia = const [],
    this.corpoEstado,
    this.corpoEstadoOutros,
    this.sexoBiologicoEstimado,
    this.dataObito,
    this.horaObito,
    this.tipoEstimativaHoraObito,
    this.causaMorte,
    this.examesSolicitados,
    this.descricaoExames,
    this.balisticas = const [],
    this.exames = const [],
    this.dataNecropsia,
    this.horaNecropsia,
    this.numeroDeclaracaoObito,
    this.delegaciaSolicitante,
  }) : uuid = const Uuid().v4(),
       status = StatusCaso.rascunho,
       hashIntegridade = null,
       removido = false,
       versao = 1,
       dadosLaudo = dadosLaudo ?? DadosLaudoModel.novo(),
       criadoEmDispositivo = DateTime.now(),
       atualizadoEm = DateTime.now(),
       finalizadoEm = null;

  factory Caso.fromMap(Map<String, dynamic> map) {
    String? _toTitleCase(String? text) {
      if (text == null || text.trim().isEmpty) return text;
      final trimmed = text.trim();
      return trimmed.substring(0, 1).toUpperCase() + trimmed.substring(1).toLowerCase();
    }

    String? _parseEstimativa(String? raw) {
      if (raw == null) return null;
      final val = raw.toUpperCase();
      if (val.contains('PERICIAL')) return 'Pericialmente Estimadas';
      if (val.contains('ATESTADA')) return 'Atestadas em documento médico';
      return raw;
    }

    final Map<String, dynamic> dadosLaudoParsed =
        map['dados_laudo_json'] != null
        ? (map['dados_laudo_json'] is Map
              ? Map<String, dynamic>.from(map['dados_laudo_json'] as Map)
              : Map<String, dynamic>.from(
                  (() {
                    try {
                      return jsonDecode(map['dados_laudo_json'].toString())
                              as Map? ??
                          {};
                    } catch (_) {
                      return {};
                    }
                  })(),
                ))
        : <String, dynamic>{};

    if (dadosLaudoParsed['auditoria'] is Map) {
      final auditoriaMap = Map<String, dynamic>.from(
        dadosLaudoParsed['auditoria'] as Map,
      );
      auditoriaMap.remove('atn_id');
      auditoriaMap.remove('atn_nome');
      dadosLaudoParsed['auditoria'] = auditoriaMap;
    }

    final String? delegaciaSolicitanteParsed =
        dadosLaudoParsed['delegacia_solicitante']?.toString() ??
        map['delegacia_solicitante']?.toString();
    final DadosLaudoModel modelDadosLaudo = DadosLaudoModel.fromMap(
      dadosLaudoParsed,
    );

    List<String> parsedAtns = [];
    final rawAtns = map['atns_ids'];
    if (rawAtns is List) {
      parsedAtns = List<String>.from(rawAtns.map((e) => e.toString()));
    } else if (rawAtns is String && rawAtns.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAtns);
        if (decoded is List) {
          parsedAtns = List<String>.from(decoded.map((e) => e.toString()));
        }
      } catch (e) {
        debugPrint(
          '[Caso.fromMap] Erro ao decodificar atns_ids JSON string: $e',
        );
      }
    }

    List<EvidenciaMultimidia> parsedEvidencias = [];
    final rawEvidencias = map['evidencias_multimidia'] ?? map['evidencias'];
    if (rawEvidencias is List) {
      parsedEvidencias = rawEvidencias
          .whereType<Map>()
          .map((x) => EvidenciaMultimidia.fromMap(Map<String, dynamic>.from(x)))
          .toList();
    }

    List<BalisticaModel> parsedBalisticas = [];
    final rawBalisticas = map['balisticas'];
    final casoUuidParsed = map['uuid']?.toString() ?? '';
    if (rawBalisticas is List) {
      parsedBalisticas = rawBalisticas
          .whereType<Map>()
          .map((x) {
            final m = Map<String, dynamic>.from(x);
            if (m['exame_id'] == null || m['exame_id'].toString().isEmpty) {
              m['exame_id'] = m['caso_uuid'] ?? casoUuidParsed;
            }
            return BalisticaModel.fromMap(m);
          })
          .toList();
    } else if (rawBalisticas is String && rawBalisticas.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBalisticas);
        if (decoded is List) {
          parsedBalisticas = decoded
              .whereType<Map>()
              .map((x) {
                final m = Map<String, dynamic>.from(x);
                if (m['exame_id'] == null || m['exame_id'].toString().isEmpty) {
                  m['exame_id'] = m['caso_uuid'] ?? casoUuidParsed;
                }
                return BalisticaModel.fromMap(m);
              })
              .toList();
        }
      } catch (e) {
        debugPrint(
          '[Caso.fromMap] Erro ao decodificar balisticas JSON string: $e',
        );
      }
    }

    List<ExameSolicitadoModel> parsedExames = [];
    final rawExames = map['exames'] ?? map['exames_solicitados'];
    if (rawExames is List) {
      parsedExames = rawExames
          .whereType<Map>()
          .map(
            (x) => ExameSolicitadoModel.fromMap(Map<String, dynamic>.from(x)),
          )
          .toList();
    } else if (rawExames is String && rawExames.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawExames);
        if (decoded is List) {
          parsedExames = decoded
              .whereType<Map>()
              .map(
                (x) =>
                    ExameSolicitadoModel.fromMap(Map<String, dynamic>.from(x)),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('[Caso.fromMap] Erro ao decodificar exames JSON string: $e');
      }
    }

    if (parsedExames.isEmpty && dadosLaudoParsed.containsKey('exames_offline_backup')) {
      final rawBackup = dadosLaudoParsed['exames_offline_backup'];
      List<dynamic>? backupList;
      if (rawBackup is List) {
        backupList = rawBackup;
      } else if (rawBackup is String && rawBackup.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawBackup);
          if (decoded is List) backupList = decoded;
        } catch (e) {
          debugPrint('[Caso.fromMap] Erro ao decodificar exames_offline_backup: $e');
        }
      }

      if (backupList != null) {
        parsedExames = backupList
            .whereType<Map>()
            .map(
              (x) => ExameSolicitadoModel.fromMap(Map<String, dynamic>.from(x)),
            )
            .toList();
      }
    }

    return Caso(
      uuid: map['uuid']?.toString() ?? '',
      idUsuarioCriador: map['id_usuario_criador']?.toString() ?? '',
      numeroLaudoExterno: map['numero_laudo_externo']?.toString(),
      status: StatusCaso.values.firstWhere(
        (e) =>
            e.name.toUpperCase() ==
            (map['status']?.toString() ?? '').toUpperCase(),
        orElse: () => StatusCaso.rascunho,
      ),
      dadosLaudo: modelDadosLaudo,

      hashIntegridade: map['hash_integridade']?.toString(),
      removido: map['removido'] is bool
          ? map['removido'] as bool
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,

      criadoEmDispositivo:
          DateTime.tryParse(map['criado_em_dispositivo']?.toString() ?? '') ??
          DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null
          ? DateTime.tryParse(map['atualizado_em'].toString())
          : null,
      finalizadoEm: map['finalizado_em'] != null
          ? DateTime.tryParse(map['finalizado_em'].toString())
          : null,

      deviceId: map['device_id']?.toString(),
      numeroPic: map['numero_pic']?.toString() ?? '',
      numeroBo: map['numero_bo']?.toString() ?? '',
      numeroRequisicao: map['numero_requisicao']?.toString() ?? '',
      nomeVitima: map['nome_vitima']?.toString() ?? '',
      destino: map['destino']?.toString() ?? '',
      requisitante: map['requisitante']?.toString() ?? '',
      atnsIds: parsedAtns,
      pdfLocalPath: map['pdf_local_path']?.toString(),
      pdfUrl: map['pdf_url']?.toString(),
      isDraftSynced: map['is_draft_synced'] is bool
          ? map['is_draft_synced'] as bool
          : (map['is_draft_synced'] as int? ?? 0) == 1,
      syncError: map['sync_error'] is bool
          ? map['sync_error'] as bool
          : (map['sync_error'] as int? ?? 0) == 1,
      evidenciasMultimidia: parsedEvidencias,
      corpoEstado: _toTitleCase(map['corpo_estado']?.toString()),
      corpoEstadoOutros: map['corpo_estado_outros']?.toString(),
      sexoBiologicoEstimado: _toTitleCase(map['sexo_biologico_estimado']?.toString()),
      dataObito: map['data_obito']?.toString(),
      horaObito: map['hora_obito']?.toString(),
      tipoEstimativaHoraObito: _parseEstimativa(map['tipo_estimativa_hora_obito']?.toString()),

      /// Valida e converte o payload de causa da morte.
      /// Estruturas compostas nativas da API (Map/List) são aceitas diretamente.
      /// Strings oriundas do SQLite são submetidas a decode estrito, rejeitando
      /// primitivas que poderiam corromper o round-trip de persistência local.
      causaMorte: (() {
        final raw = map['causa_morte'];
        if (raw == null) return null;

        List<dynamic> listRaw = [];
        if (raw is List) {
          listRaw = raw;
        } else if (raw is String && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) listRaw = decoded;
          } catch (e) {
            debugPrint('[CasoModel] Parse error em causa_morte: $e');
          }
        }

        if (listRaw.isEmpty) return null;
        return listRaw
            .whereType<Map>()
            .map((x) => CausaMorteModel.fromMap(Map<String, dynamic>.from(x)))
            .toList();
      })(),
      examesSolicitados: (() {
        // Fallback primário: a chave exata do SQLite ou a antiga chave boolean do backend
        final raw = map['tem_exames_solicitados'] ?? map['exames_solicitados_flag'];
        if (raw != null) {
          if (raw is bool) return raw;
          if (raw is int) return raw == 1;
          if (raw is String) return raw.toLowerCase() == 'true' || raw == '1';
        }

        // Fallback secundário: O backend envia a lista JSON sob a chave 'exames_solicitados'
        final legacyRaw = map['exames_solicitados'];
        if (legacyRaw is bool) return legacyRaw;
        if (legacyRaw is int) return legacyRaw == 1;

        // Se for lista JSON do backend ou estiver em branco, usamos a dedução da lista polimórfica já parseada
        if (parsedExames.isNotEmpty) return true;
        
        return false;
      })(),
      descricaoExames: map['descricao_exames']?.toString(),
      balisticas: parsedBalisticas,
      exames: parsedExames,
      dataNecropsia: map['data_necropsia']?.toString(),
      horaNecropsia: map['hora_necropsia']?.toString(),
      numeroDeclaracaoObito: map['numero_declaracao_obito']?.toString(),
      delegaciaSolicitante: delegaciaSolicitanteParsed,
    );
  }

  Caso copyWith({
    String? uuid,
    String? idUsuarioCriador,
    String? numeroLaudoExterno,
    StatusCaso? status,
    DadosLaudoModel? dadosLaudo,
    String? hashIntegridade,
    bool? removido,
    int? versao,
    String? deviceId,
    DateTime? criadoEmDispositivo,
    DateTime? atualizadoEm,
    DateTime? finalizadoEm,
    String? numeroPic,
    String? numeroBo,
    String? numeroRequisicao,
    String? nomeVitima,
    String? destino,
    String? requisitante,
    List<String>? atnsIds,
    String? pdfLocalPath,
    String? pdfUrl,
    bool? isDraftSynced,
    bool? syncError,
    List<EvidenciaMultimidia>? evidenciasMultimidia,
    String? corpoEstado,
    String? corpoEstadoOutros,
    String? sexoBiologicoEstimado,
    String? dataObito,
    String? horaObito,
    String? tipoEstimativaHoraObito,
    List<CausaMorteModel>? causaMorte,
    bool? examesSolicitados,
    String? descricaoExames,
    List<BalisticaModel>? balisticas,
    List<ExameSolicitadoModel>? exames,
    String? dataNecropsia,
    String? horaNecropsia,
    String? numeroDeclaracaoObito,
    String? delegaciaSolicitante,
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
      finalizadoEm: finalizadoEm ?? this.finalizadoEm,
      numeroPic: numeroPic ?? this.numeroPic,
      numeroBo: numeroBo ?? this.numeroBo,
      numeroRequisicao: numeroRequisicao ?? this.numeroRequisicao,
      nomeVitima: nomeVitima ?? this.nomeVitima,
      destino: destino ?? this.destino,
      requisitante: requisitante ?? this.requisitante,
      atnsIds: atnsIds ?? this.atnsIds,
      pdfLocalPath: pdfLocalPath ?? this.pdfLocalPath,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      isDraftSynced: isDraftSynced ?? this.isDraftSynced,
      syncError: syncError ?? this.syncError,
      evidenciasMultimidia:
          evidenciasMultimidia ?? this.evidenciasMultimidia,
      corpoEstado: corpoEstado ?? this.corpoEstado,
      corpoEstadoOutros: corpoEstadoOutros ?? this.corpoEstadoOutros,
      sexoBiologicoEstimado:
          sexoBiologicoEstimado ?? this.sexoBiologicoEstimado,
      dataObito: dataObito ?? this.dataObito,
      horaObito: horaObito ?? this.horaObito,
      tipoEstimativaHoraObito:
          tipoEstimativaHoraObito ?? this.tipoEstimativaHoraObito,
      causaMorte: causaMorte ?? this.causaMorte,
      examesSolicitados: examesSolicitados ?? this.examesSolicitados,
      descricaoExames: descricaoExames ?? this.descricaoExames,
      balisticas: balisticas ?? this.balisticas,
      exames: exames ?? this.exames,
      dataNecropsia: dataNecropsia ?? this.dataNecropsia,
      horaNecropsia: horaNecropsia ?? this.horaNecropsia,
      numeroDeclaracaoObito:
          numeroDeclaracaoObito ?? this.numeroDeclaracaoObito,
      delegaciaSolicitante: delegaciaSolicitante ?? this.delegaciaSolicitante,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id_usuario_criador': idUsuarioCriador,
      'numero_laudo_externo': numeroLaudoExterno,
      'status': status.name.toUpperCase(),
      'dados_laudo_json': jsonEncode({
        ...dadosLaudo.toMap(),
        if (delegaciaSolicitante != null)
          'delegacia_solicitante': delegaciaSolicitante,
        if (exames.isNotEmpty)
          'exames_offline_backup': exames.map((e) => e.toSyncMap()).toList(),
      }),
      'hash_integridade': hashIntegridade,
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em_dispositivo': criadoEmDispositivo.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
      'finalizado_em': finalizadoEm?.toIso8601String(),
      'device_id': deviceId,
      'numero_pic': numeroPic,
      'numero_bo': numeroBo,
      'numero_requisicao': numeroRequisicao,
      'nome_vitima': nomeVitima,
      'destino': destino,
      'requisitante': requisitante,
      'atns_ids': jsonEncode(atnsIds),
      'pdf_local_path': pdfLocalPath,
      'pdf_url': pdfUrl,
      'is_draft_synced': isDraftSynced ? 1 : 0,
      'sync_error': syncError ? 1 : 0,
      'corpo_estado': corpoEstado,
      'corpo_estado_outros': corpoEstadoOutros,
      'sexo_biologico_estimado': sexoBiologicoEstimado,
      'data_obito': dataObito,
      'hora_obito': horaObito,
      'tipo_estimativa_hora_obito': tipoEstimativaHoraObito,
      'causa_morte': causaMorte != null
          ? jsonEncode(causaMorte!.map((e) => e.toMap()).toList())
          : null,
      'exames_solicitados': examesSolicitados == null
          ? null
          : (examesSolicitados! ? 1 : 0),
      'descricao_exames': descricaoExames,
      'balisticas': jsonEncode(balisticas.map((e) => e.toMap()).toList()),
      'exames': jsonEncode(exames.map((e) => e.toSyncMap()).toList()),
      'data_necropsia': dataNecropsia,
      'hora_necropsia': horaNecropsia,
      'numero_declaracao_obito': numeroDeclaracaoObito,
    };
  }

  String? _formatDateToSync(String? date) {
    if (date == null || date.trim().isEmpty) return null;
    if (date.contains('-')) return date;
    final parts = date.split('/');
    if (parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String? _formatTimeToSync(String? time) {
    if (time == null || time.trim().isEmpty) return null;
    if (time.split(':').length == 3) return time;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    return '${parts[0]}:${parts[1]}:00';
  }

  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'versao': versao,
      'removido': removido,
      'status_pericia': _mapearStatusParaApi(status),
      'device_id': deviceId ?? '167a0d1d-1af1-4538-9420-75247c19d164',
      'atns_ids': atnsIds,
      'criado_em_dispositivo': criadoEmDispositivo.toUtc().toIso8601String(),
      'atualizado_em': (atualizadoEm ?? criadoEmDispositivo)
          .toUtc()
          .toIso8601String(),
      'finalizado_em': finalizadoEm?.toUtc().toIso8601String(),
      'perito_responsavel': idUsuarioCriador,
      'numero_pic': numeroPic,
      'numero_laudo_externo': numeroLaudoExterno,
      'numero_bo': numeroBo,
      'numero_requisicao': numeroRequisicao,
      'requisitante': requisitante,
      'delegacia_solicitante': delegaciaSolicitante,
      'destino': destino,
      'nome_vitima': nomeVitima,
      'dados_laudo_json': dadosLaudo.toMap(),
      'pdf_url': pdfUrl,
      'corpo_estado': (corpoEstado?.trim().isEmpty ?? true) ? null : corpoEstado,
      'corpo_estado_outros': corpoEstadoOutros,
      'sexo_biologico_estimado': (sexoBiologicoEstimado?.trim().isEmpty ?? true) ? null : sexoBiologicoEstimado,
      'data_obito': _formatDateToSync(dataObito),
      'hora_obito': _formatTimeToSync(horaObito),
      'tipo_estimativa_hora_obito': (tipoEstimativaHoraObito?.trim().isEmpty ?? true) ? null : tipoEstimativaHoraObito,
      'causa_morte': causaMorte?.map((e) => e.toMap()).toList(),
      'exames_solicitados_flag': examesSolicitados,
      'descricao_exames': descricaoExames,
      'exames_solicitados': exames.map((e) => e.toSyncMap()).toList(),
      'balisticas': balisticas.map((e) => e.toMap()).toList(),
      'data_necropsia': _formatDateToSync(dataNecropsia),
      'hora_necropsia': _formatTimeToSync(horaNecropsia),
      'numero_declaracao_obito': numeroDeclaracaoObito,
    };
  }

  String _mapearStatusParaApi(StatusCaso statusLocal) {
    switch (statusLocal) {
      case StatusCaso.rascunho:
        return 'EM_ANDAMENTO';
      case StatusCaso.laudo_pendente:
        return 'LAUDO_PENDENTE';
      case StatusCaso.finalizado:
      case StatusCaso.sincronizado:
      case StatusCaso.arquivado:
        return 'CONCLUIDO';
      default:
        return 'EM_ANDAMENTO';
    }
  }
}

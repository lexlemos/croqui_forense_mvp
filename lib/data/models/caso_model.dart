import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/data/models/auditoria_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';

enum SortCriteria { numero, data }
enum SortOrder { asc, desc }

enum StatusCaso {
  rascunho,
  // ignore: constant_identifier_names
  laudo_pendente,
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
  final dynamic causaMorte;
  final bool? examesSolicitados;
  final String? descricaoExames;
  final bool? objetoRetirado;
  final String? descricaoObjeto;
  final String? dataNecropsia;
  final String? horaNecropsia;
  final String? numeroDeclaracaoObito;

  AuditoriaModel get auditoria {
    final map = dadosLaudo['auditoria'];
    if (map is Map<String, dynamic>) {
      return AuditoriaModel.fromJson(map);
    } else if (map is Map) {
      return AuditoriaModel.fromJson(Map<String, dynamic>.from(map));
    }
    return AuditoriaModel();
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
    this.objetoRetirado,
    this.descricaoObjeto,
    this.dataNecropsia,
    this.horaNecropsia,
    this.numeroDeclaracaoObito,
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
    this.objetoRetirado,
    this.descricaoObjeto,
    this.dataNecropsia,
    this.horaNecropsia,
    this.numeroDeclaracaoObito,
  }) : uuid = const Uuid().v4(), 
       status = StatusCaso.rascunho,
       hashIntegridade = null,
       removido = false,
       versao = 1,
       criadoEmDispositivo = DateTime.now(),
       atualizadoEm = DateTime.now(),
       finalizadoEm = null;

  factory Caso.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> dadosLaudoParsed = map['dados_laudo_json'] != null 
        ? (map['dados_laudo_json'] is Map
            ? Map<String, dynamic>.from(map['dados_laudo_json'] as Map)
            : Map<String, dynamic>.from((() {
                try {
                  return jsonDecode(map['dados_laudo_json'].toString()) as Map? ?? {};
                } catch (_) {
                  return {};
                }
              })()))
        : <String, dynamic>{};

    // Limpa chaves legadas de ATN de dentro do auditoria no dados_laudo_json
    if (dadosLaudoParsed['auditoria'] is Map) {
      final auditoriaMap = Map<String, dynamic>.from(dadosLaudoParsed['auditoria'] as Map);
      auditoriaMap.remove('atn_id');
      auditoriaMap.remove('atn_nome');
      dadosLaudoParsed['auditoria'] = auditoriaMap;
    }

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
        debugPrint('[Caso.fromMap] Erro ao decodificar atns_ids JSON string: $e');
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

    return Caso(
      uuid: map['uuid']?.toString() ?? '',
      idUsuarioCriador: map['id_usuario_criador']?.toString() ?? '',
      numeroLaudoExterno: map['numero_laudo_externo']?.toString(),
      status: StatusCaso.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['status']?.toString() ?? '').toUpperCase(),
        orElse: () => StatusCaso.rascunho,
      ),
      dadosLaudo: dadosLaudoParsed,
      
      hashIntegridade: map['hash_integridade']?.toString(),
      removido: map['removido'] is bool 
          ? map['removido'] as bool 
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,

      criadoEmDispositivo: DateTime.tryParse(map['criado_em_dispositivo']?.toString() ?? '') ?? DateTime.now(),
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
      corpoEstado: map['corpo_estado']?.toString(),
      corpoEstadoOutros: map['corpo_estado_outros']?.toString(),
      sexoBiologicoEstimado: map['sexo_biologico_estimado']?.toString(),
      dataObito: map['data_obito']?.toString(),
      horaObito: map['hora_obito']?.toString(),
      tipoEstimativaHoraObito: map['tipo_estimativa_hora_obito']?.toString(),
      causaMorte: map['causa_morte'] != null
          ? (() {
              final val = map['causa_morte'];
              if (val is Map || val is List) return val;
              try {
                final decoded = jsonDecode(val.toString());
                if (decoded is Map || decoded is List) return decoded;
              } catch (_) {}
              return null;
            })()
          : null,
      examesSolicitados: map['exames_solicitados'] != null
          ? (map['exames_solicitados'] is bool
              ? map['exames_solicitados'] as bool
              : (map['exames_solicitados'] as int? ?? 0) == 1)
          : null,
      descricaoExames: map['descricao_exames']?.toString(),
      objetoRetirado: map['objeto_retirado'] != null
          ? (map['objeto_retirado'] is bool
              ? map['objeto_retirado'] as bool
              : (map['objeto_retirado'] as int? ?? 0) == 1)
          : null,
      descricaoObjeto: map['descricao_objeto']?.toString(),
      dataNecropsia: map['data_necropsia']?.toString(),
      horaNecropsia: map['hora_necropsia']?.toString(),
      numeroDeclaracaoObito: map['numero_declaracao_obito']?.toString(),
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
    String? corpoEstado,
    String? corpoEstadoOutros,
    String? sexoBiologicoEstimado,
    String? dataObito,
    String? horaObito,
    String? tipoEstimativaHoraObito,
    dynamic causaMorte,
    bool? examesSolicitados,
    String? descricaoExames,
    bool? objetoRetirado,
    String? descricaoObjeto,
    String? dataNecropsia,
    String? horaNecropsia,
    String? numeroDeclaracaoObito,
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
      corpoEstado: corpoEstado ?? this.corpoEstado,
      corpoEstadoOutros: corpoEstadoOutros ?? this.corpoEstadoOutros,
      sexoBiologicoEstimado: sexoBiologicoEstimado ?? this.sexoBiologicoEstimado,
      dataObito: dataObito ?? this.dataObito,
      horaObito: horaObito ?? this.horaObito,
      tipoEstimativaHoraObito: tipoEstimativaHoraObito ?? this.tipoEstimativaHoraObito,
      causaMorte: causaMorte ?? this.causaMorte,
      examesSolicitados: examesSolicitados ?? this.examesSolicitados,
      descricaoExames: descricaoExames ?? this.descricaoExames,
      objetoRetirado: objetoRetirado ?? this.objetoRetirado,
      descricaoObjeto: descricaoObjeto ?? this.descricaoObjeto,
      dataNecropsia: dataNecropsia ?? this.dataNecropsia,
      horaNecropsia: horaNecropsia ?? this.horaNecropsia,
      numeroDeclaracaoObito: numeroDeclaracaoObito ?? this.numeroDeclaracaoObito,
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
      'causa_morte': causaMorte != null ? jsonEncode(causaMorte) : null,
      'exames_solicitados': examesSolicitados == null ? null : (examesSolicitados! ? 1 : 0),
      'descricao_exames': descricaoExames,
      'objeto_retirado': objetoRetirado == null ? null : (objetoRetirado! ? 1 : 0),
      'descricao_objeto': descricaoObjeto,
      'data_necropsia': dataNecropsia,
      'hora_necropsia': horaNecropsia,
      'numero_declaracao_obito': numeroDeclaracaoObito,
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
      'finalizado_em': finalizadoEm?.toIso8601String(),
      'device_id': deviceId,
      'numero_pic': numeroPic,
      'numero_bo': numeroBo,
      'numero_requisicao': numeroRequisicao,
      'nome_vitima': nomeVitima,
      'destino': destino,
      'requisitante': requisitante,
      'atns_ids': atnsIds,
      'pdf_local_path': pdfLocalPath,
      'pdf_url': pdfUrl,
      'is_draft_synced': isDraftSynced,
      'corpo_estado': corpoEstado,
      'corpo_estado_outros': corpoEstadoOutros,
      'sexo_biologico_estimado': sexoBiologicoEstimado,
      'data_obito': dataObito,
      'hora_obito': horaObito,
      'tipo_estimativa_hora_obito': tipoEstimativaHoraObito,
      'causa_morte': causaMorte,
      'exames_solicitados': examesSolicitados,
      'descricao_exames': descricaoExames,
      'objeto_retirado': objetoRetirado,
      'descricao_objeto': descricaoObjeto,
      'data_necropsia': dataNecropsia,
      'hora_necropsia': horaNecropsia,
      'numero_declaracao_obito': numeroDeclaracaoObito,
      'perito_responsavel': idUsuarioCriador,
    };
  }
}

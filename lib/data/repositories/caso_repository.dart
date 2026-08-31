import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class CasoRepository implements ISyncRepository {
  final DatabaseHelper _dbHelper;

  CasoRepository(this._dbHelper);

  Future<Database> get database async => _dbHelper.database;

  Future<void> insertCase(Caso novoCaso) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final map = novoCaso.toMap()..['is_draft_synced'] = 0;
        final rowsAffected = await txn.update(
          tableCasos,
          map,
          where: 'uuid = ?',
          whereArgs: [novoCaso.uuid],
        );
        if (rowsAffected == 0) {
          await txn.insert(
            tableCasos,
            map,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });
    } catch (e) {
      throw Exception('Erro de persistência ao inserir caso: $e');
    }
  }

  Future<void> insertCaseComEvidenciasLote(Caso novoCaso, List<EvidenciaMultimidia> evidencias) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final map = novoCaso.toMap()..['is_draft_synced'] = 0;
        final rows = await txn.update(
          tableCasos,
          map,
          where: 'uuid = ?',
          whereArgs: [novoCaso.uuid],
        );
        if (rows == 0) {
          await txn.insert(
            tableCasos,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final ev in evidencias) {
          await txn.insert(
            tableEvidenciasMultimidia,
            ev.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw Exception('Erro de persistência atômica ao inserir caso e evidências em lote: $e');
    }
  }

  /// Motor de Upsert (Sincronização Pull). Resolve conflitos verificando o [atualizado_em] e lida com Tombstones.
  @override
  Future<void> upsertCasoTransaction(Map<String, dynamic> jsonCaso) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final casoBackend = Caso.fromMap(jsonCaso);

        final localRow = await txn.query(
          tableCasos,
          where: 'uuid = ?',
          whereArgs: [casoBackend.uuid],
          limit: 1,
        );

        bool deveAtualizarCaso = true;

        if (localRow.isNotEmpty) {
          final localAtualizadoEmStr = localRow.first['atualizado_em']?.toString();
          final localAtualizadoEm = localAtualizadoEmStr != null ? DateTime.tryParse(localAtualizadoEmStr) : null;
          final backendAtualizadoEm = casoBackend.atualizadoEm;

          if (localAtualizadoEm != null && backendAtualizadoEm != null) {
            if (!backendAtualizadoEm.isAfter(localAtualizadoEm)) {
              deveAtualizarCaso = false;
            }
          }
        }

        final batch = txn.batch();

        if (deveAtualizarCaso) {
          final mapParaSalvar = casoBackend.toMap();
          if (jsonCaso['removido'] == true) {
            mapParaSalvar['removido'] = 1;
          }

          if (localRow.isEmpty) {
            batch.insert(
              tableCasos,
              mapParaSalvar,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            batch.update(
              tableCasos,
              mapParaSalvar,
              where: 'uuid = ?',
              whereArgs: [casoBackend.uuid],
            );
          }
        }

        final List<dynamic> rawEvidenciasList = [];
        if (jsonCaso['evidencias_multimidia'] is List) {
          rawEvidenciasList.addAll(jsonCaso['evidencias_multimidia'] as List);
        }
        if (jsonCaso['evidencias'] is List) {
          rawEvidenciasList.addAll(jsonCaso['evidencias'] as List);
        }

        if (jsonCaso['achados'] is List) {
          final achadosList = jsonCaso['achados'] as List;
          for (final achadoJson in achadosList) {
            if (achadoJson is Map) {
              final aMap = Map<String, dynamic>.from(achadoJson);
              if (aMap['evidencias_multimidia'] is List) {
                rawEvidenciasList.addAll(aMap['evidencias_multimidia'] as List);
              }
              if (aMap['evidencias'] is List) {
                rawEvidenciasList.addAll(aMap['evidencias'] as List);
              }
            }
          }
        }

        final achadosParaSalvar = <Map<String, dynamic>>[];
        final evidenciasParaSalvar = <Map<String, dynamic>>[];
        final achadosComEvidenciaExplicita = <String>{};

        for (final evJson in rawEvidenciasList) {
          if (evJson is! Map) continue;
          final evMap = Map<String, dynamic>.from(evJson);
          final evBackend = EvidenciaMultimidia.fromMap(evMap);
          if (evBackend.uuid.isEmpty) continue;

          final mapEvSalvar = evBackend.toMap()..['foto_sincronizada'] = 1;
          if (evJson['removido'] == true) {
            mapEvSalvar['removido'] = 1;
          }
          evidenciasParaSalvar.add(mapEvSalvar);
          if (evBackend.achadoUuid != null && evBackend.achadoUuid!.isNotEmpty) {
            achadosComEvidenciaExplicita.add(evBackend.achadoUuid!);
          }
        }

        if (jsonCaso['achados'] is List) {
          final achadosList = jsonCaso['achados'] as List;
          for (final achadoJson in achadosList) {
            if (achadoJson is! Map) continue;
            final aMap = Map<String, dynamic>.from(achadoJson);
            final achadoBackend = Achado.fromMap(aMap);
            if (achadoBackend.uuid.isEmpty) continue;

            final mapAchadoSalvar = achadoBackend.toMap();
            if (achadoJson['removido'] == true) {
              mapAchadoSalvar['removido'] = 1;
            }
            achadosParaSalvar.add(mapAchadoSalvar);

            if (achadoBackend.photoPath != null &&
                achadoBackend.photoPath!.isNotEmpty &&
                !achadosComEvidenciaExplicita.contains(achadoBackend.uuid)) {
              final evidenciaUuid = const Uuid().v5(
                casoBackend.uuid,
                'achado-evidencia-${achadoBackend.uuid}',
              );
              evidenciasParaSalvar.add({
                'uuid': evidenciaUuid,
                'caso_uuid': casoBackend.uuid,
                'achado_uuid': achadoBackend.uuid,
                'tipo': 'ACHADO',
                'caminho_arquivo_encriptado': achadoBackend.photoPath,
                'foto_sincronizada': 1,
                'removido': achadoBackend.removido ? 1 : 0,
                'versao': achadoBackend.versao,
                'criado_em': achadoBackend.criadoEm.toUtc().toIso8601String(),
              });
            }
          }
        }

        for (final mapAchado in achadosParaSalvar) {
          batch.insert(
            tableAchados,
            mapAchado,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final mapEvidencia in evidenciasParaSalvar) {
          batch.insert(
            tableEvidenciasMultimidia,
            mapEvidencia,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    } catch (e, stackTrace) {
      debugPrint('[CasoRepository] ❌ Erro na transação de upsertCasoTransaction (caso uuid: ${jsonCaso['uuid']}): $e\n$stackTrace');
      throw Exception('Erro de persistência atômica no Upsert: $e');
    }
  }

  Future<void> updateCase(Caso caso) async {
    final db = await database;
    try {
      final map = caso.toMap()..['is_draft_synced'] = 0;
      await db.update(
        tableCasos,
        map,
        where: "uuid = ? AND UPPER(status) != 'FINALIZADO'",
        whereArgs: [caso.uuid],
      );
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar caso: $e');
    }
  }

  Future<void> reabrirCaso(Caso caso) async {
    final db = await database;
    try {
      final map = caso.toMap()
        ..['is_draft_synced'] = 0
        ..['status'] = 'RASCUNHO';
      await db.update(
        tableCasos,
        map,
        where: 'uuid = ?',
        whereArgs: [caso.uuid],
      );
    } catch (e) {
      throw Exception('Erro de persistência ao reabrir caso: $e');
    }
  }

  @override
  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await database;
    final result = await db.query(
      tableAchados,
      where: 'caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      orderBy: 'criado_em DESC',
    );
    return result.map((map) => Achado.fromMap(map)).toList();
  }

  @override
  Future<Map<String, List<Achado>>> getAchadosEmLote(List<String> casoUuids) async {
    if (casoUuids.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(casoUuids.length, '?').join(',');
    final result = await db.query(
      tableAchados,
      where: 'caso_uuid IN ($placeholders) AND removido = 0',
      whereArgs: casoUuids,
      orderBy: 'criado_em DESC',
    );
    final Map<String, List<Achado>> grouped = {};
    for (final map in result) {
      final achado = Achado.fromMap(map);
      (grouped[achado.casoUuid] ??= []).add(achado);
    }
    return grouped;
  }

  Future<List<Caso>> getAllCases(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCasos,
      where: 'id_usuario_criador = ? AND removido = 0',
      whereArgs: [usuarioId],
      orderBy: 'atualizado_em DESC, criado_em_dispositivo DESC',
    );
    return List.generate(maps.length, (i) => Caso.fromMap(maps[i]));
  }

  Future<Caso?> getCaseByUuid(String uuid) async {
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where: 'uuid = ? AND removido = 0',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caso.fromMap(maps.first);
  }

  @override
  Future<List<Caso>> getCasosNaoSincronizados(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where: "id_usuario_criador = ? AND status = 'FINALIZADO' AND (is_draft_synced IS NULL OR is_draft_synced = 0) AND removido = 0",
      whereArgs: [usuarioId],
      orderBy: 'criado_em_dispositivo ASC',
    );
    return maps.map(Caso.fromMap).toList();
  }

  @override
  Future<List<Caso>> getRascunhosNaoSincronizados(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where: "id_usuario_criador = ? AND UPPER(status) != 'FINALIZADO' AND (is_draft_synced IS NULL OR is_draft_synced = 0) AND removido = 0",
      whereArgs: [usuarioId],
      orderBy: 'criado_em_dispositivo ASC',
    );
    return maps.map(Caso.fromMap).toList();
  }

  @override
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(List<String> casoUuids) async {
    if (casoUuids.isEmpty) return {};

    final Map<String, List<Achado>> grouped = {};
    for (final uuid in casoUuids) {
      grouped[uuid] = [];
    }

    final db = await database;
    final placeholders = List.filled(casoUuids.length, '?').join(',');

    // 1. Fotos gerais do caso (SQL na tabela evidencias_multimidia)
    try {
      final List<Map<String, dynamic>> generalEvidences = await db.query(
        tableEvidenciasMultimidia,
        where: 'caso_uuid IN ($placeholders) AND tipo = ? AND foto_sincronizada = 0 AND removido = 0',
        whereArgs: [...casoUuids, 'GERAL'],
      );

      for (final row in generalEvidences) {
        final String caseUuid = row['caso_uuid'].toString();
        final String pathString = row['caminho_arquivo_encriptado']?.toString() ?? '';
        if (pathString.isEmpty) continue;

        final achadoVirtual = Achado(
          uuid: row['uuid'].toString(),
          casoUuid: caseUuid,
          diagramaCasoUuid: '',
          diagramaNome: 'GERAL',
          tipoAchadoId: 'FOTO_GERAL',
          numeroSequencial: 0,
          posX: 0.0,
          posY: 0.0,
          isInterno: false,
          versao: 1,
          removido: false,
          criadoEm: DateTime.tryParse(row['criado_em']?.toString() ?? '') ?? DateTime.now(),
          dadosPreenchidos: {
            'photo_path': pathString,
            '_evidencia_uuid': row['uuid'].toString(),
          },
          tamanho: '',
          vistaAnatomica: '',
          localAnatomico: '',
        );
        (grouped[caseUuid] ??= []).add(achadoVirtual);
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (GERAL): $e');
    }

    // 2. Fotos de lesões (SQL na tabela evidencias_multimidia)
    try {
      final sqlAchados = '''
        SELECT
          a.*,
          e.caminho_arquivo_encriptado AS _photo_path_override,
          e.uuid                        AS _evidencia_uuid
        FROM $tableAchados a
        INNER JOIN $tableEvidenciasMultimidia e
               ON  e.achado_uuid                = a.uuid
               AND e.removido                   = 0
               AND e.caminho_arquivo_encriptado IS NOT NULL
               AND e.caminho_arquivo_encriptado != ''
               AND e.foto_sincronizada          = 0
        WHERE a.caso_uuid IN ($placeholders)
          AND a.removido  = 0
        ORDER BY a.criado_em ASC
      ''';

      final rowsAchados = await db.rawQuery(sqlAchados, casoUuids);

      for (final row in rowsAchados) {
        final casoUuid = row['caso_uuid'].toString();
        final mutableRow = Map<String, dynamic>.from(row);
        final dadosJson = mutableRow['dados_preenchidos_json'] as String? ?? '{}';
        final dados = _decodeJson(dadosJson);

        dados['photo_path'] = row['_photo_path_override'] as String?;
        dados['_evidencia_uuid'] = row['_evidencia_uuid'] as String?;

        mutableRow['dados_preenchidos_json'] = _encodeJson(dados);
        mutableRow.remove('_photo_path_override');
        mutableRow.remove('_evidencia_uuid');

        (grouped[casoUuid] ??= []).add(Achado.fromMap(mutableRow));
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (SQL): $e');
    }

    return grouped;
  }

  @override
  Future<List<Achado>> getEvidenciasPendentesPorCaso(String casoUuid) async {
    final List<Achado> pending = [];
    final db = await database;

    // 1. Fotos gerais do caso (SQL na tabela evidencias_multimidia)
    try {
      final List<Map<String, dynamic>> generalEvidences = await db.query(
        tableEvidenciasMultimidia,
        where: 'caso_uuid = ? AND tipo = ? AND foto_sincronizada = 0 AND removido = 0',
        whereArgs: [casoUuid, 'GERAL'],
      );

      for (var i = 0; i < generalEvidences.length; i++) {
        final row = generalEvidences[i];
        final String pathString = row['caminho_arquivo_encriptado']?.toString() ?? '';
        if (pathString.isEmpty) continue;

        final achadoVirtual = Achado(
          uuid: row['uuid'].toString(),
          casoUuid: casoUuid,
          diagramaCasoUuid: '',
          diagramaNome: 'GERAL',
          tipoAchadoId: 'FOTO_GERAL',
          numeroSequencial: i,
          posX: 0.0,
          posY: 0.0,
          isInterno: false,
          versao: 1,
          removido: false,
          criadoEm: DateTime.tryParse(row['criado_em']?.toString() ?? '') ?? DateTime.now(),
          dadosPreenchidos: {
            'photo_path': pathString,
            '_evidencia_uuid': row['uuid'].toString(),
          },
          tamanho: '',
          vistaAnatomica: '',
          localAnatomico: '',
        );
        pending.add(achadoVirtual);
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getEvidenciasPendentesPorCaso (GERAL): $e');
    }

    // 2. Fotos vinculadas a lesões/achados (SQL)
    try {
      const sqlAchados = '''
        SELECT
          a.*,
          e.caminho_arquivo_encriptado AS _photo_path_override,
          e.uuid                        AS _evidencia_uuid
        FROM $tableAchados a
        INNER JOIN $tableEvidenciasMultimidia e
               ON  e.achado_uuid                = a.uuid
               AND e.removido                   = 0
               AND e.caminho_arquivo_encriptado IS NOT NULL
               AND e.caminho_arquivo_encriptado != ''
               AND e.foto_sincronizada          = 0
        WHERE a.caso_uuid = ?
          AND a.removido  = 0
          AND a.diagrama_nome IS NOT NULL
          AND a.diagrama_nome != ''
        ORDER BY a.criado_em ASC
      ''';

      final rowsAchados = await db.rawQuery(sqlAchados, [casoUuid]);

      for (final row in rowsAchados) {
        final mutableRow = Map<String, dynamic>.from(row);
        final dadosJson = mutableRow['dados_preenchidos_json'] as String? ?? '{}';
        final dados = _decodeJson(dadosJson);

        dados['photo_path'] = row['_photo_path_override'] as String?;
        dados['_evidencia_uuid'] = row['_evidencia_uuid'] as String?;

        mutableRow['dados_preenchidos_json'] = _encodeJson(dados);
        mutableRow.remove('_photo_path_override');
        mutableRow.remove('_evidencia_uuid');

        pending.add(Achado.fromMap(mutableRow));
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getEvidenciasPendentesPorCaso (SQL): $e');
    }

    return pending;
  }

  @override
  Future<void> marcarCasoComoSincronizado(Caso caso) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 1,
             sync_error      = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), caso.uuid],
    );
  }

  @override
  Future<void> marcarRascunhoComoSincronizado(String casoUuid) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 1,
             sync_error      = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  @override
  Future<void> marcarCasoComErroDeSincronizacao(String casoUuid) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET sync_error      = 1,
             is_draft_synced = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  @override
  Future<void> marcarFotoComoSincronizada(Achado achado) async {
    final db = await database;
    final evidenciaUuid = achado.dadosPreenchidos['_evidencia_uuid'];
    if (evidenciaUuid != null) {
      await db.update(
        tableEvidenciasMultimidia,
        {'foto_sincronizada': 1},
        where: 'uuid = ?',
        whereArgs: [evidenciaUuid],
      );
    }
  }

  // Novos Métodos para Evidências Gerais e Exames Solicitados

  Future<EvidenciaMultimidia?> getEvidenciaByUuid(String uuid) async {
    final db = await database;
    final maps = await db.query(
      tableEvidenciasMultimidia,
      where: 'uuid = ? AND removido = 0',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EvidenciaMultimidia.fromMap(maps.first);
  }

  Future<List<EvidenciaMultimidia>> getEvidenciasGerais(String casoUuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEvidenciasMultimidia,
      where: 'caso_uuid = ? AND tipo = ? AND removido = 0',
      whereArgs: [casoUuid, 'GERAL'],
    );
    return maps.map((m) => EvidenciaMultimidia.fromMap(m)).toList();
  }

  Future<void> insertEvidenciaGeral(EvidenciaMultimidia evidencia) async {
    final db = await database;
    await db.insert(
      tableEvidenciasMultimidia,
      evidencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _marcarCasoPendenteSync(db, evidencia.casoUuid);
  }

  Future<void> deleteEvidenciaGeral(String uuid) async {
    final db = await database;
    final ev = await getEvidenciaByUuid(uuid);
    await db.update(
      tableEvidenciasMultimidia,
      {'removido': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (ev != null) {
      await _marcarCasoPendenteSync(db, ev.casoUuid);
    }
  }

  Future<void> _marcarCasoPendenteSync(DatabaseExecutor db, String casoUuid) async {
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  Future<List<ExameSolicitado>> getExamesSolicitados(String casoUuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exames_solicitados',
      where: 'caso_uuid = ?',
      whereArgs: [casoUuid],
    );
    return maps.map((m) => ExameSolicitado.fromMap(m)).toList();
  }

  Future<void> salvarExamesSolicitados({
    required String casoUuid,
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) async {
    final db = await database;
    final map = {
      'ANATOMO': anatomoLacre,
      'TOXICOLOGICO': toxicologicoLacre,
      'GENETICA': geneticaLacre,
      'OUTROS': outrosLacre,
    };

    await db.transaction((txn) async {
      for (final entry in map.entries) {
        final tipo = entry.key;
        final lacre = entry.value;

        if (lacre == null || lacre.trim().isEmpty) {
          await txn.delete(
            'exames_solicitados',
            where: 'caso_uuid = ? AND tipo_exame = ?',
            whereArgs: [casoUuid, tipo],
          );
        } else {
          final existing = await txn.query(
            'exames_solicitados',
            where: 'caso_uuid = ? AND tipo_exame = ?',
            whereArgs: [casoUuid, tipo],
          );

          if (existing.isEmpty) {
            final novo = ExameSolicitado.novo(
              casoUuid: casoUuid,
              tipoExame: tipo,
              numeroLacre: lacre,
            );
            await txn.insert('exames_solicitados', novo.toMap());
          } else {
            await txn.update(
              'exames_solicitados',
              {
                'numero_lacre': lacre,
              },
              where: 'caso_uuid = ? AND tipo_exame = ?',
              whereArgs: [casoUuid, tipo],
            );
          }
        }
      }
    });
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
    } catch (_) {
      return {};
    }
  }

  String _encodeJson(Map<String, dynamic> map) => jsonEncode(map);

  /// Persiste a lista de exames solicitados e suas filhas polimórficas de forma atômica e performática.
  Future<void> salvarExames(String casoUuid, List<ExameSolicitadoModel> exames) async {
    // Guard de imutabilidade: bloqueia escrita se o laudo já estiver finalizado
    final casoAtual = await getCaseByUuid(casoUuid);
    if (casoAtual != null && casoAtual.status == StatusCaso.finalizado) {
      throw Exception("Segurança Jurídica: Este laudo já está finalizado e é imutável.");
    }

    final db = await database;
    try {
      await db.transaction((txn) async {
        final batch = txn.batch();

        // 1. Deleta exames anteriores (ON DELETE CASCADE limpa as filhas automaticamente)
        batch.delete(
          'exames_solicitados',
          where: 'caso_uuid = ?',
          whereArgs: [casoUuid],
        );

        // 2. Insere a tabela mestra e as dependências relacionais nas filhas
        for (final exame in exames) {
          batch.insert('exames_solicitados', exame.toMap());

          final detalhes = exame.detalhes;
          if (detalhes == null) continue;

          final tipo = exame.tipoExame.toUpperCase().trim();

          if (tipo == 'TOXICOLOGICO') {
            if (detalhes is DetalhesToxicologicoModel) {
              final itemFinal = detalhes.copyWith(exameUuid: exame.uuid);
              batch.insert('detalhes_toxicologico', itemFinal.toMap());
            } else if (detalhes is Map<String, dynamic>) {
              final map = Map<String, dynamic>.from(detalhes);
              map['exame_uuid'] = exame.uuid;
              batch.insert('detalhes_toxicologico', map);
            }
          } else if (tipo == 'GENETICA') {
            if (detalhes is List) {
              for (final item in detalhes) {
                if (item is AmostraGeneticaModel) {
                  final itemFinal = item.copyWith(exameUuid: exame.uuid);
                  batch.insert('amostras_genetica', itemFinal.toMap());
                } else if (item is Map<String, dynamic>) {
                  final map = Map<String, dynamic>.from(item);
                  map['exame_uuid'] = exame.uuid;
                  batch.insert('amostras_genetica', map);
                }
              }
            } else if (detalhes is AmostraGeneticaModel) {
              final itemFinal = detalhes.copyWith(exameUuid: exame.uuid);
              batch.insert('amostras_genetica', itemFinal.toMap());
            }
          } else if (tipo == 'ANATOMO') {
            if (detalhes is List) {
              for (final item in detalhes) {
                if (item is FrascoAnatomoModel) {
                  final itemFinal = item.copyWith(exameUuid: exame.uuid);
                  batch.insert('frascos_anatomo', itemFinal.toMap());
                } else if (item is Map<String, dynamic>) {
                  final map = Map<String, dynamic>.from(item);
                  map['exame_uuid'] = exame.uuid;
                  batch.insert('frascos_anatomo', map);
                }
              }
            } else if (detalhes is FrascoAnatomoModel) {
              final itemFinal = detalhes.copyWith(exameUuid: exame.uuid);
              batch.insert('frascos_anatomo', itemFinal.toMap());
            }
          }
        }

        await _marcarCasoPendenteSync(txn, casoUuid);
        await batch.commit(noResult: true);
      });
      debugPrint('[CasoRepository] ✅ ${exames.length} exames salvos com sucesso para o caso $casoUuid');
    } catch (e) {
      debugPrint('[CasoRepository] ❌ Erro ao salvar exames para o caso $casoUuid: $e');
      rethrow;
    }
  }

  /// Recupera todos os exames solicitados e suas tabelas filhas polimórficas para um caso específico.
  Future<List<ExameSolicitadoModel>> getExamesPorCaso(String casoUuid) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> examesMaps = await db.query(
        'exames_solicitados',
        where: 'caso_uuid = ?',
        whereArgs: [casoUuid],
        orderBy: 'criado_em ASC',
      );

      if (examesMaps.isEmpty) return [];

      final exameUuids = examesMaps
          .map((map) => map['uuid']?.toString())
          .whereType<String>()
          .where((uuid) => uuid.isNotEmpty)
          .toSet()
          .toList();
      final detalhesQueries = <String>[];
      final detalhesArgs = <Object>[];

      final tiposPorUuid = <String, String>{
        for (final map in examesMaps)
          map['uuid']!.toString():
              (map['tipo_exame']?.toString() ?? '').toUpperCase().trim(),
      };
      final toxicUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'TOXICOLOGICO')
          .toList();
      final geneticaUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'GENETICA')
          .toList();
      final anatomoUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'ANATOMO')
          .toList();

      String placeholdersFor(List<String> uuids) =>
          List.filled(uuids.length, '?').join(', ');

      if (toxicUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'TOXICOLOGICO' AS detalhe_tipo,
            uuid, exame_uuid,
            historico_ocorrencia, historico_outro,
            material_sg_femoral, material_sg_cardiaca, material_sg_outro,
            numero_lacre_sg, material_urina, numero_lacre_ur,
            material_humor_vitreo, numero_lacre_hv,
            material_estomago, numero_lacre_ce,
            material_pulmao, numero_lacre_pm, quantificacao_drogas,
            NULL AS tipo_amostra, NULL AS descricao_outro,
            NULL AS pesquisa_semen, NULL AS pesquisa_dna,
            NULL AS quantidade_swabs, NULL AS numero_lacre,
            NULL AS numero_frasco, NULL AS coracao, NULL AS figado,
            NULL AS baco, NULL AS encefalo,
            NULL AS pulmao_d_lsd, NULL AS pulmao_d_lmd, NULL AS pulmao_d_lid,
            NULL AS pulmao_e_lse, NULL AS pulmao_e_lie,
            NULL AS rim_d, NULL AS rim_e,
            NULL AS pele_regiao, NULL AS partes_moles_regiao,
            NULL AS outras_regiao
          FROM detalhes_toxicologico
          WHERE exame_uuid IN (${placeholdersFor(toxicUuids)})
        ''');
        detalhesArgs.addAll(toxicUuids);
      }

      if (geneticaUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'GENETICA' AS detalhe_tipo,
            uuid, exame_uuid,
            NULL AS historico_ocorrencia, NULL AS historico_outro,
            NULL AS material_sg_femoral, NULL AS material_sg_cardiaca,
            NULL AS material_sg_outro, NULL AS numero_lacre_sg,
            NULL AS material_urina, NULL AS numero_lacre_ur,
            NULL AS material_humor_vitreo, NULL AS numero_lacre_hv,
            NULL AS material_estomago, NULL AS numero_lacre_ce,
            NULL AS material_pulmao, NULL AS numero_lacre_pm,
            NULL AS quantificacao_drogas,
            tipo_amostra, descricao_outro, pesquisa_semen, pesquisa_dna,
            quantidade_swabs, numero_lacre,
            NULL AS numero_frasco, NULL AS coracao, NULL AS figado,
            NULL AS baco, NULL AS encefalo,
            NULL AS pulmao_d_lsd, NULL AS pulmao_d_lmd, NULL AS pulmao_d_lid,
            NULL AS pulmao_e_lse, NULL AS pulmao_e_lie,
            NULL AS rim_d, NULL AS rim_e,
            NULL AS pele_regiao, NULL AS partes_moles_regiao,
            NULL AS outras_regiao
          FROM amostras_genetica
          WHERE exame_uuid IN (${placeholdersFor(geneticaUuids)})
        ''');
        detalhesArgs.addAll(geneticaUuids);
      }

      if (anatomoUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'ANATOMO' AS detalhe_tipo,
            uuid, exame_uuid,
            NULL AS historico_ocorrencia, NULL AS historico_outro,
            NULL AS material_sg_femoral, NULL AS material_sg_cardiaca,
            NULL AS material_sg_outro, NULL AS numero_lacre_sg,
            NULL AS material_urina, NULL AS numero_lacre_ur,
            NULL AS material_humor_vitreo, NULL AS numero_lacre_hv,
            NULL AS material_estomago, NULL AS numero_lacre_ce,
            NULL AS material_pulmao, NULL AS numero_lacre_pm,
            NULL AS quantificacao_drogas,
            NULL AS tipo_amostra, NULL AS descricao_outro,
            NULL AS pesquisa_semen, NULL AS pesquisa_dna,
            NULL AS quantidade_swabs, numero_lacre,
            numero_frasco, coracao, figado, baco, encefalo,
            pulmao_d_lsd, pulmao_d_lmd, pulmao_d_lid,
            pulmao_e_lse, pulmao_e_lie, rim_d, rim_e,
            pele_regiao, partes_moles_regiao, outras_regiao
          FROM frascos_anatomo
          WHERE exame_uuid IN (${placeholdersFor(anatomoUuids)})
        ''');
        detalhesArgs.addAll(anatomoUuids);
      }

      final detalhesRows = detalhesQueries.isEmpty
          ? <Map<String, dynamic>>[]
          : await db.rawQuery(
              detalhesQueries.join(' UNION ALL '),
              detalhesArgs,
            );

      final toxicByExame = <String, Map<String, dynamic>>{};
      final geneticaByExame = <String, List<Map<String, dynamic>>>{};
      final anatomoByExame = <String, List<Map<String, dynamic>>>{};

      for (final row in detalhesRows) {
        final exameUuid = row['exame_uuid']?.toString() ?? '';
        switch (row['detalhe_tipo']) {
          case 'TOXICOLOGICO':
            toxicByExame.putIfAbsent(exameUuid, () => row);
            break;
          case 'GENETICA':
            geneticaByExame.putIfAbsent(exameUuid, () => []).add(row);
            break;
          case 'ANATOMO':
            anatomoByExame.putIfAbsent(exameUuid, () => []).add(row);
            break;
        }
      }

      return examesMaps.map((mapMestre) {
        final exameUuid = mapMestre['uuid']?.toString() ?? '';
        final tipo = tiposPorUuid[exameUuid] ?? '';
        dynamic detalhesObj;

        if (tipo == 'TOXICOLOGICO') {
          final detalhe = toxicByExame[exameUuid];
          if (detalhe != null) {
            detalhesObj = DetalhesToxicologicoModel.fromMap(detalhe);
          }
        } else if (tipo == 'GENETICA') {
          detalhesObj = (geneticaByExame[exameUuid] ?? [])
              .map(AmostraGeneticaModel.fromMap)
              .toList();
        } else if (tipo == 'ANATOMO') {
          final detalhes = anatomoByExame[exameUuid] ?? [];
          detalhes.sort((a, b) =>
              ((a['numero_frasco'] as num?) ?? 0)
                  .compareTo((b['numero_frasco'] as num?) ?? 0));
          detalhesObj = detalhes.map(FrascoAnatomoModel.fromMap).toList();
        }

        return ExameSolicitadoModel.fromMap(
          mapMestre,
          detalhes: detalhesObj,
        );
      }).toList();
    } catch (e) {
      debugPrint('[CasoRepository] ❌ Erro ao obter exames para o caso $casoUuid: $e');
      return [];
    }
  }
}

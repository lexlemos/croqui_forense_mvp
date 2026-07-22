import 'dart:convert';

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
      final rowsAffected = await db.update(
        tableCasos,
        novoCaso.toMap(),
        where: 'uuid = ?',
        whereArgs: [novoCaso.uuid],
      );
      if (rowsAffected == 0) {
        await db.insert(
          tableCasos,
          novoCaso.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    } catch (e) {
      throw Exception('Erro de persistência ao inserir caso: $e');
    }
  }

  Future<void> insertCaseComEvidenciasLote(Caso novoCaso, List<EvidenciaMultimidia> evidencias) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final rows = await txn.update(
          tableCasos,
          novoCaso.toMap(),
          where: 'uuid = ?',
          whereArgs: [novoCaso.uuid],
        );
        if (rows == 0) {
          await txn.insert(
            tableCasos,
            novoCaso.toMap(),
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

  Future<void> updateCase(Caso caso) async {
    final db = await database;
    try {
      await db.update(
        tableCasos,
        caso.toMap(),
        where: 'uuid = ?',
        whereArgs: [caso.uuid],
      );
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar caso: $e');
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

  Future<List<Caso>> getAllCases() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCasos,
      where: 'removido = 0',
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
  Future<List<Caso>> getCasosNaoSincronizados() async {
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where: "status = 'FINALIZADO' AND removido = 0",
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
        grouped[caseUuid]!.add(achadoVirtual);
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

        if (!grouped.containsKey(casoUuid)) {
          grouped[casoUuid] = [];
        }

        grouped[casoUuid]!.add(Achado.fromMap(mutableRow));
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
         SET status        = 'SINCRONIZADO',
             atualizado_em = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), caso.uuid],
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
  }

  Future<void> deleteEvidenciaGeral(String uuid) async {
    final db = await database;
    await db.update(
      tableEvidenciasMultimidia,
      {'removido': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
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

      final List<ExameSolicitadoModel> resultado = [];

      for (final mapMestre in examesMaps) {
        final String exameUuid = mapMestre['uuid']?.toString() ?? '';
        final String tipo = (mapMestre['tipo_exame']?.toString() ?? '').toUpperCase().trim();

        dynamic detalhesObj;

        if (tipo == 'TOXICOLOGICO') {
          final toxicMaps = await db.query(
            'detalhes_toxicologico',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
            limit: 1,
          );
          if (toxicMaps.isNotEmpty) {
            detalhesObj = DetalhesToxicologicoModel.fromMap(toxicMaps.first);
          }
        } else if (tipo == 'GENETICA') {
          final genMaps = await db.query(
            'amostras_genetica',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
          );
          detalhesObj = genMaps.map((m) => AmostraGeneticaModel.fromMap(m)).toList();
        } else if (tipo == 'ANATOMO') {
          final anatomoMaps = await db.query(
            'frascos_anatomo',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
            orderBy: 'numero_frasco ASC',
          );
          detalhesObj = anatomoMaps.map((m) => FrascoAnatomoModel.fromMap(m)).toList();
        }

        resultado.add(ExameSolicitadoModel.fromMap(mapMestre, detalhes: detalhesObj));
      }

      return resultado;
    } catch (e) {
      debugPrint('[CasoRepository] ❌ Erro ao obter exames para o caso $casoUuid: $e');
      return [];
    }
  }
}
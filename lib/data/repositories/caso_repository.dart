import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class CasoRepository implements ISyncRepository {

  final DatabaseHelper _dbHelper;

  CasoRepository(this._dbHelper);

  Future<Database> get database async => _dbHelper.database;

  Future<void> insertCase(Caso novoCaso) async {
    final db = await database;
    try {
      await db.insert(
        tableCasos,
        novoCaso.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('Erro de persistência ao inserir caso: $e');
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
    final db = await database;

    for (final uuid in casoUuids) {
      grouped[uuid] = [];

      // 1. Fotos gerais extraídas do JSON do caso
      try {
        final List<Map<String, dynamic>> casoRows = await db.query(
          tableCasos,
          where: 'uuid = ? AND removido = 0',
          whereArgs: [uuid],
        );

        if (casoRows.isNotEmpty) {
          final casoMap = casoRows.first;
          final dadosLaudoRaw = casoMap['dados_laudo_json'] as String? ?? '{}';
          final Map<String, dynamic> dadosLaudo = _decodeJson(dadosLaudoRaw);
          final identificacao = dadosLaudo['identificacao'] as Map?;
          final fotosGerais = identificacao?['fotos_gerais'] as List?;

          if (fotosGerais != null && fotosGerais.isNotEmpty) {
            for (var i = 0; i < fotosGerais.length; i++) {
              final String pathString = fotosGerais[i].toString();
              if (pathString.isEmpty || pathString == 'null') continue;

              final achadoVirtual = Achado(
                uuid: uuid,
                casoUuid: uuid,
                templateDiagramaId: 'GERAL',
                tipoAchadoId: 'FOTO_GERAL',
                numeroSequencial: i,
                posX: 0.0,
                posY: 0.0,
                isInterno: false,
                estaPendente: true,
                versao: 1,
                removido: false,
                criadoEm: DateTime.now(),
                dadosPreenchidos: {
                  'photo_path': pathString,
                  '_evidencia_uuid': 'GERAL_${uuid}_$i',
                },
              );
              grouped[uuid]!.add(achadoVirtual);
            }
          }
        }
      } catch (e) {
        debugPrint('[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (JSON): $e');
      }

      // 2. Fotos de achados (lesões) na tabela evidencias_multimidia
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
                 AND e.foto_sincronizada           = 0
          WHERE a.caso_uuid = ?
            AND a.removido  = 0
          ORDER BY a.criado_em ASC
        ''';

        final rowsAchados = await db.rawQuery(sqlAchados, [uuid]);

        for (final row in rowsAchados) {
          final mutableRow = Map<String, dynamic>.from(row);
          final dadosJson = mutableRow['dados_preenchidos_json'] as String? ?? '{}';
          final dados = _decodeJson(dadosJson);

          dados['photo_path'] = row['_photo_path_override'] as String?;
          dados['_evidencia_uuid'] = row['_evidencia_uuid'] as String?;

          mutableRow['dados_preenchidos_json'] = _encodeJson(dados);
          mutableRow.remove('_photo_path_override');
          mutableRow.remove('_evidencia_uuid');

          grouped[uuid]!.add(Achado.fromMap(mutableRow));
        }
      } catch (e) {
        debugPrint('[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (SQL): $e');
      }
    }

    return grouped;
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
    final String? evidenciaUuid =
        achado.dadosPreenchidos['_evidencia_uuid'] as String?;

    if (evidenciaUuid == null || evidenciaUuid.isEmpty) return;

    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableEvidenciasMultimidia
         SET foto_sincronizada = 1,
             atualizado_em     = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), evidenciaUuid],
    );
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
    } catch (_) {
      return {};
    }
  }

  String _encodeJson(Map<String, dynamic> map) => jsonEncode(map);
}
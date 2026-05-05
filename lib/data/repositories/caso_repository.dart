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

  // ---------------------------------------------------------------------------
  // CRUD Básico
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // ISyncRepository — Os 4 Métodos de Sincronização
  // ---------------------------------------------------------------------------

  /// Retorna todos os [Caso]s com `status = 'FINALIZADO'` prontos para sync.
  ///
  /// Rascunhos são ignorados. O índice `idx_casos_status` garante performance.
  @override
  Future<List<Caso>> getCasosNaoSincronizados() async {
    final db = await database;
    try {
      final maps = await db.query(
        tableCasos,
        where: "status = 'FINALIZADO' AND removido = 0",
        orderBy: 'criado_em_dispositivo ASC',
      );
      debugPrint(
        '[CasoRepository] getCasosNaoSincronizados: '
        '${maps.length} caso(s) encontrado(s).',
      );
      return maps.map(Caso.fromMap).toList();
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getCasosNaoSincronizados: $e');
      rethrow;
    }
  }

  /// Retorna os [Achado]s do [casoUuid] que possuem evidências fotográficas
  /// ainda não enviadas ao servidor (`foto_sincronizada = 0`).
  ///
  /// Cada [Achado] retornado terá dois campos extras em `dadosPreenchidos`:
  /// - `photo_path`       → caminho do arquivo cifrado no disco.
  /// - `_evidencia_uuid`  → uuid da linha em `evidencias_multimidia`, usado
  ///                        por [marcarFotoComoSincronizada] para o UPDATE.
  @override
  Future<List<Achado>> getAchadosComFotosPendentes(String casoUuid) async {
    final db = await database;
    try {
      const sql = '''
        SELECT
          a.*,
          e.caminho_arquivo_encriptado  AS _photo_path_override,
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

      final rows = await db.rawQuery(sql, [casoUuid]);
      debugPrint(
        '[CasoRepository] getAchadosComFotosPendentes: '
        '${rows.length} foto(s) pendente(s) para caso $casoUuid.',
      );

      return rows.map((row) {
        final mutableRow = Map<String, dynamic>.from(row);

        final dadosJson = mutableRow['dados_preenchidos_json'] as String? ?? '{}';
        final dados = _decodeJson(dadosJson);
        dados['photo_path']      = row['_photo_path_override'] as String?;
        dados['_evidencia_uuid'] = row['_evidencia_uuid']      as String?;
        mutableRow['dados_preenchidos_json'] = _encodeJson(dados);

        mutableRow.remove('_photo_path_override');
        mutableRow.remove('_evidencia_uuid');

        return Achado.fromMap(mutableRow);
      }).toList();
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getAchadosComFotosPendentes: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(List<String> casoUuids) async {
    if (casoUuids.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(casoUuids.length, '?').join(',');
    final sql = '''
      SELECT
        a.*,
        e.caminho_arquivo_encriptado  AS _photo_path_override,
        e.uuid                        AS _evidencia_uuid
      FROM $tableAchados a
      INNER JOIN $tableEvidenciasMultimidia e
             ON  e.achado_uuid                = a.uuid
             AND e.removido                   = 0
             AND e.caminho_arquivo_encriptado IS NOT NULL
             AND e.caminho_arquivo_encriptado != ''
             AND e.foto_sincronizada           = 0
      WHERE a.caso_uuid IN ($placeholders)
        AND a.removido  = 0
      ORDER BY a.criado_em ASC
    ''';
    final rows = await db.rawQuery(sql, casoUuids);

    final Map<String, List<Achado>> grouped = {};
    for (final row in rows) {
      final mutableRow = Map<String, dynamic>.from(row);
      final dadosJson = mutableRow['dados_preenchidos_json'] as String? ?? '{}';
      final dados = _decodeJson(dadosJson);
      dados['photo_path'] = row['_photo_path_override'] as String?;
      dados['_evidencia_uuid'] = row['_evidencia_uuid'] as String?;
      mutableRow['dados_preenchidos_json'] = _encodeJson(dados);
      mutableRow.remove('_photo_path_override');
      mutableRow.remove('_evidencia_uuid');
      final achado = Achado.fromMap(mutableRow);
      (grouped[achado.casoUuid] ??= []).add(achado);
    }
    return grouped;
  }

  /// Atualiza somente `status` e `atualizado_em` do [caso] para 'SINCRONIZADO'.
  ///
  /// UPDATE cirúrgico — não reescreve o laudo inteiro, evitando race conditions.
  @override
  Future<void> marcarCasoComoSincronizado(Caso caso) async {
    final db = await database;
    try {
      final rowsAffected = await db.rawUpdate(
        '''
        UPDATE $tableCasos
           SET status        = 'SINCRONIZADO',
               atualizado_em = ?
         WHERE uuid     = ?
           AND removido = 0
        ''',
        [DateTime.now().toIso8601String(), caso.uuid],
      );
      if (rowsAffected == 0) {
        debugPrint(
          '[CasoRepository] ⚠️ marcarCasoComoSincronizado: caso ${caso.uuid} '
          'não encontrado ou já removido.',
        );
      } else {
        debugPrint('[CasoRepository] ✅ Caso ${caso.uuid} → SINCRONIZADO.');
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ marcarCasoComoSincronizado: $e');
      rethrow;
    }
  }

  /// Seta `foto_sincronizada = 1` na linha de `evidencias_multimidia`
  /// correspondente ao [achado].
  ///
  /// O UUID da evidência é lido de `achado.dadosPreenchidos['_evidencia_uuid']`,
  /// campo injetado pelo [getAchadosComFotosPendentes].
  @override
  Future<void> marcarFotoComoSincronizada(Achado achado) async {
    final db = await database;

    final String? evidenciaUuid =
        achado.dadosPreenchidos['_evidencia_uuid'] as String?;

    if (evidenciaUuid == null || evidenciaUuid.isEmpty) {
      debugPrint(
        '[CasoRepository] ⚠️ marcarFotoComoSincronizada: achado ${achado.uuid} '
        'sem _evidencia_uuid — foto não marcada.',
      );
      return;
    }

    try {
      final rowsAffected = await db.rawUpdate(
        '''
        UPDATE $tableEvidenciasMultimidia
           SET foto_sincronizada = 1,
               atualizado_em     = ?
         WHERE uuid     = ?
           AND removido = 0
        ''',
        [DateTime.now().toIso8601String(), evidenciaUuid],
      );
      if (rowsAffected == 0) {
        debugPrint(
          '[CasoRepository] ⚠️ marcarFotoComoSincronizada: evidência '
          '$evidenciaUuid não encontrada ou já removida.',
        );
      } else {
        debugPrint(
          '[CasoRepository] ✅ Evidência $evidenciaUuid → foto_sincronizada = 1.',
        );
      }
    } catch (e) {
      debugPrint('[CasoRepository] ❌ marcarFotoComoSincronizada: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
    } catch (_) {
      return {};
    }
  }

  String _encodeJson(Map<String, dynamic> map) => jsonEncode(map);
}
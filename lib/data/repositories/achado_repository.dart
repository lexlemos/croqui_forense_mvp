import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';
import 'package:path/path.dart' as p;

class AchadoRepository {
  final DatabaseHelper _dbHelper;

  AchadoRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.database;

  Future<void> insertAchado(Achado achado) async {
    final db = await _db;
    try {
      await db.transaction((txn) async {
        final rowsAffected = await txn.update(
          'achados',
          achado.toMap(),
          where: 'uuid = ?',
          whereArgs: [achado.uuid],
        );
        if (rowsAffected == 0) {
          await txn.insert(
            'achados',
            achado.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await _garantirEvidencia(txn, achado);
        await _marcarCasoPendenteSync(txn, achado.casoUuid);
      });
    } catch (e) {
      throw Exception('Erro de persistência ao inserir achado: $e');
    }
  }

  Future<bool> isCasoFinalizado(String casoUuid) async {
    final db = await _db;
    final res = await db.query(
      'casos',
      columns: ['status'],
      where: 'uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      limit: 1,
    );
    if (res.isEmpty) return false;
    final statusStr = res.first['status']?.toString().toUpperCase() ?? '';
    return statusStr == 'FINALIZADO';
  }

  Future<Achado?> getAchadoByUuid(String uuid) async {
    final db = await _db;
    final res = await db.query(
      'achados',
      where: 'uuid = ? AND removido = 0',
      whereArgs: [uuid],
      limit: 1,
    );
    if (res.isEmpty) return null;
    var achado = Achado.fromMap(res.first);

    final hasBalistica =
        (achado.tipoFerimento != null && achado.tipoFerimento!.isNotEmpty) ||
        (achado.tipoObjeto != null && achado.tipoObjeto!.isNotEmpty) ||
        (achado.numeroLacre != null && achado.numeroLacre!.isNotEmpty) ||
        (achado.comentarioAdicional != null &&
            achado.comentarioAdicional!.isNotEmpty);

    if (!hasBalistica) {
      final detId =
          deterministicUuidV5(achado.uuid, 'balistica').toLowerCase();
      final legacyDetId =
          deterministicUuidV4(achado.uuid, 'balistica').toLowerCase();
      final achadoUuidLower = achado.uuid.trim().toLowerCase();

      final balisticasRows = await db.rawQuery(
        '''
        SELECT * FROM balisticas 
        WHERE LOWER(TRIM(id)) = ? 
           OR LOWER(TRIM(id)) = ? 
           OR LOWER(TRIM(id)) = ? 
           OR LOWER(TRIM(exame_id)) = ?
        LIMIT 1
        ''',
        [detId, legacyDetId, achadoUuidLower, achadoUuidLower],
      );

      if (balisticasRows.isNotEmpty) {
        final bRow = balisticasRows.first;
        achado = achado.copyWith(
          tipoFerimento:
              bRow['tipo_ferimento']?.toString() ?? achado.tipoFerimento,
          tipoObjeto:
              bRow['tipo_objeto']?.toString() ?? achado.tipoObjeto,
          numeroLacre:
              bRow['numero_lacre']?.toString() ?? achado.numeroLacre,
          comentarioAdicional:
              bRow['comentario_adicional']?.toString() ??
              achado.comentarioAdicional,
        );
      }
    }

    return achado;
  }

  Future<void> updateAchado(Achado achado) async {
    if (await isCasoFinalizado(achado.casoUuid)) {
      throw Exception('Segurança Jurídica: Impossível atualizar achado de laudo finalizado.');
    }
    final db = await _db;
    try {
      await db.transaction((txn) async {
        final rowsAffected = await txn.update(
          'achados',
          achado.toMap(),
          where: "uuid = ? AND caso_uuid IN (SELECT uuid FROM casos WHERE UPPER(status) != 'FINALIZADO')",
          whereArgs: [achado.uuid],
        );
        debugPrint('[AchadoRepository] updateAchado ${achado.uuid}: $rowsAffected row(s) affected');
        if (rowsAffected == 0) {
          throw Exception('Achado ${achado.uuid} não encontrado no banco ou laudo finalizado.');
        }
        await _garantirEvidencia(txn, achado);
        await _marcarCasoPendenteSync(txn, achado.casoUuid);
      });
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar achado: $e');
    }
  }

  Future<void> _garantirEvidencia(DatabaseExecutor db, Achado achado) async {
    final photo = achado.photoPath;
    if (photo == null || photo.isEmpty) {
      await db.update(
        'evidencias_multimidia',
        {'removido': 1},
        where: 'achado_uuid = ?',
        whereArgs: [achado.uuid],
      );
      await _marcarCasoPendenteSync(db, achado.casoUuid);
      return;
    }

    final List<Map<String, dynamic>> rows = await db.query(
      'evidencias_multimidia',
      where: 'achado_uuid = ?',
      whereArgs: [achado.uuid],
    );

    if (rows.isEmpty) {
      final derivedUuid = p.basenameWithoutExtension(photo);
      await db.insert('evidencias_multimidia', {
        'uuid': derivedUuid,
        'caso_uuid': achado.casoUuid,
        'achado_uuid': achado.uuid,
        'tipo': 'ACHADO',
        'caminho_arquivo_encriptado': photo,
        'foto_sincronizada': 0,
        'removido': 0,
        'versao': 1,
        'criado_em': DateTime.now().toUtc().toIso8601String(),
      });
      await _marcarCasoPendenteSync(db, achado.casoUuid);
    } else {
      final existing = rows.first;
      final existingPath = existing['caminho_arquivo_encriptado']?.toString();
      final wasRemoved = existing['removido'] == 1;

      if (existingPath != photo || wasRemoved) {
        await db.update(
          'evidencias_multimidia',
          {
            'caminho_arquivo_encriptado': photo,
            'removido': 0,
            'foto_sincronizada': existingPath == photo ? existing['foto_sincronizada'] : 0,
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'achado_uuid = ?',
          whereArgs: [achado.uuid],
        );
        await _marcarCasoPendenteSync(db, achado.casoUuid);
      }
    }
  }

  Future<void> deleteAchado(String uuid) async {
    final achado = await getAchadoByUuid(uuid);
    if (achado != null && await isCasoFinalizado(achado.casoUuid)) {
      throw Exception('Segurança Jurídica: Impossível remover achado de laudo finalizado.');
    }
    final db = await _db;
    try {
      await db.rawUpdate(
        "UPDATE achados SET removido = 1 WHERE uuid = ? AND caso_uuid IN (SELECT uuid FROM casos WHERE UPPER(status) != 'FINALIZADO')",
        [uuid],
      );
      if (achado != null) {
        await _marcarCasoPendenteSync(db, achado.casoUuid);
      }
    } catch (e) {
      throw Exception('Erro de persistência ao remover achado: $e');
    }
  }

  Future<void> _marcarCasoPendenteSync(DatabaseExecutor db, String casoUuid) async {
    await db.rawUpdate(
      '''
      UPDATE casos
         SET is_draft_synced = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toUtc().toIso8601String(), casoUuid],
    );
  }

  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await _db;
    final result = await db.query(
      'achados',
      where: 'caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      orderBy: 'criado_em DESC',
    );
    final achados = result.map((m) => Achado.fromMap(m)).toList();

    final balisticasRows = await db.rawQuery(
      '''
      SELECT * FROM balisticas 
      WHERE exame_id = ? 
         OR exame_id IN (SELECT uuid FROM achados WHERE caso_uuid = ?)
      ''',
      [casoUuid, casoUuid],
    );

    if (balisticasRows.isEmpty) {
      return achados;
    }

    final Map<String, Map<String, dynamic>> balisticaById = {
      for (final r in balisticasRows)
        if (r['id'] != null) r['id'].toString().trim().toLowerCase(): r,
    };

    return achados.map((achado) {
      final hasBalistica =
          (achado.tipoFerimento != null && achado.tipoFerimento!.isNotEmpty) ||
          (achado.tipoObjeto != null && achado.tipoObjeto!.isNotEmpty) ||
          (achado.numeroLacre != null && achado.numeroLacre!.isNotEmpty) ||
          (achado.comentarioAdicional != null &&
              achado.comentarioAdicional!.isNotEmpty);

      if (hasBalistica) return achado;

      final detId =
          deterministicUuidV5(achado.uuid, 'balistica').toLowerCase();
      final legacyDetId =
          deterministicUuidV4(achado.uuid, 'balistica').toLowerCase();
      final achadoUuidLower = achado.uuid.trim().toLowerCase();
      final bRow = (detId.isNotEmpty ? balisticaById[detId] : null) ??
          (legacyDetId.isNotEmpty ? balisticaById[legacyDetId] : null) ??
          balisticaById[achadoUuidLower] ??
          balisticasRows
              .where((r) =>
                  r['exame_id']?.toString().trim().toLowerCase() ==
                  achadoUuidLower)
              .firstOrNull;

      if (bRow != null) {
        return achado.copyWith(
          tipoFerimento:
              bRow['tipo_ferimento']?.toString() ?? achado.tipoFerimento,
          tipoObjeto:
              bRow['tipo_objeto']?.toString() ?? achado.tipoObjeto,
          numeroLacre:
              bRow['numero_lacre']?.toString() ?? achado.numeroLacre,
          comentarioAdicional:
              bRow['comentario_adicional']?.toString() ??
              achado.comentarioAdicional,
        );
      }
      return achado;
    }).toList();
  }

  Future<List<Achado>> getAchadosDeEntradaPorCaso(String casoUuid) async {
    final db = await _db;
    final result = await db.query(
      'achados',
      where: r"caso_uuid = ? AND removido = 0 AND (json_extract(dados_preenchidos_json, '$.tipo_orificio') = 'Entrada' OR json_extract(dados_preenchidos_json, '$.dynamicFields.tipo_orificio') = 'Entrada')",
      whereArgs: [casoUuid],
      orderBy: 'numero_sequencial ASC',
    );
    return result.map((m) => Achado.fromMap(m)).toList();
  }
}

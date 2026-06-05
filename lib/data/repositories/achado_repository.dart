import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class AchadoRepository {
  final DatabaseHelper _dbHelper;

  AchadoRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.database;

  Future<void> insertAchado(Achado achado) async {
    final db = await _db;
    try {
      await db.insert(
        'achados',
        achado.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _garantirEvidencia(db, achado);
    } catch (e) {
      throw Exception('Erro de persistência ao inserir achado: $e');
    }
  }

  Future<void> updateAchado(Achado achado) async {
    final db = await _db;
    try {
      final rowsAffected = await db.update(
        'achados',
        achado.toMap(),
        where: 'uuid = ?',
        whereArgs: [achado.uuid],
      );
      debugPrint('[AchadoRepository] updateAchado ${achado.uuid}: $rowsAffected row(s) affected');
      if (rowsAffected == 0) {
        throw Exception('Achado ${achado.uuid} não encontrado no banco.');
      }
      await _garantirEvidencia(db, achado);
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
      return;
    }

    final List<Map<String, dynamic>> rows = await db.query(
      'evidencias_multimidia',
      where: 'achado_uuid = ? AND removido = 0',
      whereArgs: [achado.uuid],
    );

    if (rows.isEmpty) {
      await db.insert('evidencias_multimidia', {
        'uuid': const Uuid().v4(),
        'achado_uuid': achado.uuid,
        'tipo': 'FOTO',
        'caminho_arquivo_encriptado': photo,
        'foto_sincronizada': 0,
        'removido': 0,
        'versao': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
    } else {
      final existingPath = rows.first['caminho_arquivo_encriptado']?.toString();
      if (existingPath != photo) {
        await db.update(
          'evidencias_multimidia',
          {
            'caminho_arquivo_encriptado': photo,
            'foto_sincronizada': 0,
            'atualizado_em': DateTime.now().toIso8601String(),
          },
          where: 'achado_uuid = ? AND removido = 0',
          whereArgs: [achado.uuid],
        );
      }
    }
  }

  Future<void> deleteAchado(String uuid) async {
    final db = await _db;
    try {
      await db.rawUpdate('UPDATE achados SET removido = 1 WHERE uuid = ?', [uuid]);
    } catch (e) {
      throw Exception('Erro de persistência ao remover achado: $e');
    }
  }

  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await _db;
    final result = await db.query(
      'achados',
      where: 'caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      orderBy: 'criado_em DESC',
    );
    return result.map((m) => Achado.fromMap(m)).toList();
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

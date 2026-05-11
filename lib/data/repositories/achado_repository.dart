import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
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
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar achado: $e');
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
}

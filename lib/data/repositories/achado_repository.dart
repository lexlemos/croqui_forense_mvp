import 'package:sqflite_sqlcipher/sqflite.dart';
import '../local/database_helper.dart';
import '../models/achado_model.dart';

class AchadoRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

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
      await db.update(
        'achados',
        achado.toMap(),
        where: 'uuid = ?',
        whereArgs: [achado.uuid],
      );
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
      where: 'diagrama_caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      orderBy: 'criado_em DESC',
    );
    return result.map((m) => Achado.fromMap(m)).toList();
  }
}
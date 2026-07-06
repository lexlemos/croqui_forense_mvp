import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';

class InjuryTypeRepository {
  final DatabaseHelper _dbHelper;

  InjuryTypeRepository(this._dbHelper);

  Future<List<InjuryType>> getAllTypes() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      tableTiposAchados,
      where: 'ativo = 1',
      orderBy: 'ordem ASC',
    );
    return result.map((m) => InjuryType.fromMap(m)).toList();
  }

  Future<void> upsertAll(List<InjuryType> types) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final existingRows = await txn.query(tableTiposAchados, columns: ['id']);
      final existingIds = existingRows.map((row) => row['id'] as String).toSet();

      final batch = txn.batch();
      for (final type in types) {
        if (existingIds.contains(type.id)) {
          batch.update(
            tableTiposAchados,
            type.toMap(),
            where: 'id = ?',
            whereArgs: [type.id],
          );
        } else {
          batch.insert(
            tableTiposAchados,
            type.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }
}
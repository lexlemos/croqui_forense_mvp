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
    final batch = db.batch();
    for (final type in types) {
      batch.insert(
        tableTiposAchados,
        type.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
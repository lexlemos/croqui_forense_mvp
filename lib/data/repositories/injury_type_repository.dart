import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';

class InjuryTypeRepository {
  final DatabaseHelper _dbHelper;

  InjuryTypeRepository(this._dbHelper);

  Future<List<InjuryType>> getAllTypes() async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'tipos_achados',
      where: 'ativo = 1',
      orderBy: 'ordem ASC',
    );

    return result.map((m) => InjuryType.fromMap(m)).toList();
  }
}
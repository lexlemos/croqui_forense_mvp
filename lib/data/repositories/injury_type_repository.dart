import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';

class InjuryTypeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance; 

  Future<List<InjuryType>> getAllTypes() async {
    final db = await _dbHelper.database;
    
    final result = await db.query(
      'injury_types',
      where: 'ativo = 1',
      orderBy: 'ordem ASC',
    );

    return result.map((m) => InjuryType.fromMap(m)).toList();
  }
}
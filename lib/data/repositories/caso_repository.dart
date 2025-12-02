import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';

class CasoRepository {
  final DatabaseHelper _dbHelper;

  CasoRepository(this._dbHelper);

  Future<void> insertCase(Caso novoCaso) async {
    final db = await _dbHelper.database;
    
    await db.insert(
      tableCasos,
      novoCaso.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, 
    );
  }

  Future<List<Caso>> getAllCases() async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableCasos,
      where: 'removido = 0',
      orderBy: 'atualizado_em DESC, criado_em_dispositivo DESC',
    );

    return List.generate(maps.length, (i) {
      return Caso.fromMap(maps[i]);
    });
  }
}
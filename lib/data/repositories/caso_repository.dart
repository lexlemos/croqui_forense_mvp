import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

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

/// Faz o JOIN: Achados -> Diagramas -> Caso
  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await _dbHelper.database;

    const sql = '''
      SELECT a.* FROM $tableAchados a
      INNER JOIN $tableDiagramasDoCaso d ON a.diagrama_caso_uuid = d.uuid
      WHERE d.caso_uuid = ? 
      AND a.removido = 0
    ''';

    final result = await db.rawQuery(sql, [casoUuid]);

    return result.map((map) => Achado.fromMap(map)).toList();
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
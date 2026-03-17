import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class CasoRepository {

  final DatabaseHelper _dbHelper;

  CasoRepository(this._dbHelper); 

  Future<Database> get database async => _dbHelper.database;

  Future<void> insertCase(Caso novoCaso) async {
    final db = await database;
    try {
      await db.insert(
        tableCasos,
        novoCaso.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace, 
      );
    } catch (e) {
      throw Exception('Erro de persistência ao inserir caso: $e');
    }
  }

  Future<void> updateCase(Caso caso) async {
    final db = await database;
    try {
      await db.update(
        tableCasos,
        caso.toMap(),
        where: 'uuid = ?',
        whereArgs: [caso.uuid],
      );
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar caso: $e');
    }
  }

  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await database;

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
    final db = await database;
    
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
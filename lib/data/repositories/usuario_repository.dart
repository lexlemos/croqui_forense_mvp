import 'package:sqflite/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class UsuarioRepository {
  late final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get database async => _dbHelper.database;

  Future<Usuario?> getUsuarioByMatricula(String matricula) async {
    final db = await database;
    
    final maps = await db.query(
      'usuarios',
      where: 'matricula_funcional = ?',
      whereArgs: [matricula],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<Usuario?> getUsuarioById(int id) async {
    final db = await database;
    
    final maps = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }
}
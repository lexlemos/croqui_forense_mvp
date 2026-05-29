import 'package:sqflite_sqlcipher/sqflite.dart';
import '../local/database_helper.dart';

class DiagramaRepository {
  final DatabaseHelper _dbHelper;

  DiagramaRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.database;

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await _db;
    return db.query('templates_diagrama');
  }
}
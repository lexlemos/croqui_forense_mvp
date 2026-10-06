import 'package:sqflite_sqlcipher/sqflite.dart';
import '../local/database_helper.dart';

/// Repositório de acesso e consulta aos templates de diagramas corporais e croquis forenses.
///
/// Gerencia a leitura das definições visuais cadastradas na tabela local `templates_diagrama`.
class DiagramaRepository {
  final DatabaseHelper _dbHelper;

  /// Cria uma instância de [DiagramaRepository] associada ao [DatabaseHelper].
  DiagramaRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.database;

  /// Retorna a listagem de todos os templates de diagramas anatômicos persistidos localmente.
  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await _db;
    return db.query('templates_diagrama');
  }
}


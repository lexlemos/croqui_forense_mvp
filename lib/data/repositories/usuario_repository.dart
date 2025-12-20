import 'package:sqflite/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart'; 

class UsuarioRepository {
  final DatabaseHelper _dbHelper;

  UsuarioRepository(this._dbHelper);

  Future<Database> get database async => _dbHelper.database;

  Future<Usuario?> getUsuarioByMatricula(String matricula) async {
    final db = await database;
    final maps = await db.query(
      'usuarios',
      where: 'matricula_funcional = ?',
      whereArgs: [matricula],
    );
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<Usuario?> getUsuarioById(String id) async {
    final db = await database;
    final maps = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<List<Usuario>> getUsuarios({
    int page = 0,
    int pageSize = 20,
    String? query,
  }) async {
    final db = await database;

    final whereClause = query != null && query.isNotEmpty
        ? 'nome_completo LIKE ? OR matricula_funcional LIKE ?'
        : null;

    final args = query != null && query.isNotEmpty
        ? ['%$query%', '%$query%']
        : null;

    final maps = await db.query(
      'usuarios',
      where: whereClause,
      whereArgs: args,
      limit: pageSize,
      offset: page * pageSize,
      orderBy: 'nome_completo ASC',
    );

    return maps.map((e) => Usuario.fromMap(e)).toList();
  }

  Future<int> countUsuarios({String? query}) async {
    final db = await database;
    final whereClause = query != null && query.isNotEmpty
        ? 'WHERE nome_completo LIKE ? OR matricula_funcional LIKE ?'
        : '';
    final args = query != null && query.isNotEmpty ? ['%$query%', '%$query%'] : [];
    
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM usuarios $whereClause', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Papel>> getAllPapeis() async {
    final db = await database;
    final maps = await db.query('papeis', orderBy: 'nome ASC'); 
    return maps.map((e) => Papel.fromMap(e)).toList();
  }

  Future<void> createUsuario(Usuario usuario) async {
    final db = await database;
    try {
     
      await db.insert('usuarios', usuario.toMap());
    } catch (e) {
      if (e is DatabaseException && e.isUniqueConstraintError()) {
        throw Exception('Matrícula já existente.');
      }
      rethrow;
    }
  }
  Future<void> updatePin(String id, String novoHash, String novoSalt) async {
    final db = await database;
    await db.update(
      'usuarios',
      {
        'hash_pin_offline': novoHash,
        'salt': novoSalt,
        'deve_alterar_pin': 0, 
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStatusUsuario(String id, bool ativo) async {
    final db = await database;
    await db.update(
      'usuarios',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
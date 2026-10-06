import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart';

/// Repositório de dados encarregado da persistência e consulta local de usuários e papéis institucionais.
///
/// Opera sobre as tabelas `usuarios` e `papeis` no banco de dados relacional SQLite
/// criptografado ([SQLCipher]), provendo a base cadastral para autenticação offline,
/// auditoria da cadeia de custódia e gerenciamento de perfis no dispositivo.
class UsuarioRepository {
  final DatabaseHelper _dbHelper;

  UsuarioRepository(this._dbHelper);

  /// Instância ativa e segura da base de dados local gerenciada pelo [DatabaseHelper].
  Future<Database> get database async => _dbHelper.database;

  /// Localiza um [Usuario] na base local a partir de sua matrícula funcional institucional.
  ///
  /// Retorna o [Usuario] correspondente ou `null` caso a matrícula não esteja cadastrada no dispositivo.
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

  /// Recupera o registro do [Usuario] local a partir de seu identificador único universal ([id]).
  ///
  /// Retorna a entidade correspondente ou `null` se não encontrada.
  Future<Usuario?> getUsuarioById(String id) async {
    final db = await database;
    final maps = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  /// Recupera uma listagem paginada de usuários locais, ordenada alfabeticamente por nome.
  ///
  /// Permite filtragem textual opcional ([query]) que pesquisa simultaneamente por
  /// correspondência parcial (`LIKE`) no nome completo ou na matrícula funcional.
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

  /// Contabiliza o número total de usuários cadastrados localmente que atendem ao critério de busca.
  ///
  /// Utilizado no cálculo de metadados de paginação na interface de gerenciamento de usuários.
  Future<int> countUsuarios({String? query}) async {
    final db = await database;
    final whereClause = query != null && query.isNotEmpty
        ? 'WHERE nome_completo LIKE ? OR matricula_funcional LIKE ?'
        : '';
    final args = query != null && query.isNotEmpty
        ? ['%$query%', '%$query%']
        : [];

    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM usuarios $whereClause',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Retorna a listagem de todos os papéis e perfis operacionais ([Papel]) registrados no banco local.
  Future<List<Papel>> getAllPapeis() async {
    final db = await database;
    final maps = await db.query('papeis', orderBy: 'nome ASC');
    return maps.map((e) => Papel.fromMap(e)).toList();
  }

  /// Insere ou atualiza (`upsert`) o registro do [usuario] na base de dados local.
  ///
  /// Executa primeiramente a atualização filtrada pelo identificador primário. Caso
  /// nenhuma linha seja afetada (novo usuário), realiza a inserção com resolução
  /// [ConflictAlgorithm.ignore].
  Future<void> createUsuario(Usuario usuario) async {
    final db = await database;
    final rowsAffected = await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
    if (rowsAffected == 0) {
      await db.insert(
        'usuarios',
        usuario.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Atualiza o estado de habilitação funcional ([ativo]) do usuário no banco de dados local.
  ///
  /// Throws [Exception] caso ocorra falha de I/O ou erro de persistência durante a execução do comando SQL.
  Future<void> updateStatusUsuario(String id, bool ativo) async {
    final db = await database;
    try {
      await db.update(
        'usuarios',
        {'ativo': ativo ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception(
        'Erro de persistência ao atualizar status do usuário: $e',
      );
    }
  }
}

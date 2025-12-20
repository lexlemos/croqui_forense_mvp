import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/local/database_seeder.dart';

class DatabaseHelper {
  static const String _kDbName = 'croqui_forense_mvp.db';
  static const int _kVersion = 2; 
  static const String _kEncKey = 'db_encryption_key';

  final IDatabaseFactory _dbFactory;
  final KeyStorageInterface _keyStorage;

  static DatabaseHelper? _instance;
  Database? _db;

  DatabaseHelper._internal(this._dbFactory, this._keyStorage);

  static void init(IDatabaseFactory factory, KeyStorageInterface storage) {
    _instance = DatabaseHelper._internal(factory, storage);
  }

  static DatabaseHelper get instance {
    if (_instance == null) {
      throw Exception("DatabaseHelper não inicializado. Chame DatabaseHelper.init() no main.dart.");
    }
    return _instance!;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await _dbFactory.getDatabasesPath();
    final path = join(dbPath, _kDbName);

    var key = await _keyStorage.read(key: _kEncKey);
    
    if (key == null) {
      key = const Uuid().v4() + const Uuid().v4();
      await _keyStorage.save(key: _kEncKey, value: key);
    }

    return await _dbFactory.openDatabase(
      path,
      version: _kVersion,
      password: key,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          for (var sql in kFullDatabaseCreationScripts) {
            await txn.execute(sql);
          }
          final seeder = DatabaseSeeder(txn); 
          await seeder.seedAll();
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {

        if (oldVersion < 2) {
          await _migrateV1toV2(db);
        }

      },
    );
  }
  String _getScriptFor(String tableName) {
    final script = kTableScripts[tableName];
    if (script == null) {
      throw Exception("Script de criação para tabela '$tableName' não encontrado em kTableScripts.");
    }
    return script;
  }

  Future<void> _migrateV1toV2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');

      await _performTableMigration(
        txn, 
        tableName: tablePapeis, 
        createScript: _getScriptFor(tablePapeis), 
        copyScript: 'INSERT INTO papeis (id, nome, descricao, e_padrao) SELECT CAST(id AS TEXT), nome, descricao, e_padrao FROM papeis_old'
      );
      await _performTableMigration(
        txn, 
        tableName: tablePermissoes, 
        createScript: _getScriptFor(tablePermissoes), 
        copyScript: 'INSERT INTO permissoes (id, codigo, descricao) SELECT CAST(id AS TEXT), codigo, descricao FROM permissoes_old'
      );

      await _performTableMigration(
        txn, 
        tableName: tableUsuarios, 
        createScript: _getScriptFor(tableUsuarios), 
        copyScript: '''
          INSERT INTO usuarios (
            id, matricula_funcional, papel_id, nome_completo, ativo, hash_pin_offline, 
            deve_alterar_pin, criado_em, atualizado_em, versao, device_id, salt
          ) 
          SELECT 
            CAST(id AS TEXT), matricula_funcional, CAST(papel_id AS TEXT), nome_completo, ativo, hash_pin_offline, 
            1, criado_em, atualizado_em, versao, device_id, NULL 
          FROM usuarios_old
        '''
      );

      await _performTableMigration(
        txn, 
        tableName: tablePapelPermissoes, 
        createScript: _getScriptFor(tablePapelPermissoes), 
        copyScript: '''
          INSERT INTO papel_permissoes (papel_id, permissao_id) 
          SELECT CAST(papel_id AS TEXT), CAST(permissao_id AS TEXT) 
          FROM papel_permissoes_old
        '''
      );
      await _performTableMigration(
        txn,
        tableName: tableCasos,
        createScript: _getScriptFor(tableCasos), 
        copyScript: '''
          INSERT INTO casos (uuid, id_usuario_criador, numero_laudo_externo, status, hash_integridade, removido, dados_laudo_json, versao, criado_em_dispositivo, criado_em_rede_confiavel, atualizado_em, device_id, proveniencia)
          SELECT uuid, CAST(id_usuario_criador AS TEXT), numero_laudo_externo, status, hash_integridade, removido, dados_laudo_json, versao, criado_em_dispositivo, criado_em_rede_confiavel, atualizado_em, device_id, proveniencia
          FROM casos_old
        '''
      );

      await _performTableMigration(
        txn,
        tableName: tableLogAuditoria,
        createScript: _getScriptFor(tableLogAuditoria),
        copyScript: '''
          INSERT INTO log_auditoria (id, caso_uuid, id_usuario, codigo_acao, transacao_uuid, detalhes_json, timestamp, device_id, proveniencia)
          SELECT CAST(id AS TEXT), caso_uuid, CAST(id_usuario AS TEXT), codigo_acao, transacao_uuid, detalhes_json, timestamp, device_id, proveniencia
          FROM log_auditoria_old
        '''
      );

      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  Future<void> _performTableMigration(Transaction txn, {
    required String tableName,
    required String createScript,
    required String copyScript,
  }) async {
    final check = await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
    if (check.isEmpty) return; 

    print('Migrando tabela: $tableName...');

    await txn.execute('ALTER TABLE $tableName RENAME TO ${tableName}_old');
    await txn.execute(createScript);
    await txn.execute(copyScript);
    await txn.execute('DROP TABLE ${tableName}_old');
  }
  
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
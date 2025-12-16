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
        print("--- INICIANDO MIGRAÇÃO DE BANCO DE DADOS: v$oldVersion -> v$newVersion ---");
        
        if (oldVersion < 2) {
          await _migrateV1toV2(db);
        }
        
        print("--- MIGRAÇÃO CONCLUÍDA COM SUCESSO ---");
      },
    );
  }
  Future<void> _migrateV1toV2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');

      await _performTableMigration(
        txn, 
        tableName: 'papeis', 
        createScript: kFullDatabaseCreationScripts[0], 
        copyScript: 'INSERT INTO papeis (id, nome, descricao, e_padrao) SELECT CAST(id AS TEXT), nome, descricao, e_padrao FROM papeis_old'
      );

      await _performTableMigration(
        txn, 
        tableName: 'permissoes', 
        createScript: kFullDatabaseCreationScripts[1], 
        copyScript: 'INSERT INTO permissoes (id, codigo, descricao) SELECT CAST(id AS TEXT), codigo, descricao FROM permissoes_old'
      );

      await _performTableMigration(
        txn, 
        tableName: 'usuarios', 
        createScript: kFullDatabaseCreationScripts[2], 
        copyScript: '''
          INSERT INTO usuarios (id, matricula_funcional, papel_id, nome_completo, ativo, hash_pin_offline, deve_alterar_pin, criado_em, atualizado_em, versao, device_id, salt) 
          SELECT CAST(id AS TEXT), matricula_funcional, CAST(papel_id AS TEXT), nome_completo, ativo, hash_pin_offline, deve_alterar_pin, criado_em, atualizado_em, versao, device_id, salt 
          FROM usuarios_old
        '''
      );

      await _performTableMigration(
        txn, 
        tableName: 'papel_permissoes', 
        createScript: kFullDatabaseCreationScripts[3], 
        copyScript: '''
          INSERT INTO papel_permissoes (papel_id, permissao_id) 
          SELECT CAST(papel_id AS TEXT), CAST(permissao_id AS TEXT) 
          FROM papel_permissoes_old
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
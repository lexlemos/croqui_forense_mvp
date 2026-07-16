import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/local/database_seeder.dart';

class DatabaseHelper {
  static const String _kDbName = kDatabaseName; 
  static const int _kVersion = kDatabaseVersion; 

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
      throw Exception(
          "DatabaseHelper não inicializado. Chame DatabaseHelper.init() no main.dart.");
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

    final db = await _dbFactory.openDatabase(
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
      onUpgrade: _onUpgrade, 
    );

    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DatabaseHelper] 🔄 Iniciando migração do banco (v$oldVersion para v$newVersion)...');

    await db.transaction((txn) async {
      for (int i = oldVersion + 1; i <= newVersion; i++) {
        await _executeMigration(txn, i);
      }
    });
    
    debugPrint('[DatabaseHelper] ✅ Migração concluída com sucesso!');
  }

  /// Executa o SQL específico de cada versão
  Future<void> _executeMigration(Transaction txn, int version) async {
    switch (version) {
      case 2:
        debugPrint('[DatabaseHelper] Executando migração para a versão 2...');
        await txn.execute('ALTER TABLE tipos_achados ADD COLUMN is_interno INTEGER DEFAULT 0;');
        break;
        
      case 3:
        debugPrint('[DatabaseHelper] Executando migração para a versão 3...');
        break;
        
      default:
        debugPrint('[DatabaseHelper] Nenhuma migração específica definida para a versão $version');
    }
  }
}
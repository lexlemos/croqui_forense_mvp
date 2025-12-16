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
        
      },
    );
  }
  
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
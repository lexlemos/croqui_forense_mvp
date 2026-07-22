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
        await _addColumnIfNotExists(txn, 'tipos_achados', 'is_interno', 'INTEGER DEFAULT 0');
        break;
        
      case 3:
        debugPrint('[DatabaseHelper] Executando migração para a versão 3...');
        await _addColumnIfNotExists(txn, 'casos', 'numero_pic', 'TEXT');
        await _addColumnIfNotExists(txn, 'casos', 'numero_bo', 'TEXT');
        await _addColumnIfNotExists(txn, 'casos', 'numero_requisicao', 'TEXT');
        await _addColumnIfNotExists(txn, 'casos', 'nome_vitima', 'TEXT');
        await _addColumnIfNotExists(txn, 'casos', 'destino', 'TEXT');
        await _addColumnIfNotExists(txn, 'casos', 'requisitante', 'TEXT');
        await _addColumnIfNotExists(txn, 'achados', 'tamanho', 'TEXT');
        await _addColumnIfNotExists(txn, 'achados', 'vista_anatomica', 'TEXT');
        await _addColumnIfNotExists(txn, 'achados', 'local_anatomico', 'TEXT');
        await _addColumnIfNotExists(txn, 'achados', 'diagrama_caso_uuid', "TEXT DEFAULT ''");

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS exames_solicitados (
              uuid TEXT PRIMARY KEY,
              caso_uuid TEXT NOT NULL,
              tipo_exame TEXT NOT NULL,
              quantidade_amostras INTEGER DEFAULT 1,
              numero_lacre TEXT NOT NULL,
              criado_em TEXT NOT NULL,
              FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE
          );
        ''');

        try {
          await txn.execute('ALTER TABLE evidencias_multimidia RENAME TO old_evidencias_multimidia;');
          await txn.execute('''
            CREATE TABLE evidencias_multimidia (
                uuid TEXT PRIMARY KEY,
                caso_uuid TEXT NOT NULL,
                achado_uuid TEXT,
                substituida_por TEXT,
                tipo TEXT DEFAULT 'ACHADO',
                caminho_arquivo_encriptado TEXT,
                hash_arquivo TEXT,
                foto_sincronizada INTEGER NOT NULL DEFAULT 0,
                removido INTEGER DEFAULT 0,
                versao INTEGER DEFAULT 1,
                criado_em TEXT,
                atualizado_em TEXT,
                descricao TEXT,
                FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE,
                FOREIGN KEY (achado_uuid) REFERENCES achados(uuid) ON DELETE CASCADE,
                FOREIGN KEY (substituida_por) REFERENCES evidencias_multimidia(uuid) ON DELETE SET NULL
            );
          ''');
          await txn.execute('''
            INSERT INTO evidencias_multimidia (
              uuid, caso_uuid, achado_uuid, substituida_por, tipo, 
              caminho_arquivo_encriptado, hash_arquivo, foto_sincronizada, 
              removido, versao, criado_em, atualizado_em
            )
            SELECT 
              o.uuid, 
              COALESCE(a.caso_uuid, ''), 
              o.achado_uuid, 
              o.substituida_por, 
              'ACHADO', 
              o.caminho_arquivo_encriptado, 
              o.hash_arquivo, 
              o.foto_sincronizada, 
              o.removido, 
              o.versao, 
              o.criado_em, 
              o.atualizado_em 
            FROM old_evidencias_multimidia o
            LEFT JOIN achados a ON a.uuid = o.achado_uuid;
          ''');
          await txn.execute('DROP TABLE IF EXISTS old_evidencias_multimidia;');
        } catch (e) {
          debugPrint('[DatabaseHelper] Falha ao alterar/migrar tabela evidencias_multimidia: $e');
        }
        break;

      case 4:
        debugPrint('[DatabaseHelper] Executando migração para a versão 4...');
        await _addColumnIfNotExists(txn, 'evidencias_multimidia', 'descricao', 'TEXT');
        break;

      case 5:
        debugPrint('[DatabaseHelper] Executando migração para a versão 5 (Limpeza de Tabelas Obsoletas)...');
        await _addColumnIfNotExists(txn, 'evidencias_multimidia', 'descricao', 'TEXT');
        // Limpeza de dívida técnica / remoção segura de tabelas descontinuadas
        await txn.execute('DROP TABLE IF EXISTS diagramas_do_caso;');
        await txn.execute('DROP TABLE IF EXISTS old_evidencias_multimidia;');
        break;
        
      default:
        debugPrint('[DatabaseHelper] Nenhuma migração específica definida para a versão $version');
    }
  }

  /// Utilitário para adicionar coluna de forma idempotente (somente se não existir)
  Future<void> _addColumnIfNotExists(
    Transaction txn,
    String tableName,
    String columnName,
    String columnTypeDef,
  ) async {
    final info = await txn.rawQuery("PRAGMA table_info($tableName);");
    final exists = info.any((row) => row['name']?.toString() == columnName);
    if (!exists) {
      await txn.execute("ALTER TABLE $tableName ADD COLUMN $columnName $columnTypeDef;");
    }
  }
}
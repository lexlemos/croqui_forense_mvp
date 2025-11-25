// lib/data/local/database_helper.dart

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle; // 🔑 Necessário para ler o arquivo SQL como asset

// ✅ Importações corrigidas:
import 'package:croqui_forense_mvp/data/local/database_seeder.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';


class DatabaseHelper {
  static Database? _database;
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  String? _encryptionKey;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    _encryptionKey = await _getEncryptionKey();

    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, kDatabaseName);

    // Configura o caminho global se necessário (depende da sua implementação)
    await databaseFactory.setDatabasesPath(databasesPath);

    // O openDatabase é o ponto de inicialização e upgrade
    return await openDatabase(
      path,
      version: kDatabaseVersion,
      onCreate: _onCreate,
      // O 'password' é o que ativa a criptografia com sqflite_sqlcipher
      password: _encryptionKey,
    );
  }

  Future<String> _getEncryptionKey() async {
    const String keyName = 'db_encryption_key';
    // Tenta ler a chave de criptografia armazenada de forma segura
    String? key = await secureStorage.read(key: keyName);

    if (key == null) {
      // TODO  Em produção, use uma biblioteca para gerar uma chave criptograficamente segura
      // (e.g., UUIDs longos ou chaves geradas por pacotes de criptografia)
      key = 'ChaveSecreta_MVP_CroquiForense_2025';
      await secureStorage.write(key: keyName, value: key);
    }
    return key;
  }

  /// Método chamado apenas na primeira vez que o banco é aberto.
  Future _onCreate(Database db, int version) async {
    // 1. Ativa a verificação de chaves estrangeiras (boa prática)
    await db.execute('PRAGMA foreign_keys = ON;');

    // 2. Carrega o script SQL de criação de tabelas do arquivo asset
    final String schemaSql = await rootBundle.loadString(kDatabaseSchemaAssetPath);

    // 3. Executa o script SQL (que contém todos os CREATE TABLE e INDEXES)
    await db.execute(schemaSql);

    // 4. Popula o banco com dados iniciais (seeder)
    final seeder = DatabaseSeeder(db);
    await seeder.seedAll();
  }

// Você pode adicionar um método onUpgrade aqui se for necessário
// Future _onUpgrade(Database db, int oldVersion, int newVersion) async { ... }
}
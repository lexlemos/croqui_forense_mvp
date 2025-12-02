// lib/data/local/sqlcipher_database_factory.dart

import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite_common/sqlite_api.dart'; 
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';

class SqlCipherDatabaseFactory implements IDatabaseFactory {
  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnDatabaseConfigureFn? onConfigure,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    String? password,
  }) {

    return sqlcipher.openDatabase(
      path,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      password: password,
    );
  }

  @override
  Future<String> getDatabasesPath() => sqlcipher.getDatabasesPath();
}
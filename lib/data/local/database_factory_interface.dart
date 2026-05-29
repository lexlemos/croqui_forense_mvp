import 'package:sqflite_sqlcipher/sqflite.dart';

abstract class IDatabaseFactory {
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnDatabaseConfigureFn? onConfigure,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    String? password,
  });
  
  Future<String> getDatabasesPath();
}
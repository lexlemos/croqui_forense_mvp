import 'package:sqflite_common/sqlite_api.dart';

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
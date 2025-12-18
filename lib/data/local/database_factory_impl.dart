import 'package:sqflite_sqlcipher/sqflite.dart'; 
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';

class DatabaseFactoryImpl implements IDatabaseFactory {
  
  @override
  Future<String> getDatabasesPath() async {
    return await getDatabasesPath();
  }

  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    String? password,
    Function(Database)? onConfigure,
    Function(Database, int)? onCreate,
    Function(Database, int, int)? onUpgrade,
  }) async {
    return await openDatabase(
      path,
      password: password,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }
}
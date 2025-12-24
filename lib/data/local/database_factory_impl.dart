
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher; 
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';

class DatabaseFactoryImpl implements IDatabaseFactory {
  
  @override
  Future<String> getDatabasesPath() async {
    return await sqlcipher.getDatabasesPath();
  }

  @override
  Future<sqlcipher.Database> openDatabase(
    String path, {
    int? version,
    String? password,
    Function(sqlcipher.Database)? onConfigure,
    Function(sqlcipher.Database, int)? onCreate,
    Function(sqlcipher.Database, int, int)? onUpgrade,
  }) async {
    
    return await sqlcipher.openDatabase(
      path,
      password: password,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }
}
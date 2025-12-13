import 'package:sqflite/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';

class DatabaseFactoryImpl implements IDatabaseFactory {
  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    String? password, 
    Function? onConfigure,
    Function? onCreate,
    Function? onUpgrade,
  }) async {
    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async => await onConfigure?.call(db),
        onCreate: (db, version) async => await onCreate?.call(db, version),
        onUpgrade: (db, old, newV) async => await onUpgrade?.call(db, old, newV),
      ),
    );
  }

  @override
  Future<String> getDatabasesPath() async {
    return await databaseFactory.getDatabasesPath();
  }
}
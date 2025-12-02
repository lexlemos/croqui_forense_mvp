import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';

class FfiDatabaseFactory implements IDatabaseFactory {
  FfiDatabaseFactory() {
    sqfliteFfiInit();
  }

  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnDatabaseConfigureFn? onConfigure,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    String? password,
  }) {
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: onConfigure,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  Future<String> getDatabasesPath() async {
    return databaseFactoryFfi.getDatabasesPath();
  }
}
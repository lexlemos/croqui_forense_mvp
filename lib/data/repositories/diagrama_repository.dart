import 'package:sqflite_sqlcipher/sqflite.dart';
import '../local/database_helper.dart';

class DiagramaRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<void> garantirExistencia(String casoUuid, String diagramaUuid) async {
    final db = await _db;
    try {
      await db.insert(
        'diagramas_do_caso',
        {
          'uuid': diagramaUuid, 
          'caso_uuid': casoUuid,
          'template_id': 'corpo_humano_padrao', 
          'removido': 0,
          'versao': 1,
          'criado_em': DateTime.now().toIso8601String(),
          'device_id': 'APP_TABLET',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      throw Exception('Erro de persistência ao garantir diagrama: $e');
    }
  }

}
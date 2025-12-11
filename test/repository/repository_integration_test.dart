import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

import '../helpers/ffi_database_factory.dart'; 

class MockKeyStorage implements IKeyStorage {
  @override
  Future<String?> read(String key) async => 'CHAVE_MOCK_TESTES';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  late DatabaseHelper dbHelper;
  late UsuarioRepository usuarioRepo;
  late CasoRepository casoRepo;
  late Usuario adminUser;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    sqfliteFfiInit(); 
    databaseFactory = databaseFactoryFfi;

    final dbFactory = FfiDatabaseFactory(); 
    final mockStorage = MockKeyStorage();

    dbHelper = DatabaseHelper(dbFactory, mockStorage);
    await dbHelper.database; 

    usuarioRepo = UsuarioRepository(dbHelper);
    casoRepo = CasoRepository(dbHelper);
    
    final user = await usuarioRepo.getUsuarioByMatricula('ADMIN001');
    if (user == null) fail('Seeder falhou: Usuário ADMIN001 não encontrado');
    adminUser = user;
  });

  group('Fase 2 - Persistência (Via FFI)', () {
     test('1. Deve encontrar o usuário Admin padrão...', () async {

     });
     
  });
}
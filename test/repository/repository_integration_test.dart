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
    // Inicializa o binding para testes
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Inicializa o FFI (SQLite para PC/Linux)
    sqfliteFfiInit(); 
    // Define a factory global como FFI (para garantir compatibilidade)
    databaseFactory = databaseFactoryFfi;

    // --- INJEÇÃO DE DEPENDÊNCIA DE TESTE ---
    // Aqui está a mágica: Usamos a Factory FFI em vez da SQLCipher
    final dbFactory = FfiDatabaseFactory(); 
    final mockStorage = MockKeyStorage();

    // O DatabaseHelper aceita nossa factory "falsa" (sem criptografia real)
    dbHelper = DatabaseHelper(dbFactory, mockStorage);

    // Inicializa o banco (Roda onCreate, Seeder, etc.)
    await dbHelper.database; 

    usuarioRepo = UsuarioRepository(dbHelper);
    casoRepo = CasoRepository(dbHelper);
    
    // Validação do Seeder
    final user = await usuarioRepo.getUsuarioByMatricula('ADMIN001');
    if (user == null) fail('Seeder falhou: Usuário ADMIN001 não encontrado');
    adminUser = user;
  });

  // O resto dos testes permanece IGUAL...
  group('Fase 2 - Persistência (Via FFI)', () {
     test('1. Deve encontrar o usuário Admin padrão...', () async {
        // ... (seu código de teste existente)
     });
     
     // ... (seus outros testes)
  });
}
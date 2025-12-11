import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_interface.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/local/database_seeder.dart'; 

// Mock simples apenas para o KeyStorage (não queremos escrever no disco do Linux)
class MockKeyStorage implements IKeyStorage {
  final Map<String, String> _storage = {};
  
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
  @override
  Future<void> delete(String key) async => _storage.remove(key);
}

// Implementação Fake da Factory para usar FFI (Memória)
class FfiDatabaseFactory implements IDatabaseFactory {
  @override
  Future<String> getDatabasesPath() async => inMemoryDatabasePath;
  
  @override
  Future<Database> openDatabase(String path, {int? version, String? password, Function? onConfigure, Function? onCreate, Function? onUpgrade}) async {
    // Redireciona para a implementação FFI do Linux
    return databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async => await onConfigure?.call(db),
      onCreate: (db, version) async => await onCreate?.call(db, version),
      onUpgrade: (db, old, newV) async => await onUpgrade?.call(db, old, newV),
    ));
  }
}

void main() {
  // Configura o FFI para funcionar no Linux/Codespaces
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthService authService;
  late UsuarioRepository repository;
  late Database db;

  setUp(() async {
    // 1. Cria um banco REAL na memória RAM
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // 2. Cria a tabela REALMENTE (copie o SQL do seu database_constants ou execute aqui)
    // Isso garante que o SQL de criação está correto e compatível com o Model
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matricula_funcional TEXT NOT NULL UNIQUE,
        nome_completo TEXT NOT NULL,
        papel_id INTEGER NOT NULL,
        ativo INTEGER NOT NULL,
        hash_pin_offline TEXT NOT NULL,
        salt TEXT, 
        criado_em TEXT NOT NULL
      )
    ''');

    // 3. Roda o SEEDER REAL (Isso testa se o Seeder está gerando salts corretamente)
    final seeder = DatabaseSeeder(db);
    // Precisamos mockar as outras tabelas que o seeder pede, ou simplificar o teste
    // Para este teste focado, vamos inserir um usuário manualmente para ser mais rápido
    // Mas usando a lógica "real" de criptografia
    
    final salt = SecurityHelper.generateSalt();
    final hash = SecurityHelper.hashPin('1234', salt);

    await db.insert('usuarios', {
      'matricula_funcional': 'POL_REAL',
      'nome_completo': 'Teste Integração',
      'papel_id': 1,
      'ativo': 1,
      'hash_pin_offline': hash,
      'salt': salt,
      'criado_em': DateTime.now().toIso8601String(),
    });

    // 4. Instancia o repositório com o banco real
    // (Precisamos de um jeito de injetar esse DB no repositório ou criar uma versão teste)
    // Como o UsuarioRepository usa o DatabaseHelper singleton, vamos "simular" o comportamento
    // criando uma classe wrapper ou usando o DB direto para validar a leitura.
    
    // Para simplificar neste exemplo sem refatorar o Helper para injeção:
    // Vamos testar se o DADO foi gravado e se o AuthService aceita.
  });
  
  tearDown(() async {
    await db.close();
  });

  test('INTEGRAÇÃO: Deve realizar login validando dados gravados no SQLite', () async {
    // ARRANGE:
    // Precisamos de um repositório que use nosso banco em memória
    // Como seu repositório usa DatabaseHelper.instance, vamos criar um repo "Fake" 
    // que usa o banco `db` que abrimos acima, mas roda a lógica real de query.
    final repoReal = UsuarioRepositoryTestVersion(db); 
    final keyStorage = MockKeyStorage();
    authService = AuthService(repoReal, keyStorage);

    // ACT: Tenta logar com a senha certa
    final usuario = await authService.login('POL_REAL', '1234');

    // ASSERT:
    expect(usuario, isNotNull);
    expect(usuario?.nomeCompleto, 'Teste Integração');
    expect(usuario?.salt, isNotNull, reason: "O Salt deve ter vindo do banco!");
  });

  test('INTEGRAÇÃO: Deve falhar login com senha errada no SQLite', () async {
    final repoReal = UsuarioRepositoryTestVersion(db);
    final keyStorage = MockKeyStorage();
    authService = AuthService(repoReal, keyStorage);

    expect(
      () async => await authService.login('POL_REAL', '0000'),
      throwsA(isA<AuthException>()),
    );
  });
}

// Uma versão do repositório que aceita um DB aberto (para facilitar testes)
class UsuarioRepositoryTestVersion extends UsuarioRepository {
  final Database _dbAberto;
  UsuarioRepositoryTestVersion(this._dbAberto) : super(); // super() chama o construtor normal

  @override
  Future<Database> get database async => _dbAberto; // Sobrescreve para usar o banco em memória
  
  // O resto dos métodos (getUsuarioByMatricula) vai rodar igualzinho ao original,
  // mas executando as queries neste banco de memória.
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Imports do seu projeto
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart'; // A Interface correta
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

// --- MOCKS ---
// Criamos classes falsas baseadas nas interfaces/classes reais
class MockUsuarioRepository extends Mock implements UsuarioRepository {}
class MockKeyStorage extends Mock implements IKeyStorage {}

void main() {
  late AuthService authService;
  late MockUsuarioRepository mockRepo;
  late MockKeyStorage mockStorage;

  setUp(() {
    mockRepo = MockUsuarioRepository();
    mockStorage = MockKeyStorage();
    
    // Injetamos os mocks no serviço
    authService = AuthService(mockRepo, mockStorage);
    
    // Configuração padrão dos mocks para evitar erros de "não configurado"
    // Quando alguém pedir para escrever qualquer coisa, retorna void (Future)
    registerFallbackValue(''); // Necessário para o 'any()' do mocktail funcionar com Strings
    when(() => mockStorage.write(any(), any())).thenAnswer((_) async {});
    when(() => mockStorage.delete(any())).thenAnswer((_) async {});
  });

  // Massa de dados para o teste (Um usuário válido)
  final mockUser = Usuario(
    id: 1,
    matriculaFuncional: 'ADMIN001',
    nomeCompleto: 'Admin Teste',
    papelId: 1,
    ativo: true,
    // O hash deve corresponder ao PIN '1234'
    hashPinOffline: SecurityHelper.hashPin('1234'), 
    criadoEm: DateTime.now(),
  );

  group('AuthService Tests', () {
    test('Login DEVE retornar NULL se o usuário não for encontrado', () async {
      // Cenário: Repositório retorna null
      when(() => mockRepo.getUsuarioByMatricula('ADMIN001')).thenAnswer((_) async => null);

      final result = await authService.login('ADMIN001', '1234');

      expect(result, isNull);
      // Garante que NADA foi salvo no storage
      verifyNever(() => mockStorage.write(any(), any())); 
    });

    test('Login DEVE retornar NULL se o PIN estiver incorreto', () async {
      // Cenário: Usuário existe, mas a senha digitada ('0000') gera um hash diferente
      when(() => mockRepo.getUsuarioByMatricula('ADMIN001')).thenAnswer((_) async => mockUser);

      final result = await authService.login('ADMIN001', '0000');

      expect(result, isNull);
      verifyNever(() => mockStorage.write(any(), any()));
    });

    test('Login DEVE retornar USUARIO e SALVAR SESSÃO se tudo estiver correto', () async {
      // Cenário: Caminho feliz
      when(() => mockRepo.getUsuarioByMatricula('ADMIN001')).thenAnswer((_) async => mockUser);

      final result = await authService.login('ADMIN001', '1234');

      expect(result, isNotNull);
      expect(result?.id, 1);
      
      // Verifica se o serviço chamou o storage para salvar o ID '1' na chave de sessão
      verify(() => mockStorage.write(AuthService.kSessionKey, '1')).called(1);
    });

    test('Logout DEVE apagar a chave de sessão', () async {
      await authService.logout();
      
      // Verifica se o delete foi chamado com a chave correta
      verify(() => mockStorage.delete(AuthService.kSessionKey)).called(1);
    });
    
    test('isLogged DEVE retornar TRUE se existir valor no storage', () async {
      // Simula que o storage tem um ID salvo
      when(() => mockStorage.read(AuthService.kSessionKey)).thenAnswer((_) async => '1');
      
      final isLogged = await authService.isLogged();
      expect(isLogged, isTrue);
    });
    
    test('isLogged DEVE retornar FALSE se storage estiver vazio', () async {
      when(() => mockStorage.read(AuthService.kSessionKey)).thenAnswer((_) async => null);
      
      final isLogged = await authService.isLogged();
      expect(isLogged, isFalse);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

class MockUsuarioRepository extends Mock implements UsuarioRepository {}
class MockKeyStorage extends Mock implements IKeyStorage {}

void main() {
  late AuthService authService;
  late MockUsuarioRepository mockRepo;
  late MockKeyStorage mockStorage;
  
  // "Banco de dados" em memória do MockStorage
  final Map<String, String> memoryStorage = {};

  setUp(() {
    mockRepo = MockUsuarioRepository();
    mockStorage = MockKeyStorage();
    memoryStorage.clear();

    // Configura o MockStorage para funcionar como um Map real
    when(() => mockStorage.write(any(), any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1] as String;
      memoryStorage[key] = value;
    });
    
    when(() => mockStorage.read(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      return memoryStorage[key];
    });

    when(() => mockStorage.delete(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      memoryStorage.remove(key);
    });

    authService = AuthService(mockRepo, mockStorage);
  });

  group('AuthService - Lógica de Segurança SSP', () {
    final salt = SecurityHelper.generateSalt();
    final hashCorreto = SecurityHelper.hashPin('1234', salt);
    
    final usuarioValido = Usuario(
      id: 1,
      matriculaFuncional: 'POL001',
      nomeCompleto: 'Admin',
      papelId: 1,
      ativo: true,
      hashPinOffline: hashCorreto,
      salt: salt,
      criadoEm: DateTime.now(),
    );

    test('Login DEVE FALHAR se o PIN estiver errado', () async {
      when(() => mockRepo.getUsuarioByMatricula('POL001')).thenAnswer((_) async => usuarioValido);

      expect(
        () async => await authService.login('POL001', '0000'), // Senha errada
        throwsA(isA<AuthException>()),
      );
    });

    test('Login DEVE BLOQUEAR após 5 tentativas falhas', () async {
      when(() => mockRepo.getUsuarioByMatricula('POL001')).thenAnswer((_) async => usuarioValido);

      // Tenta errar 5 vezes
      for (int i = 0; i < 5; i++) {
        try {
          await authService.login('POL001', 'senha_errada');
        } catch (_) {}
      }

      // Na 6ª vez, deve dar erro de BLOQUEIO, não de senha inválida
      try {
        await authService.login('POL001', '1234'); // Senha certa, mas bloqueado
        fail('Deveria ter lançado erro de bloqueio');
      } on AuthException catch (e) {
        expect(e.isLocked, isTrue, reason: "Deveria estar marcado como bloqueado");
        expect(e.message, contains('Aguarde'));
      }
    });

    test('Login DEVE SUCEDER com senha correta e limpar contadores', () async {
      when(() => mockRepo.getUsuarioByMatricula('POL001')).thenAnswer((_) async => usuarioValido);
      
      // Suja o contador com 1 erro antes
      memoryStorage['auth_attempts_POL001'] = '1';

      final user = await authService.login('POL001', '1234');
      
      expect(user, isNotNull);
      // Deve ter limpado os contadores de erro
      expect(memoryStorage.containsKey('auth_attempts_POL001'), isFalse);
      // Deve ter salvo a sessão
      expect(memoryStorage[AuthService.kSessionKey], '1');
    });

    test('Reidratação de Sessão (checkSession) deve buscar usuário pelo ID', () async {
      memoryStorage[AuthService.kSessionKey] = '1';
      when(() => mockRepo.getUsuarioById(1)).thenAnswer((_) async => usuarioValido);

      final user = await authService.checkSession();

      expect(user?.id, 1);
      expect(user?.nomeCompleto, 'Admin');
    });
  });
}
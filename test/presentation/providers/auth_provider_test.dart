import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider(mockAuthService);
  });

  final mockUser = Usuario(
    id: 1,
    matriculaFuncional: 'ADMIN001',
    nomeCompleto: 'Admin Teste',
    papelId: 1,
    ativo: true,
    hashPinOffline: 'hash_qualquer',
    criadoEm: DateTime.now(),
  );

  group('AuthProvider Tests', () {
    
    test('Estado inicial deve ser: não logado e sem loading', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.usuario, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('Login com SUCESSO deve atualizar o estado do usuário', () async {
      when(() => mockAuthService.login('ADMIN001', '1234'))
          .thenAnswer((_) async => mockUser);

      final futureLogin = authProvider.login('ADMIN001', '1234');
      
      final erro = await futureLogin;

      // Verificações
      expect(erro, isNull, reason: 'Não deve retornar mensagem de erro');
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.usuario, equals(mockUser));
      expect(authProvider.isLoading, isFalse);

      verify(() => mockAuthService.login('ADMIN001', '1234')).called(1);
    });

    test('Login com FALHA deve retornar erro e não logar', () async {
      when(() => mockAuthService.login('ADMIN001', '0000'))
          .thenAnswer((_) async => null);

      final erro = await authProvider.login('ADMIN001', '0000');

      // Verificações
      expect(erro, isNotNull, reason: 'Deve retornar uma string de erro');
      expect(erro, contains('inválidos')); // Verifica parte da mensagem
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.usuario, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('Logout deve limpar o usuário da memória', () async {

      when(() => mockAuthService.logout()).thenAnswer((_) async {});

      await authProvider.logout();

      expect(authProvider.usuario, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      verify(() => mockAuthService.logout()).called(1);
    });
  });
}
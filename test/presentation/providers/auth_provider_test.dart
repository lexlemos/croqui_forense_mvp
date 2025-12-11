import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  // Usuário fake para testes
  final mockUser = Usuario(
    id: 1, matriculaFuncional: 'POL1', nomeCompleto: 'Test', 
    papelId: 1, ativo: true, hashPinOffline: 'hash', salt: 'salt', 
    criadoEm: DateTime.now()
  );

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider(mockAuthService);
  });

  group('AuthProvider (Gerenciamento de Estado)', () {
    test('checkLoginStatus deve carregar usuário se houver sessão', () async {
      // Arrange
      when(() => mockAuthService.checkSession()).thenAnswer((_) async => mockUser);

      // Act
      await authProvider.checkLoginStatus();

      // Assert
      expect(authProvider.isLogged, isTrue);
      expect(authProvider.usuario, equals(mockUser));
      expect(authProvider.isLoading, isFalse);
    });

    test('checkLoginStatus deve ficar deslogado se sessão for nula', () async {
      when(() => mockAuthService.checkSession()).thenAnswer((_) async => null);

      await authProvider.checkLoginStatus();

      expect(authProvider.isLogged, isFalse);
      expect(authProvider.usuario, isNull);
    });

    test('login com sucesso deve atualizar estado do usuário', () async {
      when(() => mockAuthService.login('POL1', '1234')).thenAnswer((_) async => mockUser);

      await authProvider.login('POL1', '1234');

      expect(authProvider.isLogged, isTrue);
      expect(authProvider.usuario?.nomeCompleto, 'Test');
    });

    test('login com erro deve repassar exceção e parar loading', () async {
      when(() => mockAuthService.login('POL1', '0000'))
          .thenThrow(AuthException('Senha errada'));

      // Act & Assert
      expect(
        () async => await authProvider.login('POL1', '0000'),
        throwsA(isA<AuthException>()),
      );

      // Loading deve ter parado mesmo com erro
      expect(authProvider.isLoading, isFalse);
    });

    test('logout deve realizar Hard Logout (null na memória)', () async {
      // Simula estar logado primeiro
      when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => mockUser);
      await authProvider.login('POL1', '1234');
      
      // Configura logout do service
      when(() => mockAuthService.logout()).thenAnswer((_) async {});

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.isLogged, isFalse);
      expect(authProvider.usuario, isNull); // Memória limpa
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';

class MockUsuarioRepository extends Mock implements UsuarioRepository {}
class MockKeyStorage extends Mock implements KeyStorageInterface {}
class MockRemoteDataSource extends Mock implements IRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUsuarioRepository mockUsuarioRepository;
  late MockKeyStorage mockKeyStorage;
  late MockRemoteDataSource mockRemoteDataSource;
  late AuthService authService;

  setUpAll(() {
    registerFallbackValue(Usuario(
      id: 'dummy',
      matriculaFuncional: 'dummy',
      nomeCompleto: 'dummy',
      roles: const <String>[],
      ativo: true,
      hashPinOffline: 'dummy',
      salt: 'dummy',
      criadoEm: DateTime.now(),
    ));
  });

  setUp(() {
    mockUsuarioRepository = MockUsuarioRepository();
    mockKeyStorage = MockKeyStorage();
    mockRemoteDataSource = MockRemoteDataSource();
    authService = AuthService(
      mockUsuarioRepository,
      mockKeyStorage,
      mockRemoteDataSource,
    );

    when(() => mockKeyStorage.save(
      key: any(named: 'key'),
      value: any(named: 'value'),
    )).thenAnswer((_) async {});

    when(() => mockUsuarioRepository.createUsuario(any()))
        .thenAnswer((_) async => 1);
  });

  group('AuthService - RBAC Trava Estrita e Segurança de Tokens', () {
    test('Permite login e salva token quando usuário possui role PERITO', () async {
      when(() => mockRemoteDataSource.login('123456', '1234')).thenAnswer((_) async => <String, dynamic>{
        'access_token': 'token_jwt_valido',
        'refresh_token': 'refresh_token_valido',
        'user': <String, dynamic>{
          'id': 'usr-001',
          'nome': 'Dr. Perito Oficial',
          'roles': <String>['PERITO'],
        },
      });

      await authService.login('123456', '1234');

      expect(authService.isLogged, isTrue);
      expect(authService.usuario?.id, equals('usr-001'));
      verify(() => mockKeyStorage.save(key: 'access_token', value: 'token_jwt_valido')).called(1);
      verify(() => mockRemoteDataSource.setBearerToken('token_jwt_valido')).called(1);
    });

    test('Permite login e salva token quando usuário possui role MEDICO_LEGISTA', () async {
      when(() => mockRemoteDataSource.login('legista01', '1234')).thenAnswer((_) async => <String, dynamic>{
        'access_token': 'token_jwt_legista',
        'user': <String, dynamic>{
          'id': 'usr-002',
          'nome': 'Dra. Médica Legista',
          'roles': <String>['MEDICO_LEGISTA'],
        },
      });

      await authService.login('legista01', '1234');

      expect(authService.isLogged, isTrue);
      verify(() => mockKeyStorage.save(key: 'access_token', value: 'token_jwt_legista')).called(1);
    });

    test('Permite login e salva token quando usuário possui role ADMIN', () async {
      when(() => mockRemoteDataSource.login('admin', '1234')).thenAnswer((_) async => <String, dynamic>{
        'access_token': 'token_jwt_admin',
        'user': <String, dynamic>{
          'id': 'usr-003',
          'nome': 'Administrador Central',
          'roles': <String>['ADMIN'],
        },
      });

      await authService.login('admin', '1234');

      expect(authService.isLogged, isTrue);
      verify(() => mockKeyStorage.save(key: 'access_token', value: 'token_jwt_admin')).called(1);
    });

    test('BLOQUEIA ACESSO e NÃO SALVA token no KeyStorage quando role não é autorizada (ex: ATN)', () async {
      when(() => mockRemoteDataSource.login('atn_user', '1234')).thenAnswer((_) async => <String, dynamic>{
        'access_token': 'token_proibido_123',
        'user': <String, dynamic>{
          'id': 'usr-999',
          'nome': 'Auxiliar Técnico',
          'roles': <String>['ATN'],
        },
      });

      expect(
        () => authService.login('atn_user', '1234'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Acesso restrito'),
          ),
        ),
      );

      expect(authService.isLogged, isFalse);
      expect(authService.usuario, isNull);

      verifyNever(() => mockKeyStorage.save(key: 'access_token', value: any(named: 'value')));
      verifyNever(() => mockKeyStorage.save(key: 'refresh_token', value: any(named: 'value')));
      verifyNever(() => mockKeyStorage.save(key: 'user_id', value: any(named: 'value')));
      verifyNever(() => mockRemoteDataSource.setBearerToken(any()));
      verifyNever(() => mockUsuarioRepository.createUsuario(any()));
    });

    test('BLOQUEIA ACESSO e NÃO SALVA token quando lista de roles é vazia', () async {
      when(() => mockRemoteDataSource.login('user_sem_role', '1234')).thenAnswer((_) async => <String, dynamic>{
        'access_token': 'token_vazio_123',
        'user': <String, dynamic>{
          'id': 'usr-000',
          'nome': 'Usuário Indefinido',
          'roles': <String>[],
        },
      });

      expect(
        () => authService.login('user_sem_role', '1234'),
        throwsA(isA<AuthException>()),
      );

      verifyNever(() => mockKeyStorage.save(key: 'access_token', value: any(named: 'value')));
      verifyNever(() => mockRemoteDataSource.setBearerToken(any()));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/domain/services/device_info_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/sync_provider.dart';

class MockRemoteDataSource extends Mock implements IRemoteDataSource {}
class MockSyncRepository extends Mock implements ISyncRepository {}
class MockAuthService extends Mock implements AuthService {}
class MockKeyStorage extends Mock implements KeyStorageInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRemoteDataSource mockRemoteDataSource;
  late MockSyncRepository mockSyncRepository;
  late MockAuthService mockAuthService;
  late MockKeyStorage mockKeyStorage;
  late SyncService syncService;

  final usuarioTeste = Usuario(
    id: 'perito-001',
    matriculaFuncional: '123456',
    nomeCompleto: 'Dr. Perito Legista',
    roles: const <String>['PERITO'],
    ativo: true,
    hashPinOffline: 'hash',
    salt: 'salt',
    criadoEm: DateTime.now(),
  );

  setUp(() {
    DeviceInfoService.setMockDeviceId('device-test-id');
    mockRemoteDataSource = MockRemoteDataSource();
    mockSyncRepository = MockSyncRepository();
    mockAuthService = MockAuthService();
    mockKeyStorage = MockKeyStorage();

    when(() => mockKeyStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockKeyStorage.save(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async {});

    syncService = SyncService(
      remoteDataSource: mockRemoteDataSource,
      repository: mockSyncRepository,
      authService: mockAuthService,
      keyStorage: mockKeyStorage,
    );
  });

  tearDown(() {
    DeviceInfoService.setMockDeviceId(null);
  });

  group('SyncService - Blindagem contra Falsos Positivos de Sincronização', () {
    test('Lança SyncNetworkException e aborta ciclo imediatamente quando o backend está offline', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => false);

      expect(
        () => syncService.execute(),
        throwsA(isA<SyncNetworkException>().having(
          (e) => e.message,
          'message',
          contains('Servidor central indisponível'),
        )),
      );

      verifyNever(() => mockRemoteDataSource.pullCasos(lastSyncTimestamp: any(named: 'lastSyncTimestamp')));
      verifyNever(() => mockSyncRepository.getCasosPendentesSync(any()));
      verifyNever(() => mockRemoteDataSource.pushTextual(any()));
    });

    test('Lança AuthException quando o servidor está online mas nenhum perito está autenticado', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => true);
      when(() => mockAuthService.usuario).thenReturn(null);

      expect(
        () => syncService.execute(),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Nenhum perito autenticado'),
        )),
      );
    });

    test('Retorna SyncResult com mensagem descritiva de ausência de pendências quando 0 casos forem enviados', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => true);
      when(() => mockAuthService.usuario).thenReturn(usuarioTeste);
      when(() => mockRemoteDataSource.pullCasos(lastSyncTimestamp: any(named: 'lastSyncTimestamp')))
          .thenAnswer((_) async => <Map<String, dynamic>>[]);
      when(() => mockSyncRepository.getCasosPendentesSync('perito-001'))
          .thenAnswer((_) async => <Caso>[]);

      final result = await syncService.execute();

      expect(result.casosEnviados, 0);
      expect(result.casosRecebidos, 0);
      expect(result.temPendencias, false);
      expect(result.mensagem, 'Tudo atualizado. Nenhum laudo pendente de sincronização.');
    });

    test('Repassa SyncPushTextualException e não emite falso positivo caso o push bulk falhe', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => true);
      when(() => mockAuthService.usuario).thenReturn(usuarioTeste);
      when(() => mockRemoteDataSource.pullCasos(lastSyncTimestamp: any(named: 'lastSyncTimestamp')))
          .thenAnswer((_) async => <Map<String, dynamic>>[]);

      final casoPendente = Caso.fromMap({
        'uuid': 'caso-uuid-001',
        'id_usuario_criador': 'perito-001',
        'status': 'FINALIZADO',
      });

      when(() => mockSyncRepository.getCasosPendentesSync('perito-001'))
          .thenAnswer((_) async => <Caso>[casoPendente]);
      when(() => mockSyncRepository.getAchadosEmLote(any()))
          .thenAnswer((_) async => <String, List<Achado>>{'caso-uuid-001': []});
      when(() => mockRemoteDataSource.pushTextual(any()))
          .thenThrow(const SyncPushTextualException('Erro interno do servidor', statusCode: 500));

      expect(
        () => syncService.execute(),
        throwsA(isA<SyncPushTextualException>()),
      );
    });
  });

  group('SyncProvider - Notificação de Estado e Feedback de UI', () {
    test('Transiciona para SyncState.error sem falso positivo de sucesso quando backend estiver fora do ar', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => false);

      final provider = SyncProvider(syncService);
      final estadosCapturados = <SyncState>[];
      String? capturedError;
      provider.addListener(() {
        estadosCapturados.add(provider.state);
        if (provider.state == SyncState.error) {
          capturedError = provider.errorMessage;
        }
      });

      await provider.startSync();

      expect(estadosCapturados, contains(SyncState.loading));
      expect(estadosCapturados, contains(SyncState.error));
      expect(estadosCapturados, isNot(contains(SyncState.success)));
      expect(capturedError, contains('Servidor central indisponível'));

      provider.dispose();
    });

    test('Transiciona para SyncState.success com mensagem clara quando não há pendências', () async {
      when(() => mockRemoteDataSource.checkHealth()).thenAnswer((_) async => true);
      when(() => mockAuthService.usuario).thenReturn(usuarioTeste);
      when(() => mockRemoteDataSource.pullCasos(lastSyncTimestamp: any(named: 'lastSyncTimestamp')))
          .thenAnswer((_) async => <Map<String, dynamic>>[]);
      when(() => mockSyncRepository.getCasosPendentesSync('perito-001'))
          .thenAnswer((_) async => <Caso>[]);

      final provider = SyncProvider(syncService);
      final estadosCapturados = <SyncState>[];
      String? capturedFeedback;
      provider.addListener(() {
        estadosCapturados.add(provider.state);
        if (provider.state == SyncState.success) {
          capturedFeedback = provider.feedbackMessage;
        }
      });

      await provider.startSync();

      expect(estadosCapturados, contains(SyncState.loading));
      expect(estadosCapturados, contains(SyncState.success));
      expect(estadosCapturados, isNot(contains(SyncState.error)));
      expect(capturedFeedback, 'Tudo atualizado. Nenhum laudo pendente de sincronização.');

      provider.dispose();
    });
  });
}


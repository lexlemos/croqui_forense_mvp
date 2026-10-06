import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/data/models/parsed_sync_payload.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/active_case_lock_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class MockRemoteDataSource extends Mock implements IRemoteDataSource {}
class MockSyncRepository extends Mock implements ISyncRepository {}
class MockKeyStorage extends Mock implements KeyStorageInterface {}

class FakeParsedSyncPayload extends Fake implements ParsedSyncPayload {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeParsedSyncPayload());
  });

  group('SyncService com ActiveCaseLockService (ADR-0002)', () {
    late MockRemoteDataSource mockRemoteDataSource;
    late MockSyncRepository mockSyncRepository;
    late MockKeyStorage mockKeyStorage;
    late IActiveCaseLockService lockService;
    late SyncService syncService;

    setUp(() {
      mockRemoteDataSource = MockRemoteDataSource();
      mockSyncRepository = MockSyncRepository();
      mockKeyStorage = MockKeyStorage();
      lockService = ActiveCaseLockService();

      when(() => mockKeyStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockKeyStorage.save(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => mockSyncRepository.upsertCasoTransaction(any()))
          .thenAnswer((_) async {});

      syncService = SyncService(
        remoteDataSource: mockRemoteDataSource,
        repository: mockSyncRepository,
        keyStorage: mockKeyStorage,
        activeCaseLockService: lockService,
      );
    });

    test(
      'Ignora upsert de caso remoto bloqueado em edição ativa e processa os demais',
      () async {
        final casoAtivoJson = {
          'uuid': 'caso-em-edicao-ativa',
          'numero_requisicao': 'REQ-101',
          'status': 'EM_ANDAMENTO',
          'atualizado_em': '2026-10-06T12:00:00Z',
        };

        final casoLivreJson = {
          'uuid': 'caso-livre',
          'numero_requisicao': 'REQ-102',
          'status': 'FINALIZADO',
          'atualizado_em': '2026-10-06T11:00:00Z',
        };

        // Bloqueia o primeiro caso simulando a tela do Croqui aberta
        lockService.acquireLock('caso-em-edicao-ativa');

        when(
          () => mockRemoteDataSource.pullCasos(
            lastSyncTimestamp: any(named: 'lastSyncTimestamp'),
          ),
        ).thenAnswer((_) async => [casoAtivoJson, casoLivreJson]);

        await syncService.pullCasos();

        // 1. Verifica que upsertCasoTransaction foi chamado para o caso livre
        verify(
          () => mockSyncRepository.upsertCasoTransaction(
            any(that: predicate<ParsedSyncPayload>((p) => p.caso.uuid == 'caso-livre')),
          ),
        ).called(1);

        // 2. Verifica que upsertCasoTransaction NUNCA foi chamado para o caso bloqueado
        verifyNever(
          () => mockSyncRepository.upsertCasoTransaction(
            any(that: predicate<ParsedSyncPayload>((p) => p.caso.uuid == 'caso-em-edicao-ativa')),
          ),
        );

        // 3. Verifica que o caso bloqueado foi devidamente catalogado
        expect(
          syncService.laudosIgnoradosPorEdicaoAtiva,
          contains('caso-em-edicao-ativa'),
        );
        expect(
          syncService.laudosIgnoradosPorEdicaoAtiva,
          isNot(contains('caso-livre')),
        );
      },
    );
  });
}

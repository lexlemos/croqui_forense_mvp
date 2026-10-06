import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/platform/safe_wakelock.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/sync_provider.dart';

class MockSyncService extends Mock implements SyncService {}
class MockWakelockManager extends Mock implements IWakelockManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncProvider com SafeWakelock (ADR-0001)', () {
    late MockSyncService mockSyncService;
    late MockWakelockManager mockWakelockManager;
    late SyncProvider syncProvider;

    setUp(() {
      mockSyncService = MockSyncService();
      mockWakelockManager = MockWakelockManager();

      when(() => mockWakelockManager.enable()).thenAnswer((_) async {});
      when(() => mockWakelockManager.disable()).thenAnswer((_) async {});
      when(() => mockWakelockManager.isEnabled).thenAnswer((_) async => false);

      syncProvider = SyncProvider(
        mockSyncService,
        wakelockManager: mockWakelockManager,
      );
    });

    test(
      'Habilita wakelock ao iniciar sincronização e desabilita em caso de sucesso',
      () async {
        when(() => mockSyncService.execute()).thenAnswer(
          (_) async => SyncResult.sucesso(casosEnviados: 1),
        );

        await syncProvider.startSync();

        verifyInOrder([
          () => mockWakelockManager.enable(),
          () => mockSyncService.execute(),
          () => mockWakelockManager.disable(),
        ]);
      },
    );

    test(
      'Garante desabilitação do wakelock mesmo quando SyncService lança SyncNetworkException',
      () async {
        when(() => mockSyncService.execute()).thenThrow(
          const SyncNetworkException('Erro de conectividade'),
        );

        await syncProvider.startSync();

        verify(() => mockWakelockManager.enable()).called(1);
        verify(() => mockWakelockManager.disable()).called(1);
        expect(syncProvider.state, equals(SyncState.idle));
      },
    );

    test(
      'Garante desabilitação do wakelock mesmo quando SyncService lança AuthException',
      () async {
        when(() => mockSyncService.execute()).thenThrow(
          const AuthException('Sessão expirada'),
        );

        await syncProvider.startSync();

        verify(() => mockWakelockManager.enable()).called(1);
        verify(() => mockWakelockManager.disable()).called(1);
        expect(syncProvider.state, equals(SyncState.idle));
      },
    );
  });
}

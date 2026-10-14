import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/datasources/remote_data_source_impl.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/domain/services/domain_sync_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAtnRepository extends Mock implements AtnRepository {}

class MockInjuryTypeRepository extends Mock implements InjuryTypeRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ATNs Mocks e Rota Remota Desativada', () {
    test(
      '1. RemoteDataSourceImpl.getAtns retorna lista de mocks sem requisicao HTTP remota',
      () async {
        final mockApiClient = MockApiClient();
        final remoteDataSource = RemoteDataSourceImpl(mockApiClient);

        final result = await remoteDataSource.getAtns();

        expect(result, isNotEmpty);
        expect(result.length, equals(kMockAtnsRaw.length));
        expect(result.first['nome'], contains('ATN'));
      },
    );

    test(
      '2. AtnModel.fromMap deserializa com sucesso todos os mocks padrao',
      () {
        final models = kMockAtnsRaw.map((m) => AtnModel.fromMap(m)).toList();

        expect(models.length, equals(5));
        for (final atn in models) {
          expect(atn.id, isNotEmpty);
          expect(atn.nome, isNotEmpty);
          expect(atn.ativo, isTrue);
        }
      },
    );

    test(
      '3. DomainSyncService.syncAtns invoca semearMocksSeNecessario no repositorio',
      () async {
        final mockApiClient = MockApiClient();
        final remoteDataSource = RemoteDataSourceImpl(mockApiClient);
        final mockAtnRepo = MockAtnRepository();
        final mockInjuryRepo = MockInjuryTypeRepository();

        when(
          () => mockAtnRepo.semearMocksSeNecessario(),
        ).thenAnswer((_) async {});

        final domainSyncService = DomainSyncService(
          remoteDataSource: remoteDataSource,
          injuryTypeRepository: mockInjuryRepo,
          atnRepository: mockAtnRepo,
        );

        await domainSyncService.syncAtns();

        verify(() => mockAtnRepo.semearMocksSeNecessario()).called(1);
      },
    );
  });
}

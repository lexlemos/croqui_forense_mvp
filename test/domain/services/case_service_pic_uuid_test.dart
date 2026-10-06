import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

class MockCasoRepository extends Mock implements CasoRepository {}
class MockUsuarioRepository extends Mock implements UsuarioRepository {}
class MockRemoteDataSource extends Mock implements IRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaseService.createNewCase - Preservação do UUID Oficial (PIC Lookup)', () {
    late MockCasoRepository mockCasoRepository;
    late MockUsuarioRepository mockUsuarioRepository;
    late MockRemoteDataSource mockRemoteDataSource;
    late CaseService caseService;

    final usuarioTeste = Usuario(
      id: 'perito-001',
      matriculaFuncional: '123456',
      nomeCompleto: 'Dr. Legista',
      roles: const ['PERITO'],
      ativo: true,
      hashPinOffline: 'hash',
      salt: 'salt',
      criadoEm: DateTime.now(),
    );

    setUpAll(() {
      registerFallbackValue(Caso.novo(idUsuarioCriador: 'dummy'));
    });

    setUp(() {
      mockCasoRepository = MockCasoRepository();
      mockUsuarioRepository = MockUsuarioRepository();
      mockRemoteDataSource = MockRemoteDataSource();

      caseService = CaseService(
        mockCasoRepository,
        mockUsuarioRepository,
        mockRemoteDataSource,
      );
    });

    test('preserva o uuid oficial fornecido pela consulta do backend', () async {
      const oficialUuid = '09fff950-a98f-4ae6-ab7f-b5028647969c';

      when(() => mockCasoRepository.getCaseByUuid(oficialUuid))
          .thenAnswer((_) async => null);
      when(() => mockCasoRepository.insertCase(any()))
          .thenAnswer((_) async {});

      final caso = await caseService.createNewCase(
        criador: usuarioTeste,
        numeroLaudo: 'CD-1320821',
        numeroPic: 'PIC-2026-001',
        uuid: oficialUuid,
      );

      expect(caso.uuid, equals(oficialUuid));
      verify(() => mockCasoRepository.insertCase(any(
        that: predicate<Caso>((c) => c.uuid == oficialUuid),
      ))).called(1);
    });

    test('gera novo UUID v4 quando nenhum uuid for fornecido', () async {
      when(() => mockCasoRepository.insertCase(any()))
          .thenAnswer((_) async {});

      final caso = await caseService.createNewCase(
        criador: usuarioTeste,
        numeroLaudo: 'CD-1320822',
        numeroPic: 'PIC-NOVO',
      );

      expect(caso.uuid, isNotEmpty);
      expect(caso.uuid.length, equals(36)); // UUID v4 format
      verify(() => mockCasoRepository.insertCase(any())).called(1);
    });

    test('retorna o caso local existente se o uuid oficial já estiver gravado', () async {
      const oficialUuid = '09fff950-a98f-4ae6-ab7f-b5028647969c';
      final casoExistente = Caso.novo(
        uuid: oficialUuid,
        idUsuarioCriador: usuarioTeste.id,
        numeroPic: 'PIC-2026-001',
      );

      when(() => mockCasoRepository.getCaseByUuid(oficialUuid))
          .thenAnswer((_) async => casoExistente);

      final caso = await caseService.createNewCase(
        criador: usuarioTeste,
        numeroLaudo: 'CD-1320821',
        numeroPic: 'PIC-2026-001',
        uuid: oficialUuid,
      );

      expect(caso.uuid, equals(oficialUuid));
      verifyNever(() => mockCasoRepository.insertCase(any()));
    });
  });
}

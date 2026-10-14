import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

class MockCasoRepository extends Mock implements CasoRepository {}

class MockUsuarioRepository extends Mock implements UsuarioRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaseService - Deep Module Operations (Tópico 04)', () {
    late MockCasoRepository mockCasoRepository;
    late MockUsuarioRepository mockUsuarioRepository;
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
      registerFallbackValue(
        EvidenciaMultimidia.novo(
          casoUuid: 'dummy',
          tipo: 'GERAL',
          caminhoArquivoEncriptado: '/path/test.jpg',
        ),
      );
    });

    setUp(() {
      mockCasoRepository = MockCasoRepository();
      mockUsuarioRepository = MockUsuarioRepository();
      caseService = CaseService(mockCasoRepository, mockUsuarioRepository);
    });

    test(
      '1. createNewCase com evidencias salva atomicamente em lote via insertCaseComEvidenciasLote',
      () async {
        when(
          () => mockCasoRepository.getCaseByUuid(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCasoRepository.insertCaseComEvidenciasLote(any(), any()),
        ).thenAnswer((_) async {});

        final evidencias = [
          EvidenciaMultimidia.novo(
            casoUuid: 'caso-uuid-001',
            tipo: 'GERAL',
            caminhoArquivoEncriptado: '/data/foto1.jpg',
            descricao: 'Foto geral frontal',
          ),
        ];

        final caso = await caseService.createNewCase(
          criador: usuarioTeste,
          numeroLaudo: 'LAUDO-2026-001',
          evidencias: evidencias,
        );

        expect(caso, isNotNull);
        verify(
          () => mockCasoRepository.insertCaseComEvidenciasLote(
            any(
              that: predicate<Caso>(
                (c) => c.numeroLaudoExterno == 'LAUDO-2026-001',
              ),
            ),
            evidencias,
          ),
        ).called(1);
        verifyNever(() => mockCasoRepository.insertCase(any()));
      },
    );

    test(
      '2. createNewCase sem evidencias delega para insertCase tradicional',
      () async {
        when(
          () => mockCasoRepository.getCaseByUuid(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCasoRepository.insertCase(any()),
        ).thenAnswer((_) async {});

        final caso = await caseService.createNewCase(
          criador: usuarioTeste,
          numeroLaudo: 'LAUDO-2026-002',
        );

        expect(caso, isNotNull);
        verify(
          () => mockCasoRepository.insertCase(
            any(
              that: predicate<Caso>(
                (c) => c.numeroLaudoExterno == 'LAUDO-2026-002',
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => mockCasoRepository.insertCaseComEvidenciasLote(any(), any()),
        );
      },
    );

    test('3. expurgarCasosAntigos delega para CasoRepository', () async {
      when(
        () => mockCasoRepository.expurgarCasosAntigos(),
      ).thenAnswer((_) async {});

      await caseService.expurgarCasosAntigos();

      verify(() => mockCasoRepository.expurgarCasosAntigos()).called(1);
    });

    test(
      '4. getExamesPorCaso delega para CasoRepository e retorna lista tipada',
      () async {
        when(
          () => mockCasoRepository.getExamesPorCaso('caso-123'),
        ).thenAnswer((_) async => []);

        final result = await caseService.getExamesPorCaso('caso-123');

        expect(result, isEmpty);
        verify(() => mockCasoRepository.getExamesPorCaso('caso-123')).called(1);
      },
    );

    test(
      '5. salvarExames delega para CasoRepository com a lista de modelos se laudo não finalizado',
      () async {
        when(
          () => mockCasoRepository.getCaseByUuid('caso-123'),
        ).thenAnswer((_) async => null);
        when(
          () => mockCasoRepository.salvarExames('caso-123', any()),
        ).thenAnswer((_) async {});

        await caseService.salvarExames('caso-123', []);

        verify(() => mockCasoRepository.salvarExames('caso-123', [])).called(1);
      },
    );

    test(
      '5b. salvarExames bloqueia e lanca Exception caso laudo esteja finalizado',
      () async {
        final casoFinalizado = Caso.novo(
          uuid: 'caso-123',
          idUsuarioCriador: 'perito-001',
        ).copyWith(status: StatusCaso.finalizado);
        when(
          () => mockCasoRepository.getCaseByUuid('caso-123'),
        ).thenAnswer((_) async => casoFinalizado);

        expect(
          () => caseService.salvarExames('caso-123', []),
          throwsA(isA<Exception>()),
        );
        verifyNever(() => mockCasoRepository.salvarExames(any(), any()));
      },
    );

    test(
      '6. getEvidenciasPorCaso delega para CasoRepository com a lista completa',
      () async {
        when(
          () => mockCasoRepository.getEvidenciasPorCaso('caso-123'),
        ).thenAnswer((_) async => []);

        final result = await caseService.getEvidenciasPorCaso('caso-123');

        expect(result, isEmpty);
        verify(
          () => mockCasoRepository.getEvidenciasPorCaso('caso-123'),
        ).called(1);
      },
    );
  });
}

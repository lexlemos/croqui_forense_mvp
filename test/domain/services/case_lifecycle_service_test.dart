import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_engine.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_lifecycle_service.dart';

class MockCaseService extends Mock implements CaseService {}
class MockPdfReportEngine extends Mock implements IPdfReportEngine {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCaseService mockCaseService;
  late MockPdfReportEngine mockPdfEngine;
  late MockSyncService mockSyncService;
  late CaseLifecycleService lifecycleService;

  final usuarioPerito = Usuario(
    id: 'perito-001',
    matriculaFuncional: '123456',
    nomeCompleto: 'Dr. Perito Oficial',
    roles: const <String>['MEDICO_LEGISTA'],
    ativo: true,
    hashPinOffline: 'hash',
    salt: 'salt',
    criadoEm: DateTime.now(),
  );

  final casoBase = Caso.fromMap({
    'uuid': 'caso-uuid-001',
    'id_usuario_criador': 'perito-001',
    'numero_requisicao': '2026/001',
    'numero_laudo_externo': '2026/001',
    'status': 'EM_ANDAMENTO',
    'versao': 1,
    'removido': 0,
    'criado_em_dispositivo': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    'atualizado_em': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
  });

  setUpAll(() {
    registerFallbackValue(casoBase);
    registerFallbackValue(const PdfReportOptions());
  });

  setUp(() {
    mockCaseService = MockCaseService();
    mockPdfEngine = MockPdfReportEngine();
    mockSyncService = MockSyncService();

    when(() => mockCaseService.salvarRascunho(any())).thenAnswer((_) async {});
    when(() => mockSyncService.pushCasoRascunho(any())).thenAnswer((_) async {});

    lifecycleService = CaseLifecycleService(
      caseService: mockCaseService,
      pdfEngine: mockPdfEngine,
      syncService: mockSyncService,
    );
  });

  group('CaseLifecycleService - Transição de Estado e Integridade Forense', () {
    test('1. markPending transiciona para laudoPendente, incrementa versao (OCC) e enfileira push', () async {
      final resultado = await lifecycleService.markPending(casoBase);

      expect(resultado.status, equals(StatusCaso.laudoPendente));
      expect(resultado.versao, equals(2));
      expect(resultado.isDraftSynced, isFalse);
      verify(() => mockCaseService.salvarRascunho(any(that: predicate<Caso>((c) =>
          c.status == StatusCaso.laudoPendente && c.versao == 2)))).called(1);
      verify(() => mockSyncService.pushCasoRascunho(any())).called(1);
    });

    test('2. concludeCase bloqueia e lança ExamesPendentesException quando houver exames aguardando', () async {
      final List<ExameSolicitadoModel> examesComPendencia = [
        ExameSolicitadoModel(
          uuid: 'exame-01',
          casoUuid: casoBase.uuid,
          tipoExame: 'Toxicologia',
          status: 'aguardando',
          criadoEm: DateTime.now(),
        ),
      ];

      expect(
        () => lifecycleService.concludeCase(
          caso: casoBase,
          perito: usuarioPerito,
          examesModel: examesComPendencia,
        ),
        throwsA(isA<ExamesPendentesException>()),
      );

      verifyZeroInteractions(mockPdfEngine);
    });

    test('3. concludeCase gera PDF via IPdfReportEngine, define pdfLocalPath e finaliza com versao + 1', () async {
      final fakePdfFile = File('dummy/laudo_oficial.pdf');
      when(() => mockPdfEngine.generatePdfFile(
            any(),
            achados: any(named: 'achados'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => fakePdfFile);

      final resultado = await lifecycleService.concludeCase(
        caso: casoBase,
        perito: usuarioPerito,
        examesModel: const [],
      );

      expect(resultado.status, equals(StatusCaso.finalizado));
      expect(resultado.pdfLocalPath, equals(fakePdfFile.path));
      expect(resultado.versao, equals(2));
      expect(resultado.finalizadoEm, isNotNull);

      verify(() => mockPdfEngine.generatePdfFile(any(), options: any(named: 'options'))).called(1);
      verify(() => mockCaseService.salvarRascunho(any(that: predicate<Caso>((c) =>
          c.status == StatusCaso.finalizado && c.pdfLocalPath == fakePdfFile.path)))).called(1);
      verify(() => mockSyncService.pushCasoRascunho(any())).called(1);
    });

    test('4. reopenCase invoca CaseService.reabrirCaso e retorna caso com status em andamento', () async {
      final casoReaberto = casoBase.copyWith(status: StatusCaso.emAndamento, versao: 3);
      when(() => mockCaseService.reabrirCaso('caso-uuid-001')).thenAnswer((_) async {});
      when(() => mockCaseService.buscarCasoPorUuid('caso-uuid-001')).thenAnswer((_) async => casoReaberto);

      final resultado = await lifecycleService.reopenCase('caso-uuid-001');

      expect(resultado.status, equals(StatusCaso.emAndamento));
      verify(() => mockCaseService.reabrirCaso('caso-uuid-001')).called(1);
      verify(() => mockCaseService.buscarCasoPorUuid('caso-uuid-001')).called(1);
    });
  });
}

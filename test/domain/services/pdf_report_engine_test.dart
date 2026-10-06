import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_engine.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';

class MockPdfService extends Mock implements PdfService {}
class MockPdfReportService extends Mock implements PdfReportService {}
class MockCaseService extends Mock implements CaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Cabeçalho binário padrão PDF (%PDF-1.4)
  final fakePdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

  final casoTeste = Caso.novo(
    idUsuarioCriador: 'perito-001',
    numeroLaudoExterno: 'CD-2026-999',
    numeroPic: 'PIC-2026-777',
    numeroBo: 'BO-2026-555',
    nomeVitima: 'Vítima de Teste Pericial',
    destino: '1ª Vara Criminal',
    requisitante: 'Delegacia de Homicídios',
  );

  setUpAll(() {
    registerFallbackValue(casoTeste);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Usuario(
      id: 'p1',
      matriculaFuncional: '1',
      nomeCompleto: 'Dr. Teste',
      roles: const ['PERITO'],
      ativo: true,
      hashPinOffline: '',
      salt: '',
      criadoEm: DateTime.now(),
    ));
  });

  group('PdfReportEngine - Unificação e Compilação Vetorial', () {
    late MockPdfService mockPdfService;
    late MockPdfReportService mockPdfReportService;
    late MockCaseService mockCaseService;
    late IPdfReportEngine engine;

    setUp(() {
      mockPdfService = MockPdfService();
      mockPdfReportService = MockPdfReportService();
      mockCaseService = MockCaseService();

      when(() => mockPdfService.gerarLaudoPdf(
            caso: any(named: 'caso'),
            achados: any(named: 'achados'),
            perito: any(named: 'perito'),
            schemas: any(named: 'schemas'),
            exames: any(named: 'exames'),
            examesModel: any(named: 'examesModel'),
            evidenciasGerais: any(named: 'evidenciasGerais'),
          )).thenAnswer((_) async => fakePdfBytes);

      when(() => mockPdfReportService.salvarPdfNoDispositivo(
            caso: any(named: 'caso'),
            pdfBytes: any(named: 'pdfBytes'),
            caseService: any(named: 'caseService'),
          )).thenAnswer((_) async => '/tmp/laudo_teste.pdf');

      engine = PdfReportEngine(
        pdfService: mockPdfService,
        reportService: mockPdfReportService,
      );
    });

    test('generatePdfBytes sintetiza perito padrão e compila PDF com cabeçalho %PDF-', () async {
      final bytes = await engine.generatePdfBytes(
        casoTeste,
        achados: const <Achado>[],
      );

      expect(bytes, equals(fakePdfBytes));
      verify(() => mockPdfService.gerarLaudoPdf(
            caso: casoTeste,
            achados: any(named: 'achados'),
            perito: any(named: 'perito'),
            schemas: any(named: 'schemas'),
            exames: any(named: 'exames'),
            examesModel: any(named: 'examesModel'),
            evidenciasGerais: any(named: 'evidenciasGerais'),
          )).called(1);
    });

    test('generatePdfFile persiste no destinationFile e atualiza no CaseService se informado', () async {
      final tempDir = await Directory.systemTemp.createTemp('pdf_engine_test_');
      final targetFile = File('${tempDir.path}/laudo_teste.pdf');

      when(() => mockCaseService.atualizarCaminhoPdf(any(), any()))
          .thenAnswer((_) async {});

      final file = await engine.generatePdfFile(
        casoTeste,
        achados: const <Achado>[],
        destinationFile: targetFile,
        options: PdfReportOptions(caseService: mockCaseService),
      );

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), equals(fakePdfBytes));
      verify(() => mockCaseService.atualizarCaminhoPdf(casoTeste.uuid, targetFile.path)).called(1);

      await tempDir.delete(recursive: true);
    });

    test('generatePdfFile delega para PdfReportService quando destinationFile não for fornecido', () async {
      final file = await engine.generatePdfFile(
        casoTeste,
        achados: const <Achado>[],
      );

      expect(file.path, equals('/tmp/laudo_teste.pdf'));
      verify(() => mockPdfReportService.salvarPdfNoDispositivo(
            caso: casoTeste,
            pdfBytes: fakePdfBytes,
            caseService: any(named: 'caseService'),
          )).called(1);
    });
  });
}

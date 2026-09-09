import 'dart:typed_data';

import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';

/// Fachada de geração e persistência de PDFs do laudo.
///
/// Mantém o motor existente encapsulado para que os controllers coordenem o
/// fluxo da tela sem conhecer detalhes de geração ou armazenamento do PDF.
class PdfGenerationService {
  final PdfService _pdfService;
  final PdfReportService _reportService;

  PdfGenerationService({PdfService? pdfService, PdfReportService? reportService})
      : _pdfService = pdfService ?? PdfService(),
        _reportService = reportService ?? PdfReportService();

  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    Map<String, dynamic>? schemas,
    required List<ExameSolicitado> exames,
    List<em.ExameSolicitadoModel>? examesModel,
    required List<EvidenciaMultimidia> evidenciasGerais,
  }) {
    return _pdfService.gerarLaudoPdf(
      caso: caso,
      achados: achados,
      perito: perito,
      schemas: schemas,
      exames: exames,
      examesModel: examesModel,
      evidenciasGerais: evidenciasGerais,
    );
  }

  Future<String> salvarPdfNoDispositivo({
    required Caso caso,
    required Uint8List pdfBytes,
    required CaseService caseService,
  }) {
    return _reportService.salvarPdfNoDispositivo(
      caso: caso,
      pdfBytes: pdfBytes,
      caseService: caseService,
    );
  }
}

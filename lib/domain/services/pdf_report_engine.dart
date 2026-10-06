import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';

/// Opções de configuração e renderização visual para a emissão do laudo em PDF.
class PdfReportOptions {
  /// Perito médico-legista autenticado. Se nulo, sintetiza as credenciais dos metadados de auditoria do caso.
  final Usuario? perito;

  /// Lista estruturada de exames complementares solicitados. Se nulo, obtém de [Caso.exames].
  final List<em.ExameSolicitadoModel>? examesModel;

  /// Coleção de evidências fotográficas gerais. Se nulo, obtém de [Caso.evidenciasMultimidia].
  final List<EvidenciaMultimidia>? evidenciasGerais;

  /// Lista legada de exames solicitados.
  final List<ExameSolicitado> exames;

  /// Metadados opcionais de esquemas adicionais do formulário.
  final Map<String, dynamic>? schemas;

  /// Serviço de casos para atualizar o caminho do PDF no banco local SQLite, se fornecido.
  final CaseService? caseService;

  const PdfReportOptions({
    this.perito,
    this.examesModel,
    this.evidenciasGerais,
    this.exames = const [],
    this.schemas,
    this.caseService,
  });
}

/// Contrato do motor unificado e profundo de geração de laudos médico-legais em PDF.
///
/// Encapsula a complexidade de compilação gráfica vetorial, diagramas anatômicos,
/// tabelas de achados, cadeias balísticas e fotografias periciais atrás de uma interface simples.
abstract interface class IPdfReportEngine {
  /// Compila o documento oficial do laudo pericial em segundo plano via Isolate (`compute`).
  ///
  /// **Executa em isolate.**
  Future<Uint8List> generatePdfBytes(
    Caso caso, {
    List<Achado> achados = const [],
    PdfReportOptions options = const PdfReportOptions(),
  });

  /// Gera e persiste o arquivo `.pdf` no sistema de arquivos local do dispositivo.
  ///
  /// **Executa em isolate.**
  Future<File> generatePdfFile(
    Caso caso, {
    List<Achado> achados = const [],
    PdfReportOptions options = const PdfReportOptions(),
    File? destinationFile,
  });
}

/// Implementação padrão e profunda do [IPdfReportEngine].
///
/// Centraliza a orquestração e a delegação da compilação vetorial, garantindo que
/// a thread principal (UI) permaneça fluida durante a renderização pesada de documentos.
class PdfReportEngine implements IPdfReportEngine {
  final PdfService _pdfService;
  final PdfReportService _reportService;

  PdfReportEngine({
    PdfService? pdfService,
    PdfReportService? reportService,
  }) : _pdfService = pdfService ?? PdfService(),
       _reportService = reportService ?? PdfReportService();

  Usuario _obterPeritoPadrao(Caso caso, Usuario? peritoInformado) {
    if (peritoInformado != null) return peritoInformado;

    final auditoria = caso.dadosLaudo.auditoria;
    final nomePerito = auditoria.peritoResponsavel?.trim().isNotEmpty == true
        ? auditoria.peritoResponsavel!
        : 'Médico-Legista Responsável';

    return Usuario(
      id: caso.idUsuarioCriador,
      matriculaFuncional: 'IML-OFICIAL',
      nomeCompleto: nomePerito,
      roles: const ['PERITO'],
      ativo: true,
      hashPinOffline: '',
      salt: '',
      criadoEm: caso.criadoEmDispositivo,
    );
  }

  @override
  Future<Uint8List> generatePdfBytes(
    Caso caso, {
    List<Achado> achados = const [],
    PdfReportOptions options = const PdfReportOptions(),
  }) async {
    final perito = _obterPeritoPadrao(caso, options.perito);
    final examesModel = options.examesModel ?? caso.exames;
    final evidenciasGerais = options.evidenciasGerais ?? caso.evidenciasMultimidia;

    return await _pdfService.gerarLaudoPdf(
      caso: caso,
      achados: achados,
      perito: perito,
      schemas: options.schemas,
      exames: options.exames,
      examesModel: examesModel,
      evidenciasGerais: evidenciasGerais,
    );
  }

  @override
  Future<File> generatePdfFile(
    Caso caso, {
    List<Achado> achados = const [],
    PdfReportOptions options = const PdfReportOptions(),
    File? destinationFile,
  }) async {
    final bytes = await generatePdfBytes(caso, achados: achados, options: options);

    if (destinationFile != null) {
      if (!await destinationFile.parent.exists()) {
        await destinationFile.parent.create(recursive: true);
      }
      await destinationFile.writeAsBytes(bytes, flush: true);

      if (options.caseService != null) {
        await options.caseService!.atualizarCaminhoPdf(caso.uuid, destinationFile.path);
      }
      return destinationFile;
    }

    final savedPath = await _reportService.salvarPdfNoDispositivo(
      caso: caso,
      pdfBytes: bytes,
      caseService: options.caseService,
    );

    return File(savedPath);
  }
}

import 'dart:typed_data';

import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart'
    as em;
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';

/// Fachada (Facade) de geração e persistência de PDFs do laudo cadavérico.
///
/// Encapsula o motor de renderização gráfica em background Isolate ([PdfService])
/// e a camada de gerenciamento de arquivos e sanitização de storage ([PdfReportService]).
/// Permite que os controllers e telas coordenem a exportação e visualização sem
/// acoplamento direto às complexidades de I/O e Isolates.
class PdfGenerationService {
  final PdfService _pdfService;
  final PdfReportService _reportService;

  /// Cria uma instância de [PdfGenerationService] com injeção opcional de serviços.
  PdfGenerationService({
    PdfService? pdfService,
    PdfReportService? reportService,
  }) : _pdfService = pdfService ?? PdfService(),
       _reportService = reportService ?? PdfReportService();

  /// Gera os bytes binários do laudo em formato PDF oficial do IML.
  ///
  /// **Executa em isolate.** Delega o processamento pesado de imagens, SVGs e diagramação
  /// para o [PdfService.gerarLaudoPdf], evitando travamento da UI thread.
  ///
  /// Parâmetros:
  /// - [caso]: Entidade contendo os dados do laudo, histórico, identificação e quesitos.
  /// - [achados]: Lista de lesões e marcações registradas no croqui.
  /// - [perito]: Médico legista responsável pela assinatura e autenticação.
  /// - [schemas]: Metadados ou esquemas opcionais de formulário.
  /// - [exames]: Lista legada de exames solicitados.
  /// - [examesModel]: Lista estruturada e tipada dos exames (Toxicológico, Genético, Histopatológico).
  /// - [evidenciasGerais]: Fotografias e anexos gerais vinculados ao caso.
  ///
  /// Retorna um [Uint8List] contendo o arquivo PDF compilado.
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

  /// Salva fisicamente o PDF gerado no sandbox do dispositivo e atualiza o caso no SQLite.
  ///
  /// Delega a operação para [PdfReportService.salvarPdfNoDispositivo].
  ///
  /// Parâmetros:
  /// - [caso]: O caso ao qual o PDF pertence.
  /// - [pdfBytes]: Binário do documento gerado.
  /// - [caseService]: Serviço responsável por persistir o novo caminho no banco local.
  ///
  /// Retorna o caminho absoluto do arquivo `.pdf` gravado em disco.
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


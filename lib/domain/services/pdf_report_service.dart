import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

class PdfReportService {
  final PdfService _pdfService = PdfService();

  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    required List<ExameSolicitado> exames,
    List<em.ExameSolicitadoModel>? examesModel,
    required List<EvidenciaMultimidia> evidenciasGerais,
  }) async {
    return await _pdfService.gerarLaudoPdf(
      caso: caso,
      achados: achados,
      perito: perito,
      exames: exames,
      examesModel: examesModel,
      evidenciasGerais: evidenciasGerais,
    );
  }

  /// Salva fisicamente o PDF gerado no armazenamento interno do dispositivo e atualiza o `pdfLocalPath` no [Caso].
  /// Sanitiza o armazenamento removendo qualquer versão legada do arquivo antes da regeração.
  Future<String> salvarPdfNoDispositivo({
    required Caso caso,
    required Uint8List pdfBytes,
    CaseService? caseService,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final laudosDir = Directory('${docsDir.path}/laudos');
      if (!laudosDir.existsSync()) {
        laudosDir.createSync(recursive: true);
      }
      final filePath = '${laudosDir.path}/laudo_${caso.uuid}.pdf';

      // Sanitização: Se o caso tinha um pdfLocalPath antigo diferente do novo destino, limpa o arquivo antigo
      if (caso.pdfLocalPath != null && caso.pdfLocalPath!.isNotEmpty && caso.pdfLocalPath != filePath) {
        final oldFile = File(caso.pdfLocalPath!);
        if (oldFile.existsSync()) {
          try {
            await oldFile.delete();
            debugPrint('[PdfReportService] 🧹 PDF residual antigo removido: ${caso.pdfLocalPath}');
          } catch (e) {
            debugPrint('[PdfReportService] ⚠️ Falha ao remover PDF residual antigo: $e');
          }
        }
      }

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);
      debugPrint('[PdfReportService] ✅ PDF salvo com sucesso em: $filePath');

      if (caseService != null) {
        final casoAtualizado = caso.copyWith(pdfLocalPath: filePath);
        await caseService.salvarRascunho(casoAtualizado);
      }

      return filePath;
    } catch (e) {
      debugPrint('[PdfReportService] ❌ Erro ao salvar PDF localmente: $e');
      rethrow;
    }
  }

  /// Varre o diretório de laudos e remove qualquer arquivo PDF que pertença a casos excluídos ou inexistentes.
  Future<void> limparPdfsOrfaos(List<String> uuidsCasosAtivos) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final laudosDir = Directory('${docsDir.path}/laudos');
      if (!laudosDir.existsSync()) return;

      final Set<String> ativosSet = uuidsCasosAtivos.toSet();
      final List<FileSystemEntity> entities = laudosDir.listSync();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          if (fileName.startsWith('laudo_') && fileName.endsWith('.pdf')) {
            final uuid = fileName.substring('laudo_'.length, fileName.length - '.pdf'.length);
            if (!ativosSet.contains(uuid)) {
              await entity.delete();
              debugPrint('[PdfReportService] 🧹 PDF órfão removido com sucesso: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PdfReportService] ⚠️ Erro ao sanitizar PDFs órfãos: $e');
    }
  }
}

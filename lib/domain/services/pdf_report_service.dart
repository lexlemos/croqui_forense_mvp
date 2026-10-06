import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart'
    as em;
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

/// Serviço de orquestração, salvamento em disco e ciclo de vida de relatórios PDF.
///
/// Responsável por intermediar a geração dos laudos com o [PdfService], gravar os
/// binários no sandbox de armazenamento do dispositivo (`/laudos/laudo_{uuid}.pdf`),
/// atualizar o caminho persistido no banco local via [CaseService] e realizar a
/// higienização periódica de arquivos PDF órfãos ou residuais.
class PdfReportService {
  final PdfService _pdfService = PdfService();

  /// Orquestra a compilação do laudo pericial em formato PDF.
  ///
  /// **Executa em isolate.** A compilação pesada do PDF ocorre em um background worker isolate
  /// encapsulado pelo [PdfService.gerarLaudoPdf].
  ///
  /// Parâmetros:
  /// - [caso]: Objeto do caso contendo histórico, identificação, causa mortis e quesitos oficiais.
  /// - [achados]: Lista de achados periciais cadastrados no croqui.
  /// - [perito]: Perito médico-legista autenticado.
  /// - [exames]: Lista legada de requisições de exames.
  /// - [examesModel]: Lista tipada de exames complementares (Toxicológico, Genético, Histopatológico).
  /// - [evidenciasGerais]: Fotografias e mídias gerais anexadas ao caso.
  ///
  /// Retorna o binário [Uint8List] do documento gerado.
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
  ///
  /// Sanitiza o armazenamento removendo versões residuais apenas se o caso já foi previamente
  /// sincronizado com o backend ([StatusCaso.sincronizado]), garantindo a proteção contra perda
  /// de arquivos pendentes em modo offline.
  ///
  /// Parâmetros:
  /// - [caso]: Caso associado ao arquivo.
  /// - [pdfBytes]: Binário do PDF compilado.
  /// - [caseService]: Serviço opcional para atualizar o registro local no banco SQLite.
  ///
  /// Retorna o caminho absoluto do arquivo salvo.
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
      final localPath = caso.pdfLocalPath;
      if (localPath != null && localPath.isNotEmpty && localPath != filePath) {
        // Só deleta o PDF antigo se o caso já tiver sido sincronizado com o backend.
        // Se ainda não for sincronizado (status != StatusCaso.sincronizado), mantém o arquivo intacto no dispositivo.
        if (caso.status == StatusCaso.sincronizado) {
          final oldFile = File(localPath);
          if (oldFile.existsSync()) {
            try {
              await oldFile.delete();
              debugPrint(
                '[PdfReportService] 🧹 PDF residual antigo removido de caso sincronizado: $localPath',
              );
            } catch (e) {
              debugPrint(
                '[PdfReportService] ⚠️ Falha ao remover PDF residual antigo: $e',
              );
            }
          }
        }
      }

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);
      debugPrint('[PdfReportService] ✅ PDF salvo com sucesso em: $filePath');

      if (caseService != null) {
        await caseService.atualizarCaminhoPdf(caso.uuid, filePath);
      }

      return filePath;
    } catch (e) {
      debugPrint('[PdfReportService] ❌ Erro ao salvar PDF localmente: $e');
      rethrow;
    }
  }

  /// Varre o diretório de laudos e remove qualquer arquivo PDF que pertença a casos excluídos ou inexistentes.
  ///
  /// **Atenção: roda na UI thread.** Operação síncrona de I/O de disco para listagem do diretório.
  ///
  /// Parâmetros:
  /// - [uuidsCasosAtivos]: Lista de UUIDs de casos válidos no banco SQLite local. Qualquer arquivo cujo
  ///   UUID não conste nesta lista será excluído permanentemente do storage.
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
            final uuid = fileName.substring(
              'laudo_'.length,
              fileName.length - '.pdf'.length,
            );
            if (!ativosSet.contains(uuid)) {
              await entity.delete();
              debugPrint(
                '[PdfReportService] 🧹 PDF órfão removido com sucesso: ${entity.path}',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PdfReportService] ⚠️ Erro ao sanitizar PDFs órfãos: $e');
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_engine.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

/// Exceção lançada quando uma tentativa de conclusão de laudo é barrada
/// devido à existência de exames complementares laboratoriais em andamento.
class ExamesPendentesException implements Exception {
  final String message;

  const ExamesPendentesException([
    this.message = 'O laudo não pode ser finalizado com exames complementares pendentes.',
  ]);

  @override
  String toString() => message;
}

/// Contrato do módulo profundo encarregado do ciclo de vida processual e legal do laudo pericial.
///
/// Encapsula a máquina de estados forense, validações de integridade da cadeia de custódia,
/// emissão do documento oficial em PDF e agendamento de sincronização para o backend.
abstract interface class ICaseLifecycleService {
  /// Transiciona o status do caso para [StatusCaso.laudoPendente].
  ///
  /// Persiste o novo estado no banco SQLite local com incremento de concorrência otimista (OCC)
  /// e despacha o caso atualizado para a fila de sincronização em segundo plano.
  Future<Caso> markPending(Caso caso);

  /// Conclui definitivamente o laudo pericial cadavérico.
  ///
  /// Valida preliminarmente se não existem exames complementares pendentes de resultado.
  /// Compila o documento pericial oficial em PDF via [IPdfReportEngine] em Isolate dedicado,
  /// vincula o caminho do arquivo físico ao registro, transiciona para [StatusCaso.finalizado]
  /// e enfileira o envio assinado para o [SyncService].
  ///
  /// Throws [ExamesPendentesException] caso haja qualquer [ExameSolicitadoModel] ou [ExameSolicitado]
  /// com status correspondente a 'aguardando'.
  /// Throws [Exception] caso a geração do arquivo ou a persistência SQLite falhe.
  Future<Caso> concludeCase({
    required Caso caso,
    required Usuario perito,
    List<Achado> achados = const [],
    List<ExameSolicitadoModel> examesModel = const [],
    List<ExameSolicitado> exames = const [],
    List<EvidenciaMultimidia> evidenciasGerais = const [],
  });

  /// Reabre um laudo pericial finalizado para edição corretiva ou retificadora autorizada.
  ///
  /// Throws [Exception] caso o identificador do caso não seja localizado no repositório.
  Future<Caso> reopenCase(String casoUuid);

  /// Gera uma cópia temporária do laudo pericial oficial em PDF e despacha para o utilitário nativo de compartilhamento.
  ///
  /// Grava o documento no diretório temporário do sistema operacional, invoca o canal de plataforma
  /// via [SharePlus] e assegura a remoção do arquivo temporário no término da operação para evitar vazamentos de dados sensíveis.
  Future<void> shareTemporaryReport({
    required Caso caso,
    required Usuario perito,
    List<Achado> achados = const [],
    List<ExameSolicitadoModel> examesModel = const [],
    List<ExameSolicitado> exames = const [],
    List<EvidenciaMultimidia> evidenciasGerais = const [],
    Map<String, dynamic> schemas = const {},
  });

  /// Faz o download do laudo compilado em formato Word (.docx) pelo servidor central do IML
  /// e despacha o arquivo para o utilitário nativo de compartilhamento ([SharePlus]).
  ///
  /// Permite injetar [shareAction] customizado para fins de testes automatizados.
  /// Requer conectividade com a API central do IML.
  Future<void> shareDocxReport({
    required Caso caso,
    Future<void> Function(File file)? shareAction,
  });
}

/// Implementação padrão e profunda de [ICaseLifecycleService].
class CaseLifecycleService implements ICaseLifecycleService {
  final CaseService _caseService;
  final IPdfReportEngine _pdfEngine;
  final SyncService? _syncService;
  final IRemoteDataSource? _remoteDataSource;
  final Future<Directory> Function() _tempDirectoryProvider;

  CaseLifecycleService({
    required CaseService caseService,
    required IPdfReportEngine pdfEngine,
    SyncService? syncService,
    IRemoteDataSource? remoteDataSource,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : _caseService = caseService,
       _pdfEngine = pdfEngine,
       _syncService = syncService,
       _remoteDataSource = remoteDataSource,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  @override
  Future<Caso> markPending(Caso caso) async {
    final now = DateTime.now().toUtc();
    final casoAtualizado = caso.copyWith(
      status: StatusCaso.laudoPendente,
      atualizadoEm: now,
      isDraftSynced: false,
      versao: caso.versao + 1,
    );

    await _caseService.salvarRascunho(casoAtualizado);

    _syncService?.pushCasoRascunho(casoAtualizado).catchError((e) {
      debugPrint('[CaseLifecycleService] ⚠️ Erro no push em background: $e');
    });

    return casoAtualizado;
  }

  @override
  Future<Caso> concludeCase({
    required Caso caso,
    required Usuario perito,
    List<Achado> achados = const [],
    List<ExameSolicitadoModel> examesModel = const [],
    List<ExameSolicitado> exames = const [],
    List<EvidenciaMultimidia> evidenciasGerais = const [],
  }) async {
    final bool temExamePendente =
        examesModel.any((e) => e.status == 'aguardando') ||
        exames.any((e) => e.status == 'aguardando');

    if (temExamePendente) {
      debugPrint(
        '[CaseLifecycleService] Trava processual: exames complementares pendentes detectados.',
      );
      throw const ExamesPendentesException();
    }

    await _caseService.salvarRascunho(caso);

    final pdfFile = await _pdfEngine.generatePdfFile(
      caso,
      achados: achados,
      options: PdfReportOptions(
        perito: perito,
        exames: exames,
        examesModel: examesModel,
        evidenciasGerais: evidenciasGerais,
        caseService: _caseService,
      ),
    );

    final now = DateTime.now().toUtc();
    final casoFinalizado = caso.copyWith(
      status: StatusCaso.finalizado,
      pdfLocalPath: pdfFile.path,
      finalizadoEm: now,
      atualizadoEm: now,
      isDraftSynced: false,
      versao: caso.versao + 1,
    );

    await _caseService.salvarRascunho(casoFinalizado);

    _syncService?.pushCasoRascunho(casoFinalizado).catchError((e) {
      debugPrint('[CaseLifecycleService] ⚠️ Erro no push do caso finalizado: $e');
    });

    return casoFinalizado;
  }

  @override
  Future<Caso> reopenCase(String casoUuid) async {
    await _caseService.reabrirCaso(casoUuid);
    final casoAtualizado = await _caseService.buscarCasoPorUuid(casoUuid);
    if (casoAtualizado != null) {
      return casoAtualizado;
    }
    throw Exception('Caso $casoUuid não encontrado após reabertura.');
  }

  @override
  Future<void> shareTemporaryReport({
    required Caso caso,
    required Usuario perito,
    List<Achado> achados = const [],
    List<ExameSolicitadoModel> examesModel = const [],
    List<ExameSolicitado> exames = const [],
    List<EvidenciaMultimidia> evidenciasGerais = const [],
    Map<String, dynamic> schemas = const {},
  }) async {
    await _caseService.salvarRascunho(caso);

    final tempDir = await _tempDirectoryProvider();
    final String safeNum = (caso.numeroLaudoExterno ?? 'sem-numero').replaceAll('/', '-');
    final tempPdfFile = File('${tempDir.path}/laudo_$safeNum.pdf');

    try {
      await _pdfEngine.generatePdfFile(
        caso,
        achados: achados,
        destinationFile: tempPdfFile,
        options: PdfReportOptions(
          perito: perito,
          schemas: schemas,
          exames: exames,
          examesModel: examesModel,
          evidenciasGerais: evidenciasGerais,
        ),
      );

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(tempPdfFile.path)],
        subject: 'Laudo Pericial PDF - ${caso.numeroLaudoExterno}',
      );
    } finally {
      if (tempPdfFile.existsSync()) {
        try {
          await tempPdfFile.delete();
          debugPrint(
            '[CaseLifecycleService] 🧹 PDF temporário de exportação limpo: ${tempPdfFile.path}',
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> shareDocxReport({
    required Caso caso,
    Future<void> Function(File file)? shareAction,
  }) async {
    final remoteDS = _remoteDataSource;
    if (remoteDS == null) {
      throw Exception('Serviço de comunicação remota não configurado.');
    }

    final tempDir = await _tempDirectoryProvider();
    final String safeNum = (caso.numeroLaudoExterno ?? caso.numeroRequisicao).replaceAll('/', '-');
    final tempDocxFile = File('${tempDir.path}/laudo_$safeNum.docx');

    try {
      await remoteDS.downloadLaudoDocx(
        casoUuid: caso.uuid,
        destinationFile: tempDocxFile,
      );

      if (shareAction != null) {
        await shareAction(tempDocxFile);
      } else {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(tempDocxFile.path)],
          subject: 'Laudo Pericial DOCX - ${caso.numeroLaudoExterno ?? caso.numeroRequisicao}',
        );
      }
    } finally {
      if (tempDocxFile.existsSync()) {
        try {
          await tempDocxFile.delete();
          debugPrint(
            '[CaseLifecycleService] 🧹 DOCX temporário de exportação limpo: ${tempDocxFile.path}',
          );
        } catch (_) {}
      }
    }
  }
}

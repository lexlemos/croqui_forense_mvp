import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';

class PdfPreviewPage extends StatefulWidget {
  final Caso caso;

  const PdfPreviewPage({super.key, required this.caso});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  late final Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    final achadoService = context.read<AchadoService>();
    final caseService = context.read<CaseService>();
    final authProvider = context.read<AuthProvider>();

    _dataFuture = Future.wait([
      achadoService.listarAchados(widget.caso.uuid),
      caseService.getEvidenciasGerais(widget.caso.uuid),
      caseService.getExamesSolicitados(widget.caso.uuid),
      context.read<CasoRepository>().getExamesPorCaso(widget.caso.uuid),
    ]).then((results) {
      return {
        'achados': results[0] as List<Achado>,
        'evidenciasGerais': results[1] as List<EvidenciaMultimidia>,
        'exames': results[2] as List<ExameSolicitado>,
        'examesModel': results[3] as List<em.ExameSolicitadoModel>,
        'perito': authProvider.usuario,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-visualização do Laudo'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Salvar PDF Localmente',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PDF salvo localmente com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final achados = data['achados'] as List<Achado>;
          final evidenciasGerais = data['evidenciasGerais'] as List<EvidenciaMultimidia>;
          final exames = data['exames'] as List<ExameSolicitado>;
          final examesModel = data['examesModel'] as List<em.ExameSolicitadoModel>;
          final perito = data['perito'] as Usuario?;

          if (perito == null) {
            return const Center(child: Text('Perito não autenticado.'));
          }

          final reportService = PdfReportService();

          return PdfPreview(
            build: (format) async {
              final pdfBytes = await reportService.gerarLaudoPdf(
                caso: widget.caso,
                achados: achados,
                perito: perito,
                exames: exames,
                examesModel: examesModel,
                evidenciasGerais: evidenciasGerais,
              );

              if (context.mounted) {
                final caseService = context.read<CaseService>();
                await reportService.salvarPdfNoDispositivo(
                  caso: widget.caso,
                  pdfBytes: pdfBytes,
                  caseService: caseService,
                );
              }
              return pdfBytes;
            },
            maxPageWidth: 700,
            dpi: 72,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/achado_detail_modal.dart';
import 'package:croqui_forense_mvp/presentation/pages/pdf_preview_page.dart';

import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/case_info_tab.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/exames_tab.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/croqui_details_widgets.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/croqui_viewer.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart' show BodyPartDefinition;
import 'package:croqui_forense_mvp/presentation/widgets/croqui/tabs/body_parts_tabs.dart';

class CroquiPage extends StatelessWidget {
  final Caso caso;
  final bool? isReadOnly;

  const CroquiPage({super.key, required this.caso, this.isReadOnly});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CroquiController(
        caso,
        ctx.read<AchadoService>(),
        ctx.read<CaseService>(),
        ctx.read<InjuryTypeRepository>(),
        ctx.read<AchadoRepository>(),
        ctx.read<CasoRepository>(),
        ctx.read<AtnRepository>(),
        isReadOnly: isReadOnly,
      ),
      child: const _CroquiView(),
    );
  }
}

class _CroquiView extends StatefulWidget {
  const _CroquiView();

  @override
  State<_CroquiView> createState() => _CroquiViewState();
}

class _CroquiViewState extends State<_CroquiView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (mounted) {
        final controller = context.read<CroquiController>();
        debugPrint('[AppLifecycleObserver] App minimizado/inativo — forçando flush de rascunho...');
        controller.flushAutoSave();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CroquiController>();
    const double sidebarWidth = 320.0;

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<CroquiController>(
            builder: (context, c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Exame Corporal", style: TextStyle(fontSize: 16)),
                    if (c.isReadOnly)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: const Text("CONCLUÍDO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (c.casoAtual.status == StatusCaso.laudo_pendente)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange[800], borderRadius: BorderRadius.circular(4)),
                        child: const Text("LAUDO PENDENTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                Text("Laudo: ${c.casoAtual.numeroLaudoExterno ?? 'Novo'}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
              ],
            ),
          ),
          backgroundColor: controller.isReadOnly ? Colors.blueGrey[800] : Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Visualizar PDF',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfPreviewPage(caso: controller.casoAtual),
                  ),
                );
              },
            ),
            if (!controller.isReadOnly)
              Builder(
                builder: (innerContext) => TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: Icon(
                    controller.casoAtual.status == StatusCaso.laudo_pendente
                        ? Icons.check_circle_outline
                        : Icons.assignment_turned_in,
                    size: 20,
                  ),
                  label: Text(
                    controller.casoAtual.status == StatusCaso.laudo_pendente
                        ? "CONCLUIR LAUDO"
                        : "FINALIZAR EXAME",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: controller.isProcessing ? null : () => controller.finalizarCasoDireto(innerContext),
                ),
              ),
            if (controller.isReadOnly)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') controller.reabrirCaso(context);
                  if (value == 'export') controller.exportarCaso(context);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (controller.casoAtual.status != StatusCaso.sincronizado)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, color: Colors.indigo),
                        title: Text('Editar Caso'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.share, color: Colors.indigo),
                      title: Text('Exportar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: "Frontal / Dorsal"),
              Tab(text: "Lateral Dir. / Esq."),
              Tab(text: "Tronco Dir. / Esq."),
              Tab(text: "Períneo"),
              Tab(text: "Face Dir. / Esq."),
              Tab(text: "Exames", icon: Icon(Icons.science, size: 16)),
              Tab(text: "Dados", icon: Icon(Icons.description, size: 16)),
            ],
          ),
        ),
        body: SafeArea(
          bottom: true,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      FrenteCostasTabContent(controller: controller, buildCroquiTab: _buildCroquiTab),
                      LateraisTabContent(controller: controller, buildCroquiTab: _buildCroquiTab),
                      TroncoTabContent(controller: controller, buildCroquiTab: _buildCroquiTab),
                      PerineoTabContent(controller: controller, buildCroquiTab: _buildCroquiTab),
                      RostosTabContent(controller: controller, buildCroquiTab: _buildCroquiTab),
                      const ExamesTab(),
                      const CaseInfoTab(),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              
              SizedBox(
                width: sidebarWidth,
                child: Consumer<CroquiController>(
                  builder: (context, c, _) => AchadosSidebar(
                    achados: c.achados,
                    isReadOnly: c.isReadOnly,
                    onEdit: (achado) => _showEditOrDetail(context, c, achado),
                    onDelete: (uuid) => c.deleteAchado(context, uuid),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCroquiTab(BuildContext context, CroquiController controller, String view, String svg, String mask,
      Map<int, String> colors, Map<String, BodyPartDefinition> defs) {
    return Consumer<CroquiController>(
      builder: (context, c, _) => CroquiViewer(
        svgPath: svg,
        maskPath: mask,
        colorToIdMap: colors,
        idToDefMap: defs,
        markers: c.getMarkersForView(view),
        onPartTap: (id, name, x, y) => c.addAchado(context, view, id, x, y),
      ),
    );
  }
}



void _showEditOrDetail(BuildContext context, CroquiController controller, Achado achado) {
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AchadoDetailModal(
        achado: achado,
        onEdit: controller.isReadOnly
          ? null
          : () {
              Navigator.pop(dialogContext);
              controller.editAchado(parentContext, achado);
            },
      ),
    );
  }



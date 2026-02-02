import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

import 'package:croqui_forense_mvp/presentation/widgets/croqui/case_info_tab.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/croqui_details_widgets.dart';
import 'package:croqui_forense_mvp/components/croqui/croqui_viewer.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart';

class CroquiPage extends StatelessWidget {
  final Caso caso;

  const CroquiPage({super.key, required this.caso});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CroquiController(
        caso,
        AchadoService.instance,
        ctx.read<CaseService>(),
      ),
      child: const _CroquiView(),
    );
  }
}

class _CroquiView extends StatelessWidget {
  const _CroquiView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CroquiController>();
    const double sidebarWidth = 320.0;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Exame Corporal", style: TextStyle(fontSize: 16)),
                  if (controller.isReadOnly)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text("CONCLUÍDO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              Text("Laudo: ${controller.casoAtual.numeroLaudoExterno ?? 'Novo'}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
            ],
          ),
          backgroundColor: controller.isReadOnly ? Colors.blueGrey[800] : Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            if (controller.isReadOnly)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') controller.reabrirCaso(context);
                  if (value == 'export') controller.exportarCaso(context);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
              Tab(text: "Frente"),
              Tab(text: "Costas"),
              Tab(text: "Lat. Dir"),
              Tab(text: "Lat. Esq"),
              Tab(text: "Dados", icon: Icon(Icons.description, size: 16)),
            ],
          ),
        ),
        body: Row(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCroquiTab(context, controller, 'frente', 'assets/images/croqui-frente.svg',
                        'assets/images/croqui-frente-mask.png', kColorToIdFrontMap, kIdToDefinitionFrontMap),
                    _buildCroquiTab(context, controller, 'costas', 'assets/images/croqui-costas.svg',
                        'assets/images/croqui-costas-mask.png', kColorToIdBackMap, kIdToDefinitionBackMap),
                    _buildCroquiTab(context, controller, 'lateral_dir', 'assets/images/croqui-rosto-direito.svg',
                        'assets/images/croqui-rosto-direito-mask.png', kColorToIdLateralRightMap, kIdToDefinitionLateralRightMap),
                    _buildCroquiTab(context, controller, 'lateral_esq', 'assets/images/croqui-rosto-frente.svg',
                        'assets/images/croqui-rosto-frente-mask.png', kColorToIdLateralLeftMap, kIdToDefinitionLateralLeftMap),
                    
                    CaseInfoTab(),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            
            SizedBox(
              width: sidebarWidth,
              child: AchadosSidebar(
                achados: controller.achados,
                isReadOnly: controller.isReadOnly,
                onEdit: (achado) => _showEditOrDetail(context, controller, achado),
                onDelete: (uuid) => controller.deleteAchado(uuid),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCroquiTab(BuildContext context, CroquiController controller, String view, String svg, String mask,
      Map<int, String> colors, Map<String, dynamic> defs) {
    return CroquiViewer(
      svgPath: svg,
      maskPath: mask,
      colorToIdMap: colors,
      idToDefMap: defs,
      markers: controller.getMarkersForView(view),
      onPartTap: (id, name, x, y) => controller.addAchado(context, view, id, x, y),
    );
  }

  void _showEditOrDetail(BuildContext context, CroquiController controller, Achado achado) {
    if (controller.isReadOnly) {
      _showReadOnlyDetails(context, achado);
    } else {
      controller.editAchado(context, achado);
    }
  }

  void _showReadOnlyDetails(BuildContext context, Achado achado) {
    final dados = achado.dadosPreenchidos;
    final String tipo = dados['type_label'] ?? '-';
    final String local = dados['local_anatomico_nome'] ?? '-';
    final String obs = achado.observacoesTexto ?? '';
    final String? photoPath = dados['photo_path'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tipo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(local, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text(obs),
            if (photoPath != null && File(photoPath).existsSync())
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.file(File(photoPath), height: 200),
              )
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))],
      ),
    );
  }
}
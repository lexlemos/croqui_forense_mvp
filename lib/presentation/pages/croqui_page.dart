import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/achado_detail_modal.dart';

import 'package:croqui_forense_mvp/presentation/widgets/croqui/case_info_tab.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/croqui_details_widgets.dart';
import 'package:croqui_forense_mvp/presentation/widgets/croqui/croqui_viewer.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart' as face_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart' as face_left;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart' as lat_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart' as lat_left;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart' as trunk_right;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart' as trunk_left;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart' as perineal;

class CroquiPage extends StatelessWidget {
  final Caso caso;

  const CroquiPage({super.key, required this.caso});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CroquiController(
        caso,
        ctx.read<AchadoService>(),
        ctx.read<CaseService>(),
        ctx.read<InjuryTypeRepository>(),
        ctx.read<AchadoRepository>(),
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
      length: 6,
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
              Tab(text: "Frontal / Dorsal"),
              Tab(text: "Lateral Dir. / Esq."),
              Tab(text: "Tronco Dir. / Esq."),
              Tab(text: "Períneo"),
              Tab(text: "Face Dir. / Esq."),
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
                    _buildFrenteCostasTab(context, controller),
                    _buildLateraisTab(context, controller),
                    _buildTroncoTab(context, controller),
                    _buildPerineoTab(context, controller),
                    _buildRostosTab(context, controller),
                    const CaseInfoTab(),
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
                onDelete: (uuid) => controller.deleteAchado(context, uuid),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFrenteCostasTab(BuildContext context, CroquiController controller) {
    return _FrenteCostasTabContent(
      controller: controller,
      buildCroquiTab: _buildCroquiTab,
    );
  }

  Widget _buildLateraisTab(BuildContext context, CroquiController controller) {
    return _LateraisTabContent(
      controller: controller,
      buildCroquiTab: _buildCroquiTab,
    );
  }

  Widget _buildTroncoTab(BuildContext context, CroquiController controller) {
    return _TroncoTabContent(
      controller: controller,
      buildCroquiTab: _buildCroquiTab,
    );
  }

  Widget _buildPerineoTab(BuildContext context, CroquiController controller) {
    final sexo = controller.sexoDoExaminado;
    final isMale = !sexo.toLowerCase().startsWith('f');
    final segmentedValue = (sexo == 'Feminino' || sexo == 'Masculino') ? sexo : 'Masculino';
    
    final activeColors = Map<int, String>.fromEntries(
      perineal.kColorToIdPerinealMap.entries.where((e) => e.value.startsWith(isMale ? 'male_' : 'female_'))
    );
    final activeDefs = Map<String, BodyPartDefinition>.fromEntries(
      perineal.kIdToDefinitionPerinealMap.entries.where((e) => e.key.startsWith(isMale ? 'male_' : 'female_'))
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Sexo do Examinado: ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.indigo,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(value: 'Masculino', label: Text('Masculino'), icon: Icon(Icons.male, size: 18)),
                  ButtonSegment(value: 'Feminino', label: Text('Feminino'), icon: Icon(Icons.female, size: 18)),
                ],
                selected: {segmentedValue},
                onSelectionChanged: controller.isReadOnly 
                  ? null 
                  : (newSelection) {
                      controller.alterarSexoExaminado(context, newSelection.first);
                    },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildCroquiTab(
            context,
            controller,
            'perineal',
            isMale ? 'assets/images/perineo_masculino.svg' : 'assets/images/perineo_feminino.svg',
            isMale ? 'assets/images/perineo_masculino.png' : 'assets/images/perineo_feminino.png',
            activeColors,
            activeDefs,
          ),
        ),
      ],
    );
  }

  Widget _buildRostosTab(BuildContext context, CroquiController controller) {
    return _RostosTabContent(
      controller: controller,
      buildCroquiTab: _buildCroquiTab,
    );
  }

  Widget _buildCroquiTab(BuildContext context, CroquiController controller, String view, String svg, String mask,
      Map<int, String> colors, Map<String, BodyPartDefinition> defs) {
    return CroquiViewer(
      svgPath: svg,
      maskPath: mask,
      colorToIdMap: colors,
      idToDefMap: defs,
      markers: controller.getMarkersForView(view),
      onPartTap: (id, name, x, y) => controller.addAchado(context, view, id, x, y),
    );
  }
}

class _RostosTabContent extends StatefulWidget {
  final CroquiController controller;
  final Widget Function(BuildContext, CroquiController, String, String, String, Map<int, String>, Map<String, BodyPartDefinition>) buildCroquiTab;

  const _RostosTabContent({
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<_RostosTabContent> createState() => _RostosTabContentState();
}

class _RostosTabContentState extends State<_RostosTabContent> {
  String _activeFaceView = 'face_dir'; 

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.indigo,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(value: 'face_dir', label: Text('Rosto Direito'), icon: Icon(Icons.face, size: 18)),
                  ButtonSegment(value: 'face_esq', label: Text('Rosto Esquerdo / Frente'), icon: Icon(Icons.face_5, size: 18)),
                ],
                selected: {_activeFaceView},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _activeFaceView = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _activeFaceView == 'face_dir'
              ? widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'face_dir',
                  'assets/images/croqui-rosto-direito.svg',
                  'assets/images/croqui-rosto-direito-mask.png',
                  face_right.kColorToIdLateralRightMap,
                  face_right.kIdToDefinitionLateralRightMap,
                )
              : widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'face_esq',
                  'assets/images/croqui-rosto-frente.svg',
                  'assets/images/croqui-rosto-frente-mask.png',
                  face_left.kColorToIdLateralLeftMap,
                  face_left.kIdToDefinitionLateralLeftMap,
                ),
        ),
      ],
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

class _FrenteCostasTabContent extends StatefulWidget {
  final CroquiController controller;
  final Widget Function(
    BuildContext,
    CroquiController,
    String,
    String,
    String,
    Map<int, String>,
    Map<String, BodyPartDefinition>,
  ) buildCroquiTab;

  const _FrenteCostasTabContent({
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<_FrenteCostasTabContent> createState() => _FrenteCostasTabContentState();
}

class _FrenteCostasTabContentState extends State<_FrenteCostasTabContent> {
  String _activeView = 'frente';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.indigo,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'frente',
                    label: Text('Frontal'),
                    icon: Icon(Icons.accessibility_new, size: 18),
                  ),
                  ButtonSegment(
                    value: 'costas',
                    label: Text('Dorsal'),
                    icon: Icon(Icons.accessibility, size: 18),
                  ),
                ],
                selected: {_activeView},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _activeView = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _activeView == 'frente'
              ? widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'frente',
                  'assets/images/croqui-frente.svg',
                  'assets/images/croqui-frente-mask.png',
                  kColorToIdFrontMap,
                  kIdToDefinitionFrontMap,
                )
              : widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'costas',
                  'assets/images/croqui-costas.svg',
                  'assets/images/croqui-costas-mask.png',
                  kColorToIdBackMap,
                  kIdToDefinitionBackMap,
                ),
        ),
      ],
    );
  }
}

class _LateraisTabContent extends StatefulWidget {
  final CroquiController controller;
  final Widget Function(
    BuildContext,
    CroquiController,
    String,
    String,
    String,
    Map<int, String>,
    Map<String, BodyPartDefinition>,
  ) buildCroquiTab;

  const _LateraisTabContent({
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<_LateraisTabContent> createState() => _LateraisTabContentState();
}

class _LateraisTabContentState extends State<_LateraisTabContent> {
  String _activeView = 'lateral_dir';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.indigo,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'lateral_dir',
                    label: Text('Lateral Direita'),
                    icon: Icon(Icons.chevron_right, size: 18),
                  ),
                  ButtonSegment(
                    value: 'lateral_esq',
                    label: Text('Lateral Esquerda'),
                    icon: Icon(Icons.chevron_left, size: 18),
                  ),
                ],
                selected: {_activeView},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _activeView = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _activeView == 'lateral_dir'
              ? widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'lateral_dir',
                  'assets/images/face-lateral-direita.svg',
                  'assets/images/face-lateral-direita.png',
                  lat_right.kColorToIdLateralRightMap,
                  lat_right.kIdToDefinitionLateralRightMap,
                )
              : widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'lateral_esq',
                  'assets/images/face-lateral-esquerda.svg',
                  'assets/images/face-lateral-esquerda.png',
                  lat_left.kColorToIdLateralLeftMap,
                  lat_left.kIdToDefinitionLateralLeftMap,
                ),
        ),
      ],
    );
  }
}

class _TroncoTabContent extends StatefulWidget {
  final CroquiController controller;
  final Widget Function(
    BuildContext,
    CroquiController,
    String,
    String,
    String,
    Map<int, String>,
    Map<String, BodyPartDefinition>,
  ) buildCroquiTab;

  const _TroncoTabContent({
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<_TroncoTabContent> createState() => _TroncoTabContentState();
}

class _TroncoTabContentState extends State<_TroncoTabContent> {
  String _activeView = 'trunk_dir';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.indigo,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'trunk_dir',
                    label: Text('Tronco Direito'),
                    icon: Icon(Icons.chevron_right, size: 18),
                  ),
                  ButtonSegment(
                    value: 'trunk_esq',
                    label: Text('Tronco Esquerdo'),
                    icon: Icon(Icons.chevron_left, size: 18),
                  ),
                ],
                selected: {_activeView},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _activeView = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _activeView == 'trunk_dir'
              ? widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'trunk_dir',
                  'assets/images/tronco-direito-contorno.svg',
                  'assets/images/tronco-direito-mask.png',
                  trunk_right.kColorToIdTrunkRightMap,
                  trunk_right.kIdToDefinitionTrunkRightMap,
                )
              : widget.buildCroquiTab(
                  context,
                  widget.controller,
                  'trunk_esq',
                  'assets/images/tronco-esquerdo-contorno.svg',
                  'assets/images/tronco-esquerdo-mask.png',
                  trunk_left.kColorToIdTrunkLeftMap,
                  trunk_left.kIdToDefinitionTrunkLeftMap,
                ),
        ),
      ],
    );
  }
}
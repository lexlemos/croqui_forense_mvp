import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart' as face_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart' as face_left;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart' as lat_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart' as lat_left;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart' as trunk_right;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart' as trunk_left;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart' as perineal;

typedef BuildCroquiTabCallback = Widget Function(
  BuildContext context,
  CroquiController controller,
  String view,
  String svg,
  String mask,
  Map<int, String> colors,
  Map<String, BodyPartDefinition> defs,
);

class FrenteCostasTabContent extends StatefulWidget {
  final CroquiController controller;
  final BuildCroquiTabCallback buildCroquiTab;

  const FrenteCostasTabContent({
    super.key,
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<FrenteCostasTabContent> createState() => _FrenteCostasTabContentState();
}

class _FrenteCostasTabContentState extends State<FrenteCostasTabContent> {
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

class LateraisTabContent extends StatefulWidget {
  final CroquiController controller;
  final BuildCroquiTabCallback buildCroquiTab;

  const LateraisTabContent({
    super.key,
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<LateraisTabContent> createState() => _LateraisTabContentState();
}

class _LateraisTabContentState extends State<LateraisTabContent> {
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

class TroncoTabContent extends StatefulWidget {
  final CroquiController controller;
  final BuildCroquiTabCallback buildCroquiTab;

  const TroncoTabContent({
    super.key,
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<TroncoTabContent> createState() => _TroncoTabContentState();
}

class _TroncoTabContentState extends State<TroncoTabContent> {
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

class RostosTabContent extends StatefulWidget {
  final CroquiController controller;
  final BuildCroquiTabCallback buildCroquiTab;

  const RostosTabContent({
    super.key,
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  State<RostosTabContent> createState() => _RostosTabContentState();
}

class _RostosTabContentState extends State<RostosTabContent> {
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

class PerineoTabContent extends StatelessWidget {
  final CroquiController controller;
  final BuildCroquiTabCallback buildCroquiTab;

  const PerineoTabContent({
    super.key,
    required this.controller,
    required this.buildCroquiTab,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CroquiController>(
      builder: (context, controllerState, child) {
        final sexo = controllerState.sexoDoExaminado;
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
                    onSelectionChanged: controllerState.isReadOnly 
                      ? null 
                      : (newSelection) {
                          controllerState.alterarSexoExaminado(context, newSelection.first);
                        },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: buildCroquiTab(
                context,
                controllerState,
                'perineal',
                isMale ? 'assets/images/perineo_masculino.svg' : 'assets/images/perineo_feminino.svg',
                isMale ? 'assets/images/perineo_masculino.png' : 'assets/images/perineo_feminino.png',
                activeColors,
                activeDefs,
              ),
            ),
          ],
        );
      },
    );
  }
}

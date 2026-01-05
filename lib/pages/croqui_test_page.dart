import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// --- IMPORTS DOS COMPONENTES (Usando package para evitar erros) ---
import 'package:croqui_forense_mvp/components/croqui/croqui_viewer.dart';
import 'package:croqui_forense_mvp/data/models/injury_marker_model.dart';

// --- IMPORTS DOS DADOS (CONSTANTES) ---
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart'; 

class CroquiTestPage extends StatefulWidget {
  const CroquiTestPage({super.key});

  @override
  State<CroquiTestPage> createState() => _CroquiTestPageState();
}

class _CroquiTestPageState extends State<CroquiTestPage> {
  // Lista central de marcações (lesões)
  List<InjuryMarker> _markers = [];
  final Uuid _uuid = const Uuid();

  // Função chamada quando o CroquiViewer detecta um clique válido
  void _addMarker(String croquiType, String partId, String partName, double x, double y) {
    
    // Cria o novo marcador
    final newMarker = InjuryMarker(
      id: _uuid.v4(),
      caseId: 'caso_teste_123',
      croquiType: croquiType,
      bodyPartId: partId,
      xPercent: x,
      yPercent: y,
      description: 'Lesão em $partName',
    );

    setState(() {
      _markers.add(newMarker);
    });

    // Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Adicionado: $partName"),
        duration: const Duration(milliseconds: 500),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  void _clearMarkers() {
    setState(() => _markers = []);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Frente, Costas, Lat Dir, Lat Esq
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Teste de Croqui & Marcadores"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearMarkers,
              tooltip: "Limpar todos os pinos",
            )
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
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Evita swipe acidental ao dar zoom
          children: [
            // --- ABA 1: FRENTE ---
            CroquiViewer(
              svgPath: 'assets/images/croqui-frente.svg',
              maskPath: 'assets/images/croqui-frente-mask.png',
              colorToIdMap: kColorToIdFrontMap,
              idToDefMap: kIdToDefinitionFrontMap,
              markers: _markers.where((m) => m.croquiType == 'frente').toList(),
              onPartTap: (id, name, x, y) => _addMarker('frente', id, name, x, y),
            ),

            // --- ABA 2: COSTAS ---
            CroquiViewer(
              svgPath: 'assets/images/croqui-costas.svg',
              maskPath: 'assets/images/croqui-costas-mask.png',
              colorToIdMap: kColorToIdBackMap,
              idToDefMap: kIdToDefinitionBackMap,
              markers: _markers.where((m) => m.croquiType == 'costas').toList(),
              onPartTap: (id, name, x, y) => _addMarker('costas', id, name, x, y),
            ),

            // --- ABA 3: LATERAL DIREITA ---
            CroquiViewer(
              svgPath: 'assets/images/croqui-rosto-direito.svg',
              maskPath: 'assets/images/croqui-rosto-direito-mask.png',
              colorToIdMap: kColorToIdLateralRightMap,
              idToDefMap: kIdToDefinitionLateralRightMap,
              markers: _markers.where((m) => m.croquiType == 'lateral_dir').toList(),
              onPartTap: (id, name, x, y) => _addMarker('lateral_dir', id, name, x, y),
            ),

            // --- ABA 4: LATERAL ESQUERDA (Usando rosto-frente conforme seu código) ---
            CroquiViewer(
              svgPath: 'assets/images/croqui-rosto-frente.svg', 
              maskPath: 'assets/images/croqui-rosto-frente-mask.png',
              colorToIdMap: kColorToIdLateralLeftMap,
              idToDefMap: kIdToDefinitionLateralLeftMap,
              markers: _markers.where((m) => m.croquiType == 'lateral_esq').toList(),
              onPartTap: (id, name, x, y) => _addMarker('lateral_esq', id, name, x, y),
            ),
          ],
        ),
      ),
    );
  }
}
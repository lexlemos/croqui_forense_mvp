import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart'; 

class CroquiScenario {
  final String title;
  final String svgPath;
  final String maskPath;
  final Map<int, String> colorToIdMap;
  final Map<String, BodyPartDefinition> idToDefMap;

  CroquiScenario({
    required this.title,
    required this.svgPath,
    required this.maskPath,
    required this.colorToIdMap,
    required this.idToDefMap,
  });
}

class DebugBodyTest extends StatefulWidget {
  const DebugBodyTest({super.key});

  @override
  State<DebugBodyTest> createState() => _DebugBodyTestState();
}

class _DebugBodyTestState extends State<DebugBodyTest> {
  late List<CroquiScenario> scenarios;
  
  int _currentIndex = 0; 
  img.Image? _maskImage;
  String _status = "Carregando...";
  String _selectedPartName = "Toque para testar";
  bool _showMaskOverlay = false; 
  Offset? _lastTapPos;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    
    scenarios = [
      CroquiScenario(
        title: "Corpo Frente",
        svgPath: 'assets/images/croqui-frente.svg',
        maskPath: 'assets/images/croqui-frente-mask.png',
        colorToIdMap: kColorToIdFrontMap,
        idToDefMap: kIdToDefinitionFrontMap,
      ),
      CroquiScenario(
        title: "Corpo Costas",
        svgPath: 'assets/images/croqui-costas.svg',
        maskPath: 'assets/images/croqui-costas-mask.png',
        colorToIdMap: kColorToIdBackMap,
        idToDefMap: kIdToDefinitionBackMap,
      ),
      CroquiScenario(
        title: "Rosto Lateral Dir.",
        svgPath: 'assets/images/croqui-rosto-direito.svg',
        maskPath: 'assets/images/croqui-rosto-direito-mask.png',
        colorToIdMap: kColorToIdLateralRightMap,
        idToDefMap: kIdToDefinitionLateralRightMap,
      ),
      CroquiScenario(
        title: "Rosto Frente",
        svgPath: 'assets/images/croqui-rosto-frente.svg',
        maskPath: 'assets/images/croqui-rosto-frente-mask.png',
        colorToIdMap: kColorToIdLateralLeftMap, 
        idToDefMap: kIdToDefinitionLateralLeftMap,
      ),
    ];

    _loadCurrentMask();
  }

  Future<void> _loadCurrentMask() async {
    setState(() {
      _status = "Carregando máscara...";
      _maskImage = null;
      _selectedPartName = "Aguardando toque...";
      _lastTapPos = null;
    });

    try {
      final current = scenarios[_currentIndex];
      final ByteData data = await rootBundle.load(current.maskPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final decoded = img.decodeImage(bytes);
      
      setState(() {
        _maskImage = decoded;
        _status = "Máscara carregada: ${decoded!.width}x${decoded.height}";
      });
    } catch (e) {
      setState(() => _status = "ERRO ao carregar ${scenarios[_currentIndex].maskPath}:\n$e");
    }
  }

  void _nextCroqui() {
    if (_currentIndex < scenarios.length - 1) {
      setState(() => _currentIndex++);
      _transformationController.value = Matrix4.identity();
      _loadCurrentMask();
    }
  }

  void _prevCroqui() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _transformationController.value = Matrix4.identity();
      _loadCurrentMask();
    }
  }

  void _handleTap(TapUpDetails details, Size renderSize) {
    if (_maskImage == null) return;

    final currentScenario = scenarios[_currentIndex];

    final double scaleX = _maskImage!.width / renderSize.width;
    final double scaleY = _maskImage!.height / renderSize.height;

    final int x = (details.localPosition.dx * scaleX).round();
    final int y = (details.localPosition.dy * scaleY).round();

    if (x < 0 || x >= _maskImage!.width || y < 0 || y >= _maskImage!.height) {
      setState(() => _selectedPartName = "Fora dos limites");
      return;
    }

    final pixel = _maskImage!.getPixel(x, y);
    int colorInt = (0xFF << 24) | (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();

    final String? foundId = currentScenario.colorToIdMap[colorInt];

    setState(() {
      _lastTapPos = details.localPosition;
      if (foundId != null) {
        final def = currentScenario.idToDefMap[foundId];
        _selectedPartName = "PARTE: ${def?.name.toUpperCase()}\n(ID: ${def?.dbId})";
      } else {
        _selectedPartName = "Não identificado\nCor: ${colorInt.toRadixString(16)}";
      }
    });
  }

  void _zoomIn() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1.5);
    _transformationController.value = matrix;
  }
  void _zoomOut() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1 / 1.5);
    _transformationController.value = matrix;
  }
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final currentScenario = scenarios[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentScenario.title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _currentIndex > 0 ? _prevCroqui : null, 
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _currentIndex < scenarios.length - 1 ? _nextCroqui : null,
          ),
          Switch(
            value: _showMaskOverlay, 
            activeColor: Colors.white,
            activeTrackColor: Colors.indigoAccent,
            onChanged: (v) => setState(() => _showMaskOverlay = v)
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(heroTag: "zIn", onPressed: _zoomIn, mini: true, child: const Icon(Icons.add)),
          const SizedBox(height: 10),
          FloatingActionButton(heroTag: "zOut", onPressed: _zoomOut, mini: true, child: const Icon(Icons.remove)),
          const SizedBox(height: 10),
          FloatingActionButton(heroTag: "rst", backgroundColor: Colors.red, onPressed: _resetZoom, mini: true, child: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            width: double.infinity,
            child: Column(
              children: [
                Text("Cenário ${_currentIndex + 1} de ${scenarios.length}", style: const TextStyle(color: Colors.grey)),
                Text(_status, style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 5),
                Text(_selectedPartName, 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: _selectedPartName.startsWith("PARTE") ? Colors.green[800] : Colors.red,
                  )),
              ],
            ),
          ),
          
          Expanded(
            child: _maskImage == null 
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      double aspectRatio = _maskImage!.width / _maskImage!.height;
                      double renderWidth = constraints.maxWidth;
                      double renderHeight = renderWidth / aspectRatio;

                      if (renderHeight > constraints.maxHeight) {
                        renderHeight = constraints.maxHeight;
                        renderWidth = renderHeight * aspectRatio;
                      }

                      return Center(
                        child: SizedBox(
                          width: renderWidth,
                          height: renderHeight,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.1,
                            maxScale: 10.0,
                            boundaryMargin: const EdgeInsets.all(500),
                            panEnabled: true,
                            child: GestureDetector(
                              onTapUp: (d) => _handleTap(d, Size(renderWidth, renderHeight)),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: SvgPicture.asset(
                                      currentScenario.svgPath,
                                      fit: BoxFit.fill,
                                      placeholderBuilder: (ctx) => const Center(child: CircularProgressIndicator()),
                                    ),
                                  ),
                                  if (_showMaskOverlay)
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.6,
                                        child: Image.asset(
                                          currentScenario.maskPath,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                                  if (_lastTapPos != null)
                                    Positioned(
                                      left: _lastTapPos!.dx - 10,
                                      top: _lastTapPos!.dy - 10,
                                      child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white, width: 2),
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
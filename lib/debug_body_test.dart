import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
// IMPORTANTE: Importe o arquivo de dados que acabamos de criar
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';

class DebugBodyTest extends StatefulWidget {
  const DebugBodyTest({super.key});

  @override
  State<DebugBodyTest> createState() => _DebugBodyTestState();
}

class _DebugBodyTestState extends State<DebugBodyTest> {
  final String assetVisual = 'assets/images/croqui-frente.svg';
  final String assetMask = 'assets/images/croqui-frente-mask.png';

  img.Image? _maskImage;
  String _status = "Carregando máscara...";
  // Em vez de _lastColor, agora vamos guardar o nome da parte tocada
  String _selectedPartName = "Nenhuma parte selecionada";
  bool _showMaskOverlay = false; 
  Offset? _lastTapPos;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadMask();
  }

  Future<void> _loadMask() async {
    try {
      final ByteData data = await rootBundle.load(assetMask);
      final Uint8List bytes = data.buffer.asUint8List();
      _maskImage = img.decodeImage(bytes);
      setState(() => _status = "Pronto para testes.");
    } catch (e) {
      setState(() => _status = "Erro ao carregar máscara: $e");
    }
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

  void _handleTap(TapUpDetails details, Size renderSize) {
    if (_maskImage == null) return;

    final double scaleX = _maskImage!.width / renderSize.width;
    final double scaleY = _maskImage!.height / renderSize.height;

    final int x = (details.localPosition.dx * scaleX).round();
    final int y = (details.localPosition.dy * scaleY).round();

    if (x < 0 || x >= _maskImage!.width || y < 0 || y >= _maskImage!.height) {
      setState(() => _selectedPartName = "Toque fora dos limites");
      return;
    }

    // 1. Lê o pixel da imagem de máscara
    final pixel = _maskImage!.getPixel(x, y);
    
    // 2. Converte para o formato inteiro ARGB do Flutter (0xAARRGGBB)
    // Assumindo que a máscara é 100% opaca onde tem cor (Alpha 255 ou 0xFF)
    int colorInt = (0xFF << 24) | (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();

    // 3. A MÁGICA: Usa o mapa para descobrir o ID baseado na cor
    final String? foundId = kColorToIdFrontMap[colorInt];

    setState(() {
      _lastTapPos = details.localPosition;

      if (foundId != null) {
        // 4. Se achou o ID, busca os detalhes (como o nome bonito)
        final definition = kIdToDefinitionFrontMap[foundId];
        _selectedPartName = "PARTE: ${definition?.name.toUpperCase()} (ID: ${definition?.dbId})";
        print("Found ID: $foundId, DB ID: ${definition?.dbId}");
      } else {
        // Se a cor não estiver no mapa (ex: clicou no fundo transparente ou na borda suavizada)
        _selectedPartName = "Nenhuma parte identificada (Cor: ${colorInt.toRadixString(16)})";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Validação de Mapeamento"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
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
          FloatingActionButton(heroTag: "btnZoomIn", onPressed: _zoomIn, child: const Icon(Icons.add)),
          const SizedBox(height: 10),
          FloatingActionButton(heroTag: "btnZoomOut", onPressed: _zoomOut, child: const Icon(Icons.remove)),
          const SizedBox(height: 10),
          FloatingActionButton(heroTag: "btnReset", backgroundColor: Colors.redAccent, onPressed: _resetZoom, child: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Painel de Resultado (Mais destacado agora)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            color: _selectedPartName.startsWith("PARTE:") ? Colors.green[100] : Colors.grey[200],
            width: double.infinity,
            child: Column(
              children: [
                Text(_status, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                // Mostra o nome da parte em letras grandes
                Text(_selectedPartName, 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20, 
                    color: _selectedPartName.startsWith("PARTE:") ? Colors.green[900] : Colors.black87,
                    fontWeight: FontWeight.bold
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
                                      assetVisual,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  if (_showMaskOverlay)
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.6, // Um pouco mais visível
                                        child: Image.asset(
                                          assetMask,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                                  if (_lastTapPos != null)
                                    Positioned(
                                      left: _lastTapPos!.dx - 5,
                                      top: _lastTapPos!.dy - 5,
                                      child: Container(
                                        width: 10, height: 10,
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
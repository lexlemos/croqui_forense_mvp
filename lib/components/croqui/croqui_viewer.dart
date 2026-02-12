import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import '../../data/models/injury_marker_model.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';

typedef OnBodyPartSelected = void Function(
  String bodyPartId, 
  String bodyPartName, 
  double xPercent, 
  double yPercent
);

class CroquiViewer extends StatefulWidget {
  final String svgPath;
  final String maskPath;
  final Map<int, String> colorToIdMap;     
  final Map<String, BodyPartDefinition> idToDefMap;   
  final List<InjuryMarker> markers;        
  final OnBodyPartSelected onPartTap;      

  const CroquiViewer({
    super.key,
    required this.svgPath,
    required this.maskPath,
    required this.colorToIdMap,
    required this.idToDefMap,
    required this.markers,
    required this.onPartTap,
  });

  @override
  State<CroquiViewer> createState() => _CroquiViewerState();
}

class _CroquiViewerState extends State<CroquiViewer> {
  img.Image? _maskImage;
  bool _isLoading = true;
  String? _errorMessage;
  
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMask();
  }

  @override
  void didUpdateWidget(covariant CroquiViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maskPath != widget.maskPath) {
      _loadMask();
    }
  }

  Future<void> _loadMask() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ByteData data = await rootBundle.load(widget.maskPath);
      final Uint8List bytes = data.buffer.asUint8List();
      _maskImage = img.decodeImage(bytes);
      
      if (_maskImage == null) throw Exception("Falha ao decodificar imagem");

    } catch (e) {
      debugPrint("Erro ao carregar máscara: $e");
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTap(TapUpDetails details) {
    if (_maskImage == null) return;

    // 1. Busca o tamanho EXATO que a imagem está ocupando na tela agora
    final RenderBox? box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Size widgetSize = box.size;
    final Offset localPos = box.globalToLocal(details.globalPosition);

    // 2. Cálculo da porcentagem (0.0 a 1.0)
    double xPercent = localPos.dx / widgetSize.width;
    double yPercent = localPos.dy / widgetSize.height;

    // 3. Mapeia para o pixel da imagem original (Máscara PNG)
    final int imgX = (xPercent * _maskImage!.width).floor();
    final int imgY = (yPercent * _maskImage!.height).floor();

    // Proteção de limites
    if (imgX < 0 || imgX >= _maskImage!.width || imgY < 0 || imgY >= _maskImage!.height) return;

    final pixel = _maskImage!.getPixel(imgX, imgY);
    int colorInt = (0xFF << 24) | (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();

    final String? foundId = widget.colorToIdMap[colorInt];

    if (foundId != null) {
      final def = widget.idToDefMap[foundId];
      widget.onPartTap(foundId, def?.name ?? "Desconhecido", xPercent, yPercent);
    }
  }

@override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text("Erro: $_errorMessage", style: const TextStyle(color: Colors.red)));
    if (_maskImage == null) return const SizedBox();

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          // FittedBox garante que não há espaço extra invisível
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _maskImage!.width.toDouble(),
              height: _maskImage!.height.toDouble(),
              child: Stack(
                key: _imageKey, // A chave mágica para o cálculo de posição
                children: [
                  // CAMADA 1: O SVG (Agora sem borda vermelha)
                  Positioned.fill(
                    child: SvgPicture.asset(
                      widget.svgPath,
                      fit: BoxFit.fill, 
                    ),
                  ),

                  // CAMADA 2: O Detector de Toque
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: _handleTap,
                    ),
                  ),

                  // CAMADA 3: Os Marcadores
                  ...widget.markers.map((marker) {
                    
                    double left = marker.xPercent * _maskImage!.width;
                    double top = marker.yPercent * _maskImage!.height;
                    const double iconSize = 40.0; // Tamanho do ícone

                    return Positioned(
                      left: left - (iconSize / 2), // Centraliza X
                      top: top - iconSize,         // Ponta no Y
                      
                      child: const Icon(
                        Icons.location_on, 
                        // Se quiser mudar a cor do PINO, altere aqui:
                        color: Colors.red, 
                        size: iconSize,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(2, 2))
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
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
  final List<Achado> markers;     
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
  ui.Image? _uiMaskImage;
  ByteData? _rawMaskBytes;
  bool _isLoadingMask = true;
  String? _errorMessage;
  final GlobalKey _imageKey = GlobalKey();

  int _maskWidth = 0;
  int _maskHeight = 0;

  Widget? _cachedSvg;

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
    if (oldWidget.svgPath != widget.svgPath) {
      _cachedSvg = null;
    }
  }

  @override
  void dispose() {
    _uiMaskImage?.dispose();
    _uiMaskImage = null;
    _rawMaskBytes = null;
    _cachedSvg = null;
    super.dispose();
  }

  Future<void> _loadMask() async {
    if (!mounted) return;
    
    final String currentLoadPath = widget.maskPath;

    setState(() {
      _isLoadingMask = true;
      _errorMessage = null;
      _uiMaskImage?.dispose();
      _uiMaskImage = null;
      _rawMaskBytes = null;
      _maskWidth = 0;
      _maskHeight = 0;
    });

    try {
      final ByteData data = await rootBundle.load(currentLoadPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode using native C++ engine codec off the main thread
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image uiImage = frameInfo.image;

      // Extract raw RGBA bytes asynchronously
      final ByteData? rawBytes = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (!mounted) {
        uiImage.dispose();
        return;
      }

      if (widget.maskPath != currentLoadPath) {
        uiImage.dispose();
        return;
      }

      if (rawBytes == null) {
        uiImage.dispose();
        throw Exception("Falha ao obter bytes da máscara"); 
      }

      setState(() {
        _uiMaskImage = uiImage;
        _rawMaskBytes = rawBytes;
        _maskWidth = uiImage.width;
        _maskHeight = uiImage.height;
        _isLoadingMask = false;
      });

    } catch (e) {
      debugPrint("Erro ao carregar máscara: $e");
      if (mounted && widget.maskPath == currentLoadPath) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingMask = false;
        });
      }
    }
  }

  void _handleTap(TapUpDetails details) {
    if (_rawMaskBytes == null || _maskWidth <= 0 || _maskHeight <= 0) return;

    final RenderBox? box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Size widgetSize = box.size;
    final Offset localPos = box.globalToLocal(details.globalPosition);

    double xPercent = localPos.dx / widgetSize.width;
    double yPercent = localPos.dy / widgetSize.height;

    final int imgX = (xPercent * _maskWidth).floor();
    final int imgY = (yPercent * _maskHeight).floor();

    if (imgX < 0 || imgX >= _maskWidth || imgY < 0 || imgY >= _maskHeight) return;

    final int pixelOffset = (imgY * _maskWidth + imgX) * 4;
    final ByteData rawBytes = _rawMaskBytes!;
    if (pixelOffset < 0 || pixelOffset + 4 > rawBytes.lengthInBytes) return;

    final int r = rawBytes.getUint8(pixelOffset);
    final int g = rawBytes.getUint8(pixelOffset + 1);
    final int b = rawBytes.getUint8(pixelOffset + 2);
    final int a = rawBytes.getUint8(pixelOffset + 3);

    int colorInt = (a << 24) | (r << 16) | (g << 8) | b;

    final String? foundId = widget.colorToIdMap[colorInt];
    if (foundId == null) return; // early return for unmapped color

    final def = widget.idToDefMap[foundId];
    if (def == null) return; // early return if definition is not in currently active dictionary (e.g. wrong sex)

    widget.onPartTap(foundId, def.name, xPercent, yPercent);
  }

  Widget _getSvgBackground() {
    _cachedSvg ??= RepaintBoundary(
      child: SvgPicture.asset(
        widget.svgPath,
        fit: BoxFit.fill,
      ),
    );
    return _cachedSvg!;
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Erro ao carregar diagrama: $_errorMessage",
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bool showCanvas = _maskWidth > 0 && _maskHeight > 0;
    if (!showCanvas) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          child: AspectRatio(
            aspectRatio: _maskWidth / _maskHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double containerWidth = constraints.maxWidth;
                final double containerHeight = constraints.maxHeight;

                return Stack(
                  key: _imageKey,
                  children: [
                    Positioned.fill(
                      child: _getSvgBackground(),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _handleTap,
                      ),
                    ),

                    ...widget.markers.where((marker) {
                      final String? bodyPartId = marker.dadosPreenchidos['local_anatomico_id']?.toString();
                      if (bodyPartId == null) return false;
                      return widget.idToDefMap.containsKey(bodyPartId);
                    }).map((marker) {
                      double left = marker.posX * containerWidth;
                      double top = marker.posY * containerHeight;
                      const double iconSize = 24.0;

                      return Positioned(
                        left: left - (iconSize / 2),
                        top: top - iconSize,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: iconSize,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(2, 2))
                          ],
                        ),
                      );
                    }),

                    if (_isLoadingMask)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
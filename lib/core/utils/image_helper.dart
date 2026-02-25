import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageHelper {
  
  static Future<File> compressImage(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    
    final evidenciasDir = Directory(p.join(dir.path, 'evidencias'));
    
    if (!await evidenciasDir.exists()) {
      await evidenciasDir.create(recursive: true);
    }

    final fileName = "evidencia_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final targetPath = p.join(evidenciasDir.path, fileName);

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80, 
      minWidth: 1280, 
      minHeight: 1280,
      rotate: 0, 
      keepExif: false, 
    );

    if (result == null) {
      throw Exception("Falha ao comprimir imagem");
    }

    return File(result.path);
  }
}
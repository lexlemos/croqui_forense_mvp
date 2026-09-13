import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageHelper {
  
  static Future<File> compressImage(File file, String fotoUuid) async {
    final dir = await getApplicationDocumentsDirectory();
    
    final evidenciasDir = Directory(p.join(dir.path, 'evidencias'));
    
    if (!await evidenciasDir.exists()) {
      await evidenciasDir.create(recursive: true);
    }

    final fileName = "$fotoUuid.jpg";
    String targetPath = p.join(evidenciasDir.path, fileName);

    bool usedTemp = false;
    if (file.absolute.path == targetPath) {
      targetPath = p.join(evidenciasDir.path, 'temp_$fileName');
      usedTemp = true;
    }

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, 
      minWidth: 1200, 
      minHeight: 1200,
      rotate: 0, 
      keepExif: true, 
    );

    if (result == null) {
      throw Exception("Falha ao comprimir imagem");
    }

    if (usedTemp) {
      File tempFile = File(result.path);
      String finalPath = p.join(evidenciasDir.path, fileName);
      await tempFile.copy(finalPath);
      await tempFile.delete();
      return File(finalPath);
    }

    return File(result.path);
  }
}
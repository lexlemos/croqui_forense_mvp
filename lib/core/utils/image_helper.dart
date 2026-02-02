import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageHelper {
  
  static Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.path, "out_${DateTime.now().millisecondsSinceEpoch}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80, 
      minWidth: 1280, 
      minHeight: 1280,
    );

    return File(result!.path);
  }
  static Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    dir.deleteSync(recursive: true);
  }
}
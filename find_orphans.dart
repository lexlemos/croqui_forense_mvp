import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final allFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  
  final allPaths = allFiles.map((f) => f.path.replaceAll('\\', '/')).toList();
  
  final importPatterns = <String, int>{};
  for (final path in allPaths) {
    importPatterns[path] = 0;
  }

  for (final file in allFiles) {
    final content = file.readAsStringSync();
    for (final path in allPaths) {
      final fileName = path.split('/').last;
      // Basic check: if the content contains the filename
      if (content.contains(fileName) && file.path.replaceAll('\\', '/') != path) {
        importPatterns[path] = importPatterns[path]! + 1;
      }
    }
  }

  final orphans = importPatterns.entries.where((e) => e.value == 0 && !e.key.endsWith('main.dart')).toList();
  print('Orphan files:');
  for (final orphan in orphans) {
    print(orphan.key);
  }
}

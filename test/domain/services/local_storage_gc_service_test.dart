import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/domain/services/local_storage_gc_service.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockDatabase extends Mock implements Database {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory evidenciasDir;
  late Directory laudosDir;
  late MockDatabaseHelper mockDbHelper;
  late MockDatabase mockDb;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gc_test_');
    evidenciasDir = Directory(p.join(tempDir.path, 'evidencias'));
    await evidenciasDir.create(recursive: true);
    laudosDir = Directory(p.join(tempDir.path, 'laudos'));
    await laudosDir.create(recursive: true);

    mockDbHelper = MockDatabaseHelper();
    mockDb = MockDatabase();
    when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalStorageGcService - Invariante 3 e Proteção de Fotos Locais', () {
    test('1. limparArquivosOrfaos preserva foto local registrada e remove apenas órfãos reais', () async {
      // 1. Cria foto válida local e foto órfã no disco
      final fotoValida = File(p.join(evidenciasDir.path, 'foto_evidencia_1.jpg'));
      await fotoValida.writeAsString('bytes-validos-foto-1');

      final fotoOrfa = File(p.join(evidenciasDir.path, 'foto_orfa_antiga.jpg'));
      await fotoOrfa.writeAsString('bytes-foto-orfa');

      // 2. Simula o banco SQLite registrando o caminho do arquivo físico local
      // e os campos novos remotos (chave_storage / url_storage)
      when(() => mockDb.query(
        tableCasos,
        columns: ['pdf_local_path'],
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      )).thenAnswer((_) async => []);

      when(() => mockDb.query(
        tableEvidenciasMultimidia,
        columns: ['caminho_arquivo_encriptado'],
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      )).thenAnswer((_) async => [
        {
          'caminho_arquivo_encriptado': fotoValida.path,
          'chave_storage': '2026/10/caso-123/evidencias/foto_1.jpg',
          'url_storage': 'https://s3.policiacientifica.se.gov.br/signed/foto_1.jpg',
        }
      ]);

      final gcService = LocalStorageGcService(
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      final removidos = await gcService.limparArquivosOrfaos();

      // 3. Asserções rigorosas (Invariante 3):
      expect(removidos, equals(1), reason: 'Apenas a foto órfã real deve ser removida');
      expect(fotoValida.existsSync(), isTrue, reason: 'Foto local com referência ativa NUNCA pode ser apagada');
      expect(fotoOrfa.existsSync(), isFalse, reason: 'Arquivo sem registro no banco deve ser limpo');
    });

    test('2. executarLimpezaDeRotina não expurga casos em andamento ou recentes', () async {
      when(() => mockDb.rawQuery(any(), any())).thenAnswer((_) async => []);

      final gcService = LocalStorageGcService(
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      final expurgados = await gcService.executarLimpezaDeRotina();
      expect(expurgados, equals(0));
    });
  });
}

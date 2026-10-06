import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/domain/services/media_storage_service.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockDatabaseHelper mockDbHelper;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('media_storage_test_');
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockDbHelper = MockDatabaseHelper();

    when(() => mockApiClient.dio).thenReturn(mockDio);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MediaStorageService - Resolução de Mídia Offline-First', () {
    test('1. Retorna arquivo local existente sem realizar chamada de rede', () async {
      final existingFile = File('${tempDir.path}/foto_existente.jpg');
      final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01]);
      await existingFile.writeAsBytes(fakeBytes, flush: true);

      final service = MediaStorageService(
        apiClient: mockApiClient,
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      final file = await service.getLocalMediaFile(
        localPath: existingFile.path,
      );

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(await file.readAsBytes(), equals(fakeBytes));
      verifyZeroInteractions(mockDio);
    });

    test('2. Quando arquivo local não existe, faz fetch via API /media/{uuid}.jpg e persiste no disco', () async {
      const evidenciaUuid = 'e8b8c2d1-0000-4000-8000-000000000001';
      final downloadedBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);

      when(() => mockDio.get<List<int>>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<List<int>>(
            data: downloadedBytes,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/media/$evidenciaUuid.jpg'),
          ));

      final service = MediaStorageService(
        apiClient: mockApiClient,
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      final file = await service.getLocalMediaFile(
        localPath: '${tempDir.path}/arquivo_inexistente.jpg',
        evidenciaUuid: evidenciaUuid,
      );

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(await file.readAsBytes(), equals(downloadedBytes));

      // Verifica que a URL correta foi solicitada
      verify(() => mockDio.get<List<int>>(
            any(that: contains('media/$evidenciaUuid.jpg')),
            options: any(named: 'options'),
          )).called(1);
    });

    test('3. resolveImageBytes retorna bytes da imagem baixada em cache', () async {
      const evidenciaUuid = 'e8b8c2d1-0000-4000-8000-000000000002';
      final downloadedBytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);

      when(() => mockDio.get<List<int>>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<List<int>>(
            data: downloadedBytes,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/media/$evidenciaUuid.jpg'),
          ));

      final service = MediaStorageService(
        apiClient: mockApiClient,
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      final bytes = await service.resolveImageBytes(
        evidenciaUuid: evidenciaUuid,
      );

      expect(bytes, isNotNull);
      expect(bytes, equals(downloadedBytes));
    });

    test('4. saveCapturedImage copia arquivo para pasta de evidencias com nome uuid.jpg', () async {
      final rawSourceFile = File('${tempDir.path}/raw_camera.jpg');
      final rawBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      await rawSourceFile.writeAsBytes(rawBytes);

      final service = MediaStorageService(
        apiClient: mockApiClient,
        dbHelper: mockDbHelper,
        baseDirectoryOverride: tempDir,
      );

      const newUuid = 'foto-uuid-999';
      final savedFile = await service.saveCapturedImage(rawSourceFile, newUuid);

      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.path, endsWith('foto-uuid-999.jpg'));
      expect(await savedFile.readAsBytes(), equals(rawBytes));
    });
  });
}

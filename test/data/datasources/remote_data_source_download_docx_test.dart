import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/data/datasources/remote_data_source_impl.dart';

class MockDio extends Mock implements Dio {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late RemoteDataSourceImpl remoteDataSource;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    remoteDataSource = RemoteDataSourceImpl(mockApiClient);
    tempDir = Directory.systemTemp.createTempSync('docx_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('RemoteDataSourceImpl - downloadLaudoDocx', () {
    test('1. Baixa bytes com sucesso e persiste no arquivo destino', () async {
      final destFile = File('${tempDir.path}/laudo_teste.docx');
      final fakeBytes = [80, 75, 3, 4, 1, 2, 3]; // Assinatura PK zip/docx

      when(
        () => mockDio.get<List<int>>(
          'croqui/laudo-docx/caso-123',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          data: fakeBytes,
          statusCode: 200,
          requestOptions: RequestOptions(path: 'croqui/laudo-docx/caso-123'),
        ),
      );

      final resultado = await remoteDataSource.downloadLaudoDocx(
        casoUuid: 'caso-123',
        destinationFile: destFile,
      );

      expect(resultado.existsSync(), isTrue);
      expect(await resultado.readAsBytes(), equals(fakeBytes));
    });

    test(
      '2. Lança exceção amigável quando backend retorna 404 (pacote ausente)',
      () async {
        final destFile = File('${tempDir.path}/laudo_404.docx');

        when(
          () => mockDio.get<List<int>>(
            'croqui/laudo-docx/caso-404',
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: 'croqui/laudo-docx/caso-404'),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(
                path: 'croqui/laudo-docx/caso-404',
              ),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(
          () => remoteDataSource.downloadLaudoDocx(
            casoUuid: 'caso-404',
            destinationFile: destFile,
          ),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains('não encontrado no servidor'),
            ),
          ),
        );
      },
    );

    test(
      '3. Lança exceção de conectividade quando dispositivo está offline',
      () async {
        final destFile = File('${tempDir.path}/laudo_offline.docx');

        when(
          () => mockDio.get<List<int>>(
            'croqui/laudo-docx/caso-offline',
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: 'croqui/laudo-docx/caso-offline',
            ),
            type: DioExceptionType.connectionError,
          ),
        );

        expect(
          () => remoteDataSource.downloadLaudoDocx(
            casoUuid: 'caso-offline',
            destinationFile: destFile,
          ),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains('Dispositivo offline'),
            ),
          ),
        );
      },
    );

    test(
      '4. Lança exceção de permissão negada quando backend retorna 403',
      () async {
        final destFile = File('${tempDir.path}/laudo_403.docx');

        when(
          () => mockDio.get<List<int>>(
            'croqui/laudo-docx/caso-403',
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: 'croqui/laudo-docx/caso-403'),
            response: Response(
              statusCode: 403,
              requestOptions: RequestOptions(
                path: 'croqui/laudo-docx/caso-403',
              ),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(
          () => remoteDataSource.downloadLaudoDocx(
            casoUuid: 'caso-403',
            destinationFile: destFile,
          ),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains('Permissão negada (403)'),
            ),
          ),
        );
      },
    );
  });
}

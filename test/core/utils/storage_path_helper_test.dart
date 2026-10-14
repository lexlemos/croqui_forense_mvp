import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/utils/storage_path_helper.dart';

void main() {
  group('StoragePathHelper - Identificação de Caminhos Locais vs Remotos', () {
    test('Identifica URLs HTTP e HTTPS como remotas', () {
      expect(
        StoragePathHelper.isRemoteKeyOrUrl('http://s3.local/bucket/foto.jpg'),
        isTrue,
      );
      expect(
        StoragePathHelper.isRemoteKeyOrUrl(
          'https://minio.policiacientifica.se.gov.br/foto.png',
        ),
        isTrue,
      );
      expect(
        StoragePathHelper.isHttpUrl(
          'https://minio.policiacientifica.se.gov.br/foto.png',
        ),
        isTrue,
      );
      expect(
        StoragePathHelper.isHttpUrl(
          'http://minio.policiacientifica.se.gov.br/foto.png',
        ),
        isTrue,
      );
      expect(StoragePathHelper.isHttpUrl('bucket/chave.png'), isFalse);
      expect(
        StoragePathHelper.isLocalFilePath('http://s3.local/bucket/foto.jpg'),
        isFalse,
      );
    });

    test(
      'Identifica chaves de bucket sem separador de diretório do SO como remotas',
      () {
        expect(
          StoragePathHelper.isRemoteKeyOrUrl('2026/10/caso-uuid/foto.jpg'),
          isTrue,
        );
        expect(
          StoragePathHelper.isRemoteKeyOrUrl('evidencia-uuid-123.jpg'),
          isTrue,
        );
      },
    );

    test(
      'Identifica caminhos absolutos do sistema operacional como locais',
      () {
        const caminhoLinux =
            '/data/user/0/br.gov.se.policiacientifica/evidencias/foto.jpg';
        const caminhoWindows =
            'C:\\dev\\croqui_forense_mvp\\evidencias\\foto.jpg';

        if (Platform.isWindows) {
          expect(StoragePathHelper.isLocalFilePath(caminhoWindows), isTrue);
          expect(StoragePathHelper.isRemoteKeyOrUrl(caminhoWindows), isFalse);
        } else {
          expect(StoragePathHelper.isLocalFilePath(caminhoLinux), isTrue);
          expect(StoragePathHelper.isRemoteKeyOrUrl(caminhoLinux), isFalse);
        }
      },
    );

    test('Lida de forma segura com valores nulos e strings vazias', () {
      expect(StoragePathHelper.isRemoteKeyOrUrl(null), isFalse);
      expect(StoragePathHelper.isRemoteKeyOrUrl(''), isFalse);
      expect(StoragePathHelper.isLocalFilePath(null), isFalse);
      expect(StoragePathHelper.isLocalFilePath(''), isFalse);
    });
  });
}

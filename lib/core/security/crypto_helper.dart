// lib/core/security/crypto_helper.dart
//
// Scaffold para criptografia de evidências forenses.
// Não utilizado no MVP (envio em plaintext). Será implementado com
// AES-256-GCM (pointycastle) antes do deploy em produção.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CryptoResult {
  final File encryptedFile;
  final String plainHash;
  final String cipherHash;
  final String saltBase64;
  final String mockChaveCifradaBase64;

  const CryptoResult({
    required this.encryptedFile,
    required this.plainHash,
    required this.cipherHash,
    required this.saltBase64,
    required this.mockChaveCifradaBase64,
  });
}

class CryptoHelper {
  CryptoHelper._();

  static const List<int> jpegMagicPrefix = [0xFF, 0xD8, 0xFF, 0xE0];

  static Future<CryptoResult> encryptEvidence(File arquivoOriginal) async {
    final Uint8List plainBytes = await arquivoOriginal.readAsBytes();
    final String plainHash = _sha256hex(plainBytes);

    final Uint8List salt = _generateSalt(32);
    final String saltBase64 = base64.encode(salt);

    final Uint8List cipherBytes = _xorEncrypt(plainBytes, salt);

    final Uint8List payload = Uint8List(jpegMagicPrefix.length + cipherBytes.length)
      ..setAll(0, jpegMagicPrefix)
      ..setAll(jpegMagicPrefix.length, cipherBytes);

    final String cipherHash = _sha256hex(payload);

    final File encryptedFile = await _writeTempFile(payload, suffix: '.jpg');
    final String mockChaveCifradaBase64 = base64.encode(salt);

    return CryptoResult(
      encryptedFile: encryptedFile,
      plainHash: plainHash,
      cipherHash: cipherHash,
      saltBase64: saltBase64,
      mockChaveCifradaBase64: mockChaveCifradaBase64,
    );
  }

  static Future<void> deleteEncryptedFile(File encryptedFile) async {
    try {
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
    } catch (_) {}
  }

  static Uint8List _generateSalt(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  static Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  static String _sha256hex(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  static Future<File> _writeTempFile(Uint8List bytes, {String suffix = ''}) async {
    final dir = await getTemporaryDirectory();
    final name = '${DateTime.now().microsecondsSinceEpoch}$suffix';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

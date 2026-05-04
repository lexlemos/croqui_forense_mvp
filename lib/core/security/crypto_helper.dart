// lib/core/security/crypto_helper.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ===========================================================================
// RESULTADO DA CRIPTOGRAFIA
// ===========================================================================

/// Resultado retornado por [CryptoHelper.encryptEvidence].
///
/// Encapsula o arquivo cifrado temporário e todos os metadados de integridade
/// necessários para o upload seguro e a auditoria forense.
class CryptoResult {
  /// Arquivo temporário contendo o blob cifrado (AES-256-CTR simulado via XOR).
  ///
  /// **Deve ser deletado** após o upload via [CryptoHelper.deleteEncryptedFile].
  final File encryptedFile;

  /// SHA-256 do arquivo **original** (plaintext), em hex lowercase.
  ///
  /// Enviado ao backend para verificar a integridade antes da criptografia.
  final String plainHash;

  /// SHA-256 do arquivo **cifrado**, em hex lowercase.
  ///
  /// Permite ao servidor detectar corrupção durante o upload.
  final String cipherHash;

  /// Salt aleatório de 32 bytes codificado em Base64.
  ///
  /// Combinado com a chave de sessão para derivar a chave de criptografia.
  final String saltBase64;

  /// Representação Base64 da chave cifrada (mock para MVP).
  ///
  /// Em produção, este campo deve conter a chave de sessão AES
  /// cifrada com a chave pública RSA do servidor.
  ///
  /// TODO: [CRYPTO] Substituir por RSA-OAEP real antes do deploy.
  final String mockChaveCifradaBase64;

  const CryptoResult({
    required this.encryptedFile,
    required this.plainHash,
    required this.cipherHash,
    required this.saltBase64,
    required this.mockChaveCifradaBase64,
  });
}

// ===========================================================================
// CRYPTO HELPER — Métodos estáticos, sem estado
// ===========================================================================

/// Utilitário de criptografia de evidências forenses.
///
/// Todos os métodos são **estáticos** — não há instância, não há estado
/// compartilhado entre chamadas. Seguro para uso concorrente.
///
/// ### Aviso de MVP
/// A criptografia atual usa XOR com um salt aleatório como substituto
/// temporário para AES-256. Isso NÃO oferece segurança criptográfica real.
/// Antes do deploy em produção, substitua por `package:pointycastle` com
/// AES-256-GCM e derivação de chave via PBKDF2 ou HKDF.
///
/// TODO: [CRYPTO] Implementar AES-256-GCM com pointycastle antes do deploy.
class CryptoHelper {
  // Construtor privado: impede instanciação acidental.
  CryptoHelper._();

  // ---------------------------------------------------------------------------
  // CRIPTOGRAFIA
  // ---------------------------------------------------------------------------

  /// Cifra o [arquivoOriginal] e salva o resultado em um arquivo temporário.
  ///
  /// Retorna um [CryptoResult] com o arquivo cifrado e os metadados de
  /// integridade. O chamador é **obrigado** a deletar o arquivo temporário
  /// após o upload chamando [deleteEncryptedFile].
  ///
  /// ### Implementação atual (MVP)
  /// - Gera 32 bytes de salt aleatório via [Random.secure].
  /// - XOR byte-a-byte dos dados com um keystream derivado do salt.
  /// - Calcula SHA-256 do plaintext e do ciphertext.
  ///
  /// TODO: [CRYPTO] Substituir XOR por AES-256-GCM (pointycastle).
  static Future<CryptoResult> encryptEvidence(File arquivoOriginal) async {
    debugPrint('[CryptoHelper] 🔐 Cifrando: ${arquivoOriginal.path}');

    // 1. Lê o arquivo original em memória.
    final Uint8List plainBytes = await arquivoOriginal.readAsBytes();

    // 2. Calcula o SHA-256 do plaintext (integridade pré-cifra).
    final String plainHash = _sha256hex(plainBytes);

    // 3. Gera um salt aleatório de 32 bytes.
    final Uint8List salt = _generateSalt(32);
    final String saltBase64 = base64.encode(salt);

    // 4. Cifra via XOR (MVP — substitua por AES-256-GCM em produção).
    final Uint8List cipherBytes = _xorEncrypt(plainBytes, salt);

    // 5. Calcula o SHA-256 do ciphertext (integridade pós-cifra).
    final String cipherHash = _sha256hex(cipherBytes);

    // 6. Persiste o arquivo cifrado no diretório temporário do app.
    final File encryptedFile = await _writeTempFile(
      cipherBytes,
      suffix: '.enc',
    );

    // 7. Mock da chave cifrada (em produção: RSA-OAEP com chave pública do servidor).
    final String mockChaveCifradaBase64 = base64.encode(salt); // placeholder

    debugPrint(
      '[CryptoHelper] ✅ Cifrado: ${encryptedFile.path} '
      '(plain: $plainHash, cipher: $cipherHash)',
    );

    return CryptoResult(
      encryptedFile: encryptedFile,
      plainHash: plainHash,
      cipherHash: cipherHash,
      saltBase64: saltBase64,
      mockChaveCifradaBase64: mockChaveCifradaBase64,
    );
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  /// Deleta o arquivo cifrado temporário gerado por [encryptEvidence].
  ///
  /// Deve ser chamado no bloco `finally` do upload para garantir que
  /// nenhum dado sensível permaneça no armazenamento do dispositivo.
  ///
  /// Silencia erros de I/O para não mascarar exceções do upload principal.
  static Future<void> deleteEncryptedFile(File encryptedFile) async {
    try {
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
        debugPrint('[CryptoHelper] 🗑️ Arquivo cifrado deletado: ${encryptedFile.path}');
      }
    } catch (e) {
      debugPrint('[CryptoHelper] ⚠️ Falha ao deletar arquivo cifrado: $e');
      // Engole o erro — o arquivo pode não existir em alguns cenários de teste.
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVADOS
  // ---------------------------------------------------------------------------

  /// Gera [length] bytes criptograficamente aleatórios.
  static Uint8List _generateSalt(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// Cifra [data] via XOR com um keystream derivado ciclicamente de [key].
  ///
  /// TODO: [CRYPTO] Substituir por AES-256-GCM (pointycastle) antes do deploy.
  static Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Retorna o SHA-256 de [bytes] como string hexadecimal lowercase.
  static String _sha256hex(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Salva [bytes] em um arquivo temporário no cache do app e retorna o [File].
  static Future<File> _writeTempFile(Uint8List bytes, {String suffix = ''}) async {
    final dir = await getTemporaryDirectory();
    final name = '${DateTime.now().microsecondsSinceEpoch}$suffix';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

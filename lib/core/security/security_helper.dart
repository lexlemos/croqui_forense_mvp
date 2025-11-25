import 'dart:convert';
// A chave é usar 'show sha256' para garantir que ele seja importado
import 'package:crypto/crypto.dart' show sha256;

class SecurityHelper {
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}


import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  // TODO::: Em produção, usaríamos um algoritmo mais forte como Argon2 ou Bcrypt,
  // mas para o requisito MVP local, o SHA-256 é suficiente.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
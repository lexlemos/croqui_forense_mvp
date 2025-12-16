import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/key_derivators/api.dart';

class SecurityHelper {
  static const int _iterations = 10000;
  static const int _keyLength = 32; 
  static const int _saltLength = 16;

  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      saltBytes[i] = random.nextInt(256);
    }
    return base64Encode(saltBytes);
  }

  static String hashPin(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final pinBytes = utf8.encode(pin); 

    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));

    final params = Pbkdf2Parameters(saltBytes, _iterations, _keyLength);
    derivator.init(params);
    final derivedKey = derivator.process(Uint8List.fromList(pinBytes));

    return base64Encode(derivedKey);
  }

  static bool verifyPin(String inputPin, String storedHash, String storedSalt) {
    try {
      final newHash = hashPin(inputPin, storedSalt);
      
      return _constantTimeCompare(newHash, storedHash);
    } catch (e) {
      return false;
    }
  }

  static bool _constantTimeCompare(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);

    if (aBytes.length != bBytes.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < aBytes.length; i++) {
      result |= aBytes[i] ^ bBytes[i];
    }
    return result == 0;
  }
}
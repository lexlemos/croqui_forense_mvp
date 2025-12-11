import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

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

    final derivedKey = _pbkdf2(pinBytes, saltBytes, _iterations, _keyLength);
    
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

  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final derivedKey = Uint8List(keyLength);
    final blockLength = hmac.convert([]).bytes.length;
    final totalBlocks = (keyLength / blockLength).ceil();

    int offset = 0;
    for (int block = 1; block <= totalBlocks; block++) {
      var u = hmac.convert([...salt, ..._intTo4Bytes(block)]).bytes;
      var t = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < u.length; j++) {
          t[j] ^= u[j];
        }
      }

      final copyLen = min(blockLength, keyLength - offset);
      for (int i = 0; i < copyLen; i++) {
        derivedKey[offset + i] = t[i];
      }
      offset += copyLen;
    }

    return derivedKey;
  }

  static List<int> _intTo4Bytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
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
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

void main() {
  print('--- 🕵️ LABORATÓRIO FORENSE DIGITAL ---');
  print('Testando integridade do algoritmo PBKDF2\n');

  const pinOriginal = '1234';
  print('1. PIN Definido: "$pinOriginal"');

  final salt = SecurityHelper.generateSalt();
  print('2. Salt Gerado (Base64): $salt');

  final hash = SecurityHelper.hashPin(pinOriginal, salt);
  print('3. Hash Resultante: $hash');

  final validouCorreto = SecurityHelper.verifyPin(pinOriginal, hash, salt);
  print('4. Teste Senha Correta ("1234"): ${validouCorreto ? "✅ SUCESSO" : "❌ FALHA"}');

  final validouErrado = SecurityHelper.verifyPin('0000', hash, salt);
  print('5. Teste Senha Errada ("0000"):  ${!validouErrado ? "✅ BLOQUEADO" : "❌ FALHA DE SEGURANÇA"}');

  final hash2 = SecurityHelper.hashPin(pinOriginal, salt);
  if (hash == hash2) {
    print('6. Consistência do Algoritmo:    ✅ ESTÁVEL');
  } else {
    print('6. Consistência do Algoritmo:    ❌ INSTÁVEL (Resultados diferentes)');
  }
}
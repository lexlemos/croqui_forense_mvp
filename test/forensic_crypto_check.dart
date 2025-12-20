import 'package:croqui_forense_mvp/core/security/security_helper.dart';

void main() {
  print('--- 🕵️ LABORATÓRIO FORENSE DIGITAL ---');
  print('Testando integridade do algoritmo PBKDF2\n');

  // 1. Definição do Cenário
  const pinOriginal = '1234';
  print('1. PIN Definido: "$pinOriginal"');

  // 2. Geração do Salt
  final salt = SecurityHelper.generateSalt();
  print('2. Salt Gerado (Base64): $salt');
  
  // Validação do Salt
  if (salt.isEmpty || !salt.contains(RegExp(r'[A-Za-z0-9+/=]'))) {
    print('   ❌ ALERTA: O Salt parece estar mal formatado ou vazio.');
  } else {
    print('   ✅ Formato do Salt OK.');
  }

  // 3. Geração do Hash
  final hash = SecurityHelper.hashPin(pinOriginal, salt);
  print('3. Hash Resultante: $hash');

  // 4. Teste de Validação Positiva
  final validouCorreto = SecurityHelper.verifyPin(pinOriginal, hash, salt);
  print('4. Teste Senha Correta ("1234"): ${validouCorreto ? "✅ SUCESSO" : "❌ FALHA"}');

  // 5. Teste de Validação Negativa (Simulação de Ataque)
  final validouErrado = SecurityHelper.verifyPin('0000', hash, salt);
  print('5. Teste Senha Errada ("0000"):  ${!validouErrado ? "✅ BLOQUEADO" : "❌ FALHA DE SEGURANÇA"}');

  // 6. Teste de Consistência (Mesmo input deve gerar mesmo output com mesmo salt)
  final hash2 = SecurityHelper.hashPin(pinOriginal, salt);
  if (hash == hash2) {
    print('6. Consistência do Algoritmo:    ✅ ESTÁVEL');
  } else {
    print('6. Consistência do Algoritmo:    ❌ INSTÁVEL (Resultados diferentes)');
  }
}
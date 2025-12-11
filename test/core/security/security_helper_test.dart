import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

void main() {
  group('SecurityHelper (Núcleo Criptográfico)', () {
    
    test('generateSalt deve criar strings únicas e aleatórias', () {
      final salt1 = SecurityHelper.generateSalt();
      final salt2 = SecurityHelper.generateSalt();

      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2))); // Devem ser diferentes
    });

    test('hashPin deve gerar hash consistente para mesmo pin e salt', () {
      const pin = '1234';
      final salt = SecurityHelper.generateSalt();

      final hash1 = SecurityHelper.hashPin(pin, salt);
      final hash2 = SecurityHelper.hashPin(pin, salt);

      expect(hash1, equals(hash2));
    });

    test('hashPin deve gerar hash DIFERENTE para mesmo pin com salt DIFERENTE', () {
      const pin = '1234';
      final salt1 = SecurityHelper.generateSalt();
      final salt2 = SecurityHelper.generateSalt();

      final hash1 = SecurityHelper.hashPin(pin, salt1);
      final hash2 = SecurityHelper.hashPin(pin, salt2);

      expect(hash1, isNot(equals(hash2))); // Proteção contra Rainbow Tables
    });

    test('verifyPin deve retornar true para senha correta', () {
      const pin = '9999';
      final salt = SecurityHelper.generateSalt();
      final hash = SecurityHelper.hashPin(pin, salt);

      final isValid = SecurityHelper.verifyPin(pin, hash, salt);
      expect(isValid, isTrue);
    });

    test('verifyPin deve retornar false para senha incorreta', () {
      const pin = '9999';
      final salt = SecurityHelper.generateSalt();
      final hash = SecurityHelper.hashPin(pin, salt);

      final isValid = SecurityHelper.verifyPin('0000', hash, salt);
      expect(isValid, isFalse);
    });
  });

  group('SecurityHelper - Edge Cases & Produção', () {
      test('Deve suportar caracteres UTF-8 (Acentos, Emojis)', () {
        const pinComplexo = 'Ação@123!🔑';
        final salt = SecurityHelper.generateSalt();
        
        // Gera o hash
        final hash = SecurityHelper.hashPin(pinComplexo, salt);
        
        // Verifica se consegue validar corretamente
        final isValid = SecurityHelper.verifyPin(pinComplexo, hash, salt);
        
        expect(isValid, isTrue, reason: "Falhou ao processar caracteres especiais");
      });

      test('Não deve quebrar com string vazia (embora a UI deva bloquear)', () {
        const pinVazio = '';
        final salt = SecurityHelper.generateSalt();
        
        // Não deve lançar exceção
        final hash = SecurityHelper.hashPin(pinVazio, salt);
        
        expect(hash, isNotEmpty);
        expect(SecurityHelper.verifyPin('', hash, salt), isTrue);
      });

      test('verifyPin deve retornar false se o hash armazenado estiver corrompido (base64 inválido)', () {
        const pin = '1234';
        final salt = SecurityHelper.generateSalt();
        const hashCorrompido = 'ISSO_NAO_EH_BASE64_VALIDO_%%%';

        // O método tem um try-catch interno para retornar false em vez de crashar o app?
        final isValid = SecurityHelper.verifyPin(pin, hashCorrompido, salt);
        
        expect(isValid, isFalse, reason: "Deveria retornar false em vez de lançar Exception");
      });
    });
}
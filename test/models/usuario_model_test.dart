import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

void main() {
  group('UsuarioModel - Infraestrutura de Segurança', () {
    test('Deve suportar o campo SALT na conversão fromMap/toMap', () {
      // 1. Arrange (Dados simulados do banco)
      final usuarioMap = {
        'id': 1,
        'matricula_funcional': 'POL001',
        'nome_completo': 'Perito Teste',
        'papel_id': 1,
        'ativo': 1,
        'hash_pin_offline': 'hash_antigo',
        'salt': 'random_salt_string_123', 
        'criado_em': DateTime.now().toIso8601String(),
      };

      // 2. Act (Converte para Objeto)
      final usuario = Usuario.fromMap(usuarioMap);

      // 3. Assert (Verifica se leu corretamente)
      expect(usuario.salt, 'random_salt_string_123');
      expect(usuario.matriculaFuncional, 'POL001');

      // 4. Act (Converte de volta para Map)
      final novoMap = usuario.toMap();

      // 5. Assert (Verifica se gravou corretamente)
      expect(novoMap['salt'], 'random_salt_string_123');
    });

    test('Deve aceitar SALT nulo (para compatibilidade com usuários antigos)', () {
      final usuarioMapSemSalt = {
        'id': 2,
        'matricula_funcional': 'POL002',
        'nome_completo': 'Perito Antigo',
        'papel_id': 1,
        'ativo': 1,
        'hash_pin_offline': 'hash_antigo',
        // 'salt': null, // Simulando ausência
        'criado_em': DateTime.now().toIso8601String(),
      };

      final usuario = Usuario.fromMap(usuarioMapSemSalt);
      expect(usuario.salt, isNull);
    });
  });
}
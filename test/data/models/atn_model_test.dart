import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/core/exceptions/database_corrupted_exception.dart';

void main() {
  group('AtnModel - Unificação de Usuários e ATNs', () {
    test(
      'instancia corretamente a partir do payload novo do backend (nome_completo, email, cpf)',
      () {
        final json = {
          'id': '140f97d4-b7ce-4cf3-8872-5dda87c4fb70',
          'nome_completo': 'Carlos Silva',
          'email': 'carlos.silva@iml.gov.br',
          'cpf': '12345678901',
        };

        final atn = AtnModel.fromMap(json);

        expect(atn.id, equals('140f97d4-b7ce-4cf3-8872-5dda87c4fb70'));
        expect(atn.nome, equals('Carlos Silva'));
        expect(atn.email, equals('carlos.silva@iml.gov.br'));
        expect(atn.cpf, equals('12345678901'));
        expect(atn.ativo, isTrue);
      },
    );

    test('mantem retrocompatibilidade com payload legado (nome, ativo)', () {
      final jsonLegado = {
        'id': 'atn-mock-001',
        'nome': 'Mariana Oliveira Lima (ATN)',
        'ativo': 1,
      };

      final atn = AtnModel.fromMap(jsonLegado);

      expect(atn.id, equals('atn-mock-001'));
      expect(atn.nome, equals('Mariana Oliveira Lima (ATN)'));
      expect(atn.ativo, isTrue);
      expect(atn.email, isNull);
    });

    test(
      'lanca DatabaseCorruptedException quando id ou nome estiverem vazios',
      () {
        expect(
          () => AtnModel.fromMap({'id': '', 'nome': 'Invalido'}),
          throwsA(isA<DatabaseCorruptedException>()),
        );
        expect(
          () => AtnModel.fromMap({'id': 'valid-id', 'nome': ''}),
          throwsA(isA<DatabaseCorruptedException>()),
        );
      },
    );

    test('toMap gera mapa compatível com tabela local SQLite atns', () {
      final atn = AtnModel(
        id: 'uuid-1',
        nome: 'Henrique Barros',
        email: 'henrique@iml.com',
        cpf: '00000000008',
      );

      final map = atn.toMap();

      expect(map['id'], equals('uuid-1'));
      expect(map['nome'], equals('Henrique Barros'));
      expect(map['ativo'], equals(1));
    });
  });
}

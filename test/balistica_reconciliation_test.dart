import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/balistica_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';

void main() {
  group('Reconciliação de Balística no Flutter', () {
    test('1. BalisticaModel.fromMap suporta snake_case, camelCase e numeroLacre numérico', () {
      final bSnake = BalisticaModel.fromMap({
        'id': 'b-1',
        'caso_uuid': 'caso-1',
        'tipo_ferimento': 'Entrada',
        'tipo_objeto': 'Projétil',
        'numero_lacre': 12345, // int em vez de String
        'comentario_adicional': 'Fragmento encontrado',
      });
      expect(bSnake.id, equals('b-1'));
      expect(bSnake.exameId, equals('caso-1'));
      expect(bSnake.tipoFerimento, equals('Entrada'));
      expect(bSnake.tipoObjeto, equals('Projétil'));
      expect(bSnake.numeroLacre, equals('12345'));
      expect(bSnake.comentarioAdicional, equals('Fragmento encontrado'));

      final bCamel = BalisticaModel.fromMap({
        'uuid': 'b-2',
        'exame_id': 'caso-2',
        'achado_uuid': 'achado-2',
        'tipoFerimento': 'Saída',
        'tipoObjeto': 'Estojo',
        'numeroLacre': '998877',
        'comentarioAdicional': 'Lacre íntegro',
      });
      expect(bCamel.id, equals('b-2'));
      expect(bCamel.exameId, equals('caso-2'));
      expect(bCamel.achadoUuid, equals('achado-2'));
      expect(bCamel.tipoFerimento, equals('Saída'));
      expect(bCamel.tipoObjeto, equals('Estojo'));
      expect(bCamel.numeroLacre, equals('998877'));
      expect(bCamel.comentarioAdicional, equals('Lacre íntegro'));
    });

    test('2. Achado.fromMap lê dados balísticos da raiz e de dados_preenchidos_json', () {
      // Da raiz em snake_case
      final aRoot = Achado.fromMap({
        'uuid': 'achado-001',
        'caso_uuid': 'caso-001',
        'diagrama_caso_uuid': 'diag-001',
        'diagrama_nome': 'frente',
        'tipo_achado_id': 'tipo-1',
        'tamanho': '2.0',
        'vista_anatomica': 'frente',
        'local_anatomico': 'Tórax',
        'tipo_ferimento': 'Entrada',
        'tipo_objeto': 'Projétil',
        'numero_lacre': '123456',
        'comentario_adicional': 'Calibre .38',
      });
      expect(aRoot.tipoFerimento, equals('Entrada'));
      expect(aRoot.tipoObjeto, equals('Projétil'));
      expect(aRoot.numeroLacre, equals('123456'));
      expect(aRoot.comentarioAdicional, equals('Calibre .38'));

      // De dentro de dados_preenchidos_json
      final aJson = Achado.fromMap({
        'uuid': 'achado-002',
        'caso_uuid': 'caso-002',
        'diagrama_caso_uuid': 'diag-002',
        'diagrama_nome': 'costas',
        'tipo_achado_id': 'tipo-2',
        'tamanho': '1.5',
        'vista_anatomica': 'costas',
        'local_anatomico': 'Dorsal',
        'dados_preenchidos_json': {
          'tipo_ferimento': 'Saída',
          'tipo_objeto': 'Estojo',
          'numero_lacre': '654321',
          'comentario_adicional': 'Sem deformação',
        },
      });
      expect(aJson.tipoFerimento, equals('Saída'));
      expect(aJson.tipoObjeto, equals('Estojo'));
      expect(aJson.numeroLacre, equals('654321'));
      expect(aJson.comentarioAdicional, equals('Sem deformação'));
    });

    test('3. Reconciliação com UUID determinístico V5 idêntica ao payload real do backend', () {
      final achado1Uuid = '49cc9dd0-3e0b-4df3-99f8-3f7cee6e7e18';
      final achado2Uuid = '7c50d3f1-f96f-47f9-888a-24b093ef2090';

      final balistica1DetId = deterministicUuidV5(achado1Uuid, 'balistica');
      final balistica2DetId = deterministicUuidV5(achado2Uuid, 'balistica');

      expect(balistica1DetId, equals('e65ffe6d-c913-50ba-aa6d-e379c49befb3'));
      expect(balistica2DetId, equals('ef776931-ebd5-5c99-85f9-c89a86f0c5bc'));

      final rawCaseJson = {
        'uuid': 'ae97e6c8-c8b8-4413-86e9-06310b30fbd0',
        'achados': [
          {
            'uuid': achado1Uuid,
            'caso_uuid': 'ae97e6c8-c8b8-4413-86e9-06310b30fbd0',
            'diagrama_caso_uuid': 'bd0f7f76-ea76-4f9b-a756-2c807605f6ad',
            'diagrama_nome': 'frente',
            'tipo_achado_id': '4d206b8f-7411-41ae-8a48-a5b1fb8cb2b2',
            'tamanho': '1.0',
            'vista_anatomica': 'frente',
            'local_anatomico': 'Esternal',
          },
          {
            'uuid': achado2Uuid,
            'caso_uuid': 'ae97e6c8-c8b8-4413-86e9-06310b30fbd0',
            'diagrama_caso_uuid': 'f07766ab-c459-4e4d-aff8-fe2975140876',
            'diagrama_nome': 'trunk_dir',
            'tipo_achado_id': '4d206b8f-7411-41ae-8a48-a5b1fb8cb2b2',
            'tamanho': '1.0',
            'vista_anatomica': 'trunk_dir',
            'local_anatomico': 'Torácica',
          }
        ],
        'balisticas': [
          {
            'id': 'ef776931-ebd5-5c99-85f9-c89a86f0c5bc',
            'exame_id': 'ae97e6c8-c8b8-4413-86e9-06310b30fbd0',
            'tipo_ferimento': 'Entrada',
            'tipo_objeto': 'Estojo',
            'numero_lacre': '46665',
            'comentario_adicional': 'Calibre 9mm',
          },
          {
            'id': 'e65ffe6d-c913-50ba-aa6d-e379c49befb3',
            'exame_id': 'ae97e6c8-c8b8-4413-86e9-06310b30fbd0',
            'tipo_ferimento': 'Saída',
            'tipo_objeto': 'Projétil',
            'numero_lacre': 'aaacxfd',
            'comentario_adicional': 'Projétil deformado',
          }
        ]
      };

      final caso = Caso.fromMap(rawCaseJson);
      expect(caso.balisticas.length, equals(2));

      // Simula o processo de reconciliação de parsing
      final balisticasMap = {for (final b in caso.balisticas) b.id.toLowerCase(): b};

      final achadosReconciliados = (rawCaseJson['achados'] as List).map((rawA) {
        final a = Achado.fromMap(rawA as Map<String, dynamic>);
        final detId = deterministicUuidV5(a.uuid, 'balistica').toLowerCase();
        final matchedB = balisticasMap[detId];
        if (matchedB != null) {
          return a.copyWith(
            tipoFerimento: matchedB.tipoFerimento,
            tipoObjeto: matchedB.tipoObjeto,
            numeroLacre: matchedB.numeroLacre,
            comentarioAdicional: matchedB.comentarioAdicional,
          );
        }
        return a;
      }).toList();

      final a1 = achadosReconciliados.firstWhere((x) => x.uuid == achado1Uuid);
      final a2 = achadosReconciliados.firstWhere((x) => x.uuid == achado2Uuid);

      expect(a1.tipoFerimento, equals('Saída'));
      expect(a1.tipoObjeto, equals('Projétil'));
      expect(a1.numeroLacre, equals('aaacxfd'));
      expect(a1.comentarioAdicional, equals('Projétil deformado'));

      expect(a2.tipoFerimento, equals('Entrada'));
      expect(a2.tipoObjeto, equals('Estojo'));
      expect(a2.numeroLacre, equals('46665'));
      expect(a2.comentarioAdicional, equals('Calibre 9mm'));

      // Verifica se o toMap e persistência SQLite preservam as colunas
      final mapParaSqlite = a2.toMap();
      expect(mapParaSqlite['tipo_ferimento'], equals('Entrada'));
      expect(mapParaSqlite['tipo_objeto'], equals('Estojo'));
      expect(mapParaSqlite['numero_lacre'], equals('46665'));
      expect(mapParaSqlite['comentario_adicional'], equals('Calibre 9mm'));
    });
  });
}

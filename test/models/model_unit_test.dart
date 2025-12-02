import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
// Importa todos os Models
import 'package:croqui_forense_mvp/data/models/papel_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/diagrama_caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/permissao_model.dart';

void main() {
  group('Model Stress and Edge Case Tests', () {
    final testUuid = const Uuid().v4();
    final testDateTime = DateTime.now().toUtc();
    
    // ========================================================
    // 1. TESTE DE CASOS NULOS (NULL EDGE CASES)
    // ========================================================

    test('1.1 Models should handle all nullable fields correctly (DB -> Dart)', () {
      final Map<String, dynamic> nullCasoMap = {
        'uuid': testUuid,
        'id_usuario_criador': 1,
        'numero_laudo_externo': null, // Testando Null
        'status': 'RASCUNHO',
        'hash_integridade': null, // Testando Null
        'removido': 0,
        'versao': 1,
        'criado_em_dispositivo': testDateTime.toIso8601String(),
        'criado_em_rede_confiavel': null, // Testando Null
        'atualizado_em': null, // Testando Null
        'device_id': null,
        'proveniencia': null,
      };

      final deserializedCaso = Caso.fromMap(nullCasoMap);
      
      // Verificações
      expect(deserializedCaso.numeroLaudoExterno, isNull);
      expect(deserializedCaso.hashIntegridade, isNull);
      expect(deserializedCaso.atualizadoEm, isNull);
      
      // Verifica se o toMap() reverte os nulos corretamente (sem quebrar)
      final mapBack = deserializedCaso.toMap();
      expect(mapBack['numero_laudo_externo'], isNull);
    });
    
    // ========================================================
    // 2. TESTE DE ENTRADAS INVÁLIDAS E EXCEÇÕES
    // ========================================================

    test('2.1 Caso Model must default to RASCUNHO on invalid Status string', () {
      final Map<String, dynamic> invalidStatusMap = {
        'uuid': testUuid,
        'id_usuario_criador': 1,
        'status': 'ERRO_DELETADO', // String inválida
        'removido': 0, 'versao': 1, 'criado_em_dispositivo': testDateTime.toIso8601String(),
      };
      
      final deserializedCaso = Caso.fromMap(invalidStatusMap);
      
      // O método fromMap deve ter um orElse, que cai em RASCUNHO.
      expect(deserializedCaso.status, StatusCaso.rascunho);
    });
    
    test('2.2 Achado Model must throw FormatException for malformed JSON', () {
      final malformedMap = {
        'uuid': const Uuid().v4(),
        'diagrama_caso_uuid': testUuid,
        'tipo_achado_id': 'PAF',
        'numero_sequencial': 1,
        'pos_x': 0.5, 'pos_y': 0.5,
        'esta_pendente': 1,
        'removido': 0, 'versao': 1, 'criado_em': testDateTime.toIso8601String(),
        
        // Dados Preenchidos: JSON quebrado (String com erro de sintaxe)
        'dados_preenchidos_json': '{ "campo": "valor", ', // Falta o fechamento }
      };

      // O fromMap deve lançar a exceção de decodificação
      expect(() => Achado.fromMap(malformedMap), throwsA(isA<FormatException>()),
        reason: 'JSON malformado deve lançar exceção para garantir integridade.',
      );
    });

    // ========================================================
    // 3. TESTE DE CONSISTÊNCIA DE RELAÇÕES (UUIDs)
    // ========================================================
    
    test('3.1 DiagramaCaso foreign key should match parent Caso UUID', () {
      final parentCasoUuid = const Uuid().v4();
      final childDiagrama = DiagramaCaso.novo(
        casoUuid: parentCasoUuid,
        templateId: 'ADULTO_FRENTE',
      );
      
      final map = childDiagrama.toMap();
      
      // Verifica se o FK no mapa é exatamente igual ao PK do pai
      expect(map['caso_uuid'], equals(parentCasoUuid));
    });
  });
}
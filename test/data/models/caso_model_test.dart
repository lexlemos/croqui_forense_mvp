import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';

void main() {
  group('CasoModel - Auditoria e Correções de Contrato', () {
    test('Converte tipo_estimativa_hora_obito do servidor para os literais da UI', () {
      final caso1 = Caso.fromMap({
        'uuid': 'caso-001',
        'tipo_estimativa_hora_obito': 'ESTIMADA_PERICIALMENTE',
      });
      expect(caso1.tipoEstimativaHoraObito, equals('Pericialmente Estimadas'));

      final caso2 = Caso.fromMap({
        'uuid': 'caso-002',
        'tipo_estimativa_hora_obito': 'ATESTADA_EM_DOCUMENTO_MEDICO',
      });
      expect(caso2.tipoEstimativaHoraObito, equals('Atestadas em documento médico'));

      final caso3 = Caso.fromMap({
        'uuid': 'caso-003',
        'tipo_estimativa_hora_obito': 'Pericialmente Estimadas',
      });
      expect(caso3.tipoEstimativaHoraObito, equals('Pericialmente Estimadas'));

      final caso4 = Caso.fromMap({
        'uuid': 'caso-004',
        'tipo_estimativa_hora_obito': null,
      });
      expect(caso4.tipoEstimativaHoraObito, isNull);
    });

    test('Carrega balisticas a partir de List e de JSON String sem erro de cast', () {
      final casoFromList = Caso.fromMap({
        'uuid': 'caso-balistica-001',
        'balisticas': [
          {
            'id': 'bal-1',
            'tipo_ferimento': 'Entrada',
            'tipo_objeto': 'Projétil',
            'numero_lacre': '12345',
          }
        ],
      });
      expect(casoFromList.balisticas.length, equals(1));
      expect(casoFromList.balisticas.first.id, equals('bal-1'));
      expect(casoFromList.balisticas.first.exameId, equals('caso-balistica-001'));
      expect(casoFromList.balisticas.first.tipoFerimento, equals('Entrada'));

      final casoFromString = Caso.fromMap({
        'uuid': 'caso-balistica-002',
        'balisticas': '[{"id":"bal-2","tipo_ferimento":"Saída","tipo_objeto":"Estojo","numero_lacre":"999"}]',
      });
      expect(casoFromString.balisticas.length, equals(1));
      expect(casoFromString.balisticas.first.id, equals('bal-2'));
      expect(casoFromString.balisticas.first.exameId, equals('caso-balistica-002'));
      expect(casoFromString.balisticas.first.tipoFerimento, equals('Saída'));
    });
  });
}

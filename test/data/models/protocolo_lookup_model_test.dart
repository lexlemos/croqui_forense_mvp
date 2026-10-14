import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/protocolo_lookup_model.dart';

void main() {
  group('ProtocoloLookupModel - Extração do ID Oficial do Exame', () {
    test('extrai exameId a partir de documento.id', () {
      final json = {
        'documento': {
          'id': '09fff950-a98f-4ae6-ab7f-b5028647969c',
          'protocolo_externo': 'PIC-2026-001',
          'protocolo_interno': 'CD-1320821',
        },
        'status': 'ENTRADA_CUSTODIA',
      };

      final dto = ProtocoloLookupModel.fromMap(json);

      expect(dto.exameId, equals('09fff950-a98f-4ae6-ab7f-b5028647969c'));
      expect(dto.numeroPic, equals('PIC-2026-001'));
      expect(dto.numeroRequisicao, equals('CD-1320821'));
    });

    test('extrai exameId a partir de exame.id com fallback seguro', () {
      final json = {
        'exame': {
          'id': '11111111-2222-3333-4444-555555555555',
          'pic': 'PIC-2026-002',
          'cd': 'CD-999',
        },
        'status': 'ENTRADA_CUSTODIA',
      };

      final dto = ProtocoloLookupModel.fromMap(json);

      expect(dto.exameId, equals('11111111-2222-3333-4444-555555555555'));
      expect(dto.numeroPic, equals('PIC-2026-002'));
    });

    test(
      'extrai exameId quando o backend expõe id ou uuid diretamente na raiz',
      () {
        final jsonComId = {
          'id': '22222222-3333-4444-5555-666666666666',
          'pic': 'PIC-2026-003',
        };
        final dtoComId = ProtocoloLookupModel.fromMap(jsonComId);
        expect(
          dtoComId.exameId,
          equals('22222222-3333-4444-5555-666666666666'),
        );

        final jsonComUuid = {
          'uuid': '33333333-4444-5555-6666-777777777777',
          'pic': 'PIC-2026-004',
        };
        final dtoComUuid = ProtocoloLookupModel.fromMap(jsonComUuid);
        expect(
          dtoComUuid.exameId,
          equals('33333333-4444-5555-6666-777777777777'),
        );
      },
    );

    test('retorna exameId nulo se nenhum ID for fornecido no payload', () {
      final jsonVazio = {'pic': 'PIC-MANUAL-001'};
      final dto = ProtocoloLookupModel.fromMap(jsonVazio);
      expect(dto.exameId, isNull);
    });

    test('extrai dataFato e horaFato a partir do payload de ocorrencia', () {
      final jsonOcorrencia = {
        "documento": {
          "id": "7b54f2d8-fbd2-4262-ad7f-b542bdcb8cb5",
          "protocolo_interno": "24532026",
          "protocolo_externo": "14674325A",
        },
        "ocorrencia": {"data_fato": "2026-10-06", "hora_fato": "10:01:00"},
        "vitima": {"nome_completo": "Antonio de Oliveira Pinto"},
      };

      final dto = ProtocoloLookupModel.fromMap(jsonOcorrencia);
      expect(dto.dataFato, equals('2026-10-06'));
      expect(dto.horaFato, equals('10:01:00'));
      expect(dto.nomeVitima, equals('Antonio de Oliveira Pinto'));
      expect(dto.numeroPic, equals('14674325A'));
      expect(dto.numeroRequisicao, equals('24532026'));
    });
  });
}

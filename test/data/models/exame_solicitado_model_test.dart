import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';

void main() {
  group('ExameSolicitadoModel - Herança de Status ATN no Pull Sync', () {
    test('herda status RECUSADO e justificativa de detalhes_toxicologico quando pai está PENDENTE', () {
      final map = {
        'uuid': 'exame-tox-1',
        'caso_uuid': 'caso-1',
        'tipo_exame': 'TOXICOLOGICO',
        'status_confirmacao_atn': 'PENDENTE',
        'detalhes_toxicologico': [
          {
            'uuid': 'det-1',
            'exame_uuid': 'exame-tox-1',
            'status_confirmacao_atn': 'RECUSADO',
            'justificativa_recusa': 'Amostra de sangue insuficiente ou coagulada.',
          }
        ],
      };

      final model = ExameSolicitadoModel.fromMap(map);

      expect(model.statusConfirmacaoAtn, equals(StatusConfirmacaoATN.RECUSADO));
      expect(model.justificativaRecusa, equals('Amostra de sangue insuficiente ou coagulada.'));
      expect(model.detalhes, isA<DetalhesToxicologicoModel>());
    });

    test('herda status RECUSADO e justificativa de amostras_genetica quando pai está PENDENTE', () {
      final map = {
        'uuid': 'exame-gen-1',
        'caso_uuid': 'caso-1',
        'tipo_exame': 'GENETICA',
        'status_confirmacao_atn': 'PENDENTE',
        'amostras_genetica': [
          {
            'uuid': 'amostra-1',
            'exame_uuid': 'exame-gen-1',
            'tipo_amostra': 'SWAB_BUCAL_VITIMA',
            'status_confirmacao_atn': 'CONFIRMADO',
          },
          {
            'uuid': 'amostra-2',
            'exame_uuid': 'exame-gen-1',
            'tipo_amostra': 'SWAB_VAGINAL_1',
            'status_confirmacao_atn': 'RECUSADO',
            'justificativa_recusa': 'Lacre violado no transporte.',
          }
        ],
      };

      final model = ExameSolicitadoModel.fromMap(map);

      expect(model.statusConfirmacaoAtn, equals(StatusConfirmacaoATN.RECUSADO));
      expect(model.justificativaRecusa, equals('Lacre violado no transporte.'));
      expect(model.detalhes, isA<List<AmostraGeneticaModel>>());
    });

    test('herda status RECUSADO e justificativa de frascos_anatomo quando pai está PENDENTE', () {
      final map = {
        'uuid': 'exame-anat-1',
        'caso_uuid': 'caso-1',
        'tipo_exame': 'ANATOMO',
        'status_confirmacao_atn': 'PENDENTE',
        'frascos_anatomo': [
          {
            'uuid': 'frasco-1',
            'exame_uuid': 'exame-anat-1',
            'numero_frasco': 1,
            'status_confirmacao_atn': 'RECUSADO',
            'justificativa_recusa': 'Frasco vazando líquido fixador.',
          }
        ],
      };

      final model = ExameSolicitadoModel.fromMap(map);

      expect(model.statusConfirmacaoAtn, equals(StatusConfirmacaoATN.RECUSADO));
      expect(model.justificativaRecusa, equals('Frasco vazando líquido fixador.'));
      expect(model.detalhes, isA<List<FrascoAnatomoModel>>());
    });

    test('mantém status explícito do pai caso ele já venha diferente de PENDENTE', () {
      final map = {
        'uuid': 'exame-tox-2',
        'caso_uuid': 'caso-1',
        'tipo_exame': 'TOXICOLOGICO',
        'status_confirmacao_atn': 'CONFIRMADO',
        'detalhes_toxicologico': [
          {
            'uuid': 'det-2',
            'exame_uuid': 'exame-tox-2',
            'status_confirmacao_atn': 'CONFIRMADO',
          }
        ],
      };

      final model = ExameSolicitadoModel.fromMap(map);

      expect(model.statusConfirmacaoAtn, equals(StatusConfirmacaoATN.CONFIRMADO));
    });
  });
}

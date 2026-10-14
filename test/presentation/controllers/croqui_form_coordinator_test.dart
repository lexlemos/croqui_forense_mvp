import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_form_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final casoTeste = Caso.fromMap({
    'uuid': 'caso-form-123',
    'id_usuario_criador': 'perito-01',
    'numero_requisicao': 'REQ-100',
    'numero_bo': 'BO-200',
    'numero_pic': 'PIC-300',
    'nome_vitima': 'João da Silva',
    'status': 'EM_ANDAMENTO',
    'versao': 1,
  });

  group('CroquiFormCoordinator - Gerenciamento de Formulário', () {
    test(
      '1. Inicializa todos os controladores com os dados originais do caso',
      () {
        final coordinator = CroquiFormCoordinator(casoTeste);

        expect(coordinator.numeroLaudoCtrl.text, equals('REQ-100'));
        expect(coordinator.boCtrl.text, equals('BO-200'));
        expect(coordinator.picCtrl.text, equals('PIC-300'));
        expect(coordinator.nomeVitimaCtrl.text, equals('João da Silva'));

        coordinator.dispose();
      },
    );

    test(
      '2. validarCamposObrigatorios retorna false se quesito1 estiver incompleto',
      () {
        final coordinator = CroquiFormCoordinator(casoTeste);
        coordinator.quesito1Ctrl.text = 'X';

        expect(coordinator.validarCamposObrigatorios(), isFalse);

        coordinator.dispose();
      },
    );

    test(
      '3. extrairCasoAtualizado reflete edições nos controladores com incremento OCC',
      () {
        final coordinator = CroquiFormCoordinator(casoTeste);
        coordinator.nomeVitimaCtrl.text = 'Maria Oliveira';
        coordinator.conclusaoCtrl.text = 'Laudo pericial conclusivo';

        final casoAtualizado = coordinator.extrairCasoAtualizado(
          casoBase: casoTeste,
          atns: const [],
        );

        expect(casoAtualizado.nomeVitima, equals('Maria Oliveira'));
        expect(
          casoAtualizado.dadosLaudo.conclusao.conclusaoTexto,
          equals('Laudo pericial conclusivo'),
        );
        expect(casoAtualizado.versao, equals(2));
        expect(casoAtualizado.isDraftSynced, isFalse);

        coordinator.dispose();
      },
    );

    test(
      '4. adicionarCausaMorte e removerCausaMorte alteram lista de controllers com segurança',
      () {
        final coordinator = CroquiFormCoordinator(casoTeste);
        final qtdInicial = coordinator.causasMorteCtrls.length;

        coordinator.adicionarCausaMorte();
        expect(coordinator.causasMorteCtrls.length, equals(qtdInicial + 1));

        coordinator.removerCausaMorte(coordinator.causasMorteCtrls.length - 1);
        expect(coordinator.causasMorteCtrls.length, equals(qtdInicial));

        coordinator.dispose();
      },
    );
  });
}

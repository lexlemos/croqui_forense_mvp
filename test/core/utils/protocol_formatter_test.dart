import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/utils/protocol_formatter.dart';

void main() {
  group('ProtocolFormatter', () {
    test('formatarRequisicao formata 8 digitos com barra no ano', () {
      expect(formatarRequisicao('12342026'), equals('1234/2026'));
    });

    test('formatarRequisicao formata 6 digitos com barra no ano', () {
      expect(formatarRequisicao('122026'), equals('12/2026'));
    });

    test('formatarRequisicao preserva string que ja tem barra', () {
      expect(formatarRequisicao('1234/2026'), equals('1234/2026'));
    });

    test('formatarRequisicao lida com nulo e vazio', () {
      expect(formatarRequisicao(null), equals(''));
      expect(formatarRequisicao(''), equals(''));
      expect(formatarRequisicao('   '), equals(''));
    });

    test('sanitizarRequisicao remove barra para persistencia', () {
      expect(sanitizarRequisicao('1234/2026'), equals('12342026'));
      expect(sanitizarRequisicao(' 1234/2026 '), equals('12342026'));
      expect(sanitizarRequisicao('12342026'), equals('12342026'));
      expect(sanitizarRequisicao(null), equals(''));
    });
  });
}

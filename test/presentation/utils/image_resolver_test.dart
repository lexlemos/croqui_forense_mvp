import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/presentation/utils/image_resolver.dart';

void main() {
  group('ImageResolver - Seleção de Evidências Multimídia para Achados', () {
    const achadoUuid = 'achado-teste-123';

    test('1. Retorna null quando a lista está vazia ou não contém o achado', () {
      expect(
        ImageResolver.selecionarMelhorEvidenciaParaAchado(achadoUuid, []),
        isNull,
      );

      final outraEvidencia = EvidenciaMultimidia(
        uuid: 'ev-outra',
        casoUuid: 'caso-1',
        achadoUuid: 'outro-achado',
        tipo: 'ACHADO',
        fotoSincronizada: true,
        removido: false,
        versao: 1,
        criadoEm: DateTime.utc(2026, 10, 10, 12, 0),
      );
      expect(
        ImageResolver.selecionarMelhorEvidenciaParaAchado(achadoUuid, [outraEvidencia]),
        isNull,
      );
    });

    test('2. Ignora evidências com removido = true', () {
      final evRemovida = EvidenciaMultimidia(
        uuid: 'ev-removida',
        casoUuid: 'caso-1',
        achadoUuid: achadoUuid,
        tipo: 'ACHADO',
        caminhoArquivoEncriptado: 'caminho/foto.jpg',
        fotoSincronizada: true,
        removido: true,
        versao: 1,
        criadoEm: DateTime.utc(2026, 10, 10, 12, 0),
      );
      expect(
        ImageResolver.selecionarMelhorEvidenciaParaAchado(achadoUuid, [evRemovida]),
        isNull,
      );
    });

    test('3. Prioriza evidência com caminho/storage preenchido sobre placeholder nulo (cenário pós-reinstalação)', () {
      final evSemFoto = EvidenciaMultimidia(
        uuid: 'ev-placeholder-sem-foto',
        casoUuid: 'caso-1',
        achadoUuid: achadoUuid,
        tipo: 'ACHADO',
        caminhoArquivoEncriptado: null,
        fotoSincronizada: true,
        removido: false,
        versao: 1,
        criadoEm: DateTime.utc(2026, 10, 10, 13, 0),
      );

      final evComFoto = EvidenciaMultimidia(
        uuid: 'ev-real-com-foto',
        casoUuid: 'caso-1',
        achadoUuid: achadoUuid,
        tipo: 'ACHADO',
        caminhoArquivoEncriptado: 'evidencias_multimidia/casos/caso-1/achados/foto.jpg',
        fotoSincronizada: true,
        removido: false,
        versao: 1,
        criadoEm: DateTime.utc(2026, 10, 10, 14, 0),
      );

      // Mesmo se a evidência sem foto estiver em primeiro lugar na lista (ordem do pull):
      final selecionada = ImageResolver.selecionarMelhorEvidenciaParaAchado(
        achadoUuid,
        [evSemFoto, evComFoto],
      );

      expect(selecionada, isNotNull);
      expect(selecionada!.uuid, equals('ev-real-com-foto'));
      expect(selecionada.caminhoArquivoEncriptado, isNotEmpty);
    });

    test('4. Entre múltiplas evidências com foto, escolhe a mais recente / maior versão', () {
      final evVersao1 = EvidenciaMultimidia(
        uuid: 'ev-v1',
        casoUuid: 'caso-1',
        achadoUuid: achadoUuid,
        tipo: 'ACHADO',
        caminhoArquivoEncriptado: 'path/antiga.jpg',
        fotoSincronizada: true,
        removido: false,
        versao: 1,
        criadoEm: DateTime.utc(2026, 10, 10, 12, 0),
      );

      final evVersao2 = EvidenciaMultimidia(
        uuid: 'ev-v2',
        casoUuid: 'caso-1',
        achadoUuid: achadoUuid,
        tipo: 'ACHADO',
        caminhoArquivoEncriptado: 'path/recente.jpg',
        fotoSincronizada: true,
        removido: false,
        versao: 2,
        criadoEm: DateTime.utc(2026, 10, 10, 15, 0),
      );

      final selecionada = ImageResolver.selecionarMelhorEvidenciaParaAchado(
        achadoUuid,
        [evVersao1, evVersao2],
      );

      expect(selecionada, isNotNull);
      expect(selecionada!.uuid, equals('ev-v2'));
    });
  });
}

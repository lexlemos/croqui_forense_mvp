import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/dados_laudo_model.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_bloco.dart';
import 'package:croqui_forense_mvp/domain/services/laudo_builder_service.dart';

void main() {
  group('LaudoBuilderService - Montagem Canônica do LaudoDocumento e LaudoPacote', () {
    late Caso casoBase;
    late Usuario peritoBase;

    setUp(() {
      final agora = DateTime.parse('2026-10-08T12:00:00Z');
      casoBase = Caso(
        uuid: 'caso-uuid-123',
        versao: 3,
        removido: false,
        numeroRequisicao: 'REQ-2026-001',
        numeroPic: 'PIC-2026-001',
        numeroBo: 'BO-2026-001',
        numeroLaudoExterno: 'CD-2026-001',
        nomeVitima: 'JOÃO DA SILVA',
        requisitante: '1ª Delegacia Metropolitana',
        destino: '1ª Vara Criminal',
        deviceId: 'tablet-forense-01',
        idUsuarioCriador: 'perito-uuid-999',
        dadosLaudo: DadosLaudoModel.novo(),
        criadoEmDispositivo: agora,
        atualizadoEm: agora,
      );

      peritoBase = Usuario(
        id: 'perito-uuid-999',
        matriculaFuncional: 'PCSE-12345',
        nomeCompleto: 'DR. RONMEL LISBOA',
        roles: const ['PERITO'],
        ativo: true,
        hashPinOffline: '',
        salt: '',
        criadoEm: agora,
      );
    });

    test('Monta as 10 seções canônicas do laudo e a seção de fecho', () {
      final builder = LaudoBuilderService();
      final pacote = builder.buildPacote(
        caso: casoBase,
        achados: const [],
        perito: peritoBase,
      );

      expect(pacote.schema, 'laudo-pacote/1');
      expect(pacote.versaoLaudo, 3);
      expect(pacote.perito.nome, 'DR. RONMEL LISBOA');

      final secoes = pacote.documento.secoes;
      final idsSecoes = secoes.map((s) => s.id).toList();

      expect(idsSecoes, containsAllInOrder([
        'dados_iniciais',
        'historico',
        'identificacao',
        'exame_externo',
        'exame_interno',
        'exames_complementares',
        'rascunhos',
        'fotos',
        'comentario',
        'conclusao',
        'quesitos',
        'fecho',
      ]));
    });

    test('Numeração canônica de fotografias: fotos gerais primeiro, achados em seguida', () {
      final evGeral1 = EvidenciaMultimidia.novo(
        caminhoArquivoEncriptado: '/data/user/0/evidencias/foto_geral_1.jpg',
        casoUuid: 'caso-uuid-123',
        tipo: 'GERAL',
      );
      final evGeral2 = EvidenciaMultimidia.novo(
        caminhoArquivoEncriptado: '/data/user/0/evidencias/foto_geral_2.jpg',
        casoUuid: 'caso-uuid-123',
        tipo: 'GERAL',
      );

      final achadoComFoto = Achado(
        uuid: 'achado-uuid-001',
        casoUuid: 'caso-uuid-123',
        diagramaCasoUuid: 'diag-001',
        diagramaNome: 'corpo_humano',
        tipoAchadoId: 'paf_entrada',
        posX: 100.0,
        posY: 100.0,
        isInterno: false,
        removido: false,
        versao: 1,
        tamanho: '2cm',
        vistaAnatomica: 'frente',
        localAnatomico: 'frontal',
        dadosPreenchidos: {
          'view': 'frente',
          'local_anatomico_id': 'frontal',
          'local_anatomico_nome': 'Região Frontal',
          'type_label': 'Entrada de PAF',
          'photo_path': '/data/user/0/evidencias/foto_achado_1.jpg',
        },
        observacoesTexto: 'Orifício de entrada com bordas invertidas.',
        numeroSequencial: 1,
        criadoEm: DateTime.now(),
      );

      final evAchado = EvidenciaMultimidia.novo(
        caminhoArquivoEncriptado: '/data/user/0/evidencias/foto_achado_1.jpg',
        casoUuid: 'caso-uuid-123',
        achadoUuid: 'achado-uuid-001',
        tipo: 'ACHADO',
      );


      final builder = LaudoBuilderService();
      final pacote = builder.buildPacote(
        caso: casoBase.copyWith(
          evidenciasMultimidia: [evGeral1, evGeral2, evAchado],
        ),
        achados: [achadoComFoto],
        perito: peritoBase,
        evidenciasGerais: [evGeral1, evGeral2],
      );

      final fotos = pacote.fotografias;
      expect(fotos, hasLength(3));

      // Foto 1: Geral
      expect(fotos[0].numero, 1);
      expect(fotos[0].tipo, 'GERAL');
      expect(fotos[0].evidenciaUuid, evGeral1.uuid);

      // Foto 2: Geral
      expect(fotos[1].numero, 2);
      expect(fotos[1].tipo, 'GERAL');
      expect(fotos[1].evidenciaUuid, evGeral2.uuid);

      // Foto 3: Achado
      expect(fotos[2].numero, 3);
      expect(fotos[2].tipo, 'ACHADO');
      expect(fotos[2].achadoUuid, 'achado-uuid-001');

      // Verifica se a referência cruzada foto_numero foi preenchida no bloco do achado
      final secaoExameExterno = pacote.documento.secoes.firstWhere((s) => s.id == 'exame_externo');
      final blocoGrupo = secaoExameExterno.blocos.whereType<LaudoGrupoAchadosBloco>().first;
      expect(blocoGrupo.achados, hasLength(1));
      expect(blocoGrupo.achados.first.fotoNumero, 3);
      expect(blocoGrupo.achados.first.texto, contains('[VER REGISTRO FOTOGRÁFICO 3]'));
    });

    test('Grupos anatômicos sem achados exibem mensagem oficial de integridade', () {
      final builder = LaudoBuilderService();
      final pacote = builder.buildPacote(
        caso: casoBase,
        achados: const [],
        perito: peritoBase,
      );

      final secaoExameExterno = pacote.documento.secoes.firstWhere((s) => s.id == 'exame_externo');
      final blocos = secaoExameExterno.blocos.whereType<LaudoGrupoAchadosBloco>().toList();

      expect(blocos, isNotEmpty);
      for (final grupo in blocos) {
        expect(grupo.achados, isEmpty);
        expect(grupo.textoVazio, 'Sem evidências de lesões macroscópicas de natureza traumática.');
      }

      final secaoExameInterno = pacote.documento.secoes.firstWhere((s) => s.id == 'exame_interno');
      final blocosInternos = secaoExameInterno.blocos.whereType<LaudoGrupoAchadosBloco>().toList();

      expect(blocosInternos, isNotEmpty);
      for (final grupo in blocosInternos) {
        expect(grupo.achados, isEmpty);
        expect(grupo.textoVazio, 'Sem alterações macroscópicas dignas de nota.');
      }
    });
  });
}

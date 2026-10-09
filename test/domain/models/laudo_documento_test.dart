import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_bloco.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_secao.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_documento.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_pacote.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_foto.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_croqui_ref.dart';

void main() {
  group('LaudoBloco - Serialização e Desserialização', () {
    test('LaudoTituloBloco serializa e desserializa corretamente', () {
      const bloco = LaudoTituloBloco(texto: '1. HISTÓRICO', nivel: 1);
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'titulo',
        'texto': '1. HISTÓRICO',
        'nivel': 1,
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoTituloBloco;
      expect(reconstruido.texto, '1. HISTÓRICO');
      expect(reconstruido.nivel, 1);
    });

    test('LaudoParagrafoBloco serializa com estilo e recuo opcionais', () {
      const bloco = LaudoParagrafoBloco(
        texto: 'Corpo encontrado em via pública.',
        estilo: 'negrito',
        recuo: 20.0,
      );
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'paragrafo',
        'texto': 'Corpo encontrado em via pública.',
        'estilo': 'negrito',
        'recuo': 20.0,
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoParagrafoBloco;
      expect(reconstruido.texto, 'Corpo encontrado em via pública.');
      expect(reconstruido.estilo, 'negrito');
      expect(reconstruido.recuo, 20.0);
    });

    test('LaudoItemBloco serializa label e valor', () {
      const bloco = LaudoItemBloco(label: 'I) Vestes: ', valor: 'Camiseta preta');
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'item',
        'label': 'I) Vestes: ',
        'valor': 'Camiseta preta',
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoItemBloco;
      expect(reconstruido.label, 'I) Vestes: ');
      expect(reconstruido.valor, 'Camiseta preta');
    });

    test('LaudoBulletBloco serializa item com marcador', () {
      const bloco = LaudoBulletBloco(texto: 'Presença de livores dorsais fixos');
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'bullet',
        'texto': 'Presença de livores dorsais fixos',
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoBulletBloco;
      expect(reconstruido.texto, 'Presença de livores dorsais fixos');
    });

    test('LaudoGrupoAchadosBloco serializa grupo com achados e campos extras', () {
      const bloco = LaudoGrupoAchadosBloco(
        titulo: 'I) Crânio e Face:',
        textoVazio: 'Sem evidências de lesões macroscópicas de natureza traumática.',
        textoIntro: 'Com evidências de lesões macroscópicas:',
        achados: [
          LaudoAchadoItem(
            numeroSequencial: 1,
            texto: 'Entrada de PAF em frontal: orifício de bordas invertidas.',
            fotoNumero: 4,
            campos: [
              LaudoCampoExtra(label: 'Tamanho', valor: '2.5 cm'),
              LaudoCampoExtra(label: 'Profundidade', valor: 'transfixante'),
            ],
          ),
        ],
      );

      final json = bloco.toJson();
      expect(json['tipo'], 'grupo_achados');
      expect(json['titulo'], 'I) Crânio e Face:');
      expect(json['texto_vazio'], 'Sem evidências de lesões macroscópicas de natureza traumática.');
      expect(json['achados'], hasLength(1));

      final reconstruido = LaudoBloco.fromJson(json) as LaudoGrupoAchadosBloco;
      expect(reconstruido.titulo, 'I) Crânio e Face:');
      expect(reconstruido.achados.first.numeroSequencial, 1);
      expect(reconstruido.achados.first.fotoNumero, 4);
      expect(reconstruido.achados.first.campos.first.label, 'Tamanho');
      expect(reconstruido.achados.first.campos.first.valor, '2.5 cm');
    });

    test('LaudoImagemBloco serializa referência de foto ou croqui', () {
      const bloco = LaudoImagemBloco(ref: 'foto:4');
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'imagem',
        'ref': 'foto:4',
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoImagemBloco;
      expect(reconstruido.ref, 'foto:4');
    });

    test('LaudoAssinaturaBloco serializa cidade e data', () {
      const bloco = LaudoAssinaturaBloco(cidade: 'Nossa Senhora do Socorro/SE', data: '2026-10-08');
      final json = bloco.toJson();
      expect(json, {
        'tipo': 'assinatura',
        'cidade': 'Nossa Senhora do Socorro/SE',
        'data': '2026-10-08',
      });

      final reconstruido = LaudoBloco.fromJson(json) as LaudoAssinaturaBloco;
      expect(reconstruido.cidade, 'Nossa Senhora do Socorro/SE');
      expect(reconstruido.data, '2026-10-08');
    });
  });

  group('LaudoPacote - Estrutura completa do contrato laudo-pacote/1', () {
    test('Serializa e valida integridade do pacote conforme o contrato', () {
      final pacote = LaudoPacote(
        schema: 'laudo-pacote/1',
        versaoLaudo: 7,
        geradoEm: DateTime.parse('2026-10-08T15:00:00Z'),
        procedencia: const LaudoProcedencia(origem: 'APP', deviceId: 'device-uuid-123'),
        perito: const LaudoPerito(
          id: 'perito-uuid-456',
          nome: 'DR. FULANO DE TAL',
          crm: 'CRM/SE 1234',
          classe: 'Classe I',
        ),
        atns: const [
          LaudoAtn(id: 'atn-uuid-789', nome: 'BELTRANO DA SILVA'),
        ],
        documento: const LaudoDocumento(
          secoes: [
            LaudoSecao(
              id: 'historico',
              titulo: '1. HISTÓRICO',
              blocos: [
                LaudoParagrafoBloco(texto: 'Histórico pericial relatado nos autos.'),
              ],
            ),
          ],
        ),
        fotografias: const [
          LaudoFoto(
            numero: 1,
            tipo: 'GERAL',
            evidenciaUuid: 'ev-uuid-001',
            achadoUuid: null,
            legenda: 'Fotografia 1 - Identificação Geral',
            hashArquivo: 'hash123',
          ),
        ],
        croquis: const [
          LaudoCroquiRef(
            vista: 'frente',
            ordem: 1,
            artefatoUuid: 'art-uuid-001',
            largura: 1272,
            altura: 1800,
            legenda: 'VISTA: FRENTE',
          ),
        ],
      );

      final json = pacote.toJson();
      expect(json['schema'], 'laudo-pacote/1');
      expect(json['versao_laudo'], 7);
      expect(json['procedencia']['origem'], 'APP');
      expect(json['perito']['crm'], 'CRM/SE 1234');
      expect(json['atns'], hasLength(1));
      expect(json['documento']['secoes'], hasLength(1));
      expect(json['fotografias'], hasLength(1));
      expect(json['croquis'], hasLength(1));

      final reconstruido = LaudoPacote.fromJson(json);
      expect(reconstruido.schema, 'laudo-pacote/1');
      expect(reconstruido.versaoLaudo, 7);
      expect(reconstruido.perito.nome, 'DR. FULANO DE TAL');
      expect(reconstruido.documento.secoes.first.id, 'historico');
      expect(reconstruido.fotografias.first.numero, 1);
      expect(reconstruido.croquis.first.largura, 1272);
    });
  });
}

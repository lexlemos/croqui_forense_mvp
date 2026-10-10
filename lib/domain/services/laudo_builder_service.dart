import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/core/utils/protocol_formatter.dart';
import 'package:croqui_forense_mvp/presentation/utils/achado_formatter.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_bloco.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_secao.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_documento.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_foto.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_croqui_ref.dart';
import 'package:croqui_forense_mvp/domain/models/laudo_documento/laudo_pacote.dart';
import 'pdf_constants.dart';
import 'pdf_helpers.dart';

/// Serviço puro de domínio responsável por construir a estrutura oficial do
/// Laudo Pericial (`LaudoDocumento` e `LaudoPacote`) com zero dependência de renderização gráfica.
///
/// Implementa a **Decisão D8 (Opção A)** da arquitetura: o aplicativo compila uma única
/// fonte da verdade do conteúdo, consumida pelo gerador de PDF (no app) e pelo gerador de DOCX (no backend).
class LaudoBuilderService {
  /// Constrói o pacote completo do laudo pericial a partir dos dados do caso e achados.
  LaudoPacote buildPacote({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    List<EvidenciaMultimidia>? evidenciasGerais,
    List<em.ExameSolicitadoModel>? examesModel,
    List<ExameSolicitado> examesLegados = const [],
    Map<String, dynamic>? schemas,
    List<LaudoCroquiRef> croquis = const [],
  }) {
    final geradoEm = DateTime.now().toUtc();
    final ativas = achados.where((a) => !a.removido).toList();

    // 1. Numeração canônica das fotografias
    final fotosGerais = evidenciasGerais ??
        caso.evidenciasMultimidia
            .where((e) => !e.removido && (e.achadoUuid == null || e.achadoUuid!.isEmpty))
            .toList();

    final List<LaudoFoto> fotografiasOficiais = [];
    final Map<String, int> fotosPorAchadoUuid = {};
    int contadorFotos = 1;

    // A) Fotos Gerais primeiro
    for (var ev in fotosGerais) {
      fotografiasOficiais.add(
        LaudoFoto(
          numero: contadorFotos,
          tipo: 'GERAL',
          evidenciaUuid: ev.uuid,
          achadoUuid: null,
          legenda: 'Fotografia $contadorFotos - Identificação Geral',
          hashArquivo: ev.hashArquivo,
        ),
      );
      contadorFotos++;
    }

    // Mapeamento auxiliar de evidências por achado_uuid
    final todasEvidencias = caso.evidenciasMultimidia;
    final Map<String, EvidenciaMultimidia> mapaEvidenciasAchados = {
      for (var ev in todasEvidencias)
        if (ev.achadoUuid != null && ev.achadoUuid!.isNotEmpty && !ev.removido)
          ev.achadoUuid!: ev,
    };

    // B) Fotos de Achados em seguida
    for (var a in ativas) {
      String? path = a.dadosPreenchidos['photo_path']?.toString();
      final ev = mapaEvidenciasAchados[a.uuid];
      if ((path == null || path.trim().isEmpty) && ev != null) {
        path = ev.caminhoArquivoEncriptado;
      }

      if (path != null && path.trim().isNotEmpty) {
        final evUuid = ev?.uuid ?? a.uuid;
        fotosPorAchadoUuid[a.uuid] = contadorFotos;
        final labelTipo = a.dadosPreenchidos['type_label']?.toString() ?? 'Lesão';
        fotografiasOficiais.add(
          LaudoFoto(
            numero: contadorFotos,
            tipo: 'ACHADO',
            evidenciaUuid: evUuid,
            achadoUuid: a.uuid,
            legenda: 'Fotografia $contadorFotos - Ref. Achado ${a.numeroSequencial} ($labelTipo)',
            hashArquivo: ev?.hashArquivo,
          ),
        );
        contadorFotos++;
      }
    }

    // 2. Construção das 10 Seções de Conteúdo
    final secoes = <LaudoSecao>[
      _buildSecaoDadosIniciais(caso, perito),
      _buildSecaoHistorico(caso),
      _buildSecaoIdentificacao(caso),
      _buildSecaoExameExterno(ativas, fotosPorAchadoUuid, schemas),
      _buildSecaoExameInterno(ativas, fotosPorAchadoUuid, schemas),
      _buildSecaoExamesComplementares(caso, examesLegados, examesModel),
      _buildSecaoRascunhos(croquis),
      _buildSecaoFotografias(fotografiasOficiais),
      _buildSecaoComentario(caso),
      _buildSecaoConclusao(caso),
      _buildSecaoQuesitos(caso),
      _buildSecaoFecho(caso, perito),
    ];

    final documento = LaudoDocumento(secoes: secoes);

    return LaudoPacote(
      schema: 'laudo-pacote/1',
      versaoLaudo: caso.versao,
      geradoEm: geradoEm,
      procedencia: LaudoProcedencia(
        origem: 'APP',
        deviceId: (caso.deviceId != null && caso.deviceId!.isNotEmpty) ? caso.deviceId! : 'device-unknown',
      ),
      perito: LaudoPerito(
        id: perito.id,
        nome: perito.nomeCompleto.isNotEmpty ? perito.nomeCompleto : 'Perito Médico-Legista',
        crm: 'CRM/SE', // Em produção, extraído de credenciais
        classe: 'Classe I',
      ),
      atns: caso.atnsIds.map((id) => LaudoAtn(id: id, nome: id)).toList(),
      documento: documento,
      fotografias: fotografiasOficiais,
      croquis: croquis,
    );
  }

  LaudoSecao _buildSecaoDadosIniciais(Caso caso, Usuario perito) {
    final blocos = <LaudoBloco>[
      LaudoItemBloco(
        label: 'Laudo Pericial Cadavérico nº CD',
        valor: caso.numeroRequisicao.isNotEmpty
            ? formatarRequisicao(caso.numeroRequisicao)
            : (caso.numeroLaudoExterno != null
                ? formatarRequisicao(caso.numeroLaudoExterno)
                : 'XXX'),
      ),
      LaudoItemBloco(
        label: 'Requisitante: Delegado (a)',
        valor: caso.requisitante.isNotEmpty ? caso.requisitante : 'XXX',
      ),
      LaudoItemBloco(
        label: 'Destino:',
        valor: caso.destino.isNotEmpty ? caso.destino : 'XXX',
      ),
      LaudoItemBloco(
        label: 'Nome da vítima:',
        valor: caso.nomeVitima.isNotEmpty ? caso.nomeVitima : 'XXX',
      ),
    ];

    if (caso.atnsIds.isNotEmpty) {
      blocos.add(
        LaudoItemBloco(
          label: 'Técnico(s) de Necrópsia:',
          valor: caso.atnsIds.join(', '),
        ),
      );
    }

    blocos.add(const LaudoTituloBloco(texto: 'LAUDO CADAVÉRICO', nivel: 1));

    // Texto de abertura
    final data = caso.criadoEmDispositivo.toLocal();
    final dia = data.day.toString().padLeft(2, '0');
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    final anoExtenso = PdfHelpers.anoPorExtenso(data.year);

    final textoAbertura =
        'No dia $dia do mês de ${meses[data.month - 1]} do ano de $anoExtenso, neste Instituto de Medicina Legal da Coordenadoria Geral de Perícias da Secretaria de Estado da Segurança Pública de Sergipe, em conformidade com a legislação e com os dispositivos regulamentares vigentes, foram designados, o Perito Médico-Legal ${perito.nomeCompleto} e os Agentes técnicos em Necropsia para procederem a exame pericial, a fim de atender ao ofício retro, descrevendo fielmente e com todas as circunstâncias o que encontrarem e, bem assim, esclarecerem tudo quanto interessar possa com relação ao exame solicitado.';

    blocos.add(LaudoParagrafoBloco(texto: textoAbertura));

    return LaudoSecao(id: 'dados_iniciais', titulo: null, blocos: blocos);
  }

  LaudoSecao _buildSecaoHistorico(Caso caso) {
    final hist = caso.dadosLaudo.identificacao.historico;
    return LaudoSecao(
      id: 'historico',
      titulo: '1. HISTÓRICO',
      blocos: [
        LaudoParagrafoBloco(texto: hist.isNotEmpty ? hist : 'XXX'),
      ],
    );
  }

  LaudoSecao _buildSecaoIdentificacao(Caso caso) {
    final id = caso.dadosLaudo.identificacao;
    final carac = caso.dadosLaudo.caracteristicas;
    final blocos = <LaudoBloco>[
      const LaudoTituloBloco(texto: 'I) Vestes:', nivel: 2),
      LaudoParagrafoBloco(texto: id.vestes.isNotEmpty ? id.vestes : 'XXX'),
      const LaudoTituloBloco(texto: 'II) Características de identificação:', nivel: 2),
      const LaudoParagrafoBloco(
        texto: 'Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.',
      ),
      const LaudoTituloBloco(texto: 'III) Dados tanatológicos:', nivel: 2),
      const LaudoParagrafoBloco(
        texto: 'A morte está evidenciada pela presença dos seguintes sinais tanatológicos:',
      ),
      LaudoItemBloco(
        label: 'A) IMEDIATOS: ',
        valor: carac.tanatoImediato.isNotEmpty ? carac.tanatoImediato : 'XXX',
      ),
      LaudoItemBloco(
        label: 'B) CONSECUTIVOS: ',
        valor: carac.tanatoConsecutivo.isNotEmpty ? carac.tanatoConsecutivo : 'XXX',
      ),
      LaudoItemBloco(
        label: 'COMENTARIOS ADICIONAIS: ',
        valor: carac.tanatoObservacao.isNotEmpty ? carac.tanatoObservacao : 'XXX',
      ),
    ];

    return LaudoSecao(id: 'identificacao', titulo: '2. IDENTIFICAÇÃO', blocos: blocos);
  }

  LaudoSecao _buildSecaoExameExterno(
    List<Achado> todosAchados,
    Map<String, int> fotosPorAchado,
    Map<String, dynamic>? schemas,
  ) {
    final externos = todosAchados.where((a) => !a.isInterno).toList();
    final blocos = _agruparAchadosAnatomicos(
      externos,
      isInterno: false,
      fotosPorAchado: fotosPorAchado,
      schemas: schemas,
      todosAchados: todosAchados,
    );
    return LaudoSecao(id: 'exame_externo', titulo: '3. EXAME EXTERNO', blocos: blocos);
  }

  LaudoSecao _buildSecaoExameInterno(
    List<Achado> todosAchados,
    Map<String, int> fotosPorAchado,
    Map<String, dynamic>? schemas,
  ) {
    final internos = todosAchados.where((a) => a.isInterno).toList();
    final blocos = _agruparAchadosAnatomicos(
      internos,
      isInterno: true,
      fotosPorAchado: fotosPorAchado,
      schemas: schemas,
      todosAchados: todosAchados,
    );
    return LaudoSecao(id: 'exame_interno', titulo: '4. EXAME INTERNO (Cavidades)', blocos: blocos);
  }

  List<LaudoBloco> _agruparAchadosAnatomicos(
    List<Achado> achados, {
    required bool isInterno,
    required Map<String, int> fotosPorAchado,
    Map<String, dynamic>? schemas,
    required List<Achado> todosAchados,
  }) {
    final List<LaudoBloco> blocos = [];
    final List<Achado> pendentes = List.from(achados);

    PdfConstants.mapeamentoAnatomico.forEach((grupoOriginal, chavesExatas) {
      final titulo = isInterno
          ? (PdfConstants.titulosInternos[grupoOriginal] ?? grupoOriginal)
          : grupoOriginal;
      final textoVazio = isInterno
          ? 'Sem alterações macroscópicas dignas de nota.'
          : 'Sem evidências de lesões macroscópicas de natureza traumática.';
      final textoIntro = isInterno
          ? 'Com alterações macroscópicas:'
          : 'Com evidências de lesões macroscópicas:';

      final achadosGrupo = pendentes.where((a) {
        final localId = a.dadosPreenchidos['local_anatomico_id']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';
        return chavesExatas.contains(localId);
      }).toList();

      pendentes.removeWhere((a) => achadosGrupo.contains(a));

      final itensAchados = <LaudoAchadoItem>[];
      for (var a in achadosGrupo) {
        final fotoNum = fotosPorAchado[a.uuid];
        final refFoto = fotoNum != null ? ' [VER REGISTRO FOTOGRÁFICO $fotoNum]' : '';
        final descTexto = '${a.numeroSequencial}. ${a.dadosPreenchidos['type_label'] ?? 'Lesão'} em ${a.dadosPreenchidos['local_anatomico_nome'] ?? 'Região'}: ${a.observacoesTexto ?? ''}$refFoto';

        final camposFormatados = a.obterCamposFormatados(
          schemas?[a.tipoAchadoId],
          todosAchados: todosAchados,
        );

        itensAchados.add(
          LaudoAchadoItem(
            numeroSequencial: a.numeroSequencial,
            texto: descTexto,
            fotoNumero: fotoNum,
            campos: camposFormatados
                .map((c) => LaudoCampoExtra(
                      label: c['label']?.toString() ?? '',
                      valor: c['valor']?.toString() ?? '',
                    ))
                .toList(),
          ),
        );
      }

      blocos.add(
        LaudoGrupoAchadosBloco(
          titulo: '$titulo:',
          textoVazio: textoVazio,
          textoIntro: textoIntro,
          achados: itensAchados,
        ),
      );
    });

    if (pendentes.isNotEmpty) {
      final itensOutros = <LaudoAchadoItem>[];
      for (var a in pendentes) {
        final fotoNum = fotosPorAchado[a.uuid];
        final refFoto = fotoNum != null ? ' [VER REGISTRO FOTOGRÁFICO $fotoNum]' : '';
        final descTexto = '${a.numeroSequencial}. ${a.dadosPreenchidos['type_label'] ?? 'Lesão'} em ${a.dadosPreenchidos['local_anatomico_nome'] ?? 'Região'} (ID: ${a.dadosPreenchidos['local_anatomico_id']}): ${a.observacoesTexto ?? ''}$refFoto';

        itensOutros.add(
          LaudoAchadoItem(
            numeroSequencial: a.numeroSequencial,
            texto: descTexto,
            fotoNumero: fotoNum,
          ),
        );
      }

      blocos.add(
        LaudoGrupoAchadosBloco(
          titulo: 'OUTRAS REGIÕES NÃO MAPEADAS:',
          textoVazio: 'Sem alterações.',
          textoIntro: 'Com evidências de lesões:',
          achados: itensOutros,
        ),
      );
    }

    return blocos;
  }

  LaudoSecao _buildSecaoExamesComplementares(
    Caso caso,
    List<ExameSolicitado> legados,
    List<em.ExameSolicitadoModel>? estruturados,
  ) {
    final blocos = <LaudoBloco>[];
    if ((estruturados == null || estruturados.isEmpty) && legados.isEmpty) {
      blocos.add(const LaudoParagrafoBloco(texto: 'Sem exames complementares solicitados.'));
    } else {
      if (estruturados != null) {
        for (var e in estruturados) {
          blocos.add(LaudoItemBloco(label: '${e.tipoExame}: ', valor: 'SOLICITADO'));
        }
      }
      for (var l in legados) {
        blocos.add(LaudoItemBloco(label: '${l.tipoExame}: ', valor: 'SOLICITADO'));
      }
    }
    return LaudoSecao(id: 'exames_complementares', titulo: '5. EXAMES COMPLEMENTARES', blocos: blocos);
  }

  LaudoSecao _buildSecaoRascunhos(List<LaudoCroquiRef> croquis) {
    final blocos = <LaudoBloco>[];
    if (croquis.isEmpty) {
      blocos.add(const LaudoParagrafoBloco(texto: 'Sem rascunhos anexados.'));
    } else {
      for (var c in croquis) {
        blocos.add(LaudoImagemBloco(ref: 'croqui:${c.vista}'));
      }
    }
    return LaudoSecao(id: 'rascunhos', titulo: '6. RASCUNHOS E ESQUEMAS DE LESÃO', blocos: blocos);
  }

  LaudoSecao _buildSecaoFotografias(List<LaudoFoto> fotos) {
    final blocos = <LaudoBloco>[];
    if (fotos.isEmpty) {
      blocos.add(const LaudoParagrafoBloco(texto: 'Sem fotografias anexadas.'));
    } else {
      for (var f in fotos) {
        blocos.add(LaudoImagemBloco(ref: 'foto:${f.numero}'));
      }
    }
    return LaudoSecao(id: 'fotos', titulo: '7. REGISTRO FOTOGRÁFICO', blocos: blocos);
  }

  LaudoSecao _buildSecaoComentario(Caso caso) {
    final disc = caso.dadosLaudo.conclusao.discussao;
    return LaudoSecao(
      id: 'comentario',
      titulo: '8. COMENTÁRIO MÉDICO FORENSE',
      blocos: [
        LaudoParagrafoBloco(texto: disc.isNotEmpty ? disc : 'XXX'),
      ],
    );
  }

  LaudoSecao _buildSecaoConclusao(Caso caso) {
    final conc = caso.dadosLaudo.conclusao.conclusaoTexto;
    return LaudoSecao(
      id: 'conclusao',
      titulo: '9. CONCLUSÃO',
      blocos: [
        LaudoParagrafoBloco(texto: conc.isNotEmpty ? conc : 'XXX'),
        const LaudoParagrafoBloco(texto: PdfConstants.encerramentoPadrao),
      ],
    );
  }

  LaudoSecao _buildSecaoQuesitos(Caso caso) {
    final q = caso.dadosLaudo.conclusao;
    final blocos = <LaudoBloco>[
      LaudoItemBloco(
        label: '1º) Houve a morte? ',
        valor: q.quesito1Morte.isNotEmpty ? q.quesito1Morte : 'SIM, CONFORME DESCRITO NO LAUDO.',
      ),
    ];

    if (caso.causaMorte != null && caso.causaMorte!.isNotEmpty) {
      final causasList = caso.causaMorte!;
      for (int i = 0; i < causasList.length; i++) {
        final cm = causasList[i];
        final prefixo = causasList.length > 1 ? 'Causa #${i + 1} - ' : '';
        final imediata = cm.imediata.isNotEmpty ? cm.imediata : 'XXX';
        final devidoA = cm.devidoA.isNotEmpty ? cm.devidoA : 'XXX';
        final consequencia = cm.consequencia.isNotEmpty ? cm.consequencia : 'XXX';
        blocos.add(
          LaudoItemBloco(
            label: '2º) Qual a causa da morte? ($prefixo)',
            valor: 'Imediata: $imediata; Devido a: $devidoA; Consequência: $consequencia',
          ),
        );
      }
    } else {
      blocos.add(
        LaudoItemBloco(
          label: '2º) Qual a causa da morte? ',
          valor: q.quesito2Causa.isNotEmpty ? q.quesito2Causa : 'XXX',
        ),
      );
    }

    blocos.addAll([
      LaudoItemBloco(
        label: '3º) Qual o instrumento ou meio que produziu a morte? ',
        valor: q.quesito3Instrumento.isNotEmpty ? q.quesito3Instrumento : 'XXX',
      ),
      LaudoItemBloco(
        label: '4º) Foi produzida por meio de veneno, fogo, explosivo, asfixia ou tortura? ',
        valor: q.quesito4Meio.isNotEmpty ? q.quesito4Meio : 'XXX',
      ),
    ]);

    return LaudoSecao(id: 'quesitos', titulo: '10. RESPOSTA AOS QUESITOS', blocos: blocos);
  }

  LaudoSecao _buildSecaoFecho(Caso caso, Usuario perito) {
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    final dt = caso.criadoEmDispositivo.toLocal();
    final mesStr = meses[dt.month - 1];
    final dataExtenso = '${dt.day.toString().padLeft(2, '0')} de $mesStr de ${dt.year}';
    return LaudoSecao(
      id: 'fecho',
      titulo: null,
      blocos: [
        LaudoAssinaturaBloco(
          cidade: 'Nossa Senhora do Socorro/SE',
          data: dataExtenso,
        ),
      ],
    );
  }
}

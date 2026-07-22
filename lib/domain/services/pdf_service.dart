import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart' as em;
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';
import 'package:croqui_forense_mvp/presentation/utils/achado_formatter.dart';

import 'pdf_constants.dart';
import 'pdf_helpers.dart';

/// Serviço responsável pela geração e compilação do Laudo Pericial Oficial
/// em formato PDF para fins de impressão e armazenamento.
///
/// Este serviço atua como o "Motor de Exportação do Laudo Cadavérico/Lesão Corporal Oficial",
/// consolidando todas as informações coletadas pelo Perito durante o exame
/// necroscópico ou clínico, incluindo as lesões registradas graficamente no
/// croqui, fotos anexadas como evidências físicas e os quesitos respondidos.
///
/// O documento PDF resultante serve como uma "Impressão Oficial" dotada de
/// "Validação Jurídica", contendo os "Metadados do Perito" e a assinatura de
/// integridade para sua preservação legal.
class PdfService {
  static Future<pw.Font>? _cachedFontRegularFuture;
  static Future<pw.Font>? _cachedFontBoldFuture;
  static Future<pw.MemoryImage?>? _cachedLogoPoliciaFuture;

  /// Compila e gera o documento de "Impressão Oficial" do Laudo Pericial Cadavérico ou
  /// de Lesão Corporal no formato PDF.
  ///
  /// Consolida o histórico, a identificação oficial da vítima, os dados tanatológicos,
  /// as descrições detalhadas dos exames externo e interno, os exames complementares,
  /// os esquemas anatômicos (croquis) e a resposta oficial aos quesitos formulados pela autoridade requisitante.
  /// Também inclui no "Documento Físico" a certificação eletrônica com "Metadados do Perito"
  /// para conferir autenticidade e "Validação Jurídica" na cadeia de custódia.
  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    Map<String, dynamic>? schemas,
    required List<ExameSolicitado> exames,
    List<em.ExameSolicitadoModel>? examesModel,
    required List<EvidenciaMultimidia> evidenciasGerais,
  }) async {
    final pdf = pw.Document();

    _cachedFontRegularFuture ??= rootBundle.load("assets/fonts/Roboto-Regular.ttf").then((data) => pw.Font.ttf(data));
    _cachedFontBoldFuture ??= rootBundle.load("assets/fonts/Roboto-Bold.ttf").then((data) => pw.Font.ttf(data));
    _cachedLogoPoliciaFuture ??= rootBundle.load('assets/images/logo/logo-policia-se.jpeg').then<pw.MemoryImage?>((data) => pw.MemoryImage(data.buffer.asUint8List())).catchError((e) {
      debugPrint("Erro ao carregar logo: $e");
      return null;
    });

    final fontRegular = await _cachedFontRegularFuture!;
    final fontBold = await _cachedFontBoldFuture!;
    final logoPolicia = await _cachedLogoPoliciaFuture;

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final List<Achado> achadosExternos = achados.where((a) => !a.isInterno).toList();
    final List<Achado> achadosInternos = achados.where((a) => a.isInterno).toList();

    List<Map<String, dynamic>> anexosFotos = await _prepararFotos(caso, achados, evidenciasGerais);
    final croquisWidgets = await _gerarMapasSVG(achados, caso);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: PdfConstants.marginDefault,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => PdfHelpers.buildDynamicHeader(context, logoPolicia, caso.numeroRequisicao.isNotEmpty ? caso.numeroRequisicao : caso.numeroLaudoExterno),
        footer: (context) => PdfHelpers.buildInstitucionalFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            _buildDadosIniciais(caso),
            pw.SizedBox(height: 20),
            _buildTextoAbertura(caso, perito),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("1. HISTÓRICO"),
            PdfHelpers.buildParagrafoComRecuo(caso.dadosLaudo['identificacao']?['historico'] ?? "XXX"),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("2. IDENTIFICAÇÃO"),
            _buildIdentificacaoOficial(caso),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("3. EXAME EXTERNO"),
            ..._buildExameAgrupado(achadosExternos, anexosFotos, isInterno: false, schemas: schemas, todosAchados: achados),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("4. EXAME INTERNO (Cavidades)"),
            ..._buildExameAgrupado(achadosInternos, anexosFotos, isInterno: true, schemas: schemas, todosAchados: achados),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("5. EXAMES COMPLEMENTARES"),
            _buildDadosComplementares(exames, examesModel: examesModel),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("6. RASCUNHOS E ESQUEMAS DE LESÃO"),
            if (croquisWidgets.isEmpty)
              PdfHelpers.buildParagrafoComRecuo("Sem rascunhos anexados.")
            else
              ...croquisWidgets,
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("7. REGISTRO FOTOGRÁFICO"),
            if (anexosFotos.isEmpty)
              PdfHelpers.buildParagrafoComRecuo("Sem fotografias anexadas.")
            else
              ..._buildSecaoFotos(anexosFotos),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("8. COMENTÁRIO MÉDICO FORENSE"),
            PdfHelpers.buildParagrafoComRecuo((caso.dadosLaudo['conclusao']?['discussao']?.toString().isNotEmpty == true) ? caso.dadosLaudo['conclusao']!['discussao'] : "XXX"),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("9. CONCLUSÃO"),
            PdfHelpers.buildParagrafoComRecuo((caso.dadosLaudo['conclusao']?['conclusao_texto']?.toString().isNotEmpty == true) ? caso.dadosLaudo['conclusao']!['conclusao_texto'] : "XXX"),
            pw.SizedBox(height: 10),
            PdfHelpers.buildParagrafoComRecuo(PdfConstants.encerramentoPadrao),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("10. RESPOSTA AOS QUESITOS"),
            _buildDadosQuesitosOficial(caso),
            pw.SizedBox(height: 40),
            pw.Align(alignment: pw.Alignment.center, child: _buildEncerramento(caso, perito)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildDadosIniciais(Caso caso) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfHelpers.buildLinhaDetalhe("Laudo Pericial Cadavérico nº CD", caso.numeroRequisicao.isNotEmpty ? caso.numeroRequisicao : (caso.numeroLaudoExterno ?? 'XXX')),
        PdfHelpers.buildLinhaDetalhe("Boletim de Ocorrência (B.O.):", caso.numeroBo.isNotEmpty ? caso.numeroBo : 'XXX'), 
        PdfHelpers.buildLinhaDetalhe("PIC:", caso.numeroPic.isNotEmpty ? caso.numeroPic : 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Requisitante: Delegado (a)", caso.requisitante.isNotEmpty ? caso.requisitante : 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Destino:", caso.destino.isNotEmpty ? caso.destino : 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Nome da vítima:", caso.nomeVitima.isNotEmpty ? caso.nomeVitima : 'XXX', bold: true),
        pw.SizedBox(height: 20),
        pw.Center(child: pw.Text("LAUDO CADAVÉRICO", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  pw.Widget _buildTextoAbertura(Caso caso, Usuario perito) {
    final data = caso.criadoEmDispositivo.toLocal();
    final dia = data.day.toString().padLeft(2, '0');
    const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
    final anoExtenso = PdfHelpers.anoPorExtenso(data.year); 

    final texto = "No dia $dia do mês de ${meses[data.month - 1]} do ano de $anoExtenso, neste Instituto de Medicina Legal da Coordenadoria Geral de Perícias da Secretaria de Estado da Segurança Pública de Sergipe, em conformidade com a legislação e com os dispositivos regulamentares vigentes, foram designados, o Perito Médico-Legal Dr. Ronmel Lisboa dos Santos e os Agentes técnicos em Necropsia para procederem a exame pericial, a fim de atender ao ofício retro, descrevendo fielmente e com todas as circunstâncias o que encontrarem e, bem assim, esclarecerem tudo quanto interessar possa com relação ao exame solicitado.";
    return PdfHelpers.buildParagrafoComRecuo(texto);
  }

  pw.Widget _buildIdentificacaoOficial(Caso caso) {
    final id = caso.dadosLaudo['identificacao'] ?? {};
    final carac = caso.dadosLaudo['caracteristicas'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("I) Vestes:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        PdfHelpers.buildParagrafoComRecuo(id['vestes']?.toString().isNotEmpty == true ? id['vestes'] : "XXX"),
        pw.SizedBox(height: 5),
        
        pw.Text("II) Características de identificação:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        PdfHelpers.buildParagrafoComRecuo("Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos."),
        pw.SizedBox(height: 5),
        
        pw.Text("III) Dados tanatológicos:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("A morte está evidenciada pela presença dos seguintes sinais tanatológicos:", style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("A) IMEDIATOS: ", carac['tanato_imediato']?.toString().isNotEmpty == true ? carac['tanato_imediato'] : 'XXX'),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("B) CONSECUTIVOS: ", carac['tanato_consecutivo']?.toString().isNotEmpty == true ? carac['tanato_consecutivo'] : 'XXX'),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("COMENTARIOS ADICIONAIS: ", carac['tanato_observacao']?.toString().isNotEmpty == true ? carac['tanato_observacao'] : 'XXX'),
            ]
          )
        )
      ],
    );
  }

  List<pw.Widget> _buildExameAgrupado(
    List<Achado> achados,
    List<Map<String, dynamic>> anexos, {
    required bool isInterno,
    Map<String, dynamic>? schemas,
    List<Achado>? todosAchados,
  }) {
    List<pw.Widget> items = [];
    List<Achado> achadosPendentes = List.from(achados);
    
    PdfConstants.mapeamentoAnatomico.forEach((grupoOrinal, chavesExatas) {
      final tituloDaSecao = isInterno ? PdfConstants.titulosInternos[grupoOrinal]! : grupoOrinal;
      final textoVazio = isInterno ? "Sem alterações macroscópicas dignas de nota." : "Sem evidências de lesões macroscópicas de natureza traumática.";
      final textoComLesao = isInterno ? null : "Com evidências de lesões macroscópicas:"; 
      final achadosGrupo = achadosPendentes.where((a) {
        final localId = a.dadosPreenchidos['local_anatomico_id']?.toString().trim().toLowerCase() ?? '';
        return chavesExatas.contains(localId); 
      }).toList();

      achadosPendentes.removeWhere((a) => achadosGrupo.contains(a));

      items.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text("$tituloDaSecao:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))));
      
      if (achadosGrupo.isEmpty) {
        items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text(textoVazio, style: const pw.TextStyle(fontSize: 10))));
      } else {
        if (textoComLesao != null) {
           items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text(textoComLesao, style: const pw.TextStyle(fontSize: 10))));
        }
        for (var a in achadosGrupo) {
          final foto = anexos.cast<Map<String, dynamic>?>().firstWhere((f) => f != null && f['uuid'] == a.uuid, orElse: () => null);
          final refFoto = foto != null ? " [VER REGISTRO FOTOGRÁFICO ${foto['numero']}]" : "";
          
          final List<pw.Widget> columnChildren = [
            pw.Bullet(
              text: "[${a.numeroSequencial}] ${a.dadosPreenchidos['type_label']} em ${a.dadosPreenchidos['local_anatomico_nome']}: ${a.observacoesTexto ?? ''}$refFoto",
              style: const pw.TextStyle(fontSize: 10),
            ),
          ];

          final campos = a.obterCamposFormatados(schemas?[a.tipoAchadoId], todosAchados: todosAchados);
          if (campos.isNotEmpty) {
            columnChildren.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 15, top: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: campos.map((c) => pw.Text(
                    "- ${c['label']}: ${c['valor']}",
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  )).toList(),
                ),
              ),
            );
          }

          items.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 30, top: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: columnChildren,
              ),
            ),
          );
        }
      }
    });

    if (achadosPendentes.isNotEmpty) {
      items.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 10), child: pw.Text("OUTRAS REGIÕES NÃO MAPEADAS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))));
      items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Com evidências de lesões:", style: const pw.TextStyle(fontSize: 10))));
      
      for (var a in achadosPendentes) {
        final foto = anexos.cast<Map<String, dynamic>?>().firstWhere((f) => f != null && f['uuid'] == a.uuid, orElse: () => null);
        final refFoto = foto != null ? " [VER REGISTRO FOTOGRÁFICO ${foto['numero']}]" : "";
        
        final List<pw.Widget> columnChildren = [
          pw.Bullet(
            text: "[${a.numeroSequencial}] ${a.dadosPreenchidos['type_label']} em ${a.dadosPreenchidos['local_anatomico_nome']} (ID: ${a.dadosPreenchidos['local_anatomico_id']}): ${a.observacoesTexto ?? ''}$refFoto",
            style: const pw.TextStyle(fontSize: 10),
          ),
        ];

        final campos = a.obterCamposFormatados(schemas?[a.tipoAchadoId], todosAchados: todosAchados);
        if (campos.isNotEmpty) {
          columnChildren.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 15, top: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: campos.map((c) => pw.Text(
                  "- ${c['label']}: ${c['valor']}",
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                )).toList(),
              ),
            ),
          );
        }

        items.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 30, top: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: columnChildren,
            ),
          ),
        );
      }
    }

    return items;
  }

  pw.Widget _buildDadosComplementares(
    List<ExameSolicitado> exames, {
    List<em.ExameSolicitadoModel>? examesModel,
  }) {
    // Se temos os modelos ricos (Fase 4), usamos a renderização detalhada.
    if (examesModel != null && examesModel.isNotEmpty) {
      return _buildDadosComplementaresRico(examesModel);
    }

    // Fallback legado: só lacres, para casos sem migração.
    final anatomoEx  = exames.firstWhere((e) => e.tipoExame == 'ANATOMO',      orElse: () => ExameSolicitado(uuid: '', casoUuid: '', tipoExame: '', numeroLacre: '', criadoEm: DateTime.now()));
    final toxEx      = exames.firstWhere((e) => e.tipoExame == 'TOXICOLOGICO', orElse: () => ExameSolicitado(uuid: '', casoUuid: '', tipoExame: '', numeroLacre: '', criadoEm: DateTime.now()));
    final genEx      = exames.firstWhere((e) => e.tipoExame == 'GENETICA',     orElse: () => ExameSolicitado(uuid: '', casoUuid: '', tipoExame: '', numeroLacre: '', criadoEm: DateTime.now()));
    final outrosEx   = exames.firstWhere((e) => e.tipoExame == 'OUTROS',       orElse: () => ExameSolicitado(uuid: '', casoUuid: '', tipoExame: '', numeroLacre: '', criadoEm: DateTime.now()));
    return pw.Column(
children: [
        PdfHelpers.buildItemComLabel('Anátomo-Patológico (Lacre): ', anatomoEx.uuid.isNotEmpty ? anatomoEx.numeroLacre : 'NÃO SOLICITADO'),
        PdfHelpers.buildItemComLabel('Toxicológico (Lacre): ',        toxEx.uuid.isNotEmpty      ? toxEx.numeroLacre      : 'NÃO SOLICITADO'),
        PdfHelpers.buildItemComLabel('Genética (Lacre): ',            genEx.uuid.isNotEmpty      ? genEx.numeroLacre      : 'NÃO SOLICITADO'),
        PdfHelpers.buildItemComLabel('Outros (Lacre): ',              outrosEx.uuid.isNotEmpty   ? outrosEx.numeroLacre   : 'NÃO SOLICITADO'),
      ],
    );
  }

  // ─── Renderização rica (Fase 4) ───────────────────────────────────────────────────

  pw.Widget _buildDadosComplementaresRico(List<em.ExameSolicitadoModel> exames) {
    if (exames.isEmpty) {
      return PdfHelpers.buildParagrafoComRecuo('Nenhum exame complementar solicitado.');
    }

    final List<pw.Widget> blocos = [];
    int contador = 0;
    final letras = ['A', 'B', 'C', 'D', 'E'];

    for (final exame in exames) {
      final tipo = exame.tipoExame.toUpperCase().trim();
      final letra = contador < letras.length ? letras[contador] : '${contador + 1}';
      contador++;

      if (tipo == 'TOXICOLOGICO') {
        blocos.add(_bloco5Toxicologico(exame, letra));
      } else if (tipo == 'GENETICA') {
        blocos.add(_bloco5Genetica(exame, letra));
      } else if (tipo == 'ANATOMO') {
        blocos.add(_bloco5Anatomo(exame, letra));
      }
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: blocos);
  }

  // ─── Bloco: TOXICOLÓGICO ────────────────────────────────────────────────────────

  pw.Widget _bloco5Toxicologico(em.ExameSolicitadoModel exame, String letra) {
    final d = exame.detalhes is DetalhesToxicologicoModel
        ? exame.detalhes as DetalhesToxicologicoModel
        : null;

    final List<pw.Widget> linhas = [];

    // Título do bloco — estilo documento oficial: negrito, sem fundo colorido
    linhas.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(
          '$letra) EXAME TOXICOLÓGICO',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ),
    );

    if (d == null) {
      linhas.add(_itemRecuado('Detalhes não disponíveis.'));
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
    }

    // Histórico da ocorrência
    final historico = d.historicoOcorrencia == 'Outro'
        ? 'Outro: ${d.historicoOutro ?? 'não especificado'}'
        : (d.historicoOcorrencia ?? 'Não informado');
    linhas.add(_subTitulo('Histórico da Ocorrência:'));
    linhas.add(_itemRecuado(historico));

    // Materiais com lacres individuais
    final bool temSg = d.materialSgFemoral || d.materialSgCardiaca || (d.materialSgOutro?.isNotEmpty == true);
    final bool temAlgumMaterial = temSg || d.materialUrina || d.materialHumorVitreo || d.materialEstomago || d.materialPulmao;

    if (temAlgumMaterial) {
      linhas.add(_subTitulo('Materiais Biológicos Solicitados:'));
    }

    if (temSg) {
      final subs = <String>[];
      if (d.materialSgFemoral) subs.add('Veia Femoral');
      if (d.materialSgCardiaca) subs.add('Cavidade Cardíaca');
      if (d.materialSgOutro?.isNotEmpty == true) subs.add('Outro sítio: ${d.materialSgOutro}');
      final lacreSg = d.numeroLacreSg?.isNotEmpty == true ? d.numeroLacreSg! : 'Não informado';
      linhas.add(_itemRecuado('- Sangue (SG) [${subs.join(', ')}] — Lacre: $lacreSg'));
      if (d.quantificacaoDrogas) {
        linhas.add(_itemRecuadoSecundario('Solicita quantificacao de drogas / farmacos'));
      }
    }

    if (d.materialUrina) {
      final lacre = d.numeroLacreUr?.isNotEmpty == true ? d.numeroLacreUr! : 'Não informado';
      linhas.add(_itemRecuado('- Urina (UR) — Lacre: $lacre'));
    }
    if (d.materialHumorVitreo) {
      final lacre = d.numeroLacreHv?.isNotEmpty == true ? d.numeroLacreHv! : 'Não informado';
      linhas.add(_itemRecuado('- Humor Vitreo (HV) — Lacre: $lacre'));
    }
    if (d.materialEstomago) {
      final lacre = d.numeroLacreCe?.isNotEmpty == true ? d.numeroLacreCe! : 'Não informado';
      linhas.add(_itemRecuado('- Conteudo Estomacal (CE) — Lacre: $lacre'));
    }
    if (d.materialPulmao) {
      final lacre = d.numeroLacrePm?.isNotEmpty == true ? d.numeroLacrePm! : 'Não informado';
      linhas.add(_itemRecuado('- Pulmao (PM) — Lacre: $lacre'));
    }

    if (!temAlgumMaterial) {
      linhas.add(_itemRecuado('Nenhum material selecionado.'));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
  }

  // ─── Bloco: GENÉTICA E BIOLÓGICO ───────────────────────────────────────────────

  pw.Widget _bloco5Genetica(em.ExameSolicitadoModel exame, String letra) {
    final amostras = (exame.detalhes is List)
        ? (exame.detalhes as List).whereType<AmostraGeneticaModel>().toList()
        : <AmostraGeneticaModel>[];

    final List<pw.Widget> linhas = [];

    // Título do bloco
    linhas.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(
          '$letra) EXAME GENÉTICO E BIOLÓGICO',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ),
    );

    if (amostras.isEmpty) {
      linhas.add(_itemRecuado('Nenhuma amostra registrada.'));
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
    }

    final questionadas = amostras.where((a) => a.tipoAmostra != 'SWAB_BUCAL_VITIMA').toList();
    final referencia   = amostras.where((a) => a.tipoAmostra == 'SWAB_BUCAL_VITIMA').toList();

    if (questionadas.isNotEmpty) {
      linhas.add(_subTitulo('Amostras Questionadas:'));
      for (final a in questionadas) {
        final desc = _descricaoAmostraGenetica(a);
        final pesqs = <String>[];
        if (a.pesquisaSemen) pesqs.add('Pesquisa de Semen');
        if (a.pesquisaDna)   pesqs.add('Pesquisa de DNA');
        final pesqStr = pesqs.isNotEmpty ? ' [${pesqs.join(' + ')}]' : '';
        final lacre = a.numeroLacre?.isNotEmpty == true ? a.numeroLacre! : 'Não informado';
        linhas.add(_itemRecuado('- $desc$pesqStr — Lacre do Envelope: $lacre'));
      }
    }

    if (referencia.isNotEmpty) {
      linhas.add(_subTitulo('Amostra de Referencia:'));
      for (final a in referencia) {
        final lacre = a.numeroLacre?.isNotEmpty == true ? a.numeroLacre! : 'Não informado';
        linhas.add(_itemRecuado('- Swab Bucal da Vitima — Qtd: ${a.quantidadeSwabs} swab(s) — Lacre do Envelope: $lacre'));
      }
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
  }

  String _descricaoAmostraGenetica(AmostraGeneticaModel a) {
    const nomes = {
      'SWAB_VAGINAL_1':    'SWAB VAGINAL - 1 (Pesquisa de sêmen e DNA)',
      'SWAB_VAGINAL_2':    'SWAB VAGINAL - 2 (Pesquisa de sêmen e DNA)',
      'SWAB_ANAL_1':       'SWAB ANAL - 1 (Pesquisa de sêmen e DNA)',
      'SWAB_ANAL_2':       'SWAB ANAL - 2 (Pesquisa de sêmen e DNA)',
      'SWAB_BUCAL_VITIMA': 'Swab Bucal da Vítima',
    };
    if (a.tipoAmostra == 'OUTRO') {
      return a.descricaoOutro?.isNotEmpty == true ? a.descricaoOutro! : 'Amostra personalizada';
    }
    return nomes[a.tipoAmostra] ?? a.tipoAmostra;
  }

  // ─── Bloco: ANÁTOMO-PATOLÓGICO ────────────────────────────────────────────────

  pw.Widget _bloco5Anatomo(em.ExameSolicitadoModel exame, String letra) {
    final frascos = (exame.detalhes is List)
        ? (exame.detalhes as List).whereType<FrascoAnatomoModel>().toList()
        : <FrascoAnatomoModel>[];

    frascos.sort((a, b) => a.numeroFrasco.compareTo(b.numeroFrasco));

    final List<pw.Widget> linhas = [];

    // Título do bloco
    linhas.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(
          '$letra) EXAME ANÁTOMO-PATOLÓGICO (HISTOPATOLÓGICO)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ),
    );

    if (frascos.isEmpty) {
      linhas.add(_itemRecuado('Nenhum frasco registrado.'));
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
    }

    for (final f in frascos) {
      final numStr = f.numeroFrasco.toString().padLeft(2, '0');
      final lacre = f.numeroLacre?.isNotEmpty == true ? f.numeroLacre! : 'Não informado';

      // Cabeçalho do frasco: numeracao + lacre
      linhas.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15, top: 6, bottom: 2),
          child: pw.Text(
            'Frasco $numStr — Lacre: $lacre',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
          ),
        ),
      );

      final orgaos = <String>[];
      if (f.coracao)  orgaos.add('Coracao');
      if (f.figado)   orgaos.add('Figado');
      if (f.baco)     orgaos.add('Baco');
      if (f.encefalo) orgaos.add('Encefalo');
      if (f.rimD)     orgaos.add('Rim D.');
      if (f.rimE)     orgaos.add('Rim E.');

      final pulmoes = <String>[];
      if (f.pulmaoDLsd) pulmoes.add('LSD');
      if (f.pulmaoDLmd) pulmoes.add('LMD');
      if (f.pulmaoDLid) pulmoes.add('LID');
      if (f.pulmaoELse) pulmoes.add('LSE');
      if (f.pulmaoELie) pulmoes.add('LIE');
      if (pulmoes.isNotEmpty) orgaos.add('Pulmao (${pulmoes.join(', ')})');

      if (orgaos.isNotEmpty) {
        linhas.add(_itemRecuado('Orgaos: ${orgaos.join(' | ')}'));
      }
      if (f.peleRegiao?.isNotEmpty == true) {
        linhas.add(_itemRecuado('Pele — Regiao: ${f.peleRegiao}'));
      }
      if (f.partesMolesRegiao?.isNotEmpty == true) {
        linhas.add(_itemRecuado('Partes Moles — Regiao: ${f.partesMolesRegiao}'));
      }
      if (f.outrasRegiao?.isNotEmpty == true) {
        linhas.add(_itemRecuado('Outras — Descricao: ${f.outrasRegiao}'));
      }
      if (orgaos.isEmpty && f.peleRegiao == null && f.partesMolesRegiao == null && f.outrasRegiao == null) {
        linhas.add(_itemRecuado('(Frasco sem conteudo especificado)'));
      }
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas);
  }

  // ─── Helpers internos ───────────────────────────────────────────────────────────

  pw.Widget _subTitulo(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 15, top: 5, bottom: 2),
    child: pw.Text(texto, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
  );

  pw.Widget _itemRecuado(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 25, top: 2),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9.5)),
  );

  /// Recuo secundário para sub-itens (ex: quantificacao abaixo de Sangue SG).
  pw.Widget _itemRecuadoSecundario(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 38, top: 1),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9)),
  );


  pw.Widget _buildDadosQuesitosOficial(Caso caso) {
    final q = caso.dadosLaudo['conclusao'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("I) Houve morte?", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text("R: ${q['quesito_1_morte']?.toString().isNotEmpty == true ? q['quesito_1_morte'] : 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text("II) Qual a causa?", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text("R: ${q['quesito_2_causa']?.toString().isNotEmpty == true ? q['quesito_2_causa'] : 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text("III) Qual o instrumento ou meio que a produziu?", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text("R: ${q['quesito_3_instrumento']?.toString().isNotEmpty == true ? q['quesito_3_instrumento'] : 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text("IV) Foi produzida por meio de veneno, fogo, explosivo, asfixia ou meio insidioso cruel?", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text("R: ${q['quesito_4_meio']?.toString().isNotEmpty == true ? q['quesito_4_meio'] : 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
      ]
    );
  }

 pw.Widget _buildEncerramento(Caso caso, Usuario perito) {
  final dataAtual = DateTime.now();
  const meses = [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho", 
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
  ];
  final mesStr = meses[dataAtual.month - 1];

  final auditoria = caso.dadosLaudo['auditoria'] as Map<String, dynamic>? ?? {};
  final nomeResponsavel = auditoria['perito_responsavel']?.toString() ?? perito.nomeCompleto;

  String dataFinalizacaoStr;
    final rawDate = auditoria['data_finalizacao'];
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        dataFinalizacaoStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);
      } catch (e) {
        dataFinalizacaoStr = "Confirmado (Data Indisponível)";
      }
    } else {
      dataFinalizacaoStr = "Confirmado no Sistema";
    }


  final dataExportacao = DateFormat("dd/MM/yyyy 'às' HH:mm:ss").format(dataAtual);

  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 20),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          "Nossa Senhora do Socorro/SE, ${dataAtual.day.toString().padLeft(2, '0')} de $mesStr de ${dataAtual.year}.",
          style: const pw.TextStyle(fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 50),
        
        pw.Container(
          width: 280,
          child: pw.Divider(color: PdfColors.black, thickness: 0.8),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          nomeResponsavel.toUpperCase(),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.Text(
          "Perito Médico Legal",
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        
        pw.SizedBox(height: 40),

        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text("CERTIFICAÇÃO DE INTEGRIDADE DIGITAL", 
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Spacer(),
                  if (caso.hashIntegridade != null)
                    pw.Text("HASH: ${caso.hashIntegridade?.substring(0, 12)}...", 
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Finalizado em: $dataFinalizacaoStr", style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text("Exportado em: $dataExportacao", style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Este documento foi gerado pelo sistema Necropsia Digital e assinado eletronicamente por $nomeResponsavel. "
                "A conferência de autenticidade deve ser feita via base de dados oficial da Coordenadoria Geral de Perícias.",
                style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  
  static final Uint8List _fallbackImageBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ]);

  Future<List<Map<String, dynamic>>> _prepararFotos(Caso caso, List<Achado> achados, List<EvidenciaMultimidia> evidenciasGerais) async {
    List<Map<String, dynamic>> anexos = [];
    int contador = 1;

    for (var ev in evidenciasGerais) {
      final path = ev.caminhoArquivoEncriptado ?? '';
      if (path.isNotEmpty) {
        final file = File(path);
        final bool existe = file.existsSync();
        final Uint8List bytes = existe ? await file.readAsBytes() : _fallbackImageBytes;
        final String statusTag = existe ? '' : ' [IMAGEM INDISPONÍVEL]';
        anexos.add({
          'numero': contador, 
          'bytes': bytes, 
          'label': 'Fotografia $contador$statusTag - Identificação Geral'
        });
        contador++;
      }
    }
    
    for (var a in achados) {
      final path = a.dadosPreenchidos['photo_path'];
      if (path != null && path.toString().isNotEmpty) {
        final file = File(path.toString());
        final bool existe = file.existsSync();
        final Uint8List bytes = existe ? await file.readAsBytes() : _fallbackImageBytes;
        final String statusTag = existe ? '' : ' [IMAGEM INDISPONÍVEL]';
        anexos.add({
          'numero': contador, 
          'uuid': a.uuid, 
          'bytes': bytes, 
          'label': 'Fotografia $contador$statusTag - Ref. Achado ${a.numeroSequencial} (${a.dadosPreenchidos['type_label']})'
        });
        contador++;
      }
    }
    return anexos;
  }

  Future<List<pw.Widget>> _gerarMapasSVG(List<Achado> achados, Caso caso) async {
    final activeAchados = achados.where((a) => !a.removido).toList();
    if (activeAchados.isEmpty) return [];

    Map<String, List<Achado>> porFolha = {};
    for (var a in activeAchados) {
      String view = a.dadosPreenchidos['view'] ?? 'frente';
      porFolha.putIfAbsent(view, () => []).add(a);
    }
    List<pw.Widget> widgets = [];

    for (var view in porFolha.keys) {
      String assetPath = 'assets/images/croqui-frente.svg';
      if (view == 'costas' || view == 'back') assetPath = 'assets/images/croqui-costas.svg';
      if (view == 'lateral_dir') assetPath = 'assets/images/face-lateral-direita.svg';
      if (view == 'lateral_esq') assetPath = 'assets/images/face-lateral-esquerda.svg';
      if (view == 'trunk_dir') assetPath = 'assets/images/tronco-direito-contorno.svg';
      if (view == 'trunk_esq') assetPath = 'assets/images/tronco-esquerdo-contorno.svg';
      if (view == 'perineal') {
        final dadosId = caso.dadosLaudo['identificacao'];
        final String sexoNorm = (dadosId != null && dadosId['sexo'] != null)
            ? dadosId['sexo'].toString().trim().toLowerCase()
            : 'masculino';
        assetPath = sexoNorm.startsWith('f')
            ? 'assets/images/perineo_feminino.svg'
            : 'assets/images/perineo_masculino.svg';
      }
      if (view == 'face_dir') assetPath = 'assets/images/croqui-rosto-direito.svg';
      if (view == 'face_esq') assetPath = 'assets/images/croqui-rosto-frente.svg';

      String svgRaw = await rootBundle.loadString(assetPath);
      svgRaw = svgRaw
          .replaceAll(RegExp(r'xmlns:inkscape="[^"]*"'), '')
          .replaceAll(RegExp(r'xmlns:sodipodi="[^"]*"'), '');

      widgets.add(pw.Wrap(children: [
        pw.Container(margin: const pw.EdgeInsets.only(bottom: 20, left: 15), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text("VISTA: ${view.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Container(width: 318.0, height: 450.0, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)), child: pw.Stack(children: [
            pw.Positioned.fill(child: pw.SvgImage(svg: svgRaw, fit: pw.BoxFit.fill)),
            ...porFolha[view]!.where((a) {
              if (view == 'perineal') {
                final String? bodyPartId = a.dadosPreenchidos['local_anatomico_id']?.toString();
                if (bodyPartId == null) return false;
                final dadosId = caso.dadosLaudo['identificacao'];
                final String sexoNorm = (dadosId != null && dadosId['sexo'] != null)
                    ? dadosId['sexo'].toString().trim().toLowerCase()
                    : 'masculino';
                final bool isMale = !sexoNorm.startsWith('f');
                return bodyPartId.startsWith(isMale ? 'male_' : 'female_');
              }
              return true;
            }).map((a) {
              double left = (a.posX.isNaN ? 0.5 : a.posX) * 318.0;
              double top = (a.posY.isNaN ? 0.5 : a.posY) * 450.0;
              return pw.Positioned(left: left - 7, top: top - 7, child: pw.Container(width: 14, height: 14, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle), child: pw.Text(a.numeroSequencial.toString(), style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))));
            }),
          ])),
        ]))
      ]));
    }
    return widgets;
  }

  List<pw.Widget> _buildSecaoFotos(List<Map<String, dynamic>> lista) {
    return lista.map((foto) => pw.Wrap(children: [
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20, left: 15), 
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center, 
          children: [
            pw.Text(foto['label'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.Container(
              height: 400, 
              width: 350, 
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)), 
              child: pw.Image(pw.MemoryImage(foto['bytes']), fit: pw.BoxFit.contain),
            ),
        ])
      )
    ])).toList();
  }
}
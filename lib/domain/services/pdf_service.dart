import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

import 'pdf_constants.dart';
import 'pdf_helpers.dart';

class PdfService {
  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
  }) async {
    await initializeDateFormatting('pt_BR', null);
    final pdf = pw.Document();

    final fontRegular = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    final fontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    pw.MemoryImage? logoPolicia;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo/logo-policia-se.jpeg');
      logoPolicia = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      print("Erro ao carregar logo: $e");
    }

    final List<Achado> achadosExternos = achados.where((a) => !a.isInterno).toList();
    final List<Achado> achadosInternos = achados.where((a) => a.isInterno).toList();

    List<Map<String, dynamic>> anexosFotos = _prepararFotos(caso, achados);
    final croquisWidgets = await _gerarMapasSVG(achados);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: PdfConstants.marginDefault,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => PdfHelpers.buildDynamicHeader(context, logoPolicia, caso.numeroLaudoExterno),
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
            PdfHelpers.buildSectionTitle("3. EXAME EXTERNO (Visum et Repertum)"),
            ..._buildExameAgrupado(achadosExternos, anexosFotos, isInterno: false),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("4. EXAME INTERNO (Cavidades)"),
            ..._buildExameAgrupado(achadosInternos, anexosFotos, isInterno: true),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("5. EXAMES COMPLEMENTARES"),
            _buildDadosComplementares(caso),
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
    final cab = caso.dadosLaudo['cabecalho'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfHelpers.buildLinhaDetalhe("Laudo Pericial Cadavérico nº CD", caso.numeroLaudoExterno ?? 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Requisição:", cab['requisicao'] ?? 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Boletim de Ocorrência (B.O.):", cab['bo'] ?? 'XXX'), 
        PdfHelpers.buildLinhaDetalhe("PIC:", cab['pic'] ?? 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Requisitante: Delegado (a)", cab['requisitante'] ?? 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Destino:", cab['destino'] ?? 'XXX'),
        PdfHelpers.buildLinhaDetalhe("Nome da vítima:", cab['vitima'] ?? 'XXX', bold: true),
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
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("I) Vestes:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        PdfHelpers.buildParagrafoComRecuo(id['vestes']?.toString().isNotEmpty == true ? id['vestes'] : "XXX"),
        pw.SizedBox(height: 5),
        
        pw.Text("II) Características de identificação:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        PdfHelpers.buildParagrafoComRecuo(id['caracteristicas']?.toString().isNotEmpty == true ? id['caracteristicas'] : "Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos."),
        pw.SizedBox(height: 5),
        
        pw.Text("III) Dados tanatológicos:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("A morte está evidenciada pela presença dos seguintes sinais tanatológicos:", style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("A) IMEDIATOS: ", id['tanato_imediato']?.toString().isNotEmpty == true ? id['tanato_imediato'] : 'XXX'),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("B) CONSECUTIVOS: ", id['tanato_consecutivo']?.toString().isNotEmpty == true ? id['tanato_consecutivo'] : 'XXX'),
              pw.SizedBox(height: 3),
              PdfHelpers.buildItemComLabel("COMENTARIOS ADICIONAIS: ", id['tanato_observacao']?.toString().isNotEmpty == true ? id['tanato_observacao'] : 'XXX'),
            ]
          )
        )
      ],
    );
  }

 List<pw.Widget> _buildExameAgrupado(List<Achado> achados, List<Map<String, dynamic>> anexos, {required bool isInterno}) {
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
          final descTamanho = (a.tamanho != '-' && a.tamanho.isNotEmpty) ? " medindo ${a.tamanho}cm" : "";
          
          items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 30), child: pw.Bullet(text: "${a.dadosPreenchidos['type_label']} em ${a.dadosPreenchidos['local_anatomico_nome']}: ${a.observacoesTexto ?? ''}$refFoto", style: const pw.TextStyle(fontSize: 10))));
        }
      }
    });

    if (achadosPendentes.isNotEmpty) {
      items.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 10), child: pw.Text("OUTRAS REGIÕES NÃO MAPEADAS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))));
      items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Com evidências de lesões:", style: const pw.TextStyle(fontSize: 10))));
      
      for (var a in achadosPendentes) {
        final foto = anexos.cast<Map<String, dynamic>?>().firstWhere((f) => f != null && f['uuid'] == a.uuid, orElse: () => null);
        final refFoto = foto != null ? " [VER REGISTRO FOTOGRÁFICO ${foto['numero']}]" : "";
        
        items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 30), child: pw.Bullet(text: "${a.dadosPreenchidos['type_label']} em ${a.dadosPreenchidos['local_anatomico_nome']} (ID: ${a.dadosPreenchidos['local_anatomico_id']}): ${a.observacoesTexto ?? ''}$refFoto", style: const pw.TextStyle(fontSize: 10))));
      }
    }

    return items;
  }

  pw.Widget _buildDadosComplementares(Caso c) {
    final ex = c.dadosLaudo['exames_complementares'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, 
      children: [
        PdfHelpers.buildItemComLabel("Anátomo-Patológico: ", (ex['anatomo']?.toString().isNotEmpty == true) ? ex['anatomo'] : 'XXX'), 
        PdfHelpers.buildItemComLabel("Toxicológico: ", (ex['toxicologico']?.toString().isNotEmpty == true) ? ex['toxicologico'] : 'XXX'), 
        PdfHelpers.buildItemComLabel("Genética: ", (ex['genetica']?.toString().isNotEmpty == true) ? ex['genetica'] : 'XXX'), // CAMPO ADICIONADO
        PdfHelpers.buildItemComLabel("Outros: ", (ex['outros']?.toString().isNotEmpty == true) ? ex['outros'] : 'XXX')
      ]
    );
  }

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
        dataFinalizacaoStr = DateFormat('dd/MM/yyyy às HH:mm').format(dt);
      } catch (e) {
        dataFinalizacaoStr = "Confirmado (Data Indisponível)";
      }
    } else {
      dataFinalizacaoStr = "Confirmado no Sistema";
    }


  final dataExportacao = DateFormat('dd/MM/yyyy ÀS HH:mm:ss').format(dataAtual);

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
                "Este documento foi gerado pelo sistema Croqui Forense Digital e assinado eletronicamente por $nomeResponsavel. "
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
  
  List<Map<String, dynamic>> _prepararFotos(Caso caso, List<Achado> achados) {
    List<Map<String, dynamic>> anexos = [];
    int contador = 1;
    final fotosGerais = caso.dadosLaudo['identificacao']?['fotos_gerais'] ?? [];
    
    for (var fotoPath in fotosGerais) {
      final file = File(fotoPath.toString());
      if (file.existsSync()) {
        anexos.add({'numero': contador, 'file': file, 'label': 'Fotografia $contador - Identificação Geral'});
        contador++;
      }
    }
    for (var a in achados) {
      final path = a.dadosPreenchidos['photo_path'];
      if (path != null && path.toString().isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          anexos.add({'numero': contador, 'uuid': a.uuid, 'file': file, 'label': 'Fotografia $contador - Ref. Achado ${a.numeroSequencial} (${a.dadosPreenchidos['type_label']})'});
          contador++;
        }
      }
    }
    return anexos;
  }

  Future<List<pw.Widget>> _gerarMapasSVG(List<Achado> achados) async {
    if (achados.isEmpty) return [];
    Map<String, List<Achado>> porFolha = {};
    for (var a in achados) {
      String view = a.dadosPreenchidos['view'] ?? 'frente';
      porFolha.putIfAbsent(view, () => []).add(a);
    }
    List<pw.Widget> widgets = [];

    for (var view in porFolha.keys) {
      String assetPath = 'assets/images/croqui-frente.svg';
      if(view == 'costas') assetPath = 'assets/images/croqui-costas.svg';
      if(view == 'lateral_dir') assetPath = 'assets/images/croqui-rosto-direito.svg';
      if(view == 'lateral_esq') assetPath = 'assets/images/croqui-rosto-frente.svg';

      String svgRaw = await rootBundle.loadString(assetPath);
      svgRaw = svgRaw.replaceAll(RegExp(r'xmlns:inkscape=".*?"'), '').replaceAll(RegExp(r'xmlns:sodipodi=".*?"'), '');

      widgets.add(pw.Wrap(children: [
        pw.Container(margin: const pw.EdgeInsets.only(bottom: 20, left: 15), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text("VISTA: ${view.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Container(width: 318.0, height: 450.0, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)), child: pw.Stack(children: [
            pw.Positioned.fill(child: pw.SvgImage(svg: svgRaw, fit: pw.BoxFit.fill)),
            ...porFolha[view]!.map((a) {
              double left = (a.posX.isNaN ? 0.5 : a.posX) * 318.0;
              double top = (a.posY.isNaN ? 0.5 : a.posY) * 450.0;
              return pw.Positioned(left: left - 7, top: top - 7, child: pw.Container(width: 14, height: 14, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle), child: pw.Text(a.numeroSequencial.toString(), style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))));
            }).toList(),
          ])),
        ]))
      ]));
    }
    return widgets;
  }

  List<pw.Widget> _buildSecaoFotos(List<Map<String, dynamic>> lista) {
    return lista.map((foto) => pw.Wrap(children: [
      pw.Container(margin: const pw.EdgeInsets.only(bottom: 20, left: 15), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(foto['label'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Container(height: 400, width: 350, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)), child: pw.Image(pw.MemoryImage(foto['file'].readAsBytesSync()), fit: pw.BoxFit.contain)),
      ]))
    ])).toList();
  }
}
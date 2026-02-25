import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class PdfService {
  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required String nomePerito,
  }) async {
    final pdf = pw.Document();

    final fontRegular = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    final fontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // --- Processamento Unificado de Fotos (Anexo II) ---
    List<Map<String, dynamic>> anexosFotos = [];
    Map<String, int> mapaAnexosFotos = {};
    int anexoContador = 1;

    // 1. Puxar as fotos gerais de Identificação (CaseInfoTab)
    final identificacaoDados = caso.dadosLaudo['identificacao'] ?? {};
    final List<dynamic> fotosGerais = identificacaoDados['fotos_gerais'] ?? [];

    for (var fotoPath in fotosGerais) {
      if (fotoPath != null && fotoPath.toString().isNotEmpty) {
        final file = File(fotoPath.toString());
        if (file.existsSync()) {
          anexosFotos.add({
            'numero': anexoContador,
            'file': file,
            'label': 'Fotografia $anexoContador - Identificação Geral do Cadáver/Cena',
          });
          anexoContador++;
        }
      }
    }

    // 2. Puxar as fotos específicas de cada Achado/Lesão
    for (var achado in achados) {
      final path = achado.dadosPreenchidos['photo_path'];
      if (path != null && path.toString().isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          anexosFotos.add({
            'numero': anexoContador,
            'file': file,
            'label': 'Fotografia $anexoContador - Ref. Achado ${achado.numeroSequencial} (${achado.dadosPreenchidos['type_label']})',
          });
          mapaAnexosFotos[achado.uuid] = anexoContador;
          anexoContador++;
        }
      }
    }

    final croquisWidgets = await _gerarMapasSVG(achados);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
    );

    // PARTE I: TEXTO
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildCabecalhoOficial(),
        footer: (context) => _buildFooter(context, nomePerito, caso.numeroLaudoExterno),
        build: (context) => [
          _buildTituloLaudo(),
          pw.SizedBox(height: 20),
          _buildPreambulo(caso),
          pw.SizedBox(height: 20),
          ..._buildIdentificacao(caso),
          pw.SizedBox(height: 20),
          ..._buildExameExternoDescritivo(achados, mapaAnexosFotos),
          pw.SizedBox(height: 20),
          ..._buildExamesComplementares(caso),
          pw.SizedBox(height: 20),
          ..._buildDiscussaoEConclusao(caso),
          pw.SizedBox(height: 20),
          ..._buildQuesitos(caso),
          pw.SizedBox(height: 40),
          _buildEncerramento(nomePerito),
        ],
      ),
    );

    // PARTE II: MAPAS
    if (croquisWidgets.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          header: (context) => _buildCabecalhoOficial(),
          footer: (context) => _buildFooter(context, nomePerito, caso.numeroLaudoExterno),
          build: (context) => croquisWidgets,
        ),
      );
    }

    // PARTE III: FOTOS
    if (anexosFotos.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          header: (context) => _buildCabecalhoOficial(),
          footer: (context) => _buildFooter(context, nomePerito, caso.numeroLaudoExterno),
          build: (context) => _buildSecaoFotos(anexosFotos),
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildCabecalhoOficial() {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text("ESTADO DE SERGIPE", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("SECRETARIA DE ESTADO DA SEGURANÇA PÚBLICA", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("INSTITUTO MÉDICO LEGAL", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1.5),
        ],
      ),
    );
  }

  pw.Widget _buildTituloLaudo() {
    return pw.Center(
      child: pw.Text("LAUDO DE EXAME PERICIAL NECROSCÓPICO", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPreambulo(Caso caso) {
    final dados = caso.dadosLaudo;
    final cabecalho = dados['cabecalho'] ?? {};
    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(caso.criadoEmDispositivo.toLocal());
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildLinhaDetalhe("Laudo Nº:", caso.numeroLaudoExterno ?? 'Gerado pelo Sistema', bold: true),
          _buildLinhaDetalhe("Requisição Nº:", cabecalho['requisicao'] ?? 'Não informado'),
          _buildLinhaDetalhe("Autoridade Requisitante:", cabecalho['requisitante'] ?? 'Não informado'),
          _buildLinhaDetalhe("Destino:", cabecalho['destino'] ?? 'Não informado'),
          pw.Divider(color: PdfColors.grey300),
          _buildLinhaDetalhe("Vítima:", cabecalho['vitima'] ?? 'Não Identificado / Ignorado', bold: true),
          _buildLinhaDetalhe("Data do Exame:", dataFormatada),
        ],
      ),
    );
  }

  List<pw.Widget> _buildIdentificacao(Caso caso) {
    final identificacao = caso.dadosLaudo['identificacao'] ?? {};
    return [
      _buildSectionTitle("I. Histórico, Identificação e Exame de Vestes"),
      _buildParagrafoTexto("Vestes: ", identificacao['vestes']),
      _buildParagrafoTexto("Características Físicas: ", identificacao['caracteristicas']),
      _buildParagrafoTexto("Dados Tanatológicos: ", identificacao['dados_tanatologicos']),
    ];
  }

  List<pw.Widget> _buildExameExternoDescritivo(List<Achado> achados, Map<String, int> mapaAnexosFotos) {
    if (achados.isEmpty) {
      return [
        _buildSectionTitle("II. Exame Externo (Visum et Repertum)"),
        pw.Text("Sem achados ou lesões externas registradas.", style: const pw.TextStyle(fontSize: 10)),
      ];
    }

    return [
      _buildSectionTitle("II. Exame Externo (Visum et Repertum)"),
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text("(As localizações topográficas exatas encontram-se no Anexo I - Mapas Corporais)", 
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      ...achados.map((achado) => _buildBlocoAchado(achado, mapaAnexosFotos[achado.uuid])),
    ];
  }

  pw.Widget _buildBlocoAchado(Achado achado, int? numFoto) {
    final d = achado.dadosPreenchidos;
    final localNome = d['local_anatomico_nome'] ?? 'Região não especificada';
    final tipo = d['type_label'] ?? 'Lesão atípica';
    final tamanho = d['size']?.toString().isNotEmpty == true ? "${d['size']} cm" : "Não medido";
    final profundidade = d['depth']?.toString().isNotEmpty == true ? d['depth'] : "Não aferida";
    final descricao = achado.observacoesTexto?.isNotEmpty == true ? achado.observacoesTexto! : "Sem descrições adicionais.";
    
    final tagFoto = numFoto != null ? " (VER FOTOGRAFIA $numFoto NO ANEXO II)" : "";

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(left: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.blueGrey, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Achado ${achado.numeroSequencial}: $tipo em $localNome", 
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black)),
          pw.SizedBox(height: 2),
          pw.Text("Tamanho: $tamanho | Profundidade: $profundidade", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("Descrição: $descricao", style: const pw.TextStyle(fontSize: 10)),
          if (tagFoto.isNotEmpty) 
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(tagFoto, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildExamesComplementares(Caso caso) {
    final exames = caso.dadosLaudo['exames_complementares'] ?? {};
    return [
      _buildSectionTitle("III. Exames Complementares"),
      _buildParagrafoTexto("Anátomo-Patológico: ", exames['anatomo']),
      _buildParagrafoTexto("Toxicológico: ", exames['toxicologico']),
      _buildParagrafoTexto("Outros Exames: ", exames['outros']),
    ];
  }

  List<pw.Widget> _buildDiscussaoEConclusao(Caso caso) {
    final conclusao = caso.dadosLaudo['conclusao'] ?? {};
    return [
      _buildSectionTitle("IV. Discussão e Conclusão"),
      _buildParagrafoTexto("Discussão do Caso:\n", conclusao['discussao']),
      pw.SizedBox(height: 8),
      _buildParagrafoTexto("Conclusão Final:\n", conclusao['conclusao_texto'], boldConteudo: true),
    ];
  }

  List<pw.Widget> _buildQuesitos(Caso caso) {
    final conclusao = caso.dadosLaudo['conclusao'] ?? {};
    return [
      _buildSectionTitle("V. Respostas aos Quesitos"),
      _buildParagrafoTexto("1. Houve Morte? ", conclusao['quesito_1_morte']),
      _buildParagrafoTexto("2. Qual a Causa? ", conclusao['quesito_2_causa']),
      _buildParagrafoTexto("3. Qual o Instrumento? ", conclusao['quesito_3_instrumento']),
      _buildParagrafoTexto("4. Qual o Meio? ", conclusao['quesito_4_meio']),
    ];
  }

  Future<List<pw.Widget>> _gerarMapasSVG(List<Achado> achados) async {
    if (achados.isEmpty) return [];

    Map<String, List<Achado>> porFolha = {};
    for (var a in achados) {
      String view = a.dadosPreenchidos['view'] ?? 'frente';
      porFolha.putIfAbsent(view, () => []).add(a);
    }

    List<pw.Widget> widgets = [
      _buildSectionTitle("ANEXO I - MAPAS CORPORAIS (CROQUIS)"),
      pw.Text("Mapeamento topográfico das lesões descritas no Exame Externo.", style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 20),
    ];

    const double pdfMapHeight = 550.0;
    const double pdfMapWidth = 388.7;

    for (var view in porFolha.keys) {
      String assetPath = '';
      switch (view) {
        case 'frente': assetPath = 'assets/images/croqui-frente.svg'; break;
        case 'costas': assetPath = 'assets/images/croqui-costas.svg'; break;
        case 'lateral_dir': assetPath = 'assets/images/croqui-rosto-direito.svg'; break;
        case 'lateral_esq': assetPath = 'assets/images/croqui-rosto-frente.svg'; break; 
        default: assetPath = 'assets/images/croqui-frente.svg';
      }

      String svgRaw = '';
      try {
        svgRaw = await rootBundle.loadString(assetPath);
        svgRaw = svgRaw.replaceAll(RegExp(r'xmlns:inkscape=".*?"'), '');
        svgRaw = svgRaw.replaceAll(RegExp(r'xmlns:sodipodi=".*?"'), '');
      } catch (e) {
        continue;
      }

      if (svgRaw.isNotEmpty) {
        widgets.add(
          pw.Wrap(
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("VISTA: ${view.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: pdfMapWidth,
                      height: pdfMapHeight,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Stack(
                        children: [
                          pw.Positioned.fill(child: pw.SvgImage(svg: svgRaw, fit: pw.BoxFit.fill)),
                          ...porFolha[view]!.map((a) {
                            double safeX = (a.posX.isNaN || a.posX.isInfinite) ? 0.5 : a.posX;
                            double safeY = (a.posY.isNaN || a.posY.isInfinite) ? 0.5 : a.posY;
                            double left = safeX * pdfMapWidth;
                            double top = safeY * pdfMapHeight;
                            const double markerSize = 14.0;
                            return pw.Positioned(
                              left: left - (markerSize / 2),
                              top: top - (markerSize / 2),
                              child: pw.Container(
                                width: markerSize, 
                                height: markerSize,
                                alignment: pw.Alignment.center,
                                decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle),
                                child: pw.Text(a.numeroSequencial.toString(), 
                                    style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }
    return widgets;
  }

  List<pw.Widget> _buildSecaoFotos(List<Map<String, dynamic>> anexosFotos) {
    List<pw.Widget> widgets = [
      _buildSectionTitle("ANEXO II - FOTOGRAFIAS DAS LESÕES"),
      pw.SizedBox(height: 20),
    ];

    for (var foto in anexosFotos) {
      final image = pw.MemoryImage(foto['file'].readAsBytesSync());
      widgets.add(
        pw.Wrap(
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(foto['label'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    height: 500, 
                    width: 450,  
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                    child: pw.Image(image, fit: pw.BoxFit.contain), 
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return widgets;
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
    );
  }

  pw.Widget _buildLinhaDetalhe(String titulo, String valor, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 140, child: pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10))),
        ],
      ),
    );
  }

  pw.Widget _buildParagrafoTexto(String rotulo, String? conteudo, {bool boldConteudo = false}) {
    final texto = (conteudo == null || conteudo.trim().isEmpty) ? "Sem registro." : conteudo;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10),
          children: [
            pw.TextSpan(text: rotulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: texto, style: pw.TextStyle(fontWeight: boldConteudo ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildEncerramento(String nomePerito) {
    return pw.Wrap(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              "Nada mais havendo a lavrar, encerra-se o presente laudo, o qual segue assinado digitalmente e/ou fisicamente pelo perito relator.",
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 50),
            pw.Container(width: 250, child: pw.Divider(color: PdfColors.black, thickness: 1)),
            pw.Text(nomePerito, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text("Perito Oficial / Médico Legista", style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, String nomePerito, String? numLaudo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Laudo: ${numLaudo ?? 'N/A'} - Gerado por Croqui Forense", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }
}
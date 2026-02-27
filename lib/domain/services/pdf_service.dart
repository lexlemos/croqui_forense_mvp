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

class PdfService {
  final Map<String, List<String>> gruposCorpo = {
    'I) Crânio e Face': ['cabeca', 'face', 'cranio', 'olho', 'orelha', 'boca', 'rosto'],
    'II) Pescoço': ['pescoco', 'cervical', 'nuca'],
    'III) Membros': ['braco', 'antebraço', 'mao', 'coxa', 'perna', 'pe', 'ombro', 'cotovelo', 'pulso', 'joelho', 'tornozelo'],
    'IV) Tórax': ['torax', 'peito', 'costas_superior', 'esternal', 'mamaria'],
    'V) Abdome': ['abdome', 'barriga', 'lombar', 'pelvis', 'umbilical', 'flanco'],
  };

  final List<String> cavidades = [
    "I) Cavidade craniana:",
    "II) Pescoço:",
    "III) Membros:",
    "IV) Cavidade torácica:",
    "V) Cavidade abdominal:"
  ];

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

    List<Map<String, dynamic>> anexosFotos = [];
    int anexoContador = 1;
    Map<String, int> mapaAnexosFotos = {};

    final identificacaoDados = caso.dadosLaudo['identificacao'] ?? {};
    final List<dynamic> fotosGerais = identificacaoDados['fotos_gerais'] ?? [];
    for (var fotoPath in fotosGerais) {
      final file = File(fotoPath.toString());
      if (file.existsSync()) {
        anexosFotos.add({
          'numero': anexoContador,
          'file': file,
          'label': 'Fotografia $anexoContador - Identificação Geral',
        });
        anexoContador++;
      }
    }

    for (var a in achados) {
      final path = a.dadosPreenchidos['photo_path'];
      if (path != null && path.toString().isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          anexosFotos.add({
            'numero': anexoContador,
            'file': file,
            'label': 'Fotografia $anexoContador - Ref. Achado ${a.numeroSequencial} (${a.dadosPreenchidos['type_label']})',
          });
          mapaAnexosFotos[a.uuid] = anexoContador;
          anexoContador++;
        }
      }
    }

    final croquisWidgets = await _gerarMapasSVG(achados);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 50),

    );

    // --- MONTAGEM CONTÍNUA DO LAUDO ---
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildDynamicHeader(context, logoPolicia, caso.numeroLaudoExterno),
        footer: (context) => _buildInstitucionalFooter(context),
        build: (context) {
          return [
            _buildDadosIniciais(caso),
            pw.SizedBox(height: 20),
            _buildTextoAbertura(caso, perito),
            pw.SizedBox(height: 15),

            _buildSectionTitle("1. HISTÓRICO"),
            _buildParagrafoTexto("", caso.dadosLaudo['identificacao']?['historico'] ?? "Não informado."),
            pw.SizedBox(height: 15),

            _buildSectionTitle("2. IDENTIFICAÇÃO"),
            _buildIdentificacaoOficial(caso),
            pw.SizedBox(height: 15),

            _buildSectionTitle("3. EXAME EXTERNO (Visum et Repertum)"),
            ..._buildExameExternoAgrupado(achados, mapaAnexosFotos),
            pw.SizedBox(height: 15),

            _buildSectionTitle("4. EXAME INTERNO (Cavidades)"),
            ..._buildExameInternoAgrupado(),
            pw.SizedBox(height: 15),

            _buildSectionTitle("5. EXAMES COMPLEMENTARES"),
            _buildDadosComplementares(caso),
            pw.SizedBox(height: 15),

            // O CROQUI AGORA FLUI DE FORMA CONTÍNUA AQUI
            _buildSectionTitle("6. RASCUNHOS E ESQUEMAS DE LESÃO"),
            if (croquisWidgets.isEmpty)
              pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Sem rascunhos anexados.", style: const pw.TextStyle(fontSize: 10)))
            else
              ...croquisWidgets,
            pw.SizedBox(height: 15),

            // AS FOTOS AGORA FLUEM DE FORMA CONTÍNUA AQUI
            _buildSectionTitle("7. REGISTRO FOTOGRÁFICO"),
            if (anexosFotos.isEmpty)
              pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Sem fotografias anexadas.", style: const pw.TextStyle(fontSize: 10)))
            else
              ..._buildSecaoFotos(anexosFotos),
            pw.SizedBox(height: 15),

            _buildSectionTitle("8. COMENTÁRIO MÉDICO FORENSE"),
            _buildParagrafoTexto("", caso.dadosLaudo['conclusao']?['discussao'] ?? "Sem comentários."),
            pw.SizedBox(height: 15),

            _buildSectionTitle("9. CONCLUSÃO"),
            _buildParagrafoTexto("", caso.dadosLaudo['conclusao']?['conclusao_texto'] ?? "Sem conclusão final."),
            pw.SizedBox(height: 10),
            
            _buildTextoPaginas(context),
            pw.SizedBox(height: 15),

            _buildSectionTitle("10. RESPOSTA AOS QUESITOS"),
            _buildDadosQuesitosOficial(caso),
            pw.SizedBox(height: 40),

            pw.Align(alignment: pw.Alignment.center, child: _buildEncerramento(perito)),
          ];
        },
      ),
    );

    return pdf.save();
  }


  pw.Widget _buildDynamicHeader(pw.Context context, pw.MemoryImage? logo, String? numLaudo) {
    if (context.pageNumber == 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 15),
        child: pw.Column(children: [
          if (logo != null) pw.Center(child: pw.Image(logo, width: 60, height: 60)),
          pw.SizedBox(height: 5),
          pw.Text("ESTADO DE SERGIPE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("SECRETARIA DE ESTADO DA SEGURANÇA PÚBLICA", style: const pw.TextStyle(fontSize: 8)),
          pw.Text("COORDENADORIA GERAL DE PERÍCIAS", style: const pw.TextStyle(fontSize: 8)),
          pw.Text("INSTITUTO MÉDICO LEGAL", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 1),
        ]),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            if (logo != null) pw.Image(logo, width: 25, height: 25),
            pw.SizedBox(width: 8),
            pw.Text("Laboratório de Tanatologia Forense", style: const pw.TextStyle(fontSize: 8)),
          ]),
          pw.Text("Laudo Cadavérico nº CD ${numLaudo ?? 'XXXX'}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Divider(thickness: 0.5),
      ]),
    );
  }

  pw.Widget _buildInstitucionalFooter(pw.Context context) {
    return pw.Column(children: [
      pw.Divider(thickness: 0.5),
      pw.Text("INSTITUTO MÉDICO-LEGAL", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.Text("Rua da Frente, S/N, Povoado Tabocas, Nossa Senhora do Socorro/SE – CEP: 49160-000", style: const pw.TextStyle(fontSize: 6)),
      pw.Text("Fone: (79) 3205-0636 – e-mail: laudos.iml@policiatecnica.se.gov.br", style: const pw.TextStyle(fontSize: 6)),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: const pw.TextStyle(fontSize: 6))),
    ]);
  }

  pw.Widget _buildDadosIniciais(Caso caso) {
    final cab = caso.dadosLaudo['cabecalho'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildLinhaDetalhe("Laudo Pericial Cadavérico nº CD", caso.numeroLaudoExterno ?? 'XXX'),
        _buildLinhaDetalhe("Requisição: BO nº", cab['requisicao'] ?? 'XXX'), 
        _buildLinhaDetalhe("Requisitante: Delegado (a)", cab['requisitante'] ?? 'XXX'),
        _buildLinhaDetalhe("Destino:", cab['destino'] ?? 'XXX'),
        _buildLinhaDetalhe("Nome da vítima:", cab['vitima'] ?? 'XXX', bold: true),
        pw.SizedBox(height: 20),
        pw.Center(child: pw.Text("LAUDO CADAVÉRICO", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  pw.Widget _buildTextoAbertura(Caso caso, Usuario perito) {
    final data = caso.criadoEmDispositivo.toLocal();
    final dia = data.day.toString().padLeft(2, '0');
    
    const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
    final mesStr = meses[data.month - 1];
    final anoExtenso = "dois mil e vinte e seis"; 

    final texto = "No dia $dia do mês de $mesStr do ano de $anoExtenso, neste Instituto de Medicina Legal da Coordenadoria Geral de Perícias da Secretaria de Estado da Segurança Pública de Sergipe, em conformidade com a legislação e com os dispositivos regulamentares vigentes, foram designados, o Perito Médico-Legal Dr. ${perito.nomeCompleto} e os Agentes técnicos em Necropsia para procederem a exame pericial, a fim de atender ao ofício retro, descrevendo fielmente e com todas as circunstâncias o que encontrarem e, bem assim, esclarecerem tudo quanto interessar possa com relação ao exame solicitado.";
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 20),
      child: pw.Text(texto, textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _buildIdentificacaoOficial(Caso caso) {
    final id = caso.dadosLaudo['identificacao'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("I) Vestes:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text(id['vestes'] ?? "Despido no momento da necrópsia.", style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 5),
        
        pw.Text("II) Características de identificação:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text(id['caracteristicas'] ?? "Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.", style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 5),
        
        pw.Text("III) Dados tanatológicos:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("A morte está evidenciada pela presença dos seguintes sinais tanatológicos:", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 3),
              pw.Text("A) IMEDIATOS: ${id['tanato_imediato'] ?? 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 3),
              pw.Text("B) CONSECUTIVOS: ${id['tanato_consecutivo'] ?? 'XXX'}", style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 3),
              pw.Text("Não se observa a presença de sinais cadavéricos de transformação.", style: const pw.TextStyle(fontSize: 10)),
            ]
          )
        )
      ],
    );
  }

  List<pw.Widget> _buildExameExternoAgrupado(List<Achado> achados, Map<String, int> mapaFotos) {
    List<pw.Widget> items = [];
    gruposCorpo.forEach((grupo, chaves) {
      final achadosGrupo = achados.where((a) {
        final local = (a.dadosPreenchidos['local_anatomico_id'] ?? '').toString().toLowerCase();
        return chaves.any((c) => local.contains(c));
      }).toList();

      items.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text("$grupo:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))));
      
      if (achadosGrupo.isEmpty) {
        items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Sem evidências de lesões macroscópicas de natureza traumática.", style: const pw.TextStyle(fontSize: 10))));
      } else {
        items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("Com evidências de lesões macroscópicas:", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))));
        for (var a in achadosGrupo) {
          final numFoto = mapaFotos[a.uuid];
          final refFoto = numFoto != null ? " [VER REGISTRO FOTOGRÁFICO $numFoto]" : "";
          items.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 30), child: pw.Bullet(text: "${a.dadosPreenchidos['type_label']} em ${a.dadosPreenchidos['local_anatomico_nome']}: ${a.observacoesTexto ?? ''}$refFoto", style: const pw.TextStyle(fontSize: 10))));
        }
      }
    });
    return items;
  }

  List<pw.Widget> _buildExameInternoAgrupado() {
    return cavidades.map((c) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6), 
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(c, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Padding(padding: const pw.EdgeInsets.only(left: 15), child: pw.Text("XXX", style: const pw.TextStyle(fontSize: 10))),
        ]
      )
    )).toList();
  }

  pw.Widget _buildDadosComplementares(Caso c) {
    final ex = c.dadosLaudo['exames_complementares'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, 
      children: [
        _buildParagrafoTexto("Anátomo-Patológico: ", ex['anatomo'] ?? 'XXX'), 
        _buildParagrafoTexto("Toxicológico: ", ex['toxicologico'] ?? 'XXX'), 
        _buildParagrafoTexto("Outros: ", ex['outros'] ?? 'XXX')
      ]
    );
  }

  pw.Widget _buildDadosQuesitosOficial(Caso caso) {
    final q = caso.dadosLaudo['conclusao'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("I) Houve morte?", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("R: ${q['quesito_1_morte'] ?? 'XXX'}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("II) Qual a causa?", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("R: ${q['quesito_2_causa'] ?? 'XXX'}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("III) Qual o instrumento ou meio que a produziu?", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("R: ${q['quesito_3_instrumento'] ?? 'XXX'}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("IV) Foi produzida por meio de veneno, fogo, explosivo, asfixia ou meio insidioso cruel?", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("R: ${q['quesito_4_meio'] ?? 'XXX'}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]
    );
  }

  pw.Widget _buildTextoPaginas(pw.Context context) {
    final totalPaginas = context.pagesCount;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 20),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10),
          children: [
            const pw.TextSpan(text: "Nada mais havendo a lavrar, encerra-se o presente Laudo Pericial que segue em formato digital, devidamente assinado, composto por "),
            pw.TextSpan(
              text: "$totalPaginas", 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            const pw.TextSpan(text: " páginas."),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildEncerramento(Usuario perito) {
    final data = DateTime.now();
    const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
    final mesStr = meses[data.month - 1];

    return pw.Wrap(children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text("Nossa Senhora do Socorro, ${data.day.toString().padLeft(2, '0')} de $mesStr de ${data.year}", style: const pw.TextStyle(fontSize: 10))
        ),
        pw.SizedBox(height: 50),
        pw.Container(width: 250, child: pw.Divider(color: PdfColors.black, thickness: 1)),
        pw.Text("Dr. ${perito.nomeCompleto}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text("Médico Legista", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("CRM ${perito.crm}", style: const pw.TextStyle(fontSize: 10)),
        pw.Text("Perito Médico Legal Classe ${perito.classe}", style: const pw.TextStyle(fontSize: 10)),
      ]),
    ]);
  }

  // --- ANEXOS NO FLUXO CONTÍNUO ---

  Future<List<pw.Widget>> _gerarMapasSVG(List<Achado> achados) async {
    if (achados.isEmpty) return [];
    Map<String, List<Achado>> porFolha = {};
    for (var a in achados) {
      String view = a.dadosPreenchidos['view'] ?? 'frente';
      porFolha.putIfAbsent(view, () => []).add(a);
    }
    List<pw.Widget> widgets = [];
    const double pdfMapHeight = 450.0;
    const double pdfMapWidth = 318.0;

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
          pw.Container(width: pdfMapWidth, height: pdfMapHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)), child: pw.Stack(children: [
            pw.Positioned.fill(child: pw.SvgImage(svg: svgRaw, fit: pw.BoxFit.fill)),
            ...porFolha[view]!.map((a) {
              double left = (a.posX.isNaN ? 0.5 : a.posX) * pdfMapWidth;
              double top = (a.posY.isNaN ? 0.5 : a.posY) * pdfMapHeight;
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

  // --- AUXILIARES GENÉRICOS ---
  pw.Widget _buildSectionTitle(String title) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4, top: 12), child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
  pw.Widget _buildLinhaDetalhe(String t, String v, {bool bold = false}) => pw.Row(children: [pw.SizedBox(width: 170, child: pw.Text(t, style: const pw.TextStyle(fontSize: 10))), pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10)))]);
  pw.Widget _buildParagrafoTexto(String r, String c) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4, left: 15), child: pw.RichText(textAlign: pw.TextAlign.justify, text: pw.TextSpan(style: const pw.TextStyle(fontSize: 10), children: [pw.TextSpan(text: r, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.TextSpan(text: c)])));
}
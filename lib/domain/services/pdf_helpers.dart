import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfHelpers {
  
  static pw.Widget buildParagrafoComRecuo(String texto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        "          $texto",
        textAlign: pw.TextAlign.justify,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  static pw.Widget buildItemComLabel(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10),
          children: [
            pw.TextSpan(text: label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: valor),
          ]
        )
      )
    );
  }

  static pw.Widget buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, top: 12), 
      child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))
    );
  }

  static pw.Widget buildLinhaDetalhe(String t, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 170, child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))), 
        pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10)))
      ])
    );
  }

  static pw.Widget buildDynamicHeader(pw.Context context, pw.MemoryImage? logo, String? numLaudo) {
    if (context.pageNumber == 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 15),
        child: pw.Column(children: [
          if (logo != null) pw.Center(child: pw.Image(logo, width: 60, height: 60)),
          pw.SizedBox(height: 5),
          pw.Text("GOVERNO DO ESTADO DE SERGIPE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("SECRETARIA DE ESTADO DA SEGURANÇA PÚBLICA DE SERGIPE", style: const pw.TextStyle(fontSize: 8)),
          pw.Text("COORDENADORIA GERAL DE PERÍCIAS", style: const pw.TextStyle(fontSize: 8)),
          pw.Text("INSTITUTO MÉDICO LEGAL", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
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

  static pw.Widget buildInstitucionalFooter(pw.Context context) {
    return pw.Column(children: [
      pw.Divider(thickness: 0.5),
      pw.Text("INSTITUTO MÉDICO-LEGAL", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.Text("Rua da Frente, S/N, Povoado Tabocas, Nossa Senhora do Socorro/SE – CEP: 49160-000", style: const pw.TextStyle(fontSize: 6)),
      pw.Text("Fone: (79) 3205-0636 – e-mail: laudos.iml@policiatecnica.se.gov.br", style: const pw.TextStyle(fontSize: 6)),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: const pw.TextStyle(fontSize: 6))),
    ]);
  }

  static String anoPorExtenso(int ano) {
    if (ano < 2000 || ano > 2099) return ano.toString();
    final unidades = ["", "um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove"];
    final dezenas = ["", "dez", "vinte", "trinta", "quarenta", "cinquenta", "sessenta", "setenta", "oitenta", "noventa"];
    final especiais = ["dez", "onze", "doze", "treze", "quatorze", "quinze", "dezesseis", "dezessete", "dezoito", "dezenove"];

    String extenso = "dois mil";
    int dezena = (ano % 100) ~/ 10;
    int unidade = ano % 10;

    if (dezena == 0 && unidade == 0) return extenso;
    extenso += " e ";

    if (dezena == 1) {
      extenso += especiais[unidade];
    } else {
      if (dezena > 1) {
        extenso += dezenas[dezena];
        if (unidade > 0) extenso += " e ${unidades[unidade]}";
      } else if (unidade > 0) {
        extenso += unidades[unidade];
      }
    }
    return extenso;
  }
}
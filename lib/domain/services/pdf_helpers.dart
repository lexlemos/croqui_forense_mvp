import 'package:pdf/widgets.dart' as pw;

/// Funções auxiliares para a "Padronização Visual e Tipográfica Oficial do IML".
///
/// Este arquivo disponibiliza construtores de widgets e conversores utilitários que asseguram que o
/// laudo físico gerado em PDF apresente o layout, fontes, espaçamentos e cabeçalhos oficiais
/// regulamentados, atendendo às formalidades exigidas para relatórios forenses criminais e cíveis.
class PdfHelpers {
  
  /// Constrói um parágrafo justificado contendo o recuo regulamentar inicial na primeira linha.
  ///
  /// Garante a padronização e o rigor visual exigido para o corpo de texto descritivo dos laudos.
  ///
  /// Parâmetros:
  /// - [texto]: O conteúdo textual a ser exibido no parágrafo.
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

  /// Constrói um item de texto justificado com o rótulo (label) em negrito e o valor em estilo regular.
  ///
  /// Ideal para a exibição de características de identificação ou dados estruturados (chave-valor).
  ///
  /// Parâmetros:
  /// - [label]: O rótulo explicativo da informação.
  /// - [valor]: O dado/valor correspondente.
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

  /// Gera um widget de título estilizado para a demarcação das seções oficiais do laudo pericial.
  ///
  /// Aplica a formatação em negrito e o tamanho de fonte padronizado para títulos.
  ///
  /// Parâmetros:
  /// - [title]: O texto identificador da seção (ex: "1. HISTÓRICO").
  static pw.Widget buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, top: 12), 
      child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))
    );
  }

  /// Renderiza uma linha horizontal de dados administrativos do laudo.
  ///
  /// Exibe um rótulo alinhado à esquerda com tamanho fixo e o seu respectivo valor ao lado,
  /// organizando as informações do cabeçalho ou dados cadastrais.
  ///
  /// Parâmetros:
  /// - [t]: O título/rótulo do detalhe.
  /// - [v]: O valor correspondente a ser exibido.
  /// - [bold]: Flag para destacar o valor em negrito, padrão falso.
  static pw.Widget buildLinhaDetalhe(String t, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 170, child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))), 
        pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10)))
      ])
    );
  }

  /// Cria o cabeçalho oficial dinâmico do documento para impressão.
  ///
  /// Na primeira página, renderiza o brasão e as informações governamentais e institucionais completas
  /// da Coordenadoria Geral de Perícias e do Instituto Médico Legal de Sergipe. Nas páginas seguintes,
  /// exibe uma versão compactada contendo o logotipo e o número do laudo pericial oficial para fins
  /// de rastreabilidade.
  ///
  /// Parâmetros:
  /// - [context]: O contexto de renderização do documento PDF.
  /// - [logo]: A imagem em memória contendo o brasão/logo da corporação.
  /// - [numLaudo]: O número de registro oficial do laudo pericial.
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
          pw.Text("INSTITUTO MÉDICO-LEGAL", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
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

  /// Constrói o rodapé padrão com dados de contato institucionais do IML de Sergipe.
  ///
  /// Inclui o endereço oficial, telefones, e-mail de contato do setor de laudos e a paginação dinâmica
  /// no formato "Página X de Y" para controle de integridade de páginas do laudo impresso.
  ///
  /// Parâmetros:
  /// - [context]: O contexto de renderização do documento PDF.
  static pw.Widget buildInstitucionalFooter(pw.Context context) {
    return pw.Column(children: [
      pw.Divider(thickness: 0.5),
      pw.Text("INSTITUTO MÉDICO-LEGAL", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.Text("Rua da Frente, S/N, Povoado Tabocas, Nossa Senhora do Socorro/SE – CEP: 49160-000", style: const pw.TextStyle(fontSize: 6)),
      pw.Text("Fone: (79) 3205-0636 – e-mail: laudos.iml@policiatecnica.se.gov.br", style: const pw.TextStyle(fontSize: 6)),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Página ${context.pageNumber} de ${context.pagesCount}", style: const pw.TextStyle(fontSize: 6))),
    ]);
  }

  /// Converte um número correspondente a um ano no intervalo entre 2000 e 2099 para sua representação textual por extenso em português.
  ///
  /// Utilizado para a redação formal de abertura do laudo pericial no IML (ex: "dois mil e vinte e seis").
  /// Caso o ano esteja fora da faixa suportada, retorna a representação numérica padrão convertida em String.
  ///
  /// Parâmetros:
  /// - [ano]: O ano a ser convertido por extenso.
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
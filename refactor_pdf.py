# -*- coding: utf-8 -*-
import re

with open('lib/domain/services/pdf_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 3. Replace gerarLaudoPdf entirely.
old_gerar = '''  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    Map<String, dynamic>? schemas,
    required List<ExameSolicitado> exames,
    List<em.ExameSolicitadoModel>? examesModel,
    required List<EvidenciaMultimidia> evidenciasGerais,
  }) async {'''

new_gerar = '''  Future<Uint8List> gerarLaudoPdf({
    required Caso caso,
    required List<Achado> achados,
    required Usuario perito,
    Map<String, dynamic>? schemas,
    required List<ExameSolicitado> exames,
    List<em.ExameSolicitadoModel>? examesModel,
    required List<EvidenciaMultimidia> evidenciasGerais,
  }) async {
    _cachedFontRegularFuture ??= rootBundle.load("assets/fonts/Roboto-Regular.ttf").then((data) => data.buffer.asUint8List());
    _cachedFontBoldFuture ??= rootBundle.load("assets/fonts/Roboto-Bold.ttf").then((data) => data.buffer.asUint8List());
    _cachedLogoPoliciaFuture ??= rootBundle.load('assets/images/logo/logo-policia-se.jpeg').then<Uint8List?>((data) => data.buffer.asUint8List()).catchError((e) {
      debugPrint("Erro ao carregar logo: \\\");
      return null;
    });

    final fontRegularBytes = await _cachedFontRegularFuture!;
    final fontBoldBytes = await _cachedFontBoldFuture!;
    final logoPoliciaBytes = await _cachedLogoPoliciaFuture;

    final Map<String, String> svgStrings = await _carregarSvgs(achados, caso);

    final payload = PdfIsolatePayload(
      caso: caso,
      achados: achados,
      perito: perito,
      schemas: schemas,
      exames: exames,
      examesModel: examesModel,
      evidenciasGerais: evidenciasGerais,
      fontRegularBytes: fontRegularBytes,
      fontBoldBytes: fontBoldBytes,
      logoPoliciaBytes: logoPoliciaBytes,
      svgStrings: svgStrings,
    );

    return await compute(_gerarLaudoPdfIsolate, payload);
  }

  Future<Map<String, String>> _carregarSvgs(List<Achado> achados, Caso caso) async {
    final Map<String, String> result = {};
    final activeAchados = achados.where((a) => !a.removido).toList();
    for (var a in activeAchados) {
      String view = a.dadosPreenchidos['view'] ?? 'frente';
      if (!result.containsKey(view)) {
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
        result[view] = svgRaw;
      }
    }
    return result;
  }

  static Future<Uint8List> _gerarLaudoPdfIsolate(PdfIsolatePayload payload) async {
    final pdf = pw.Document();

    final fontRegular = pw.Font.ttf(payload.fontRegularBytes.buffer.asByteData());
    final fontBold = pw.Font.ttf(payload.fontBoldBytes.buffer.asByteData());
    final logoPolicia = payload.logoPoliciaBytes != null ? pw.MemoryImage(payload.logoPoliciaBytes!) : null;

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final List<Achado> achadosExternos = payload.achados.where((a) => !a.isInterno).toList();
    final List<Achado> achadosInternos = payload.achados.where((a) => a.isInterno).toList();

    final service = PdfService();

    List<Map<String, dynamic>> anexosFotos = await service._prepararFotos(payload.caso, payload.achados, payload.evidenciasGerais);
    final croquisWidgets = service._gerarMapasSVGSincrono(payload.achados, payload.caso, payload.svgStrings);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: PdfConstants.marginDefault,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => PdfHelpers.buildDynamicHeader(context, logoPolicia, payload.caso.numeroRequisicao.isNotEmpty ? payload.caso.numeroRequisicao : payload.caso.numeroLaudoExterno),
        footer: (context) => PdfHelpers.buildInstitucionalFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            service._buildDadosIniciais(payload.caso),
            pw.SizedBox(height: 20),
            service._buildTextoAbertura(payload.caso, payload.perito),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("1. HISTÓRICO"),
            PdfHelpers.buildParagrafoComRecuo(payload.caso.dadosLaudo['identificacao']?['historico'] ?? "XXX"),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("2. IDENTIFICAÇÃO"),
            service._buildIdentificacaoOficial(payload.caso),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("3. EXAME EXTERNO"),
            ...service._buildExameAgrupado(achadosExternos, anexosFotos, isInterno: false, schemas: payload.schemas, todosAchados: payload.achados),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("4. EXAME INTERNO (Cavidades)"),
            ...service._buildExameAgrupado(achadosInternos, anexosFotos, isInterno: true, schemas: payload.schemas, todosAchados: payload.achados),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("5. EXAMES COMPLEMENTARES"),
            service._buildDadosComplementares(payload.exames, examesModel: payload.examesModel),
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
              ...service._buildSecaoFotos(anexosFotos),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("8. COMENTÁRIO MÉDICO FORENSE"),
            PdfHelpers.buildParagrafoComRecuo((payload.caso.dadosLaudo['conclusao']?['discussao']?.toString().isNotEmpty == true) ? payload.caso.dadosLaudo['conclusao']!['discussao'] : "XXX"),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("9. CONCLUSÃO"),
            PdfHelpers.buildParagrafoComRecuo((payload.caso.dadosLaudo['conclusao']?['conclusao_texto']?.toString().isNotEmpty == true) ? payload.caso.dadosLaudo['conclusao']!['conclusao_texto'] : "XXX"),
            pw.SizedBox(height: 10),
            PdfHelpers.buildParagrafoComRecuo(PdfConstants.encerramentoPadrao),
            pw.SizedBox(height: 15),
            PdfHelpers.buildSectionTitle("10. RESPOSTA AOS QUESITOS"),
            service._buildDadosQuesitosOficial(payload.caso),
            pw.SizedBox(height: 40),
            pw.Align(alignment: pw.Alignment.center, child: service._buildEncerramento(payload.caso, payload.perito)),
          ];
        },
      ),
    );

    return pdf.save();
  }
'''

start_idx = content.find(old_gerar)
end_idx = content.find('  pw.Widget _buildDadosIniciais(Caso caso) {')

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_gerar + "\n" + content[end_idx:]

# 4. _gerarMapasSVG -> _gerarMapasSVGSincrono
old_gerar_mapas = 'Future<List<pw.Widget>> _gerarMapasSVG(List<Achado> achados, Caso caso) async {'
new_gerar_mapas = 'List<pw.Widget> _gerarMapasSVGSincrono(List<Achado> achados, Caso caso, Map<String, String> svgStrings) {'
content = content.replace(old_gerar_mapas, new_gerar_mapas)

# inside _gerarMapasSVGSincrono, remove rootBundle.loadString and use svgStrings
pattern = r"String assetPath = 'assets/images/croqui-frente\.svg';.*?String svgRaw = await rootBundle\.loadString\(assetPath\);\s*svgRaw = svgRaw\s*\.replaceAll\(RegExp\(r'xmlns:inkscape=\"\[\^\"\]\*\"'\), ''\)\s*\.replaceAll\(RegExp\(r'xmlns:sodipodi=\"\[\^\"\]\*\"'\), ''\);"
replacement = r"String svgRaw = svgStrings[view] ?? '';\n      if (svgRaw.isEmpty) continue;"
content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# 5. Add _comprimirBytesIterativamente
new_comprimir = '''
  Future<Uint8List> _comprimirBytesIterativamente(File file) async {
    final rawBytes = await file.readAsBytes();
    if (rawBytes.lengthInBytes < 500 * 1024) return rawBytes; // Já é pequeno (500KB)

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    if (decoded.width <= 1200 && decoded.height <= 1200) return rawBytes;

    final resized = img.copyResize(decoded, width: 1200, maintainAspect: true);
    final compressedBytes = img.encodeJpg(resized, quality: 70);
    return Uint8List.fromList(compressedBytes);
  }
'''
content = content.replace("  Future<List<Map<String, dynamic>>> _prepararFotos", new_comprimir + "\n  Future<List<Map<String, dynamic>>> _prepararFotos")
content = content.replace("final Uint8List bytes = existe ? await file.readAsBytes() : _fallbackImageBytes;", "final Uint8List bytes = existe ? await _comprimirBytesIterativamente(file) : _fallbackImageBytes;")

# 6. Add PdfIsolatePayload class
payload_class = '''
class PdfIsolatePayload {
  final Caso caso;
  final List<Achado> achados;
  final Usuario perito;
  final Map<String, dynamic>? schemas;
  final List<ExameSolicitado> exames;
  final List<em.ExameSolicitadoModel>? examesModel;
  final List<EvidenciaMultimidia> evidenciasGerais;

  final Uint8List fontRegularBytes;
  final Uint8List fontBoldBytes;
  final Uint8List? logoPoliciaBytes;
  final Map<String, String> svgStrings;

  PdfIsolatePayload({
    required this.caso,
    required this.achados,
    required this.perito,
    this.schemas,
    required this.exames,
    this.examesModel,
    required this.evidenciasGerais,
    required this.fontRegularBytes,
    required this.fontBoldBytes,
    this.logoPoliciaBytes,
    required this.svgStrings,
  });
}
'''
content += payload_class

with open('lib/domain/services/pdf_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")

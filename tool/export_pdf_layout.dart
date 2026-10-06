// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:croqui_forense_mvp/domain/services/pdf_constants.dart';

/// Exporta o mapa de agrupamento anatômico do laudo para JSON.
///
/// O sistema web precisa das mesmas listas de `local_anatomico_id` que o motor de PDF
/// usa para distribuir os achados entre os grupos das seções "3. EXAME EXTERNO" e
/// "4. EXAME INTERNO (Cavidades)". Redigitar essas listas duplicaria a fonte da verdade
/// e abriria espaço para divergência silenciosa; este gerador publica o conteúdo de
/// [PdfConstants.mapeamentoAnatomico] e [PdfConstants.titulosInternos] em um arquivo
/// que o front-end consome direto.
///
/// Uso:
/// ```
/// dart run tool/export_pdf_layout.dart > docs/handoff/mapeamento-anatomico.json
/// ```
///
/// Escreve o JSON em `stdout`; o redirecionamento é do shell.
void main() {
  final payload = <String, dynamic>{
    '_fonte':
        'lib/domain/services/pdf_constants.dart — '
        'PdfConstants.mapeamentoAnatomico / PdfConstants.titulosInternos',
    '_gerar_com': 'dart run tool/export_pdf_layout.dart',
    '_nota':
        'A ordem de gruposExternos é a ordem de impressão das seções. '
        'Um achado pertence ao primeiro grupo cuja lista contenha o seu '
        'local_anatomico_id (normalizado: trim + lowercase); sobras vão para '
        'o bloco "OUTRAS REGIÕES NÃO MAPEADAS".',
    'gruposExternos': [
      for (final grupo in PdfConstants.mapeamentoAnatomico.entries)
        {
          'titulo': grupo.key,
          'tituloInterno': PdfConstants.titulosInternos[grupo.key] ?? grupo.key,
          'idsLocaisAnatomicos': grupo.value,
        },
    ],
  };

  print(const JsonEncoder.withIndent('  ').convert(payload));
}

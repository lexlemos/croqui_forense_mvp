class DiagramTemplates {
  DiagramTemplates._();

  static const String frente = 'tpl_corpo_frente';
  static const String costas = 'tpl_corpo_costas';
  static const String lateralDireito = 'tpl_corpo_lateral_dir';
  static const String lateralEsquerdo = 'tpl_corpo_lateral_esq';
  static const String troncoDireito = 'tpl_corpo_tronco_dir';
  static const String troncoEsquerdo = 'tpl_corpo_tronco_esq';
  static const String perineal = 'tpl_corpo_perineal';
  static const String rostoDireito = 'tpl_rosto_direito';
  static const String rostoEsquerdo = 'tpl_rosto_esquerdo';

  static const List<String> todos = [
    frente,
    costas,
    lateralDireito,
    lateralEsquerdo,
    troncoDireito,
    troncoEsquerdo,
    perineal,
    rostoDireito,
    rostoEsquerdo,
  ];

  static const Map<String, String> viewToTemplateId = {
    'frente': frente,
    'front': frente,
    'costas': costas,
    'back': costas,
    'lateral_dir': lateralDireito,
    'lateral_esq': lateralEsquerdo,
    'trunk_dir': troncoDireito,
    'trunk_esq': troncoEsquerdo,
    'perineal': perineal,
    'face_dir': rostoDireito,
    'face_esq': rostoEsquerdo,
  };

  static String templateIdParaView(String view) {
    return viewToTemplateId[view] ?? frente;
  }
}

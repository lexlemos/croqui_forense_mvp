class DiagramTemplates {
  DiagramTemplates._();

  static const String frente = 'tpl_corpo_frente';
  static const String costas = 'tpl_corpo_costas';
  static const String lateralDireito = 'tpl_corpo_lateral_dir';
  static const String lateralEsquerdo = 'tpl_corpo_lateral_esq';

  static const List<String> todos = [
    frente,
    costas,
    lateralDireito,
    lateralEsquerdo,
  ];

  static const Map<String, String> viewToTemplateId = {
    'frente': frente,
    'costas': costas,
    'lateral_dir': lateralDireito,
    'lateral_esq': lateralEsquerdo,
  };

  static String templateIdParaView(String view) {
    return viewToTemplateId[view] ?? frente;
  }
}

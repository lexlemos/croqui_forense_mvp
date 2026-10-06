// ignore_for_file: constant_identifier_names

/// Representa os estados possíveis de conferência física e aceite de custódia
/// de amostras biológicas e vestígios balísticos pelo Auxiliar Técnico de Necrópsia (ATN).
///
/// Este enum reflete o fluxo de conferência de cadeia de custódia no backend (API).
enum StatusConfirmacaoATN {
  /// O item foi solicitado pelo perito e aguarda conferência e aceite pelo ATN.
  PENDENTE,

  /// O ATN visualizou a requisição no aplicativo, mas ainda não validou ou recusou formalmente.
  VISUALIZADO,

  /// O ATN conferiu fisicamente o lacre/amostra e confirmou o recebimento da custódia.
  CONFIRMADO,

  /// O ATN recusou o recebimento do vestígio/amostra por inconformidade (ex: lacre violado, frasco danificado),
  /// registrando uma justificativa textual obrigatória.
  RECUSADO;

  /// Converte uma string bruta (vinda da API ou SQLite) no respectivo [StatusConfirmacaoATN].
  ///
  /// Retorna [StatusConfirmacaoATN.PENDENTE] como valor padrão defensivo caso a string seja nula ou não reconhecida.
  static StatusConfirmacaoATN fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return StatusConfirmacaoATN.PENDENTE;
    }
    final norm = value.trim().toUpperCase();
    for (final v in StatusConfirmacaoATN.values) {
      if (v.name.toUpperCase() == norm) {
        return v;
      }
    }
    return StatusConfirmacaoATN.PENDENTE;
  }

  /// Converte o enum no formato de texto em maiúsculas esperado pelo backend.
  String toBackendString() => name;
}


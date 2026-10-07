/// Utilitários para formatação e sanitização de protocolos e requisições (CD).
library protocol_formatter;

/// Formata o número da requisição / CD para exibição com a barra (ex: `1234/2026`).
///
/// Caso a string já contenha `/`, ela é retornada como está (sem duplicar).
/// Caso possua mais de 4 dígitos, os últimos 4 dígitos são considerados o ano,
/// sendo separados por `/` (ex: `12342026` -> `1234/2026`, `122026` -> `12/2026`).
String formatarRequisicao(String? valor) {
  if (valor == null) return '';
  final limpo = valor.trim();
  if (limpo.isEmpty) return '';
  if (limpo.contains('/')) return limpo;

  final digitos = limpo.replaceAll(RegExp(r'\D'), '');
  if (digitos.length > 4) {
    final prefixo = digitos.substring(0, digitos.length - 4);
    final ano = digitos.substring(digitos.length - 4);
    return '$prefixo/$ano';
  }
  return limpo;
}

/// Sanitiza o número da requisição para persistência no banco de dados e envio à API,
/// removendo barras e espaços desnecessários.
///
/// Exemplo: `1234/2026` -> `12342026`.
String sanitizarRequisicao(String? valor) {
  if (valor == null) return '';
  return valor.replaceAll('/', '').trim();
}

/// Converte datas no formato ISO (`YYYY-MM-DD`) para o formato brasileiro (`DD/MM/YYYY`).
/// Caso já esteja no padrão ou não tenha formato reconhecido, retorna o valor original.
String formatarDataBr(String? data) {
  if (data == null || data.trim().isEmpty) return '';
  final limpo = data.trim();
  if (limpo.contains('-')) {
    final parts = limpo.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
    }
  }
  return limpo;
}

/// Converte horários (`HH:MM:SS` ou `HH:MM`) para o formato `HH:MM`.
String formatarHoraBr(String? hora) {
  if (hora == null || hora.trim().isEmpty) return '';
  final limpo = hora.trim();
  final parts = limpo.split(':');
  if (parts.length >= 2) {
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
  return limpo;
}

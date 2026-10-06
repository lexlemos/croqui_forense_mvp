import 'package:croqui_forense_mvp/core/utils/json_utils.dart';

/// Manipula os dados estruturados do laudo pericial sem reescrever texto livre autoral do perito.
///
/// Utilitário para ajuste e leitura canônica de campos cadastrais (como sexo biológico do examinado),
/// preservando a integridade das descrições digitadas manualmente.
class LaudoParserService {
  /// Altera o sexo biológico do examinado na estrutura de dados do laudo pericial.
  ///
  /// Atualiza o campo estruturado na identificação e sugere a descrição padrão nas características
  /// caso o campo esteja vazio ou contenha placeholders não preenchidos (`XXX`).
  ///
  /// Parâmetros:
  /// - [dadosLaudo]: Mapa com a estrutura do laudo pericial.
  /// - [novoSexo]: Novo valor a ser atribuído (ex: 'Masculino', 'Feminino').
  Map<String, dynamic> alterarSexoExaminado({
    required Map<String, dynamic> dadosLaudo,
    required String novoSexo,
  }) {
    final novosDados = deepCopyMap(dadosLaudo);
    final identificacao = _mapOrEmpty(novosDados['identificacao']);
    identificacao['sexo'] = novoSexo;
    novosDados['identificacao'] = identificacao;

    // A característica textual é autoria manual. Não a reescrevemos por RegEx.
    // O valor estruturado acima passa a ser a fonte oficial para novas leituras.
    final caracteristicas = _mapOrEmpty(novosDados['caracteristicas']);
    if ((caracteristicas['identificacao']?.toString().trim().isEmpty ?? true) ||
        caracteristicas['identificacao']?.toString().toLowerCase().contains(
              'sexo xxx',
            ) ==
            true) {
      caracteristicas['identificacao'] =
          'Cadáver do sexo ${novoSexo.toLowerCase()}, raça XXX, estado nutricional XXX, e idade aparente de XX anos.';
    }
    caracteristicas['sexo'] = novoSexo;
    novosDados['caracteristicas'] = caracteristicas;
    return novosDados;
  }

  /// Recupera o sexo biológico normalizado do examinado a partir da estrutura do laudo.
  ///
  /// Avalia primeiro o nó de identificação e, em caso de ausência, recorre às características gerais.
  ///
  /// Parâmetros:
  /// - [dadosLaudo]: Mapa com os dados do laudo pericial.
  ///
  /// Retorna `'Feminino'`, `'Masculino'` ou `'Indeterminado'`.
  String obterSexoExaminado(Map<String, dynamic> dadosLaudo) {
    final identificacao = _mapOrEmpty(dadosLaudo['identificacao']);
    final sexo = identificacao['sexo']?.toString().trim().toLowerCase();
    if (sexo == 'feminino' || sexo == 'f') {
      return 'Feminino';
    }
    if (sexo == 'masculino' || sexo == 'm') {
      return 'Masculino';
    }

    final caracteristicas = _mapOrEmpty(dadosLaudo['caracteristicas']);
    final sexoEstruturado = caracteristicas['sexo']
        ?.toString()
        .trim()
        .toLowerCase();
    if (sexoEstruturado == 'feminino' || sexoEstruturado == 'f') {
      return 'Feminino';
    }
    if (sexoEstruturado == 'masculino' || sexoEstruturado == 'm') {
      return 'Masculino';
    }
    return 'Indeterminado';
  }

  Map<String, dynamic> _mapOrEmpty(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}


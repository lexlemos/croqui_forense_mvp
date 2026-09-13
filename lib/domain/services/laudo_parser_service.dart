import 'package:croqui_forense_mvp/core/utils/json_utils.dart';

/// Manipula os dados estruturados do laudo sem reescrever texto livre do perito.
class LaudoParserService {
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
        caracteristicas['identificacao']?.toString().toLowerCase().contains('sexo xxx') == true) {
      caracteristicas['identificacao'] =
          'Cadáver do sexo ${novoSexo.toLowerCase()}, raça XXX, estado nutricional XXX, e idade aparente de XX anos.';
    }
    caracteristicas['sexo'] = novoSexo;
    novosDados['caracteristicas'] = caracteristicas;
    return novosDados;
  }

  String obterSexoExaminado(Map<String, dynamic> dadosLaudo) {
    final identificacao = _mapOrEmpty(dadosLaudo['identificacao']);
    final sexo = identificacao['sexo']?.toString().trim().toLowerCase();
    if (sexo == 'feminino' || sexo == 'f') return 'Feminino';
    if (sexo == 'masculino' || sexo == 'm') return 'Masculino';

    final caracteristicas = _mapOrEmpty(dadosLaudo['caracteristicas']);
    final sexoEstruturado = caracteristicas['sexo']?.toString().trim().toLowerCase();
    if (sexoEstruturado == 'feminino' || sexoEstruturado == 'f') return 'Feminino';
    if (sexoEstruturado == 'masculino' || sexoEstruturado == 'm') return 'Masculino';
    return 'Indeterminado';
  }

  Map<String, dynamic> _mapOrEmpty(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

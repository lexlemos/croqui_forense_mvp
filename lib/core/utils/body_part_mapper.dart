import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart'
    as lat_left;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart'
    as face_left;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart'
    as lat_right;
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart'
    as face_right;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart'
    as perineal;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart'
    as trunk_left;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart'
    as trunk_right;

/// Resolve o nome textual padronizado e anatômico de uma região corporal a partir
/// da vista visualizada ([view]) e do identificador do elemento ou polígono de colisão ([partId]).
///
/// ### Algoritmo de Mapeamento e Áreas de Colisão:
/// O croqui utiliza vetores SVG e polígonos/paths de detecção de toque ([partId]) indexados
/// por mapas de definições anatômicas específicos para cada projeção corporal:
/// - **Frente (`frente` / `front`)**: Consulta [kIdToDefinitionFrontMap].
/// - **Costas (`costas` / `back`)**: Consulta [kIdToDefinitionBackMap].
/// - **Lateral Direita (`lateral_dir`)**: Consulta [lat_right.kIdToDefinitionLateralRightMap].
/// - **Lateral Esquerda (`lateral_esq`)**: Consulta [lat_left.kIdToDefinitionLateralLeftMap].
/// - **Tronco Direito (`trunk_dir`)**: Consulta [trunk_right.kIdToDefinitionTrunkRightMap].
/// - **Tronco Esquerdo (`trunk_esq`)**: Consulta [trunk_left.kIdToDefinitionTrunkLeftMap].
/// - **Perineal (`perineal`)**: Consulta [perineal.kIdToDefinitionPerinealMap].
/// - **Face Direita (`face_dir`)**: Consulta [face_right.kIdToDefinitionLateralRightMap].
/// - **Face Esquerda (`face_esq`)**: Consulta [face_left.kIdToDefinitionLateralLeftMap].
///
/// Caso o [partId] não seja encontrado no dicionário correspondente à [view], aplica
/// um fallback legível formatando o identificador (substituindo underlines por espaços e convertendo para maiúsculas).
String resolveBodyPartName(String view, String partId) {
  if ((view == 'frente' || view == 'front') &&
      kIdToDefinitionFrontMap.containsKey(partId)) {
    return kIdToDefinitionFrontMap[partId]!.name;
  }
  if ((view == 'costas' || view == 'back') &&
      kIdToDefinitionBackMap.containsKey(partId)) {
    return kIdToDefinitionBackMap[partId]!.name;
  }
  if (view == 'lateral_dir' &&
      lat_right.kIdToDefinitionLateralRightMap.containsKey(partId)) {
    return lat_right.kIdToDefinitionLateralRightMap[partId]!.name;
  }
  if (view == 'lateral_esq' &&
      lat_left.kIdToDefinitionLateralLeftMap.containsKey(partId)) {
    return lat_left.kIdToDefinitionLateralLeftMap[partId]!.name;
  }
  if (view == 'trunk_dir' &&
      trunk_right.kIdToDefinitionTrunkRightMap.containsKey(partId)) {
    return trunk_right.kIdToDefinitionTrunkRightMap[partId]!.name;
  }
  if (view == 'trunk_esq' &&
      trunk_left.kIdToDefinitionTrunkLeftMap.containsKey(partId)) {
    return trunk_left.kIdToDefinitionTrunkLeftMap[partId]!.name;
  }
  if (view == 'perineal' &&
      perineal.kIdToDefinitionPerinealMap.containsKey(partId)) {
    return perineal.kIdToDefinitionPerinealMap[partId]!.name;
  }
  if (view == 'face_dir' &&
      face_right.kIdToDefinitionLateralRightMap.containsKey(partId)) {
    return face_right.kIdToDefinitionLateralRightMap[partId]!.name;
  }
  if (view == 'face_esq' &&
      face_left.kIdToDefinitionLateralLeftMap.containsKey(partId)) {
    return face_left.kIdToDefinitionLateralLeftMap[partId]!.name;
  }
  return partId.replaceAll('_', ' ').toUpperCase();
}


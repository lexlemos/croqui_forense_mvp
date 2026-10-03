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

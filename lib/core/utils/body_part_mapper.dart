import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart' as latLeft;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart' as faceLeft;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart' as latRight;
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart' as faceRight;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart' as perineal;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart' as trunkLeft;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart' as trunkRight;

String resolveBodyPartName(String view, String partId) {
  if ((view == 'frente' || view == 'front') && kIdToDefinitionFrontMap.containsKey(partId)) {
    return kIdToDefinitionFrontMap[partId]!.name;
  }
  if ((view == 'costas' || view == 'back') && kIdToDefinitionBackMap.containsKey(partId)) {
    return kIdToDefinitionBackMap[partId]!.name;
  }
  if (view == 'lateral_dir' && latRight.kIdToDefinitionLateralRightMap.containsKey(partId)) {
    return latRight.kIdToDefinitionLateralRightMap[partId]!.name;
  }
  if (view == 'lateral_esq' && latLeft.kIdToDefinitionLateralLeftMap.containsKey(partId)) {
    return latLeft.kIdToDefinitionLateralLeftMap[partId]!.name;
  }
  if (view == 'trunk_dir' && trunkRight.kIdToDefinitionTrunkRightMap.containsKey(partId)) {
    return trunkRight.kIdToDefinitionTrunkRightMap[partId]!.name;
  }
  if (view == 'trunk_esq' && trunkLeft.kIdToDefinitionTrunkLeftMap.containsKey(partId)) {
    return trunkLeft.kIdToDefinitionTrunkLeftMap[partId]!.name;
  }
  if (view == 'perineal' && perineal.kIdToDefinitionPerinealMap.containsKey(partId)) {
    return perineal.kIdToDefinitionPerinealMap[partId]!.name;
  }
  if (view == 'face_dir' && faceRight.kIdToDefinitionLateralRightMap.containsKey(partId)) {
    return faceRight.kIdToDefinitionLateralRightMap[partId]!.name;
  }
  if (view == 'face_esq' && faceLeft.kIdToDefinitionLateralLeftMap.containsKey(partId)) {
    return faceLeft.kIdToDefinitionLateralLeftMap[partId]!.name;
  }
  return partId.replaceAll('_', ' ').toUpperCase();
}

import 'dart:ui';
import 'front_body_data.dart'; 

const List<BodyPartDefinition> kLateralRightPartsList = [
  BodyPartDefinition(id: 'frontal_dir', dbId: 1, name: 'Frontal (Dir)', color: Color(0xffff0000)),
  BodyPartDefinition(id: 'orbitaria_dir', dbId: 2, name: 'Orbitária (Dir)', color: Color(0xff00ff00)),
  BodyPartDefinition(id: 'parietal_dir', dbId: 3, name: 'Parietal (Dir)', color: Color(0xff0000ff)),
  BodyPartDefinition(id: 'nasal_dir', dbId: 4, name: 'Nasal (Dir)', color: Color(0xffffff00)),
  BodyPartDefinition(id: 'malar_dir', dbId: 5, name: 'Malar (Dir)', color: Color(0xff00ffff)),
  BodyPartDefinition(id: 'zigomatica_dir', dbId: 6, name: 'Zigomática (Dir)', color: Color(0xffff00ff)),
  BodyPartDefinition(id: 'temporal_dir', dbId: 7, name: 'Temporal (Dir)', color: Color(0xffff8000)),
  BodyPartDefinition(id: 'auricular_dir', dbId: 8, name: 'Auricular (Dir)', color: Color(0xff800080)),
  BodyPartDefinition(id: 'mastoidea_dir', dbId: 9, name: 'Mastóidea (Dir)', color: Color(0xff008000)),
  BodyPartDefinition(id: 'occipital_dir', dbId: 10, name: 'Occipital (Dir)', color: Color(0xff800000)),
  BodyPartDefinition(id: 'labial_dir', dbId: 11, name: 'Labial (Dir)', color: Color(0xff000080)),
  BodyPartDefinition(id: 'bucinadora_dir', dbId: 12, name: 'Bucinadora (Dir)', color: Color(0xff008080)),
  BodyPartDefinition(id: 'masseterina_dir', dbId: 13, name: 'Masseterina (Dir)', color: Color(0xff404040)),
  BodyPartDefinition(id: 'mentoniana_dir', dbId: 14, name: 'Mentoniana (Dir)', color: Color(0xffff0080)),
  BodyPartDefinition(id: 'supra_hioidea_dir', dbId: 15, name: 'Supra-hióidea (Dir)', color: Color(0xffffd700)),
  BodyPartDefinition(id: 'carotidiana_dir', dbId: 16, name: 'Carotidiana (Dir)', color: Color(0xffbf00ff)),
  BodyPartDefinition(id: 'supraclavicular_dir', dbId: 17, name: 'Supraclavicular (Dir)', color: Color(0xff00bfff)),
  BodyPartDefinition(id: 'nuca_dir', dbId: 18, name: 'Nuca (Dir)', color: Color(0xffbfff00)),
  BodyPartDefinition(id: 'infra_hioidea_dir', dbId: 19, name: 'Infra-hióidea (Dir)', color: Color(0xfffa8072)),
];

final Map<int, String> kColorToIdLateralRightMap = {
  for (var part in kLateralRightPartsList) part.color.toARGB32(): part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionLateralRightMap = {
  for (var part in kLateralRightPartsList) part.id: part,
};

import 'dart:ui';
import 'front_body_data.dart'; 

const List<BodyPartDefinition> kLateralLeftPartsList = [
  BodyPartDefinition(id: 'frontal_esq', dbId: 1, name: 'Frontal (Esq)', color: Color(0xffff0000)),
  BodyPartDefinition(id: 'orbitaria_esq', dbId: 2, name: 'Orbitária (Esq)', color: Color(0xff00ff00)),
  BodyPartDefinition(id: 'parietal_esq', dbId: 3, name: 'Parietal (Esq)', color: Color(0xff0000ff)),
  BodyPartDefinition(id: 'nasal_esq', dbId: 4, name: 'Nasal (Esq)', color: Color(0xffffff00)),
  BodyPartDefinition(id: 'malar_esq', dbId: 5, name: 'Malar (Esq)', color: Color(0xff00ffff)),
  BodyPartDefinition(id: 'zigomatica_esq', dbId: 6, name: 'Zigomática (Esq)', color: Color(0xffff00ff)),
  BodyPartDefinition(id: 'temporal_esq', dbId: 7, name: 'Temporal (Esq)', color: Color(0xffff8000)),
  BodyPartDefinition(id: 'auricular_esq', dbId: 8, name: 'Auricular (Esq)', color: Color(0xff800080)),
  BodyPartDefinition(id: 'mastoidea_esq', dbId: 9, name: 'Mastóidea (Esq)', color: Color(0xff008000)),
  BodyPartDefinition(id: 'occipital_esq', dbId: 10, name: 'Occipital (Esq)', color: Color(0xff800000)),
  BodyPartDefinition(id: 'labial_esq', dbId: 11, name: 'Labial (Esq)', color: Color(0xff000080)),
  BodyPartDefinition(id: 'bucinadora_esq', dbId: 12, name: 'Bucinadora (Esq)', color: Color(0xff008080)),
  BodyPartDefinition(id: 'masseterina_esq', dbId: 13, name: 'Masseterina (Esq)', color: Color(0xff404040)),
  BodyPartDefinition(id: 'mentoniana_esq', dbId: 14, name: 'Mentoniana (Esq)', color: Color(0xffff0080)),
  BodyPartDefinition(id: 'supra_hioidea_esq', dbId: 15, name: 'Supra-hióidea (Esq)', color: Color(0xffffd700)),
  BodyPartDefinition(id: 'carotidiana_esq', dbId: 16, name: 'Carotidiana (Esq)', color: Color(0xffbf00ff)),
  BodyPartDefinition(id: 'supraclavicular_esq', dbId: 17, name: 'Supraclavicular (Esq)', color: Color(0xff00bfff)),
  BodyPartDefinition(id: 'nuca_esq', dbId: 18, name: 'Nuca (Esq)', color: Color(0xffbfff00)),
  BodyPartDefinition(id: 'infra_hioidea_esq', dbId: 19, name: 'Infra-hióidea (Esq)', color: Color(0xfffa8072)),
];

final Map<int, String> kColorToIdLateralLeftMap = {
  for (var part in kLateralLeftPartsList) part.color.value: part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionLateralLeftMap = {
  for (var part in kLateralLeftPartsList) part.id: part,
};
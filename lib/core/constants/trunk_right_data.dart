import 'dart:ui';
import 'front_body_data.dart';

const List<BodyPartDefinition> kTrunkRightBodyPartsList = [
  BodyPartDefinition(id: 'supra_hioidea', dbId: 1, name: 'Supra-hióidéia', color: Color(0xffff0000)),
  BodyPartDefinition(id: 'infra_hioidea', dbId: 2, name: 'Infra-hióidéia', color: Color(0xff00ff00)),
  BodyPartDefinition(id: 'carotidiana', dbId: 3, name: 'Carotidiana', color: Color(0xff0000ff)),
  BodyPartDefinition(id: 'supraclaviculares', dbId: 4, name: 'Supraclaviculares', color: Color(0xffffff00)),
  BodyPartDefinition(id: 'nuca', dbId: 5, name: 'Nuca', color: Color(0xff00ffff)),
  BodyPartDefinition(id: 'clavicular', dbId: 6, name: 'Clavicular', color: Color(0xffff00ff)),
  BodyPartDefinition(id: 'infra_clavicular', dbId: 7, name: 'Infra-clavicular', color: Color(0xffff8000)),
  BodyPartDefinition(id: 'deltoidiana', dbId: 8, name: 'Deltoidiana', color: Color(0xff800080)),
  BodyPartDefinition(id: 'braco_terco_sup', dbId: 9, name: 'Terço Superior do Braço', color: Color(0xff008000)),
  BodyPartDefinition(id: 'concavo_axilar', dbId: 10, name: 'Côncavo Axilar', color: Color(0xff800000)),
  BodyPartDefinition(id: 'toracica', dbId: 11, name: 'Torácica', color: Color(0xff000080)),
  BodyPartDefinition(id: 'mamaria', dbId: 12, name: 'Mamária', color: Color(0xff004080)),
  BodyPartDefinition(id: 'epigastrica', dbId: 13, name: 'Epigástrica', color: Color(0xff008080)),
  BodyPartDefinition(id: 'hipocondrio', dbId: 14, name: 'Hipocôndrio', color: Color(0xff404040)),
  BodyPartDefinition(id: 'mesogastrica', dbId: 15, name: 'Mesogástrica', color: Color(0xffff0080)),
  BodyPartDefinition(id: 'umbilical', dbId: 16, name: 'Umbilical', color: Color(0xffffbf00)),
  BodyPartDefinition(id: 'flanco', dbId: 17, name: 'Flanco (Hipocôndrio/Lombar)', color: Color(0xffbf00ff)), 
  BodyPartDefinition(id: 'hipogastrica', dbId: 18, name: 'Hipogástrica', color: Color(0xff00bfff)),
  BodyPartDefinition(id: 'fossa_iliaca', dbId: 19, name: 'Fossa Ilíaca', color: Color(0xff00ff80)),
  BodyPartDefinition(id: 'pubiana', dbId: 20, name: 'Pubiana', color: Color(0xffff8080)),
  BodyPartDefinition(id: 'inguinal', dbId: 21, name: 'Inguinal', color: Color(0xff808000)),
  BodyPartDefinition(id: 'crural', dbId: 22, name: 'Crural', color: Color(0xff800040)),
  BodyPartDefinition(id: 'quadril', dbId: 23, name: 'Quadril', color: Color(0xffa0522d)),
  BodyPartDefinition(id: 'glutea', dbId: 24, name: 'Glútea', color: Color(0xff408000)),
];

final Map<int, String> kColorToIdTrunkRightMap = {
  for (var part in kTrunkRightBodyPartsList) part.color.value: part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionTrunkRightMap = {
  for (var part in kTrunkRightBodyPartsList) part.id: part,
};
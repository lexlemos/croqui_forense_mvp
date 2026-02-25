import 'dart:ui';
import 'front_body_data.dart'; 

const List<BodyPartDefinition> kBackBodyPartsList = [
  BodyPartDefinition(id: 'parietais', dbId: 1, name: 'Parietais', color: Color(0xffff0000)),
  BodyPartDefinition(id: 'occipital', dbId: 2, name: 'Occipital', color: Color(0xff00ff00)),
  BodyPartDefinition(id: 'temporais', dbId: 3, name: 'Temporais', color: Color(0xff0000ff)),
  BodyPartDefinition(id: 'nuca', dbId: 4, name: 'Nuca', color: Color(0xffffff00)),
  BodyPartDefinition(id: 'supra_escapulares', dbId: 5, name: 'Supra-Escapulares', color: Color(0xff00ffff)),
  BodyPartDefinition(id: 'coluna_vertebral', dbId: 6, name: 'Coluna Vertebral', color: Color(0xffff00ff)),
  BodyPartDefinition(id: 'auriculares', dbId: 7, name: 'Auriculares', color: Color(0xffff8000)),
  BodyPartDefinition(id: 'deltoidianas', dbId: 8, name: 'Deltoidianas', color: Color(0xff800080)),
  BodyPartDefinition(id: 'escapulares', dbId: 9, name: 'Escapulares', color: Color(0xff008000)),
  BodyPartDefinition(id: 'goteiras', dbId: 10, name: 'Goteiras Costovertebrais', color: Color(0xff800000)),
  BodyPartDefinition(id: 'braco_sup', dbId: 11, name: 'Terço Superior do Braço', color: Color(0xff000080)),
  BodyPartDefinition(id: 'braco_med', dbId: 12, name: 'Terço Médio do Braço', color: Color(0xff004080)),
  BodyPartDefinition(id: 'braco_inf', dbId: 13, name: 'Terço Inferior do Braço', color: Color(0xff008080)),
  BodyPartDefinition(id: 'cotovelos', dbId: 14, name: 'Cotovelos', color: Color(0xff404040)),
  BodyPartDefinition(id: 'antebraco_sup', dbId: 15, name: 'Terço superior do Antebraço', color: Color(0xffff0080)),
  BodyPartDefinition(id: 'antebraco_med', dbId: 16, name: 'Terço médio do antebraço', color: Color(0xffffbf00)),
  BodyPartDefinition(id: 'antebraco_inf', dbId: 17, name: 'Terço inferior do Antebraço', color: Color(0xffbf00ff)),
  BodyPartDefinition(id: 'punhos', dbId: 18, name: 'Punhos', color: Color(0xff00bfff)),
  BodyPartDefinition(id: 'dorso_maos', dbId: 19, name: 'Dorso das Mãos', color: Color(0xff00ff80)),
  BodyPartDefinition(id: 'infra_escapulares', dbId: 20, name: 'Infra Escapulares', color: Color(0xffff8080)),
  BodyPartDefinition(id: 'lombares', dbId: 21, name: 'Lombares', color: Color(0xff808000)),
  BodyPartDefinition(id: 'iliacas', dbId: 22, name: 'Ilíacas', color: Color(0xff800040)),
  BodyPartDefinition(id: 'sacra', dbId: 23, name: 'Sacra', color: Color(0xffa0522d)),
  BodyPartDefinition(id: 'gluteas', dbId: 24, name: 'Glúteas', color: Color(0xff408000)),
  BodyPartDefinition(id: 'quadris', dbId: 25, name: 'Quadris', color: Color(0xffffb6c1)),
  BodyPartDefinition(id: 'coxa_sup', dbId: 26, name: 'Terço Superior da Coxa', color: Color(0xffcc0000)),
  BodyPartDefinition(id: 'coxa_med', dbId: 27, name: 'Terço Médio da Coxa', color: Color(0xff66ff00)),
  BodyPartDefinition(id: 'coxa_inf', dbId: 28, name: 'Terço inferior da Coxa', color: Color(0xff4169e1)),
  BodyPartDefinition(id: 'popliteas', dbId: 29, name: 'Poplitéas', color: Color(0xffffd700)),
  BodyPartDefinition(id: 'perna_sup', dbId: 30, name: 'Terço Superior da Perna', color: Color(0xff40e0d0)),
  BodyPartDefinition(id: 'perna_med', dbId: 31, name: 'Terço Médio da Perna', color: Color(0xffee82ee)),
  BodyPartDefinition(id: 'perna_inf', dbId: 32, name: 'Terço Inferior da Perna', color: Color(0xffff7f50)),
  BodyPartDefinition(id: 'maleolar_ext', dbId: 33, name: 'Maleolar Externa', color: Color(0xff4b0082)),
  BodyPartDefinition(id: 'calcaneos', dbId: 34, name: 'Calcâneos', color: Color(0xffd2691e)),
  BodyPartDefinition(id: 'dorso_pes', dbId: 35, name: 'Dorso dos Pés', color: Color(0xffc0c0c0)),
];

final Map<int, String> kColorToIdBackMap = {
  for (var part in kBackBodyPartsList) part.color.value: part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionBackMap = {
  for (var part in kBackBodyPartsList) part.id: part,
};
import 'dart:ui';
import 'front_body_data.dart'; 

const List<BodyPartDefinition> kPerinealBodyPartsList = [
  // --- PARTES MASCULINAS ---
  BodyPartDefinition(id: 'male_pubiana', dbId: 1, name: 'Pubiana', color: Color(0xff110000)),
  BodyPartDefinition(id: 'male_pudenda', dbId: 2, name: 'Pudenda', color: Color(0xff220000)),
  BodyPartDefinition(id: 'male_genitocrurais', dbId: 3, name: 'Genitocrurais', color: Color(0xff330000)),
  BodyPartDefinition(id: 'male_face_interna_coxas', dbId: 4, name: 'Face Interna das Coxas', color: Color(0xff440000)),
  BodyPartDefinition(id: 'male_perineal', dbId: 5, name: 'Perineal', color: Color(0xff550000)),
  BodyPartDefinition(id: 'male_anal', dbId: 6, name: 'Anal', color: Color(0xff660000)),
  BodyPartDefinition(id: 'male_sacrococcigeana', dbId: 7, name: 'Sacrococcigeana', color: Color(0xff770000)),
  BodyPartDefinition(id: 'male_gluteas', dbId: 8, name: 'Glúteas', color: Color(0xff880000)),

  // --- PARTES FEMININAS ---
  BodyPartDefinition(id: 'female_pubiana', dbId: 9, name: 'Pubiana', color: Color(0xff001100)),
  BodyPartDefinition(id: 'female_pudenda', dbId: 10, name: 'Pudenda', color: Color(0xff002200)),
  BodyPartDefinition(id: 'female_genitocrurais', dbId: 11, name: 'Genitocrurais', color: Color(0xff003300)),
  BodyPartDefinition(id: 'female_face_interna_coxas', dbId: 12, name: 'Face Interna das Coxas', color: Color(0xff004400)),
  BodyPartDefinition(id: 'female_perineal', dbId: 13, name: 'Perineal', color: Color(0xff005500)),
  BodyPartDefinition(id: 'female_anal', dbId: 14, name: 'Anal', color: Color(0xff006600)),
  BodyPartDefinition(id: 'female_sacrococcigeana', dbId: 15, name: 'Sacrococcigeana', color: Color(0xff007700)),
  BodyPartDefinition(id: 'female_gluteas', dbId: 16, name: 'Glúteas', color: Color(0xff008800)),
];

final Map<int, String> kColorToIdPerinealMap = {
  for (var part in kPerinealBodyPartsList) part.color.value: part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionPerinealMap = {
  for (var part in kPerinealBodyPartsList) part.id: part,
};
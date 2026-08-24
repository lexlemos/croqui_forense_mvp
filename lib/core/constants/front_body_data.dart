import 'dart:ui';

class BodyPartDefinition {
  final String id; 
  final int dbId;  
  final String name; 
  final Color color; 

  const BodyPartDefinition({
    required this.id,
    required this.dbId,
    required this.name,
    required this.color,
  });
}
const List<BodyPartDefinition> kFrontBodyPartsList = [
  BodyPartDefinition(id: 'frontal', dbId: 1, name: 'Frontal', color: Color(0xff000001)),
  BodyPartDefinition(id: 'orbitaria', dbId: 2, name: 'Orbitária', color: Color(0xff000002)),
  BodyPartDefinition(id: 'nasal', dbId: 3, name: 'Nasal', color: Color(0xff000003)),
  BodyPartDefinition(id: 'malares', dbId: 4, name: 'Malares', color: Color(0xff000004)),
  BodyPartDefinition(id: 'masseterinas', dbId: 5, name: 'Masseterinas', color: Color(0xff000005)),
  BodyPartDefinition(id: 'auriculares', dbId: 6, name: 'Auriculares', color: Color(0xff000006)),
  BodyPartDefinition(id: 'bucinadoras', dbId: 7, name: 'Bucinadoras', color: Color(0xff000007)),
  BodyPartDefinition(id: 'labial', dbId: 8, name: 'Labial', color: Color(0xff000008)),
  BodyPartDefinition(id: 'mentoniana', dbId: 9, name: 'Mentoniana', color: Color(0xff000009)),
  BodyPartDefinition(id: 'suprahioidea', dbId: 10, name: 'Suprahioidéa', color: Color(0xff00000a)),
  BodyPartDefinition(id: 'infrahioidea', dbId: 11, name: 'Infrahioidéa', color: Color(0xff00000b)),
  BodyPartDefinition(id: 'carotidianas', dbId: 12, name: 'Carotidianas', color: Color(0xff00000c)),
  BodyPartDefinition(id: 'supraclaviculares', dbId: 13, name: 'Supraclaviculares', color: Color(0xff00000d)),
  BodyPartDefinition(id: 'claviculares', dbId: 14, name: 'Claviculares', color: Color(0xff00000e)),
  BodyPartDefinition(id: 'infraclaviculares', dbId: 15, name: 'Infraclaviculares', color: Color(0xff00000f)),
  BodyPartDefinition(id: 'esternal', dbId: 16, name: 'Esternal', color: Color(0xff000010)),
  BodyPartDefinition(id: 'deltoidiana', dbId: 17, name: 'Deltoidiana', color: Color(0xff000011)),
  BodyPartDefinition(id: 'toracicas', dbId: 18, name: 'Torácicas', color: Color(0xff000012)),
  BodyPartDefinition(id: 'mamarias', dbId: 19, name: 'Mamarias', color: Color(0xff001013)),
  BodyPartDefinition(id: 'epigastrica', dbId: 20, name: 'Epigástrica', color: Color(0xff000014)),
  BodyPartDefinition(id: 'hipocondrios', dbId: 21, name: 'Hipocôndrios', color: Color(0xff000015)),
  BodyPartDefinition(id: 'abdominal_meso', dbId: 22, name: 'Abdominal (mesogástrico)', color: Color(0xff000016)),
  BodyPartDefinition(id: 'umbilical', dbId: 23, name: 'Umbilical', color: Color(0xff000017)),
  BodyPartDefinition(id: 'hipogastrica', dbId: 24, name: 'Hipogástrica', color: Color(0xff000019)), 
  BodyPartDefinition(id: 'pubiana', dbId: 25, name: 'Pubiana', color: Color(0xff00001a)),
  BodyPartDefinition(id: 'flancos', dbId: 26, name: 'Flancos', color: Color(0xff00001b)),
  BodyPartDefinition(id: 'fossas_iliacas', dbId: 27, name: 'Fossas Ilíacas', color: Color(0xff00001c)),
  BodyPartDefinition(id: 'inguinais', dbId: 28, name: 'Inguinais', color: Color(0xff00001d)),
  BodyPartDefinition(id: 'crurais', dbId: 29, name: 'Crurais', color: Color(0xff00001e)),
  BodyPartDefinition(id: 'peniana', dbId: 30, name: 'Peniana', color: Color(0xff0001ff)),
  BodyPartDefinition(id: 'escrotal', dbId: 31, name: 'Escrotal', color: Color(0xff0099de)), 

  BodyPartDefinition(id: 'bracos_sup', dbId: 32, name: 'Terços superiores dos braços', color: Color(0xffFF0000)),
  BodyPartDefinition(id: 'bracos_med', dbId: 33, name: 'Terços Médios dos Braços', color: Color(0xffCC0000)),
  BodyPartDefinition(id: 'bracos_inf', dbId: 34, name: 'Terços Inferiores dos Braços', color: Color(0xff990000)),
  
  BodyPartDefinition(id: 'cotovelos_ant', dbId: 35, name: 'Dobra Anteriores dos Cotovelos', color: Color(0xffFF6600)), 
  
  BodyPartDefinition(id: 'antebracos_sup', dbId: 36, name: 'Terços superiores dos Antebraços', color: Color(0xffFF9900)),
  BodyPartDefinition(id: 'antebracos_med', dbId: 37, name: 'Terços Médios dos antebraços', color: Color(0xffFFCC00)), 
  BodyPartDefinition(id: 'antebracos_inf', dbId: 38, name: 'Terços Inferiores dos Antebraços', color: Color(0xffFFFF00)), 
  
  BodyPartDefinition(id: 'punhos', dbId: 39, name: 'Punhos', color: Color(0xff00FF00)), 
  BodyPartDefinition(id: 'maos_concavos', dbId: 40, name: 'Concavos das mãos', color: Color(0xff00CC00)), 
  BodyPartDefinition(id: 'maos_palmares', dbId: 41, name: 'Faces Palmares das mãos', color: Color(0xff009900)), 

  BodyPartDefinition(id: 'coxas_sup', dbId: 42, name: 'Terços Superiores das Coxas', color: Color(0xff0000FF)),
  BodyPartDefinition(id: 'coxas_med', dbId: 43, name: 'Terços Médios das Coxas', color: Color(0xff0000CC)),
  BodyPartDefinition(id: 'coxas_inf', dbId: 44, name: 'Terços Inferiores das Coxas', color: Color(0xff000099)), 
  
  BodyPartDefinition(id: 'joelhos_ant', dbId: 45, name: 'Anteriores dos Joelhos', color: Color(0xff00FFFF)), 
  BodyPartDefinition(id: 'rotulianas', dbId: 46, name: 'Rotulianas', color: Color(0xff0099FF)), 
  
  BodyPartDefinition(id: 'pernas_sup', dbId: 47, name: 'Terços Superiores das Pernas', color: Color(0xffFF00FF)), 
  BodyPartDefinition(id: 'pernas_med', dbId: 48, name: 'Terços Médios das Pernas', color: Color(0xffCC00CC)), 
  BodyPartDefinition(id: 'pernas_inf', dbId: 49, name: 'Terços inferiores das Pernas', color: Color(0xff990099)), 
  
  BodyPartDefinition(id: 'pes_dorsal', dbId: 50, name: 'Dorsal dos Pés', color: Color(0xff660066)),
  BodyPartDefinition(id: 'maleolares_int', dbId: 51, name: 'Maleolares Internas', color: Color(0xff330033)), 
  BodyPartDefinition(id: 'maleolares_ext', dbId: 52, name: 'Maleolares Externos', color: Color(0xff003333)),
];


final Map<int, String> kColorToIdFrontMap = {
  for (var part in kFrontBodyPartsList) part.color.toARGB32(): part.id,
};

final Map<String, BodyPartDefinition> kIdToDefinitionFrontMap = {
  for (var part in kFrontBodyPartsList) part.id: part,
};

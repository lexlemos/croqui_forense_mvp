import 'package:pdf/widgets.dart' as pw;

class PdfConstants {
  static const marginDefault = pw.EdgeInsets.fromLTRB(85.05, 28.35, 56.7, 56.7);

  static const String tituloLaudo = "LAUDO DE EXAME PERICIAL NECROSCÓPICO";
  static const String encerramentoPadrao = "Nada mais havendo a lavrar, encerra-se o presente Laudo Pericial que segue em formato digital, devidamente assinado, cujas páginas encontram-se numeradas no rodapé deste documento.";

  static final Map<String, List<String>> mapeamentoAnatomico = {
    'I) Crânio e Face': [
      'frontal', 'orbitaria', 'nasal', 'malares', 'masseterinas', 'auriculares', 'bucinadoras', 'labial', 'mentoniana',
      'parietais', 'occipital', 'temporais',
      'frontal_esq', 'orbitaria_esq', 'parietal_esq', 'nasal_esq', 'malar_esq', 'zigomatica_esq', 'temporal_esq', 'auricular_esq', 'mastoidea_esq', 'occipital_esq', 'labial_esq', 'bucinadora_esq', 'masseterina_esq', 'mentoniana_esq',
      'frontal_dir', 'orbitaria_dir', 'parietal_dir', 'nasal_dir', 'malar_dir', 'zigomatica_dir', 'temporal_dir', 'auricular_dir', 'mastoidea_dir', 'occipital_dir', 'labial_dir', 'bucinadora_dir', 'masseterina_dir', 'mentoniana_dir',
      // New full lateral body face/head regions:
      'parietal', 'temporal', 'auricular', 'malar', 'zigomatica', 'masseterina', 'bucinadora', 'malar_esq', 'zigomatica_esq', 'malar_dir', 'zigomatica_dir'
    ],
    'II) Pescoço': [
      'suprahioidea', 'infrahioidea', 'carotidianas', 'supraclaviculares', 'claviculares', 'infraclaviculares',
      'nuca',
      'supra_hioidea_esq', 'carotidiana_esq', 'supraclavicular_esq', 'nuca_esq', 'infra_hioidea_esq',
      'supra_hioidea_dir', 'carotidiana_dir', 'supraclavicular_dir', 'nuca_dir', 'infra_hioidea_dir',
      // New lateral/trunk neck regions:
      'supra_clavicular', 'carotidiana', 'supra_hioideia', 'infra_hioideia', 'supra_hioidea', 'infra_hioidea'
    ],
    'III) Membros': [
      'bracos_sup', 'bracos_med', 'bracos_inf', 'cotovelos_ant', 'antebracos_sup', 'antebracos_med', 'antebracos_inf', 'punhos', 'maos_concavos', 'maos_palmares',
      'braco_sup', 'braco_med', 'braco_inf', 'cotovelos', 'antebraco_sup', 'antebraco_med', 'antebraco_inf', 'dorso_maos',
      'coxas_sup', 'coxas_med', 'coxas_inf', 'joelhos_ant', 'rotulianas', 'pernas_sup', 'pernas_med', 'pernas_inf', 'pes_dorsal', 'maleolares_int', 'maleolares_ext',
      'coxa_sup', 'coxa_med', 'coxa_inf', 'popliteas', 'perna_sup', 'perna_med', 'perna_inf', 'maleolar_ext', 'calcaneos', 'dorso_pes',
      // New lateral/trunk limbs regions:
      'escapulo_umeral', 'braco_terco_sup', 'braco_terco_med', 'braco_terco_inf', 'lateral_cotovelo', 'cotovelo', 'antebraco_terco_sup', 'antebraco_terco_med', 'antebraco_terco_inf', 'punho', 'dorsal_mao', 'palmar_mao',
      'coxa_terco_sup', 'coxa_terco_med', 'coxa_terco_inf', 'face_lateral_joelho', 'joelho', 'popliteia', 'perna_terco_sup', 'perna_terco_med', 'perna_terco_inf', 'maleolar', 'dorsal_pe', 'calcaneo', 'lateral_pe', 'artelhos',
      'concavo_axilar', 'male_face_interna_coxas', 'female_face_interna_coxas'
    ],
    'IV) Tórax': [
      'esternal', 'deltoidiana', 'toracicas', 'mamarias',
      'supra_escapulares', 'coluna_vertebral', 'deltoidianas', 'escapulares', 'goteiras', 'infra_escapulares',
      // New lateral/trunk thoracic regions:
      'clavicular', 'infra_clavicular', 'hemitorax', 'mamaria', 'toracica'
    ],
    'V) Abdome': [
      'epigastrica', 'hipocondrios', 'abdominal_meso', 'umbilical', 'hipogastrica', 'pubiana', 'flancos', 'fossas_iliacas', 'inguinais', 'crurais', 'peniana', 'escrotal',
      'lombares', 'iliacas', 'sacra', 'gluteas', 'quadris',
      // New lateral/trunk/perineal abdominal/pelvic regions:
      'hipocondrio', 'epigastrica', 'flanco', 'abdominal_mesogastrica', 'umbilical', 'hipogastrica', 'pubiana', 'fossa_iliaca', 'inguinal', 'crural', 'quadril', 'glutea', 'mesogastrica',
      'male_pubiana', 'male_pudenda', 'male_genitocrurais', 'male_perineal', 'male_anal', 'male_sacrococcigeana', 'male_gluteas',
      'female_pubiana', 'female_pudenda', 'female_genitocrurais', 'female_perineal', 'female_anal', 'female_sacrococcigeana', 'female_gluteas'
    ],
  };

  static final Map<String, String> titulosInternos = {
    'I) Crânio e Face': 'I) Cavidade craniana',
    'II) Pescoço': 'II) Pescoço',
    'III) Membros': 'III) Membros',
    'IV) Tórax': 'IV) Cavidade torácica',
    'V) Abdome': 'V) Cavidade abdominal',
  };
}
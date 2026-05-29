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
      'frontal_dir', 'orbitaria_dir', 'parietal_dir', 'nasal_dir', 'malar_dir', 'zigomatica_dir', 'temporal_dir', 'auricular_dir', 'mastoidea_dir', 'occipital_dir', 'labial_dir', 'bucinadora_dir', 'masseterina_dir', 'mentoniana_dir'
    ],
    'II) Pescoço': [
      'suprahioidea', 'infrahioidea', 'carotidianas', 'supraclaviculares', 'claviculares', 'infraclaviculares',
      'nuca',
      'supra_hioidea_esq', 'carotidiana_esq', 'supraclavicular_esq', 'nuca_esq', 'infra_hioidea_esq',
      'supra_hioidea_dir', 'carotidiana_dir', 'supraclavicular_dir', 'nuca_dir', 'infra_hioidea_dir'
    ],
    'III) Membros': [
      'bracos_sup', 'bracos_med', 'bracos_inf', 'cotovelos_ant', 'antebracos_sup', 'antebracos_med', 'antebracos_inf', 'punhos', 'maos_concavos', 'maos_palmares',
      'braco_sup', 'braco_med', 'braco_inf', 'cotovelos', 'antebraco_sup', 'antebraco_med', 'antebraco_inf', 'dorso_maos',
      'coxas_sup', 'coxas_med', 'coxas_inf', 'joelhos_ant', 'rotulianas', 'pernas_sup', 'pernas_med', 'pernas_inf', 'pes_dorsal', 'maleolares_int', 'maleolares_ext',
      'coxa_sup', 'coxa_med', 'coxa_inf', 'popliteas', 'perna_sup', 'perna_med', 'perna_inf', 'maleolar_ext', 'calcaneos', 'dorso_pes'
    ],
    'IV) Tórax': [
      'esternal', 'deltoidiana', 'toracicas', 'mamarias',
      'supra_escapulares', 'coluna_vertebral', 'deltoidianas', 'escapulares', 'goteiras', 'infra_escapulares'
    ],
    'V) Abdome': [
      'epigastrica', 'hipocondrios', 'abdominal_meso', 'umbilical', 'hipogastrica', 'pubiana', 'flancos', 'fossas_iliacas', 'inguinais', 'crurais', 'peniana', 'escrotal',
      'lombares', 'iliacas', 'sacra', 'gluteas', 'quadris'
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
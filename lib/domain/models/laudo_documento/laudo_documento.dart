import 'laudo_secao.dart';

/// Modelo neutro de conteúdo do laudo pericial (uma verdade para PDF e DOCX).
class LaudoDocumento {
  final List<LaudoSecao> secoes;

  const LaudoDocumento({required this.secoes});

  Map<String, dynamic> toJson() => {
    'secoes': secoes.map((s) => s.toJson()).toList(),
  };

  factory LaudoDocumento.fromJson(Map<String, dynamic> json) => LaudoDocumento(
    secoes:
        (json['secoes'] as List<dynamic>?)
            ?.map((s) => LaudoSecao.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

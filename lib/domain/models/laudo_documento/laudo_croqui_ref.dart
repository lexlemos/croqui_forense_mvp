/// Metadados de referência de um croqui anatômico rasterizado enviado ao backend.
class LaudoCroquiRef {
  final String vista;
  final int ordem;
  final String artefatoUuid;
  final int largura;
  final int altura;
  final String legenda;

  const LaudoCroquiRef({
    required this.vista,
    required this.ordem,
    required this.artefatoUuid,
    required this.largura,
    required this.altura,
    required this.legenda,
  });

  Map<String, dynamic> toJson() => {
    'vista': vista,
    'ordem': ordem,
    'artefato_uuid': artefatoUuid,
    'largura': largura,
    'altura': altura,
    'legenda': legenda,
  };

  factory LaudoCroquiRef.fromJson(Map<String, dynamic> json) => LaudoCroquiRef(
    vista: json['vista'] as String,
    ordem: (json['ordem'] as num).toInt(),
    artefatoUuid: json['artefato_uuid'] as String,
    largura: (json['largura'] as num).toInt(),
    altura: (json['altura'] as num).toInt(),
    legenda: json['legenda'] as String,
  );
}

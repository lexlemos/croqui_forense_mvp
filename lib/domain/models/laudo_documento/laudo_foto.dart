/// Metadados de numeração oficial e referência de uma fotografia no laudo pericial.
class LaudoFoto {
  final int numero;
  final String tipo; // 'GERAL' | 'ACHADO'
  final String evidenciaUuid;
  final String? achadoUuid;
  final String legenda;
  final String? hashArquivo;

  const LaudoFoto({
    required this.numero,
    required this.tipo,
    required this.evidenciaUuid,
    this.achadoUuid,
    required this.legenda,
    this.hashArquivo,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'numero': numero,
      'tipo': tipo,
      'evidencia_uuid': evidenciaUuid,
      'achado_uuid': achadoUuid,
      'legenda': legenda,
    };
    if (hashArquivo != null) map['hash_arquivo'] = hashArquivo;
    return map;
  }

  factory LaudoFoto.fromJson(Map<String, dynamic> json) => LaudoFoto(
    numero: (json['numero'] as num).toInt(),
    tipo: json['tipo'] as String,
    evidenciaUuid: json['evidencia_uuid'] as String,
    achadoUuid: json['achado_uuid'] as String?,
    legenda: json['legenda'] as String,
    hashArquivo: json['hash_arquivo'] as String?,
  );
}

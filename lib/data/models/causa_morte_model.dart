class CausaMorte {
  final String imediata;
  final String devidoA;
  final String consequencia;

  CausaMorte({
    required this.imediata,
    required this.devidoA,
    required this.consequencia,
  });

  factory CausaMorte.fromMap(Map<String, dynamic> map) {
    return CausaMorte(
      imediata: map['imediata'] ?? '',
      devidoA: map['devido_a'] ?? '',
      consequencia: map['consequencia'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imediata': imediata,
      'devido_a': devidoA,
      'consequencia': consequencia,
    };
  }
}

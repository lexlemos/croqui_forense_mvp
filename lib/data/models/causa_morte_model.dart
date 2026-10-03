/// Modelo fortemente tipado que descreve a árvore da causa da morte.
/// Utilizado para manter a consistência da Cadeia de Custódia e evitar
/// a perda de informações (ex: arrays mal formatados) no motor Offline-First.
class CausaMorteModel {
  final String imediata;
  final String devidoA;
  final String consequencia;

  CausaMorteModel({
    required this.imediata,
    required this.devidoA,
    required this.consequencia,
  });

  factory CausaMorteModel.fromMap(Map<String, dynamic> map) {
    return CausaMorteModel(
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

class InjuryType {
  final String id;
  final String label;
  final int order;
  final bool isActive;

  InjuryType({
    required this.id,
    required this.label,
    this.order = 0,
    this.isActive = true,
  });

  factory InjuryType.fromMap(Map<String, dynamic> map) {
    return InjuryType(
      id: map['id']?.toString() ?? '',
      label: map['nome']?.toString() ?? '',
      order: map['ordem'] as int? ?? 0,
      isActive: (map['ativo'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': label,
      'ordem': order,
      'ativo': isActive ? 1 : 0,
    };
  }
}
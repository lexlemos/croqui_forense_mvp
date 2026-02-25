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
      id: map['id'],
      label: map['label'],
      order: map['ordem'] ?? 0,
      isActive: (map['ativo'] ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'ordem': order,
      'ativo': isActive ? 1 : 0,
    };
  }
}
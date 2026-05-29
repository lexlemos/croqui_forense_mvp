class Papel {
  final String id;
  final String nome;
  final String? descricao;
  final bool ePadrao;
  final DateTime criadoEm;

  Papel({
    required this.id,
    required this.nome,
    this.descricao,
    required this.ePadrao,
    required this.criadoEm,
  });


  factory Papel.fromMap(Map<String, dynamic> map) {
    return Papel(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      descricao: map['descricao']?.toString(),
      ePadrao: (map['e_padrao'] as int? ?? 0) == 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'e_padrao': ePadrao ? 1 : 0, 
      'criado_em': criadoEm.toIso8601String(),
    };
  }
  bool get isAdmin => nome == 'ADMIN';
}


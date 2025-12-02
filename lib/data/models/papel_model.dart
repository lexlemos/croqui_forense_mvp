class Papel {
  final int id;
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
      id: map['id'] as int,
      nome: map['nome'] as String,
      descricao: map.containsKey('descricao') ? map['descricao'] as String : null,
      ePadrao: (map['e_padrao'] as int) == 1,
      criadoEm: DateTime.parse(map['criado_em'] as String),
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
}


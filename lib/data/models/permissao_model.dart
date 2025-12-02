class Permissao {
  final int id;
  final String codigo;
  final String? descricao;

  Permissao({
    required this.id,
    required this.codigo,
    this.descricao,
  });

  factory Permissao.fromMap(Map<String, dynamic> map) {
    return Permissao(
      id: map['id'] as int,
      codigo: map['codigo'] as String,
      descricao: map.containsKey('descricao') ? map['descricao'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'descricao': descricao,
    };
  }
}


class Permissao {
  final String id;
  final String codigo;
  final String? descricao;

  Permissao({
    required this.id,
    required this.codigo,
    this.descricao,
  });

  factory Permissao.fromMap(Map<String, dynamic> map) {
    return Permissao(
      id: map['id']?.toString() ?? '',
      codigo: map['codigo']?.toString() ?? '',
      descricao: map['descricao']?.toString(),
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


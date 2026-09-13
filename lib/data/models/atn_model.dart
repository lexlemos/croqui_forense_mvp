import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/exceptions/database_corrupted_exception.dart';

/// Modelo representativo de um Auxiliar Técnico de Necropsia (A.T.N.).
class AtnModel {
  final String id;
  final String nome;
  final bool ativo;

  AtnModel({
    required this.id,
    required this.nome,
    this.ativo = true,
  });

  AtnModel.novo({
    required this.nome,
    this.ativo = true,
  }) : id = const Uuid().v4();

  factory AtnModel.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString().trim() ?? '';
    final nome = map['nome']?.toString().trim() ?? '';
    if (id.isEmpty || nome.isEmpty) {
      throw DatabaseCorruptedException(
        'Registro de ATN inválido no banco local.',
        cause: map,
      );
    }

    return AtnModel(
      id: id,
      nome: nome,
      ativo: map['ativo'] is bool
          ? map['ativo'] as bool
          : (map['ativo'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'ativo': ativo ? 1 : 0,
    };
  }

  AtnModel copyWith({
    String? id,
    String? nome,
    bool? ativo,
  }) {
    return AtnModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ativo: ativo ?? this.ativo,
    );
  }
}

import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/exceptions/database_corrupted_exception.dart';

/// Modelo representativo de um Auxiliar Técnico de Necropsia (A.T.N.).
class AtnModel {
  final String id;
  final String nome;
  final bool ativo;
  final String? email;
  final String? cpf;

  AtnModel({
    required this.id,
    required this.nome,
    this.ativo = true,
    this.email,
    this.cpf,
  });

  AtnModel.novo({required this.nome, this.ativo = true, this.email, this.cpf})
    : id = const Uuid().v4();

  factory AtnModel.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString().trim() ?? '';
    final nome = (map['nome_completo'] ?? map['nome'])?.toString().trim() ?? '';
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
      email: map['email']?.toString().trim(),
      cpf: map['cpf']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome': nome, 'ativo': ativo ? 1 : 0};
  }

  AtnModel copyWith({
    String? id,
    String? nome,
    bool? ativo,
    String? email,
    String? cpf,
  }) {
    return AtnModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ativo: ativo ?? this.ativo,
      email: email ?? this.email,
      cpf: cpf ?? this.cpf,
    );
  }
}

/// Mocks temporários de Auxiliares Técnicos de Necrópsia (ATNs).
///
/// Utilizados enquanto a rota remota está desativada e a busca por usuários
/// com papel [ATN] não foi finalizada.
const List<Map<String, dynamic>> kMockAtnsRaw = [
  {'id': 'atn-mock-001', 'nome': 'Carlos Eduardo Santos (ATN)', 'ativo': 1},
  {'id': 'atn-mock-002', 'nome': 'Mariana Oliveira Lima (ATN)', 'ativo': 1},
  {'id': 'atn-mock-003', 'nome': 'Roberto Alves de Menezes (ATN)', 'ativo': 1},
  {'id': 'atn-mock-004', 'nome': 'Fernanda Costa Ribeiro (ATN)', 'ativo': 1},
  {'id': 'atn-mock-005', 'nome': 'Lucas Gabriel Pereira (ATN)', 'ativo': 1},
];

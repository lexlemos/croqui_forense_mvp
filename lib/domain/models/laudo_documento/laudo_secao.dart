import 'laudo_bloco.dart';

/// Seção estruturada do laudo pericial oficial contendo blocos ordenados de conteúdo.
class LaudoSecao {
  final String id;
  final String? titulo;
  final List<LaudoBloco> blocos;

  const LaudoSecao({
    required this.id,
    this.titulo,
    this.blocos = const [],
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'blocos': blocos.map((b) => b.toJson()).toList(),
    };
    return map;
  }

  factory LaudoSecao.fromJson(Map<String, dynamic> json) => LaudoSecao(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        blocos: (json['blocos'] as List<dynamic>?)
                ?.map((b) => LaudoBloco.fromJson(b as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

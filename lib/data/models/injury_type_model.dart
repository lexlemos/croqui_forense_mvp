import 'dart:convert';

class InjuryType {
  final String id;
  final String label;
  final Map<String, dynamic> schemaFormulario;
  final int order;
  final bool isActive;
  final bool isInterno;

  InjuryType({
    required this.id,
    required this.label,
    this.schemaFormulario = const {},
    this.order = 0,
    this.isActive = true,
    this.isInterno = false,
  });

  factory InjuryType.fromMap(Map<String, dynamic> map) {
    final schemaRaw = map['schema_formulario_json'];
    Map<String, dynamic> schema = {};
    if (schemaRaw is String && schemaRaw.isNotEmpty) {
      try {
        schema = Map<String, dynamic>.from(jsonDecode(schemaRaw) as Map);
      } catch (_) {}
    } else if (schemaRaw is Map) {
      schema = Map<String, dynamic>.from(schemaRaw);
    }

    return InjuryType(
      id: map['id']?.toString() ?? '',
      label: map['nome']?.toString() ?? '',
      schemaFormulario: schema,
      order: map['ordem'] as int? ?? 0,
      isActive: (map['ativo'] as int? ?? 1) == 1,
      isInterno: (map['is_interno'] as int? ?? 0) == 1,
    );
  }

  factory InjuryType.fromJson(Map<String, dynamic> json) {
    final schemaRaw = json['schema_formulario_json'];
    Map<String, dynamic> schema = {};
    if (schemaRaw is Map) {
      schema = Map<String, dynamic>.from(schemaRaw);
    } else if (schemaRaw is String && schemaRaw.isNotEmpty) {
      try {
        schema = Map<String, dynamic>.from(jsonDecode(schemaRaw) as Map);
      } catch (_) {}
    }

    return InjuryType(
      id: json['id']?.toString() ?? '',
      label: json['nome']?.toString() ?? '',
      schemaFormulario: schema,
      order: json['ordem'] as int? ?? 0,
      isActive: true,
      isInterno: json['is_interno'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': label,
      'is_interno': isInterno ? 1 : 0,
      'schema_formulario_json': jsonEncode(schemaFormulario),
      'ordem': order,
      'ativo': isActive ? 1 : 0,
      'versao': 1,
      'atualizado_em': DateTime.now().toIso8601String(),
    };
  }
}
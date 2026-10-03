import 'package:uuid/uuid.dart';

enum TipoFerimento {
  entrada('Entrada'),
  saida('Saída'),
  raspao('Raspão'),
  indeterminado('Indeterminado');

  final String valor;
  const TipoFerimento(this.valor);

  static TipoFerimento? fromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final norm = value.trim().toLowerCase();
    for (final v in TipoFerimento.values) {
      if (v.valor.toLowerCase() == norm || v.name.toLowerCase() == norm) {
        return v;
      }
    }
    return TipoFerimento.indeterminado;
  }

  static List<String> get valores => TipoFerimento.values.map((e) => e.valor).toList();
}

enum TipoObjeto {
  projetil('Projétil'),
  estojo('Estojo'),
  fragmento('Fragmento'),
  balote('Balote'),
  chumboGrosso('Chumbo Grosso'),
  chumboFino('Chumbo Fino'),
  outro('Outro');

  final String valor;
  const TipoObjeto(this.valor);

  static TipoObjeto? fromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final norm = value.trim().toLowerCase();
    for (final v in TipoObjeto.values) {
      if (v.valor.toLowerCase() == norm || v.name.toLowerCase() == norm) {
        return v;
      }
    }
    return TipoObjeto.outro;
  }

  static List<String> get valores => TipoObjeto.values.map((e) => e.valor).toList();
}

class BalisticaModel {
  final String id;
  final String exameId;
  final String? achadoUuid;
  final String? tipoFerimento;
  final String? tipoObjeto;
  final String? numeroLacre;
  final String? comentarioAdicional;

  BalisticaModel({
    String? id,
    required this.exameId,
    this.achadoUuid,
    this.tipoFerimento,
    this.tipoObjeto,
    this.numeroLacre,
    this.comentarioAdicional,
  }) : id = id ?? const Uuid().v4();

  BalisticaModel copyWith({
    String? id,
    String? exameId,
    String? achadoUuid,
    String? tipoFerimento,
    String? tipoObjeto,
    String? numeroLacre,
    String? comentarioAdicional,
  }) {
    return BalisticaModel(
      id: id ?? this.id,
      exameId: exameId ?? this.exameId,
      achadoUuid: achadoUuid ?? this.achadoUuid,
      tipoFerimento: tipoFerimento ?? this.tipoFerimento,
      tipoObjeto: tipoObjeto ?? this.tipoObjeto,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      comentarioAdicional: comentarioAdicional ?? this.comentarioAdicional,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exame_id': exameId,
      if (tipoFerimento != null) 'tipo_ferimento': tipoFerimento,
      if (tipoObjeto != null) 'tipo_objeto': tipoObjeto,
      if (numeroLacre != null) 'numero_lacre': numeroLacre,
      if (comentarioAdicional != null) 'comentario_adicional': comentarioAdicional,
    };
  }

  factory BalisticaModel.fromMap(Map<String, dynamic> map) {
    return BalisticaModel(
      id: map['id']?.toString() ?? map['uuid']?.toString(),
      exameId: map['exame_id']?.toString() ?? map['caso_uuid']?.toString() ?? '',
      achadoUuid: (map['achado_uuid'] ?? map['achado_id'] ?? map['achadoUuid'])?.toString(),
      tipoFerimento: (map['tipo_ferimento'] ?? map['tipoFerimento'])?.toString(),
      tipoObjeto: (map['tipo_objeto'] ?? map['tipoObjeto'])?.toString(),
      numeroLacre: (map['numero_lacre'] ?? map['numeroLacre'])?.toString(),
      comentarioAdicional: (map['comentario_adicional'] ?? map['comentarioAdicional'])?.toString(),
    );
  }
}


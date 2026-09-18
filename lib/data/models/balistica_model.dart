import 'package:uuid/uuid.dart';

class BalisticaModel {
  final String id;
  final String exameId;
  final String? tipoFerimento;
  final String? tipoObjeto;
  final String? numeroLacre;
  final String? comentarioAdicional;

  BalisticaModel({
    String? id,
    required this.exameId,
    this.tipoFerimento,
    this.tipoObjeto,
    this.numeroLacre,
    this.comentarioAdicional,
  }) : id = id ?? const Uuid().v4();

  BalisticaModel copyWith({
    String? id,
    String? exameId,
    String? tipoFerimento,
    String? tipoObjeto,
    String? numeroLacre,
    String? comentarioAdicional,
  }) {
    return BalisticaModel(
      id: id ?? this.id,
      exameId: exameId ?? this.exameId,
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
      id: map['id'] ?? map['uuid'] as String?,
      exameId: map['caso_uuid']?.toString() ?? map['exame_id']?.toString() ?? '',
      tipoFerimento: map['tipo_ferimento'] as String?,
      tipoObjeto: map['tipo_objeto'] as String?,
      numeroLacre: map['numero_lacre'] as String?,
      comentarioAdicional: map['comentario_adicional'] as String?,
    );
  }
}

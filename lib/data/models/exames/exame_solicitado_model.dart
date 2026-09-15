import 'package:uuid/uuid.dart';

/// Modelo mestre para requisições de exames complementares periciais.
/// Suporta associação polimórfica com os detalhes específicos em memória via [detalhes].
class ExameSolicitadoModel {
  final String uuid;
  final String casoUuid;
  final String tipoExame; // 'TOXICOLOGICO', 'GENETICA', 'ANATOMO'
  final String? numeroLacre;
  final DateTime criadoEm;
  final String status;

  /// Objeto filho em memória para gerenciar detalhes específicos na UI.
  /// NÃO é serializado no [toMap].
  final dynamic detalhes;

  ExameSolicitadoModel({
    required this.uuid,
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    required this.criadoEm,
    this.status = 'aguardando',
    this.detalhes,
  });

  ExameSolicitadoModel.novo({
    required this.casoUuid,
    required this.tipoExame,
    this.numeroLacre,
    this.status = 'aguardando',
    this.detalhes,
  })  : uuid = const Uuid().v4(),
        criadoEm = DateTime.now();

  factory ExameSolicitadoModel.fromMap(Map<String, dynamic> map, {dynamic detalhes}) {
    return ExameSolicitadoModel(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      tipoExame: map['tipo_exame']?.toString() ?? '',
      numeroLacre: map['numero_lacre']?.toString(),
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'aguardando',
      detalhes: detalhes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'tipo_exame': tipoExame,
      'numero_lacre': numeroLacre,
      'criado_em': criadoEm.toIso8601String(),
      'status': status,
    };
  }

  ExameSolicitadoModel copyWith({
    String? uuid,
    String? casoUuid,
    String? tipoExame,
    String? numeroLacre,
    DateTime? criadoEm,
    String? status,
    dynamic detalhes,
  }) {
    return ExameSolicitadoModel(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      tipoExame: tipoExame ?? this.tipoExame,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      criadoEm: criadoEm ?? this.criadoEm,
      status: status ?? this.status,
      detalhes: detalhes ?? this.detalhes,
    );
  }
}

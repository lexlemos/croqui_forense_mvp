import 'package:uuid/uuid.dart';

class ExameSolicitado {
  final String uuid;
  final String casoUuid;
  final String tipoExame; // ex: 'ANATOMO', 'GENETICA', 'TOXICOLOGICO', 'OUTROS'
  final int quantidadeAmostras;
  final String numeroLacre;
  final DateTime criadoEm;

  ExameSolicitado({
    required this.uuid,
    required this.casoUuid,
    required this.tipoExame,
    this.quantidadeAmostras = 1,
    required this.numeroLacre,
    required this.criadoEm,
  });

  ExameSolicitado.novo({
    required this.casoUuid,
    required this.tipoExame,
    this.quantidadeAmostras = 1,
    required this.numeroLacre,
  })  : uuid = const Uuid().v4(),
        criadoEm = DateTime.now();

  factory ExameSolicitado.fromMap(Map<String, dynamic> map) {
    return ExameSolicitado(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      tipoExame: map['tipo_exame']?.toString() ?? '',
      quantidadeAmostras: map['quantidade_amostras'] as int? ?? 1,
      numeroLacre: map['numero_lacre']?.toString() ?? '',
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'tipo_exame': tipoExame,
      'quantidade_amostras': quantidadeAmostras,
      'numero_lacre': numeroLacre,
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  ExameSolicitado copyWith({
    String? uuid,
    String? casoUuid,
    String? tipoExame,
    int? quantidadeAmostras,
    String? numeroLacre,
    DateTime? criadoEm,
  }) {
    return ExameSolicitado(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      tipoExame: tipoExame ?? this.tipoExame,
      quantidadeAmostras: quantidadeAmostras ?? this.quantidadeAmostras,
      numeroLacre: numeroLacre ?? this.numeroLacre,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}

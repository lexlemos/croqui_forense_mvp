import 'dart:convert';

/// Modelo representativo do nó "auditoria" contido no `dados_laudo_json`.
class AuditoriaModel {
  final String? peritoResponsavel;
  final String? dataFinalizacao;

  AuditoriaModel({
    this.peritoResponsavel,
    this.dataFinalizacao,
  });

  factory AuditoriaModel.fromJson(Map<String, dynamic> json) {
    return AuditoriaModel(
      peritoResponsavel: json['perito_responsavel']?.toString(),
      dataFinalizacao: json['data_finalizacao']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (peritoResponsavel != null) 'perito_responsavel': peritoResponsavel,
      if (dataFinalizacao != null) 'data_finalizacao': dataFinalizacao,
    };
  }

  AuditoriaModel copyWith({
    String? peritoResponsavel,
    String? dataFinalizacao,
  }) {
    return AuditoriaModel(
      peritoResponsavel: peritoResponsavel ?? this.peritoResponsavel,
      dataFinalizacao: dataFinalizacao ?? this.dataFinalizacao,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

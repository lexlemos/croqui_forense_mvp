class Usuario {
  final int id;
  final String matriculaFuncional;
  final String nomeCompleto;
  final int papelId;
  final bool ativo;
  final String hashPinOffline;

  final DateTime criadoEm;
  final String? deviceId;

  Usuario({
    required this.id,
    required this.matriculaFuncional,
    required this.nomeCompleto,
    required this.papelId,
    required this.ativo,
    required this.hashPinOffline,
    required this.criadoEm,
    this.deviceId,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int,
      matriculaFuncional: map['matricula_funcional'] as String,
      nomeCompleto: map['nome_completo'] as String,
      papelId: map['papel_id'] as int,
      hashPinOffline: map['hash_pin_offline'] as String,
      ativo: (map['ativo'] as int) == 1, 
      criadoEm: DateTime.parse(map['criado_em'] as String),
      deviceId: map.containsKey('device_id') ? map['device_id'] as String? : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricula_funcional': matriculaFuncional,
      'nome_completo': nomeCompleto,
      'papel_id': papelId,
      'hash_pin_offline': hashPinOffline,
      'ativo': ativo ? 1 : 0, 
      'criado_em': criadoEm.toIso8601String(),
      'device_id': deviceId,
    };
  }
}


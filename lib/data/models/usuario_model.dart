class Usuario {
  final String id;
  final String matriculaFuncional;
  final String nomeCompleto;
  final String papelId;
  final bool ativo;
  final String? hashPinOffline;
  final bool deveAlterarPin;
  final String? salt;
  final DateTime criadoEm;
  final String? deviceId;

  Usuario({
    required this.id,
    required this.matriculaFuncional,
    required this.nomeCompleto,
    required this.papelId,
    required this.ativo,
    required this.hashPinOffline,
    required this.deveAlterarPin,
    required this.criadoEm,
    this.salt,
    this.deviceId,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as String,
      matriculaFuncional: map['matricula_funcional'] as String,
      nomeCompleto: map['nome_completo'] as String,
      papelId: map['papel_id'] as String,
      hashPinOffline: map['hash_pin_offline'] as String?,
      salt: map['salt'] as String?,
      ativo: (map['ativo'] as int) == 1, 
      deveAlterarPin: (map['deve_alterar_pin'] ?? 0) == 1,
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
      'deve_alterar_pin': deveAlterarPin ? 1 : 0,
      'ativo': ativo ? 1 : 0, 
      'criado_em': criadoEm.toIso8601String(),
      'salt': salt,
      'device_id': deviceId,
    };
    
  }
}


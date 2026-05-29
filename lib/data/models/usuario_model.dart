class Usuario {
  final String id;
  final String matriculaFuncional;
  final String nomeCompleto;
  final String crm;
  final String classe;
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
    required this.crm,
    required this.classe,
    this.salt,
    this.deviceId,
  });

  Usuario copyWith({
    String? id,
    String? matriculaFuncional,
    String? nomeCompleto,
    String? papelId,
    bool? ativo,
    String? hashPinOffline,
    bool? deveAlterarPin,
    String? salt,
    DateTime? criadoEm,
    String? deviceId,
    String? crm,
    String? classe,
  }) {
    return Usuario(
      id: id ?? this.id,
      matriculaFuncional: matriculaFuncional ?? this.matriculaFuncional,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      crm: crm ?? this.crm,
      classe: classe ?? this.classe,
      papelId: papelId ?? this.papelId,
      ativo: ativo ?? this.ativo,
      hashPinOffline: hashPinOffline ?? this.hashPinOffline,
      deveAlterarPin: deveAlterarPin ?? this.deveAlterarPin,
      salt: salt ?? this.salt,
      criadoEm: criadoEm ?? this.criadoEm,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id']?.toString() ?? '',
      matriculaFuncional: map['matricula_funcional']?.toString() ?? '',
      nomeCompleto: map['nome_completo']?.toString() ?? '',
      crm: map['crm']?.toString() ?? '',
      classe: map['classe']?.toString() ?? '',
      papelId: map['papel_id']?.toString() ?? '',
      hashPinOffline: map['hash_pin_offline']?.toString(),
      salt: map['salt']?.toString(),
      ativo: (map['ativo'] as int? ?? 0) == 1,
      deveAlterarPin: (map['deve_alterar_pin'] as int? ?? 0) == 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      deviceId: map['device_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricula_funcional': matriculaFuncional,
      'nome_completo': nomeCompleto,
      'papel_id': papelId,
      'crm': crm,
      'classe': classe,
      'hash_pin_offline': hashPinOffline,
      'deve_alterar_pin': deveAlterarPin ? 1 : 0,
      'ativo': ativo ? 1 : 0,
      'criado_em': criadoEm.toIso8601String(),
      'salt': salt,
      'device_id': deviceId,
    };
  }
}
import 'dart:convert';

class Usuario {
  final String id;
  final String matriculaFuncional;
  final String nomeCompleto;
  final List<String> roles;
  final bool ativo;
  final String? hashPinOffline;
  final String? salt;
  final DateTime criadoEm;
  final String? deviceId;

  Usuario({
    required this.id,
    required this.matriculaFuncional,
    required this.nomeCompleto,
    required this.roles,
    required this.ativo,
    required this.hashPinOffline,
    required this.criadoEm,
    this.salt,
    this.deviceId,
  });

  bool hasRole(String roleName) {
    return roles.any((role) => role.toUpperCase() == roleName.toUpperCase());
  }

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  Usuario copyWith({
    String? id,
    String? matriculaFuncional,
    String? nomeCompleto,
    List<String>? roles,
    bool? ativo,
    String? hashPinOffline,
    String? salt,
    DateTime? criadoEm,
    String? deviceId,
  }) {
    return Usuario(
      id: id ?? this.id,
      matriculaFuncional: matriculaFuncional ?? this.matriculaFuncional,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      roles: roles ?? this.roles,
      ativo: ativo ?? this.ativo,
      hashPinOffline: hashPinOffline ?? this.hashPinOffline,
      salt: salt ?? this.salt,
      criadoEm: criadoEm ?? this.criadoEm,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    List<String> parsedRoles = [];
    final rawRoles = map['roles'] ?? map['role'];
    if (rawRoles is List) {
      parsedRoles = rawRoles.map((e) => e.toString()).toList();
    } else if (rawRoles is String && rawRoles.isNotEmpty) {
      if (rawRoles.startsWith('[') && rawRoles.endsWith(']')) {
        try {
          final decoded = jsonDecode(rawRoles);
          if (decoded is List) {
            parsedRoles = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          parsedRoles = [rawRoles];
        }
      } else {
        parsedRoles = [rawRoles];
      }
    }

    return Usuario(
      id: map['id']?.toString() ?? map['usuario_id']?.toString() ?? '',
      matriculaFuncional: map['matricula_funcional']?.toString() ?? map['matricula']?.toString() ?? '',
      nomeCompleto: map['nome_completo']?.toString() ?? map['usuario_nome']?.toString() ?? map['nome']?.toString() ?? '',
      roles: parsedRoles,
      hashPinOffline: map['hash_pin_offline']?.toString(),
      salt: map['salt']?.toString(),
      ativo: (map['ativo'] as int? ?? 0) == 1 || map['ativo'] == true,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      deviceId: map['device_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricula_funcional': matriculaFuncional,
      'nome_completo': nomeCompleto,
      'roles': jsonEncode(roles),
      'hash_pin_offline': hashPinOffline,
      'ativo': ativo ? 1 : 0,
      'criado_em': criadoEm.toIso8601String(),
      'salt': salt,
      'device_id': deviceId,
    };
  }
}
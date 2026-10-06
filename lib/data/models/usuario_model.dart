import 'dart:convert';

/// Representação de domínio e persistência local de um usuário do sistema pericial (Perito, Médico Legista ou Administrador).
///
/// Encapsula credenciais, perfis de autorização ([roles]), estado de ativação e
/// parâmetros criptográficos ([hashPinOffline] e [salt]) empregados na autenticação
/// offline em contingências de campo sem sinal de rede.
class Usuario {
  /// Identificador único universal (UUID) do usuário na base de dados central e local.
  final String id;

  /// Matrícula institucional ou identificador funcional utilizado no login.
  final String matriculaFuncional;

  /// Nome civil completo do profissional.
  final String nomeCompleto;

  /// Lista de papéis e permissões atribuídos ao usuário (ex.: `PERITO`, `MEDICO_LEGISTA`, `ADMIN`).
  final List<String> roles;

  /// Indica se a conta do usuário está habilitada para operar o sistema.
  final bool ativo;

  /// Hash criptográfico do PIN/senha derivado localmente para validação offline.
  final String? hashPinOffline;

  /// Sal criptográfico aleatório associado ao [hashPinOffline].
  final String? salt;

  /// Timestamp do cadastro ou provisionamento do usuário no dispositivo.
  final DateTime criadoEm;

  /// Identificador exclusivo do dispositivo físico vinculado ao usuário, quando aplicável.
  final String? deviceId;

  /// Número de registro no Conselho Regional de Medicina, para Médicos Legistas.
  final String? crm;

  /// Classe ou nível funcional da carreira pericial.
  final String? classe;

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
    this.crm,
    this.classe,
  });

  /// Verifica se o usuário possui determinado perfil de autorização ([roleName]).
  ///
  /// A comparação é insensível a maiúsculas/minúsculas (`case-insensitive`).
  bool hasRole(String roleName) {
    return roles.any((role) => role.toUpperCase() == roleName.toUpperCase());
  }

  /// Construtor de conveniência para deserialização a partir de mapa JSON.
  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario.fromMap(json);

  /// Serializa a instância atual para mapa JSON.
  Map<String, dynamic> toJson() => toMap();

  /// Cria uma cópia imutável desta instância com os campos especificados atualizados.
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
    String? crm,
    String? classe,
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
      crm: crm ?? this.crm,
      classe: classe ?? this.classe,
    );
  }

  /// Reconstrói a instância de [Usuario] a partir de um registro do SQLite ou payload da API.
  ///
  /// Aplica tratamento defensivo da Lei de Postel:
  /// - Suporta [roles] serializadas como `List`, `String` simples ou `String` codificada em JSON array.
  /// - Converte campos booleanos (`ativo`) tanto no formato numérico do SQLite (`1`/`0`) quanto booleano do JSON.
  /// - Trata variações de chaves (`usuario_id`, `matricula`, `usuario_nome`).
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
      matriculaFuncional:
          map['matricula_funcional']?.toString() ??
          map['matricula']?.toString() ??
          '',
      nomeCompleto:
          map['nome_completo']?.toString() ??
          map['usuario_nome']?.toString() ??
          map['nome']?.toString() ??
          '',
      roles: parsedRoles,
      hashPinOffline: map['hash_pin_offline']?.toString(),
      salt: map['salt']?.toString(),
      ativo: (map['ativo'] as int? ?? 0) == 1 || map['ativo'] == true,
      criadoEm:
          DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
      deviceId: map['device_id']?.toString(),
      crm: map['crm']?.toString(),
      classe: map['classe']?.toString(),
    );
  }

  /// Converte a entidade para o formato de persistência relacional do banco de dados local SQLite.
  ///
  /// Serializa [roles] como JSON array e o booleano [ativo] como inteiro binário (`1`/`0`).
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
      'crm': crm,
      'classe': classe,
    };
  }
}

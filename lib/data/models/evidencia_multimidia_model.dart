import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class EvidenciaMultimidia {
  final String uuid;
  final String casoUuid;
  final String? achadoUuid; // Nullable for general case photos
  final String? substituidaPor;
  final String tipo; // 'GERAL' or 'ACHADO'
  final String? caminhoArquivoEncriptado;
  final String? hashArquivo;
  final bool fotoSincronizada;
  final bool removido;
  final int versao;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;
  final String? descricao; // Campo de descrição adicionado

  EvidenciaMultimidia({
    required this.uuid,
    required this.casoUuid,
    this.achadoUuid,
    this.substituidaPor,
    required this.tipo,
    this.caminhoArquivoEncriptado,
    this.hashArquivo,
    required this.fotoSincronizada,
    required this.removido,
    required this.versao,
    required this.criadoEm,
    this.atualizadoEm,
    this.descricao,
  });

  EvidenciaMultimidia.novo({
    required this.casoUuid,
    this.achadoUuid,
    required this.tipo,
    this.caminhoArquivoEncriptado,
    this.hashArquivo,
    this.descricao,
  })  : uuid = (caminhoArquivoEncriptado != null && caminhoArquivoEncriptado.isNotEmpty && !caminhoArquivoEncriptado.startsWith('http')) 
            ? p.basenameWithoutExtension(caminhoArquivoEncriptado) 
            : const Uuid().v4(),
        substituidaPor = null,
        fotoSincronizada = false,
        removido = false,
        versao = 1,
        criadoEm = DateTime.now(),
        atualizadoEm = null;

  factory EvidenciaMultimidia.fromMap(Map<String, dynamic> map) {
    final pathOrUrl = map['caminho_arquivo_encriptado']?.toString() ??
        map['url']?.toString() ??
        map['path']?.toString() ??
        map['url_foto']?.toString() ??
        map['url_arquivo']?.toString();

    return EvidenciaMultimidia(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid: map['caso_uuid']?.toString() ?? '',
      achadoUuid: map['achado_uuid']?.toString(),
      substituidaPor: map['substituida_por']?.toString(),
      tipo: map['tipo']?.toString() ?? 'ACHADO',
      caminhoArquivoEncriptado: pathOrUrl,
      hashArquivo: map['hash_arquivo']?.toString(),
      fotoSincronizada: map['foto_sincronizada'] is bool
          ? map['foto_sincronizada'] as bool
          : (map['foto_sincronizada'] as int? ?? 1) == 1,
      removido: map['removido'] is bool
          ? map['removido'] as bool
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null ? DateTime.tryParse(map['atualizado_em'].toString()) : null,
      descricao: map['descricao']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'achado_uuid': achadoUuid,
      'substituida_por': substituidaPor,
      'tipo': tipo,
      'caminho_arquivo_encriptado': caminhoArquivoEncriptado,
      'hash_arquivo': hashArquivo,
      'foto_sincronizada': fotoSincronizada ? 1 : 0,
      'removido': removido ? 1 : 0,
      'versao': versao,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': updatedDateTimeString(),
      'descricao': descricao,
    };
  }

  String? updatedDateTimeString() => atualizadoEm?.toIso8601String();

  Map<String, dynamic> toSyncMap() {
    return {
      'uuid': uuid,
      'caso_uuid': casoUuid,
      'achado_uuid': achadoUuid,
      'substituida_por': substituidaPor,
      'tipo': tipo,
      'caminho_arquivo_encriptado': caminhoArquivoEncriptado,
      'hash_arquivo': hashArquivo,
      'foto_sincronizada': fotoSincronizada,
      'removido': removido,
      'versao': versao,
      'criado_em': criadoEm.toUtc().toIso8601String(),
      'atualizado_em': (atualizadoEm ?? criadoEm).toUtc().toIso8601String(),
      'descricao': descricao,
    };
  }

  EvidenciaMultimidia copyWith({
    String? uuid,
    String? casoUuid,
    String? achadoUuid,
    String? substituidaPor,
    String? tipo,
    String? caminhoArquivoEncriptado,
    String? hashArquivo,
    bool? fotoSincronizada,
    bool? removido,
    int? versao,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    String? descricao,
  }) {
    return EvidenciaMultimidia(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      achadoUuid: achadoUuid ?? this.achadoUuid,
      substituidaPor: substituidaPor ?? this.substituidaPor,
      tipo: tipo ?? this.tipo,
      caminhoArquivoEncriptado: caminhoArquivoEncriptado ?? this.caminhoArquivoEncriptado,
      hashArquivo: hashArquivo ?? this.hashArquivo,
      fotoSincronizada: fotoSincronizada ?? this.fotoSincronizada,
      removido: removido ?? this.removido,
      versao: versao ?? this.versao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      descricao: descricao ?? this.descricao,
    );
  }
}

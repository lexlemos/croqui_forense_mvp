import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:croqui_forense_mvp/core/utils/storage_path_helper.dart';

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
  final String? chaveStorage; // Chave de armazenamento no bucket (MinIO/S3)
  final String? urlStorage; // URL assinada de acesso temporário

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
    this.chaveStorage,
    this.urlStorage,
  });

  EvidenciaMultimidia.novo({
    required this.casoUuid,
    this.achadoUuid,
    required this.tipo,
    this.caminhoArquivoEncriptado,
    this.hashArquivo,
    this.descricao,
    this.chaveStorage,
    this.urlStorage,
  }) : uuid =
           (caminhoArquivoEncriptado != null &&
               caminhoArquivoEncriptado.isNotEmpty &&
               !caminhoArquivoEncriptado.startsWith('http'))
           ? p.basenameWithoutExtension(caminhoArquivoEncriptado)
           : const Uuid().v4(),
       substituidaPor = null,
       fotoSincronizada = false,
       removido = false,
       versao = 1,
       criadoEm = DateTime.now(),
       atualizadoEm = null;

  factory EvidenciaMultimidia.fromMap(Map<String, dynamic> map) {
    final rawPathOrUrl =
        map['caminho_arquivo_encriptado']?.toString() ??
        map['url']?.toString() ??
        map['path']?.toString() ??
        map['url_foto']?.toString() ??
        map['url_arquivo']?.toString();

    final chave =
        map['chave_storage']?.toString() ?? map['chaveStorage']?.toString();
    final urlAssinada =
        map['url_storage']?.toString() ??
        map['urlStorage']?.toString() ??
        map['url_assinada']?.toString() ??
        map['urlAssinada']?.toString();

    // Invariante 3: referências remotas nunca poluem caminhoArquivoEncriptado.
    final String? pathLocal = StoragePathHelper.isLocalFilePath(rawPathOrUrl)
        ? rawPathOrUrl
        : (StoragePathHelper.isLocalFilePath(
                map['caminho_arquivo_encriptado']?.toString(),
              )
              ? map['caminho_arquivo_encriptado']?.toString()
              : null);

    final String? chaveFinal =
        chave ??
        (StoragePathHelper.isRemoteKeyOrUrl(rawPathOrUrl) &&
                !rawPathOrUrl!.startsWith('http')
            ? rawPathOrUrl
            : null);
    final String? urlFinal =
        urlAssinada ??
        (rawPathOrUrl != null && rawPathOrUrl.startsWith('http')
            ? rawPathOrUrl
            : null);

    return EvidenciaMultimidia(
      uuid: map['uuid']?.toString() ?? '',
      casoUuid:
          map['caso_uuid']?.toString() ?? map['exame_id']?.toString() ?? '',
      achadoUuid: map['achado_uuid']?.toString(),
      substituidaPor: map['substituida_por']?.toString(),
      tipo: map['tipo']?.toString() ?? 'ACHADO',
      caminhoArquivoEncriptado: pathLocal,
      hashArquivo: map['hash_arquivo']?.toString(),
      fotoSincronizada: map['foto_sincronizada'] is bool
          ? map['foto_sincronizada'] as bool
          : (map['foto_sincronizada'] as int? ?? 1) == 1,
      removido: map['removido'] is bool
          ? map['removido'] as bool
          : (map['removido'] as int? ?? 0) == 1,
      versao: map['versao'] as int? ?? 1,
      criadoEm:
          DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
      atualizadoEm: map['atualizado_em'] != null
          ? DateTime.tryParse(map['atualizado_em'].toString())
          : null,
      descricao: map['descricao']?.toString(),
      chaveStorage: chaveFinal,
      urlStorage: urlFinal,
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
      'chave_storage': chaveStorage,
      'url_storage': urlStorage,
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
      'chave_storage': chaveStorage,
      'url_storage': urlStorage,
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
    String? chaveStorage,
    String? urlStorage,
  }) {
    return EvidenciaMultimidia(
      uuid: uuid ?? this.uuid,
      casoUuid: casoUuid ?? this.casoUuid,
      achadoUuid: achadoUuid ?? this.achadoUuid,
      substituidaPor: substituidaPor ?? this.substituidaPor,
      tipo: tipo ?? this.tipo,
      caminhoArquivoEncriptado:
          caminhoArquivoEncriptado ?? this.caminhoArquivoEncriptado,
      hashArquivo: hashArquivo ?? this.hashArquivo,
      fotoSincronizada: fotoSincronizada ?? this.fotoSincronizada,
      removido: removido ?? this.removido,
      versao: versao ?? this.versao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      descricao: descricao ?? this.descricao,
      chaveStorage: chaveStorage ?? this.chaveStorage,
      urlStorage: urlStorage ?? this.urlStorage,
    );
  }
}

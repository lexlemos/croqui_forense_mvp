/// Bloco base selado para o modelo neutro de conteúdo do laudo pericial oficial.
///
/// Implementa a especificação dos 7 tipos de bloco definidos no contrato `laudo-pacote/1`.
sealed class LaudoBloco {
  const LaudoBloco();

  String get tipo;

  Map<String, dynamic> toJson();

  factory LaudoBloco.fromJson(Map<String, dynamic> json) {
    final tipo = json['tipo'] as String?;
    switch (tipo) {
      case 'titulo':
        return LaudoTituloBloco.fromJson(json);
      case 'paragrafo':
        return LaudoParagrafoBloco.fromJson(json);
      case 'item':
        return LaudoItemBloco.fromJson(json);
      case 'bullet':
        return LaudoBulletBloco.fromJson(json);
      case 'grupo_achados':
        return LaudoGrupoAchadosBloco.fromJson(json);
      case 'imagem':
        return LaudoImagemBloco.fromJson(json);
      case 'assinatura':
        return LaudoAssinaturaBloco.fromJson(json);
      default:
        throw FormatException('Tipo de bloco desconhecido: "$tipo"');
    }
  }
}

/// Bloco de título com nível hierárquico (1 para seções, 2 e 3 para subseções).
class LaudoTituloBloco extends LaudoBloco {
  final String texto;
  final int nivel;

  const LaudoTituloBloco({
    required this.texto,
    this.nivel = 1,
  });

  @override
  String get tipo => 'titulo';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'texto': texto,
        'nivel': nivel,
      };

  factory LaudoTituloBloco.fromJson(Map<String, dynamic> json) => LaudoTituloBloco(
        texto: json['texto'] as String,
        nivel: (json['nivel'] as num?)?.toInt() ?? 1,
      );
}

/// Bloco de parágrafo corrido com estilo e recuo opcionais.
class LaudoParagrafoBloco extends LaudoBloco {
  final String texto;
  final String? estilo; // 'normal' | 'negrito' | 'italico'
  final double? recuo;

  const LaudoParagrafoBloco({
    required this.texto,
    this.estilo,
    this.recuo,
  });

  @override
  String get tipo => 'paragrafo';

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'tipo': tipo,
      'texto': texto,
    };
    if (estilo != null) map['estilo'] = estilo;
    if (recuo != null) map['recuo'] = recuo;
    return map;
  }

  factory LaudoParagrafoBloco.fromJson(Map<String, dynamic> json) => LaudoParagrafoBloco(
        texto: json['texto'] as String,
        estilo: json['estilo'] as String?,
        recuo: (json['recuo'] as num?)?.toDouble(),
      );
}

/// Bloco de item com rótulo em negrito e valor associado.
class LaudoItemBloco extends LaudoBloco {
  final String label;
  final String valor;

  const LaudoItemBloco({
    required this.label,
    required this.valor,
  });

  @override
  String get tipo => 'item';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'label': label,
        'valor': valor,
      };

  factory LaudoItemBloco.fromJson(Map<String, dynamic> json) => LaudoItemBloco(
        label: json['label'] as String,
        valor: json['valor'] as String,
      );
}

/// Bloco de marcador (bullet point).
class LaudoBulletBloco extends LaudoBloco {
  final String texto;

  const LaudoBulletBloco({
    required this.texto,
  });

  @override
  String get tipo => 'bullet';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'texto': texto,
      };

  factory LaudoBulletBloco.fromJson(Map<String, dynamic> json) => LaudoBulletBloco(
        texto: json['texto'] as String,
      );
}

/// Campo extra formatado como label: valor secundário no achado pericial.
class LaudoCampoExtra {
  final String label;
  final String valor;

  const LaudoCampoExtra({
    required this.label,
    required this.valor,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'valor': valor,
      };

  factory LaudoCampoExtra.fromJson(Map<String, dynamic> json) => LaudoCampoExtra(
        label: json['label'] as String,
        valor: json['valor'] as String,
      );
}

/// Item descritivo de achado/lesão pertencente a um grupo anatômico.
class LaudoAchadoItem {
  final int numeroSequencial;
  final String texto;
  final int? fotoNumero;
  final List<LaudoCampoExtra> campos;

  const LaudoAchadoItem({
    required this.numeroSequencial,
    required this.texto,
    this.fotoNumero,
    this.campos = const [],
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'numero_sequencial': numeroSequencial,
      'texto': texto,
    };
    if (fotoNumero != null) map['foto_numero'] = fotoNumero;
    if (campos.isNotEmpty) {
      map['campos'] = campos.map((c) => c.toJson()).toList();
    }
    return map;
  }

  factory LaudoAchadoItem.fromJson(Map<String, dynamic> json) => LaudoAchadoItem(
        numeroSequencial: (json['numero_sequencial'] as num).toInt(),
        texto: json['texto'] as String,
        fotoNumero: (json['foto_numero'] as num?)?.toInt(),
        campos: (json['campos'] as List<dynamic>?)
                ?.map((c) => LaudoCampoExtra.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Bloco estruturado de achados agrupados por região anatômica.
class LaudoGrupoAchadosBloco extends LaudoBloco {
  final String titulo;
  final String textoVazio;
  final String textoIntro;
  final List<LaudoAchadoItem> achados;

  const LaudoGrupoAchadosBloco({
    required this.titulo,
    required this.textoVazio,
    required this.textoIntro,
    this.achados = const [],
  });

  @override
  String get tipo => 'grupo_achados';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'titulo': titulo,
        'texto_vazio': textoVazio,
        'texto_intro': textoIntro,
        'achados': achados.map((a) => a.toJson()).toList(),
      };

  factory LaudoGrupoAchadosBloco.fromJson(Map<String, dynamic> json) => LaudoGrupoAchadosBloco(
        titulo: json['titulo'] as String,
        textoVazio: json['texto_vazio'] as String,
        textoIntro: json['texto_intro'] as String,
        achados: (json['achados'] as List<dynamic>?)
                ?.map((a) => LaudoAchadoItem.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Bloco de imagem (referência cruzada para foto ou croqui rasterizado).
class LaudoImagemBloco extends LaudoBloco {
  final String ref; // ex: 'foto:4' ou 'croqui:frente'

  const LaudoImagemBloco({
    required this.ref,
  });

  @override
  String get tipo => 'imagem';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'ref': ref,
      };

  factory LaudoImagemBloco.fromJson(Map<String, dynamic> json) => LaudoImagemBloco(
        ref: json['ref'] as String,
      );
}

/// Bloco de fecho formal e encerramento do laudo.
class LaudoAssinaturaBloco extends LaudoBloco {
  final String cidade;
  final String data;

  const LaudoAssinaturaBloco({
    required this.cidade,
    required this.data,
  });

  @override
  String get tipo => 'assinatura';

  @override
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'cidade': cidade,
        'data': data,
      };

  factory LaudoAssinaturaBloco.fromJson(Map<String, dynamic> json) => LaudoAssinaturaBloco(
        cidade: json['cidade'] as String,
        data: json['data'] as String,
      );
}

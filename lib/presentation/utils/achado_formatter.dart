import 'dart:convert';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

extension AchadoUiFormatter on Achado {
  List<Map<String, String>> obterCamposFormatados(
    Map<String, dynamic>? schemaBase, {
    List<Achado>? todosAchados,
  }) {
    final List<Map<String, String>> campos = [];
    final Map<String, Achado>? achadosMap = todosAchados != null
        ? {for (var a in todosAchados) a.uuid: a}
        : null;

    final tam = tamanho.trim();
    if (tam.isNotEmpty) {
      final bool hasUnit = RegExp(r'[a-zA-Z]$').hasMatch(tam);
      final valorFormatado = hasUnit ? tam : '$tam cm';
      campos.add({'label': 'Tamanho', 'valor': valorFormatado});
    }

    final prof = profundidade.trim();
    if (prof.isNotEmpty) {
      campos.add({'label': 'Profundidade', 'valor': prof});
    }

    if (achadoRelacionadoUuid != null && achadoRelacionadoUuid!.isNotEmpty) {
      String valorVinculo = 'Vinculado (ID: ${achadoRelacionadoUuid!.length >= 8 ? achadoRelacionadoUuid!.substring(0, 8) : achadoRelacionadoUuid})';
      if (achadosMap != null && achadosMap.containsKey(achadoRelacionadoUuid)) {
        final achadoEncontrado = achadosMap[achadoRelacionadoUuid]!;
        valorVinculo = 'Achado nº ${achadoEncontrado.numeroSequencial} (${achadoEncontrado.type})';
      }
      campos.add({
        'label': 'Orifício de Entrada Vinculado',
        'valor': valorVinculo,
      });
    }

    final rawFields = dadosPreenchidos['dados_dinamicos_json'] ?? dadosPreenchidos['dynamicFields'];
    Map<String, dynamic>? dynamicFields;
    if (rawFields is Map) {
      dynamicFields = Map<String, dynamic>.from(rawFields);
    } else if (rawFields is String && rawFields.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFields);
        if (decoded is Map) {
          dynamicFields = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    if (dynamicFields != null) {
      final List<Map<String, dynamic>> schemaCampos = [];
      if (schemaBase != null) {
        final schemaCamposRaw = schemaBase['campos'];
        if (schemaCamposRaw is List) {
          for (var c in schemaCamposRaw) {
            if (c is Map) {
              schemaCampos.add(Map<String, dynamic>.from(c));
            }
          }
        }
      }

      const Set<String> chavesIgnoradas = {
        'photo_path', 'photoPath', 'view', 'local_anatomico_id', 
        'local_anatomico_nome', 'type_label', 'typeId', 'is_interno', 
        'isInterno', 'achadoRelacionadoUuid',
      };

      dynamicFields.forEach((key, val) {
        final keyStr = key.toString();
        
        if (keyStr.startsWith('_') || val == null || (val is String && val.trim().isEmpty)) {
          return;
        }
        
        if (chavesIgnoradas.contains(keyStr)) {
          return;
        }

        String label = '';
        if (schemaCampos.isNotEmpty) {
          final campoSchema = schemaCampos.firstWhere(
            (c) => c['id_campo']?.toString() == keyStr,
            orElse: () => <String, dynamic>{},
          );
          if (campoSchema.isNotEmpty) {
            label = campoSchema['label']?.toString() ?? '';
          }
        }

        if (label.isEmpty) {
          final words = keyStr.split('_');
          label = words.map((w) {
            if (w.isEmpty) return '';
            return w[0].toUpperCase() + w.substring(1);
          }).join(' ');
        }

        String valorStr = '';
        if (val is bool) {
          valorStr = val ? 'Sim' : 'Não';
        } else {
          final valStr = val.toString();
          bool traduzido = false;
          if (achadosMap != null && achadosMap.containsKey(valStr)) {
            final achadoEncontrado = achadosMap[valStr]!;
            valorStr = 'Achado nº ${achadoEncontrado.numeroSequencial} (${achadoEncontrado.type})';
            traduzido = true;
          }
          if (!traduzido) {
            valorStr = valStr;
          }
        }

        campos.add({'label': label, 'valor': valorStr});
      });
    }

    return campos;
  }
}

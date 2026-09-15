import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';

/// DTO (Data Transfer Object) estritamente tipado que encapsula a árvore 
/// hierárquica de um [Caso] (Laudo) pericial pós-parseamento.
/// 
/// Otimizado para trafegar do Background Isolate para a Main Thread 
/// sem gargalos de conversão.
class ParsedSyncPayload {
  final Caso caso;
  final List<Achado> achados;
  final List<EvidenciaMultimidia> evidencias;
  final Map<String, dynamic> rawJson;

  const ParsedSyncPayload({
    required this.caso,
    required this.achados,
    required this.evidencias,
    required this.rawJson,
  });
}

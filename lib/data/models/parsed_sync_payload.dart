import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';

/// DTO (Data Transfer Object) estritamente tipado que encapsula a árvore
/// hierárquica completa de um laudo pericial ([Caso]) pós-parseamento em Isolate secundário.
///
/// Otimizado para trafegar do Background Isolate (`compute`) para a Main Thread
/// sem sobrecarga de serialização ou bloqueio de renderização da interface.
class ParsedSyncPayload {
  /// Entidade mestre do laudo pericial com metadados clínicos e balística reconciliada.
  final Caso caso;

  /// Coleção de lesões corporais e orifícios ([Achado]s) vinculados ao laudo.
  final List<Achado> achados;

  /// Coleção de evidências fotográficas e mídias periciais vinculadas ao caso e aos achados.
  final List<EvidenciaMultimidia> evidencias;

  /// Payload JSON original bruto recebido do endpoint `GET /sync/pull`, preservado para auditoria e timestamps.
  final Map<String, dynamic> rawJson;

  const ParsedSyncPayload({
    required this.caso,
    required this.achados,
    required this.evidencias,
    required this.rawJson,
  });
}


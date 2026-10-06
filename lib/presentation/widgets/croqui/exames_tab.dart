import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/status_atn_badge.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/toxicologico_form_widget.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/genetica_form_widget.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/anatomo_form_widget.dart';

/// Aba de formulários dedicada exclusivamente à requisição e detalhamento de Exames Complementares.
///
/// **Atenção: roda na UI thread.**
///
/// ### Arquitetura e Lógicas Condicionais:
/// - **Controle de Leitura/Edição ([readOnly])**: Avalia se o laudo está em status finalizado ou sincronizado
///   para desabilitar checkboxes, campos de lacres e formulários aninhados.
/// - **Badges de Conferência ATN ([StatusAtnBadge])**: Exibidos ao lado do título de cada exame solicitado
///   para indicar se o Auxiliar Técnico de Necrópsia já confirmou, visualizou, recusou ou se o item está pendente.
/// - **Auditoria de Recusa ([JustificativaRecusaBox])**: Renderizado condicionalmente caso
///   `statusConfirmacaoAtn == StatusConfirmacaoATN.RECUSADO` e haja justificativa preenchida, alertando o perito
///   sobre eventuais inconformidades nas amostras ou recipientes.
/// - **Persistência Reativa**: Todas as alterações nos formulários invocam [CroquiController.salvarExamesModel],
///   disparando atualização no SQLite e incremento no motor OCC de sincronização.
class ExamesTab extends StatelessWidget {
  const ExamesTab({super.key});


  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CroquiController>();
    final examesList = controller.casoAtual.exames;
    final bool readOnly = controller.isReadOnly;

    // DIAGNÓSTICO: verificar se readOnly está travando a aba
    debugPrint(
      '🔍 [EXAMES_TAB BUILD] readOnly=$readOnly | exames=${examesList.length} | status=${controller.casoAtual.status}',
    );

    ExameSolicitadoModel? toxicologicoExam;
    ExameSolicitadoModel? geneticaExam;
    ExameSolicitadoModel? anatomoExam;

    for (final e in examesList) {
      if (e.tipoExame == 'TOXICOLOGICO') {
        toxicologicoExam = e;
      } else if (e.tipoExame == 'GENETICA') {
        geneticaExam = e;
      } else if (e.tipoExame == 'ANATOMO') {
        anatomoExam = e;
      }
    }

    final bool solicitarToxicologico = toxicologicoExam != null;
    final bool solicitarGenetica = geneticaExam != null;
    final bool solicitarAnatomo = anatomoExam != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Título Principal da Aba
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.science_outlined,
                  color: Colors.indigo.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exames Complementares',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Selecione e detalhe as requisições de perícia laboratorial',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // ── 1. BLOCO TOXICOLÓGICO (Roxo) ─────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.purple.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Solicitar Exame Toxicológico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (toxicologicoExam != null) ...[
                        const SizedBox(width: 8),
                        StatusAtnBadge(
                          status: toxicologicoExam.statusConfirmacaoAtn,
                        ),
                      ],
                    ],
                  ),
                  subtitle: const Text(
                    'Pesquisa de substâncias químicas, drogas, venenos e fármacos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: solicitarToxicologico,
                  enabled: !readOnly,
                  activeColor: Colors.purple.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          final newList = List<ExameSolicitadoModel>.from(
                            controller.casoAtual.exames,
                          );
                          final checked = val ?? false;
                          if (checked) {
                            final idx = newList.indexWhere(
                              (e) => e.tipoExame == 'TOXICOLOGICO',
                            );
                            if (idx == -1) {
                              final novoExame = ExameSolicitadoModel.novo(
                                casoUuid: controller.casoAtual.uuid,
                                tipoExame: 'TOXICOLOGICO',
                              );
                              newList.add(
                                novoExame.copyWith(
                                  detalhes: DetalhesToxicologicoModel.novo(
                                    exameUuid: novoExame.uuid,
                                  ),
                                ),
                              );
                            }
                          } else {
                            newList.removeWhere(
                              (e) => e.tipoExame == 'TOXICOLOGICO',
                            );
                          }
                          controller.salvarExamesModel(newList);
                        },
                ),
                if (toxicologicoExam != null &&
                    toxicologicoExam.statusConfirmacaoAtn ==
                        StatusConfirmacaoATN.RECUSADO &&
                    toxicologicoExam.justificativaRecusa != null &&
                    toxicologicoExam.justificativaRecusa!.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                    child: JustificativaRecusaBox(
                      justificativa: toxicologicoExam.justificativaRecusa!,
                    ),
                  ),
                ],
                if (solicitarToxicologico) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextFormField(
                      key: ValueKey('lacre_tox_${toxicologicoExam.uuid}'),
                      initialValue: toxicologicoExam.numeroLacre ?? '',
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Nº do Lacre (Principal/Envelope)',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'TOXICOLOGICO',
                        );
                        if (idx != -1) {
                          newList[idx] = newList[idx].copyWith(
                            numeroLacre: val.trim(),
                          );
                          controller.salvarExamesModel(newList);
                          controller.scheduleAutoSave();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ToxicologicoFormWidget(
                      readOnly: readOnly,
                      initialData:
                          toxicologicoExam.detalhes is DetalhesToxicologicoModel
                          ? toxicologicoExam.detalhes
                                as DetalhesToxicologicoModel
                          : null,
                      onChanged: (novosDetalhes) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'TOXICOLOGICO',
                        );
                        if (idx != -1) {
                          final parentUuid = newList[idx].uuid;
                          newList[idx] = newList[idx].copyWith(
                            detalhes: novosDetalhes.copyWith(
                              exameUuid: parentUuid,
                            ),
                          );
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'TOXICOLOGICO',
                          );
                          newList.add(
                            novoExame.copyWith(
                              detalhes: novosDetalhes.copyWith(
                                exameUuid: novoExame.uuid,
                              ),
                            ),
                          );
                        }
                        debugPrint('--- DUMB TEST UI [TOXICOLOGICO] ---');
                        for (final e in newList) {
                          debugPrint(
                            'Tipo: ${e.tipoExame} | Detalhes is null? ${e.detalhes == null}',
                          );
                          if (e.detalhes != null) {
                            debugPrint('Conteudo: ${e.detalhes}');
                          }
                        }
                        debugPrint(
                          '🚨🚨🚨 ON_CHANGED ACIONADO NA TAB [TOXICOLOGICO]! Detalhes nulo? ${newList.firstWhere(
                                (e) => e.tipoExame == "TOXICOLOGICO",
                                orElse: () => ExameSolicitadoModel.novo(casoUuid: "", tipoExame: ""),
                              ).detalhes == null}',
                        );
                        controller.salvarExamesModel(newList);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. BLOCO GENÉTICO (Teal) ──────────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Solicitar Exame Genético e Biológico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (geneticaExam != null) ...[
                        const SizedBox(width: 8),
                        StatusAtnBadge(
                          status: geneticaExam.statusConfirmacaoAtn,
                        ),
                      ],
                    ],
                  ),
                  subtitle: const Text(
                    'Pesquisa de DNA, sêmen e swabs de amostras biológicas',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: solicitarGenetica,
                  enabled: !readOnly,
                  activeColor: Colors.teal.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          final newList = List<ExameSolicitadoModel>.from(
                            controller.casoAtual.exames,
                          );
                          final checked = val ?? false;
                          if (checked) {
                            final idx = newList.indexWhere(
                              (e) => e.tipoExame == 'GENETICA',
                            );
                            if (idx == -1) {
                              newList.add(
                                ExameSolicitadoModel.novo(
                                  casoUuid: controller.casoAtual.uuid,
                                  tipoExame: 'GENETICA',
                                  detalhes: <AmostraGeneticaModel>[],
                                ),
                              );
                            }
                          } else {
                            newList.removeWhere(
                              (e) => e.tipoExame == 'GENETICA',
                            );
                          }
                          controller.salvarExamesModel(newList);
                        },
                ),
                if (geneticaExam != null &&
                    geneticaExam.statusConfirmacaoAtn ==
                        StatusConfirmacaoATN.RECUSADO &&
                    geneticaExam.justificativaRecusa != null &&
                    geneticaExam.justificativaRecusa!.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                    child: JustificativaRecusaBox(
                      justificativa: geneticaExam.justificativaRecusa!,
                    ),
                  ),
                ],
                if (solicitarGenetica) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextFormField(
                      key: ValueKey('lacre_gen_${geneticaExam.uuid}'),
                      initialValue: geneticaExam.numeroLacre ?? '',
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Nº do Lacre (Principal/Envelope)',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'GENETICA',
                        );
                        if (idx != -1) {
                          newList[idx] = newList[idx].copyWith(
                            numeroLacre: val.trim(),
                          );
                          controller.salvarExamesModel(newList);
                          controller.scheduleAutoSave();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: GeneticaFormWidget(
                      readOnly: readOnly,
                      initialData:
                          geneticaExam.detalhes is List<AmostraGeneticaModel>
                          ? geneticaExam.detalhes as List<AmostraGeneticaModel>
                          : <AmostraGeneticaModel>[],
                      onChanged: (novasAmostras) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'GENETICA',
                        );
                        if (idx != -1) {
                          final parentUuid = newList[idx].uuid;
                          final amostrasCorrigidas = novasAmostras
                              .map((a) => a.copyWith(exameUuid: parentUuid))
                              .toList();
                          newList[idx] = newList[idx].copyWith(
                            detalhes: amostrasCorrigidas,
                          );
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'GENETICA',
                          );
                          final amostrasCorrigidas = novasAmostras
                              .map((a) => a.copyWith(exameUuid: novoExame.uuid))
                              .toList();
                          newList.add(
                            novoExame.copyWith(detalhes: amostrasCorrigidas),
                          );
                        }
                        debugPrint('--- DUMB TEST UI [GENETICA] ---');
                        for (final e in newList) {
                          debugPrint(
                            'Tipo: ${e.tipoExame} | Detalhes is null? ${e.detalhes == null}',
                          );
                          if (e.detalhes != null) {
                            debugPrint('Conteudo: ${e.detalhes}');
                          }
                        }
                        debugPrint(
                          '🚨🚨🚨 ON_CHANGED ACIONADO NA TAB [GENETICA]! Detalhes nulo? ${newList.firstWhere(
                                (e) => e.tipoExame == "GENETICA",
                                orElse: () => ExameSolicitadoModel.novo(casoUuid: "", tipoExame: ""),
                              ).detalhes == null}',
                        );
                        controller.salvarExamesModel(newList);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. BLOCO ANÁTOMO-PATOLÓGICO (Índigo) ─────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.indigo.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Solicitar Exame Anátomo-patológico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (anatomoExam != null) ...[
                        const SizedBox(width: 8),
                        StatusAtnBadge(
                          status: anatomoExam.statusConfirmacaoAtn,
                        ),
                      ],
                    ],
                  ),
                  subtitle: const Text(
                    'Amostras histopatológicas e órgãos acondicionados em frascos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: solicitarAnatomo,
                  enabled: !readOnly,
                  activeColor: Colors.indigo.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          final newList = List<ExameSolicitadoModel>.from(
                            controller.casoAtual.exames,
                          );
                          final checked = val ?? false;
                          if (checked) {
                            final idx = newList.indexWhere(
                              (e) => e.tipoExame == 'ANATOMO',
                            );
                            if (idx == -1) {
                              newList.add(
                                ExameSolicitadoModel.novo(
                                  casoUuid: controller.casoAtual.uuid,
                                  tipoExame: 'ANATOMO',
                                  detalhes: <FrascoAnatomoModel>[],
                                ),
                              );
                            }
                          } else {
                            newList.removeWhere(
                              (e) => e.tipoExame == 'ANATOMO',
                            );
                          }
                          controller.salvarExamesModel(newList);
                        },
                ),
                if (anatomoExam != null &&
                    anatomoExam.statusConfirmacaoAtn ==
                        StatusConfirmacaoATN.RECUSADO &&
                    anatomoExam.justificativaRecusa != null &&
                    anatomoExam.justificativaRecusa!.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                    child: JustificativaRecusaBox(
                      justificativa: anatomoExam.justificativaRecusa!,
                    ),
                  ),
                ],
                if (solicitarAnatomo) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextFormField(
                      key: ValueKey('lacre_ana_${anatomoExam.uuid}'),
                      initialValue: anatomoExam.numeroLacre ?? '',
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Nº do Lacre (Principal/Envelope)',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'ANATOMO',
                        );
                        if (idx != -1) {
                          newList[idx] = newList[idx].copyWith(
                            numeroLacre: val.trim(),
                          );
                          controller.salvarExamesModel(newList);
                          controller.scheduleAutoSave();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: AnatomoFormWidget(
                      readOnly: readOnly,
                      initialData:
                          anatomoExam.detalhes is List<FrascoAnatomoModel>
                          ? anatomoExam.detalhes as List<FrascoAnatomoModel>
                          : <FrascoAnatomoModel>[],
                      onChanged: (novosFrascos) {
                        final newList = List<ExameSolicitadoModel>.from(
                          controller.casoAtual.exames,
                        );
                        final idx = newList.indexWhere(
                          (e) => e.tipoExame == 'ANATOMO',
                        );
                        if (idx != -1) {
                          final parentUuid = newList[idx].uuid;
                          final frascosCorrigidos = novosFrascos
                              .map((f) => f.copyWith(exameUuid: parentUuid))
                              .toList();
                          newList[idx] = newList[idx].copyWith(
                            detalhes: frascosCorrigidos,
                          );
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'ANATOMO',
                          );
                          final frascosCorrigidos = novosFrascos
                              .map((f) => f.copyWith(exameUuid: novoExame.uuid))
                              .toList();
                          newList.add(
                            novoExame.copyWith(detalhes: frascosCorrigidos),
                          );
                        }
                        debugPrint('--- DUMB TEST UI [ANATOMO] ---');
                        for (final e in newList) {
                          debugPrint(
                            'Tipo: ${e.tipoExame} | Detalhes is null? ${e.detalhes == null}',
                          );
                          if (e.detalhes != null) {
                            debugPrint('Conteudo: ${e.detalhes}');
                          }
                        }
                        debugPrint(
                          '🚨🚨🚨 ON_CHANGED ACIONADO NA TAB [ANATOMO]! Detalhes nulo? ${newList.firstWhere(
                                (e) => e.tipoExame == "ANATOMO",
                                orElse: () => ExameSolicitadoModel.novo(casoUuid: "", tipoExame: ""),
                              ).detalhes == null}',
                        );
                        controller.salvarExamesModel(newList);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

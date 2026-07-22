import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/toxicologico_form_widget.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/genetica_form_widget.dart';
import 'package:croqui_forense_mvp/presentation/widgets/exames/anatomo_form_widget.dart';

/// Aba dedicada exclusivamente ao gerenciamento e requisição de Exames Complementares.
/// O número do lacre é capturado individualmente dentro de cada formulário de exame,
/// por amostra/recipiente físico (cadeia de custódia — Lei 13.964/19).
class ExamesTab extends StatefulWidget {
  const ExamesTab({super.key});

  @override
  State<ExamesTab> createState() => _ExamesTabState();
}

class _ExamesTabState extends State<ExamesTab> {
  late CroquiController _controller;
  List<ExameSolicitadoModel> _examesList = [];
  bool _solicitarToxicologico = false;
  bool _solicitarGenetica = false;
  bool _solicitarAnatomo = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _controller = context.watch<CroquiController>();
      _examesList = List.from(_controller.examesSolicitadosModel);

      _solicitarToxicologico = _examesList.any((e) => e.tipoExame == 'TOXICOLOGICO');
      _solicitarGenetica = _examesList.any((e) => e.tipoExame == 'GENETICA');
      _solicitarAnatomo = _examesList.any((e) => e.tipoExame == 'ANATOMO');

      _initialized = true;
    }
  }

  void _syncWithController() {
    // Fire-and-forget: persiste em background sem bloquear o ciclo de build.
    Future.microtask(() => _controller.salvarExamesModel(_examesList));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CroquiController>();
    final bool readOnly = controller.isReadOnly;

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
                child: Icon(Icons.science_outlined, color: Colors.indigo.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exames Complementares',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  title: const Text(
                    'Solicitar Exame Toxicológico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Pesquisa de substâncias químicas, drogas, venenos e fármacos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _solicitarToxicologico,
                  enabled: !readOnly,
                  activeColor: Colors.purple.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          setState(() {
                            _solicitarToxicologico = val ?? false;
                            if (_solicitarToxicologico) {
                              final idx = _examesList.indexWhere((e) => e.tipoExame == 'TOXICOLOGICO');
                              if (idx == -1) {
                                final novoExame = ExameSolicitadoModel.novo(
                                  casoUuid: controller.casoAtual.uuid,
                                  tipoExame: 'TOXICOLOGICO',
                                );
                                _examesList.add(
                                  novoExame.copyWith(
                                    detalhes: DetalhesToxicologicoModel.novo(exameUuid: novoExame.uuid),
                                  ),
                                );
                              }
                            } else {
                              _examesList.removeWhere((e) => e.tipoExame == 'TOXICOLOGICO');
                            }
                          });
                          _syncWithController();
                        },
                ),
                if (_solicitarToxicologico)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ToxicologicoFormWidget(
                      readOnly: readOnly,
                      initialData: () {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'TOXICOLOGICO');
                        if (idx != -1 && _examesList[idx].detalhes is DetalhesToxicologicoModel) {
                          return _examesList[idx].detalhes as DetalhesToxicologicoModel;
                        }
                        return null;
                      }(),
                      onChanged: (novosDetalhes) {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'TOXICOLOGICO');
                        if (idx != -1) {
                          final parentUuid = _examesList[idx].uuid;
                          _examesList[idx] = _examesList[idx].copyWith(
                            detalhes: novosDetalhes.copyWith(exameUuid: parentUuid),
                          );
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'TOXICOLOGICO',
                          );
                          _examesList.add(
                            novoExame.copyWith(
                              detalhes: novosDetalhes.copyWith(exameUuid: novoExame.uuid),
                            ),
                          );
                        }
                        _syncWithController();
                      },
                    ),
                  ),
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
                  title: const Text(
                    'Solicitar Exame Genético e Biológico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Pesquisa de DNA, sêmen e swabs de amostras biológicas',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _solicitarGenetica,
                  enabled: !readOnly,
                  activeColor: Colors.teal.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          setState(() {
                            _solicitarGenetica = val ?? false;
                            if (_solicitarGenetica) {
                              final idx = _examesList.indexWhere((e) => e.tipoExame == 'GENETICA');
                              if (idx == -1) {
                                _examesList.add(
                                  ExameSolicitadoModel.novo(
                                    casoUuid: controller.casoAtual.uuid,
                                    tipoExame: 'GENETICA',
                                    detalhes: <AmostraGeneticaModel>[],
                                  ),
                                );
                              }
                            } else {
                              _examesList.removeWhere((e) => e.tipoExame == 'GENETICA');
                            }
                          });
                          _syncWithController();
                        },
                ),
                if (_solicitarGenetica)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: GeneticaFormWidget(
                      readOnly: readOnly,
                      initialData: () {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'GENETICA');
                        if (idx != -1 && _examesList[idx].detalhes is List<AmostraGeneticaModel>) {
                          return _examesList[idx].detalhes as List<AmostraGeneticaModel>;
                        }
                        return <AmostraGeneticaModel>[];
                      }(),
                      onChanged: (novasAmostras) {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'GENETICA');
                        if (idx != -1) {
                          final parentUuid = _examesList[idx].uuid;
                          final amostrasCorrigidas = novasAmostras
                              .map((a) => a.copyWith(exameUuid: parentUuid))
                              .toList();
                          _examesList[idx] = _examesList[idx].copyWith(detalhes: amostrasCorrigidas);
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'GENETICA',
                          );
                          final amostrasCorrigidas = novasAmostras
                              .map((a) => a.copyWith(exameUuid: novoExame.uuid))
                              .toList();
                          _examesList.add(
                            novoExame.copyWith(detalhes: amostrasCorrigidas),
                          );
                        }
                        _syncWithController();
                      },
                    ),
                  ),
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
                  title: const Text(
                    'Solicitar Exame Anátomo-patológico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Amostras histopatológicas e órgãos acondicionados em frascos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _solicitarAnatomo,
                  enabled: !readOnly,
                  activeColor: Colors.indigo.shade700,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: readOnly
                      ? null
                      : (val) {
                          setState(() {
                            _solicitarAnatomo = val ?? false;
                            if (_solicitarAnatomo) {
                              final idx = _examesList.indexWhere((e) => e.tipoExame == 'ANATOMO');
                              if (idx == -1) {
                                _examesList.add(
                                  ExameSolicitadoModel.novo(
                                    casoUuid: controller.casoAtual.uuid,
                                    tipoExame: 'ANATOMO',
                                    detalhes: <FrascoAnatomoModel>[],
                                  ),
                                );
                              }
                            } else {
                              _examesList.removeWhere((e) => e.tipoExame == 'ANATOMO');
                            }
                          });
                          _syncWithController();
                        },
                ),
                if (_solicitarAnatomo)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: AnatomoFormWidget(
                      readOnly: readOnly,
                      initialData: () {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'ANATOMO');
                        if (idx != -1 && _examesList[idx].detalhes is List<FrascoAnatomoModel>) {
                          return _examesList[idx].detalhes as List<FrascoAnatomoModel>;
                        }
                        return <FrascoAnatomoModel>[];
                      }(),
                      onChanged: (novosFrascos) {
                        final idx = _examesList.indexWhere((e) => e.tipoExame == 'ANATOMO');
                        if (idx != -1) {
                          final parentUuid = _examesList[idx].uuid;
                          final frascosCorrigidos = novosFrascos
                              .map((f) => f.copyWith(exameUuid: parentUuid))
                              .toList();
                          _examesList[idx] = _examesList[idx].copyWith(detalhes: frascosCorrigidos);
                        } else {
                          final novoExame = ExameSolicitadoModel.novo(
                            casoUuid: controller.casoAtual.uuid,
                            tipoExame: 'ANATOMO',
                          );
                          final frascosCorrigidos = novosFrascos
                              .map((f) => f.copyWith(exameUuid: novoExame.uuid))
                              .toList();
                          _examesList.add(
                            novoExame.copyWith(detalhes: frascosCorrigidos),
                          );
                        }
                        _syncWithController();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

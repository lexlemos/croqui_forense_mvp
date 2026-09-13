import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';

/// Widget de formulário isolado para requisição de exames genéticos e biológicos.
class GeneticaFormWidget extends StatefulWidget {
  final List<AmostraGeneticaModel> initialData;
  final ValueChanged<List<AmostraGeneticaModel>> onChanged;
  final bool readOnly;

  const GeneticaFormWidget({
    super.key,
    this.initialData = const [],
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<GeneticaFormWidget> createState() => _GeneticaFormWidgetState();
}

class _GeneticaFormWidgetState extends State<GeneticaFormWidget> {
  late List<AmostraGeneticaModel> _amostras;

  // Tipos fixos predefinidos
  static const String _kSwabVaginalSemen = 'SWAB_VAGINAL_1';
  static const String _kSwabVaginalDna = 'SWAB_VAGINAL_2';
  static const String _kSwabAnalSemen = 'SWAB_ANAL_1';
  static const String _kSwabAnalDna = 'SWAB_ANAL_2';
  static const String _kSwabBucalVitima = 'SWAB_BUCAL_VITIMA';

  @override
  void initState() {
    super.initState();
    _amostras = List.from(widget.initialData);
  }

  @override
  void didUpdateWidget(covariant GeneticaFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      setState(() {
        _amostras = List.from(widget.initialData);
      });
    }
  }

  void _notifyChanges() {
    widget.onChanged(List.unmodifiable(_amostras));
  }

  bool _hasTipo(String tipo) {
    return _amostras.any((a) => a.tipoAmostra == tipo);
  }

  AmostraGeneticaModel? _getTipo(String tipo) {
    try {
      return _amostras.firstWhere((a) => a.tipoAmostra == tipo);
    } catch (_) {
      return null;
    }
  }

  void _toggleTipoFixa(String tipo, bool isChecked, {bool pesquisaSemen = false, bool pesquisaDna = false}) {
    setState(() {
      if (isChecked) {
        if (!_hasTipo(tipo)) {
          _amostras.add(
            AmostraGeneticaModel.novo(
              exameUuid: '',
              tipoAmostra: tipo,
              pesquisaSemen: pesquisaSemen,
              pesquisaDna: pesquisaDna,
              quantidadeSwabs: 1,
            ),
          );
        }
      } else {
        _amostras.removeWhere((a) => a.tipoAmostra == tipo);
      }
    });
    _notifyChanges();
  }

  void _updateTipoFixaQuantity(String tipo, int delta) {
    final idx = _amostras.indexWhere((a) => a.tipoAmostra == tipo);
    if (idx != -1) {
      final item = _amostras[idx];
      final novaQtd = (item.quantidadeSwabs + delta).clamp(1, 10);
      setState(() {
        _amostras[idx] = item.copyWith(quantidadeSwabs: novaQtd);
      });
      _notifyChanges();
    }
  }

  void _addAmostraOutro() {
    setState(() {
      _amostras.add(
        AmostraGeneticaModel.novo(
          exameUuid: '',
          tipoAmostra: 'OUTRO',
          descricaoOutro: '',
          pesquisaSemen: false,
          pesquisaDna: true,
          quantidadeSwabs: 1,
        ),
      );
    });
    _notifyChanges();
  }

  void _removeAmostraAt(int index) {
    setState(() {
      _amostras.removeAt(index);
    });
    _notifyChanges();
  }

  void _updateAmostraAt(int index, AmostraGeneticaModel model) {
    setState(() {
      _amostras[index] = model;
    });
    _notifyChanges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final amostrasOutras = <MapEntry<int, AmostraGeneticaModel>>[];
    for (int i = 0; i < _amostras.length; i++) {
      if (_amostras[i].tipoAmostra == 'OUTRO') {
        amostrasOutras.add(MapEntry(i, _amostras[i]));
      }
    }

    final temBucal = _hasTipo(_kSwabBucalVitima);
    final amostraBucal = _getTipo(_kSwabBucalVitima);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      color: Colors.teal.shade50.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Icon(Icons.fingerprint, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Detalhes do Exame Genético e Biológico",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Aviso em Destaque
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "OBS: SOMENTE será realizada a análise genética se forem encaminhados 02 swabs de cada região periciada.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "Amostras Questionadas",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
            ),
            const SizedBox(height: 8),

            // Swabs Vaginal e Anal — cada um com seu campo de lacre individual
            _buildSwabFixoComLacre(
              tipo: _kSwabVaginalSemen,
              label: 'SWAB VAGINAL - 1 (Pesquisa de sêmen)',
              pesquisaSemen: true,
              pesquisaDna: false,
            ),
            _buildSwabFixoComLacre(
              tipo: _kSwabVaginalDna,
              label: 'SWAB VAGINAL - 2 (DNA)',
              pesquisaSemen: false,
              pesquisaDna: true,
            ),
            _buildSwabFixoComLacre(
              tipo: _kSwabAnalSemen,
              label: 'SWAB ANAL - 1 (Pesquisa de sêmen)',
              pesquisaSemen: true,
              pesquisaDna: false,
            ),
            _buildSwabFixoComLacre(
              tipo: _kSwabAnalDna,
              label: 'SWAB ANAL - 2 (DNA)',
              pesquisaSemen: false,
              pesquisaDna: true,
            ),

            const SizedBox(height: 12),
            Text(
              "Outras Amostras Biológicas",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
            ),
            const SizedBox(height: 8),

            // Amostras Dinâmicas (OUTRO)
            if (amostrasOutras.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  "Nenhuma outra amostra adicionada.",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                ),
              ),

            for (final entry in amostrasOutras) ...[
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.teal.shade100),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: entry.value.descricaoOutro,
                              enabled: !widget.readOnly,
                              decoration: const InputDecoration(
                                labelText: 'Descrição da amostra / Região',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                _updateAmostraAt(
                                  entry.key,
                                  entry.value.copyWith(descricaoOutro: v.trim()),
                                );
                              },
                            ),
                          ),
                          if (!widget.readOnly)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Remover amostra',
                              onPressed: () => _removeAmostraAt(entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Campo de lacre individual obrigatório
                      TextFormField(
                        initialValue: entry.value.numeroLacre ?? '',
                        enabled: !widget.readOnly,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nº Lacre do Envelope *',
                          hintText: 'Ex: 123456',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade700, size: 18),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) {
                          _updateAmostraAt(
                            entry.key,
                            entry.value.copyWith(numeroLacre: v.trim()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text("Pesquisa de sêmen", style: TextStyle(fontSize: 12)),
                              value: entry.value.pesquisaSemen,
                              enabled: !widget.readOnly,
                              dense: true,
                              activeColor: Colors.teal.shade700,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: widget.readOnly
                                  ? null
                                  : (val) {
                                      _updateAmostraAt(
                                        entry.key,
                                        entry.value.copyWith(pesquisaSemen: val ?? false),
                                      );
                                    },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text("DNA", style: TextStyle(fontSize: 12)),
                              value: entry.value.pesquisaDna,
                              enabled: !widget.readOnly,
                              dense: true,
                              activeColor: Colors.teal.shade700,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: widget.readOnly
                                  ? null
                                  : (val) {
                                      _updateAmostraAt(
                                        entry.key,
                                        entry.value.copyWith(pesquisaDna: val ?? false),
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (!widget.readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addAmostraOutro,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Adicionar outra amostra"),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal.shade800),
                ),
              ),

            const SizedBox(height: 16),
            const Divider(),

            // Amostras de Referência (DNA)
            Text(
              "Amostras de Referência (DNA)",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
            ),
            const SizedBox(height: 8),

            CheckboxListTile(
              title: const Text("Swab bucal coletado da vítima", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: temBucal,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.teal.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) => _toggleTipoFixa(_kSwabBucalVitima, val ?? false, pesquisaDna: true),
            ),

            if (temBucal)
              Padding(
                padding: const EdgeInsets.only(left: 28.0, top: 4, bottom: 8),
                child: Row(
                  children: [
                    const Text("Quantidade de swabs: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => _updateTipoFixaQuantity(_kSwabBucalVitima, -1),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Text(
                        "${amostraBucal?.quantidadeSwabs ?? 1}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _updateTipoFixaQuantity(_kSwabBucalVitima, 1),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Swab com checkbox + campo de lacre colapável abaixo quando marcado.
  Widget _buildSwabFixoComLacre({
    required String tipo,
    required String label,
    required bool pesquisaSemen,
    required bool pesquisaDna,
  }) {
    final marcado = _hasTipo(tipo);
    final amostra = _getTipo(tipo);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          value: marcado,
          enabled: !widget.readOnly,
          dense: true,
          activeColor: Colors.teal.shade700,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: widget.readOnly
              ? null
              : (val) => _toggleTipoFixa(tipo, val ?? false,
                  pesquisaSemen: pesquisaSemen, pesquisaDna: pesquisaDna),
        ),
        if (marcado && amostra != null)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 12, bottom: 8),
            child: TextFormField(
              initialValue: amostra.numeroLacre ?? '',
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nº Lacre do Envelope *',
                hintText: 'Ex: 123456',
                prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade700, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                helperText: 'Identifica individualmente este envelope lacrado',
                helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              onChanged: (v) {
                final idx = _amostras.indexWhere((a) => a.tipoAmostra == tipo);
                if (idx != -1) {
                  setState(() {
                    _amostras[idx] = _amostras[idx].copyWith(numeroLacre: v.trim());
                  });
                  _notifyChanges();
                }
              },
            ),
          ),
      ],
    );
  }
}

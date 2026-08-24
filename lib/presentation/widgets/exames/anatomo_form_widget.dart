import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';

/// Widget de formulário isolado para requisição de exames anatomopatológicos (Frascos).
class AnatomoFormWidget extends StatefulWidget {
  final List<FrascoAnatomoModel> initialData;
  final ValueChanged<List<FrascoAnatomoModel>> onChanged;
  final bool readOnly;

  const AnatomoFormWidget({
    super.key,
    this.initialData = const [],
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<AnatomoFormWidget> createState() => _AnatomoFormWidgetState();
}

class _AnatomoFormWidgetState extends State<AnatomoFormWidget> {
  late List<FrascoAnatomoModel> _frascos;

  @override
  void initState() {
    super.initState();
    _frascos = List.from(widget.initialData);
    if (_frascos.isEmpty && !widget.readOnly) {
      _frascos.add(
        FrascoAnatomoModel.novo(
          exameUuid: '',
          numeroFrasco: 1,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant AnatomoFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      setState(() {
        _frascos = List.from(widget.initialData);
        if (_frascos.isEmpty && !widget.readOnly) {
          _frascos.add(
            FrascoAnatomoModel.novo(
              exameUuid: '',
              numeroFrasco: 1,
            ),
          );
        }
      });
    }
  }

  void _notifyChanges() {
    widget.onChanged(List.unmodifiable(_frascos));
  }

  void _addFrasco() {
    setState(() {
      _frascos.add(
        FrascoAnatomoModel.novo(
          exameUuid: '',
          numeroFrasco: _frascos.length + 1,
        ),
      );
    });
    _notifyChanges();
  }

  void _removeFrascoAt(int index) {
    setState(() {
      _frascos.removeAt(index);
      // Reorganiza a numeração sequencial (1, 2, 3...)
      for (int i = 0; i < _frascos.length; i++) {
        _frascos[i] = _frascos[i].copyWith(numeroFrasco: i + 1);
      }
    });
    _notifyChanges();
  }

  void _updateFrascoAt(int index, FrascoAnatomoModel model) {
    setState(() {
      _frascos[index] = model;
    });
    _notifyChanges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade200),
      ),
      color: Colors.indigo.shade50.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Seção
            Row(
              children: [
                Icon(Icons.science, color: Colors.indigo.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Detalhes do Exame Anátomo-Patológico",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_frascos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Nenhum frasco cadastrado.",
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                ),
              ),

            // Loop de Frascos
            for (int i = 0; i < _frascos.length; i++) ...[
              _buildFrascoCard(i, _frascos[i]),
              const SizedBox(height: 12),
            ],

            // Botão Global para Adicionar Frasco
            if (!widget.readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addFrasco,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text("Adicionar Frasco 0${_frascos.length + 1}"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade800,
                    side: BorderSide(color: Colors.indigo.shade300),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrascoCard(int index, FrascoAnatomoModel frasco) {
    final numStr = frasco.numeroFrasco < 10 ? '0${frasco.numeroFrasco}' : '${frasco.numeroFrasco}';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título do Frasco + Lacre Individual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Frasco $numStr",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!widget.readOnly && _frascos.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Remover Frasco $numStr',
                    onPressed: () => _removeFrascoAt(index),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Campo de Lacre Individual — obrigatório por cadeia de custódia
            TextFormField(
              initialValue: frasco.numeroLacre ?? '',
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nº Lacre do Frasco $numStr *',
                hintText: 'Ex: 123456',
                prefixIcon: Icon(Icons.lock_outline, color: Colors.indigo.shade700, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                helperText: 'Identifica individualmente este recipiente lacrado',
                helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              onChanged: (v) {
                _updateFrascoAt(index, frasco.copyWith(numeroLacre: v.trim()));
              },
            ),
            const SizedBox(height: 12),

            // 1. Grid de Órgãos Principais (2 Colunas)
            const Text(
              "Órgãos para Análise Histopatológica",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna 1: Coração, Fígado, Baço
                Expanded(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text("Coração", style: TextStyle(fontSize: 13)),
                        value: frasco.coracao,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(coracao: val ?? false)),
                      ),
                      CheckboxListTile(
                        title: const Text("Fígado", style: TextStyle(fontSize: 13)),
                        value: frasco.figado,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(figado: val ?? false)),
                      ),
                      CheckboxListTile(
                        title: const Text("Baço", style: TextStyle(fontSize: 13)),
                        value: frasco.baco,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(baco: val ?? false)),
                      ),
                    ],
                  ),
                ),

                // Coluna 2: Rim D, Rim E, Encéfalo
                Expanded(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text("Rim Direito", style: TextStyle(fontSize: 13)),
                        value: frasco.rimD,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(rimD: val ?? false)),
                      ),
                      CheckboxListTile(
                        title: const Text("Rim Esquerdo", style: TextStyle(fontSize: 13)),
                        value: frasco.rimE,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(rimE: val ?? false)),
                      ),
                      CheckboxListTile(
                        title: const Text("Encéfalo", style: TextStyle(fontSize: 13)),
                        value: frasco.encefalo,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.indigo.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) => _updateFrascoAt(index, frasco.copyWith(encefalo: val ?? false)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // 2. Seção de Pulmões (Sub-opções detalhadas)
            const Text(
              "Pulmões (Lóbulos)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),

            // Pulmão Direito
            Row(
              children: [
                const SizedBox(
                  width: 140,
                  child: Text("Pulmão Direito (D):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildMiniCheckbox("LSD", frasco.pulmaoDLsd, widget.readOnly, (v) {
                        _updateFrascoAt(index, frasco.copyWith(pulmaoDLsd: v));
                      }),
                      _buildMiniCheckbox("LMD", frasco.pulmaoDLmd, widget.readOnly, (v) {
                        _updateFrascoAt(index, frasco.copyWith(pulmaoDLmd: v));
                      }),
                      _buildMiniCheckbox("LID", frasco.pulmaoDLid, widget.readOnly, (v) {
                        _updateFrascoAt(index, frasco.copyWith(pulmaoDLid: v));
                      }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Pulmão Esquerdo
            Row(
              children: [
                const SizedBox(
                  width: 140,
                  child: Text("Pulmão Esquerdo (E):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildMiniCheckbox("LSE", frasco.pulmaoELse, widget.readOnly, (v) {
                        _updateFrascoAt(index, frasco.copyWith(pulmaoELse: v));
                      }),
                      _buildMiniCheckbox("LIE", frasco.pulmaoELie, widget.readOnly, (v) {
                        _updateFrascoAt(index, frasco.copyWith(pulmaoELie: v));
                      }),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // 3. Regiões Descritivas
            TextFormField(
              initialValue: frasco.peleRegiao,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                labelText: 'Pele (descrever a região)',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                _updateFrascoAt(index, frasco.copyWith(peleRegiao: v.trim()));
              },
            ),
            const SizedBox(height: 8),

            TextFormField(
              initialValue: frasco.partesMolesRegiao,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                labelText: 'Partes moles (descrever a região)',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                _updateFrascoAt(index, frasco.copyWith(partesMolesRegiao: v.trim()));
              },
            ),
            const SizedBox(height: 8),

            TextFormField(
              initialValue: frasco.outrasRegiao,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                labelText: 'Outras (descrever a região)',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                _updateFrascoAt(index, frasco.copyWith(outrasRegiao: v.trim()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCheckbox(String label, bool value, bool readOnly, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: readOnly ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                activeColor: Colors.indigo.shade700,
                onChanged: readOnly ? null : (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

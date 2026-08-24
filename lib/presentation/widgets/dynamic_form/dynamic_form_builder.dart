import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class DynamicFormBuilder extends StatefulWidget {
  final dynamic schema;
  final dynamic initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final List<Achado> entradasDisponiveis;

  const DynamicFormBuilder({
    super.key,
    required this.schema,
    this.initialData = const {},
    required this.onChanged,
    this.entradasDisponiveis = const [],
  });

  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _formData;

  @override
  void initState() {
    super.initState();
    _formData = _parseMapData(widget.initialData);
  }

  @override
  void didUpdateWidget(covariant DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData || oldWidget.schema != widget.schema) {
      _formData = _parseMapData(widget.initialData);
    }
  }

  Map<String, dynamic> _parseMapData(dynamic raw) {
    if (raw == null) return {};
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('[DynamicFormBuilder] Erro ao decodificar JSON: $e');
      }
      return {};
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  List<Map<String, dynamic>> get _campos {
    return _parseCampos(widget.schema);
  }

  List<Map<String, dynamic>> _parseCampos(dynamic schemaRaw) {
    if (schemaRaw == null) return [];

    dynamic parsed = schemaRaw;
    if (parsed is String && parsed.trim().isNotEmpty) {
      try {
        parsed = jsonDecode(parsed);
      } catch (e) {
        debugPrint('[DynamicFormBuilder] Erro ao decodificar schema: $e');
        return [];
      }
    }

    if (parsed is List) {
      return parsed
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (parsed is Map) {
      final map = Map<String, dynamic>.from(parsed);

      if (map.containsKey('campos') && map['campos'] is List) {
        return (map['campos'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (map.containsKey('id_campo') || map.containsKey('label')) {
        return [map];
      }

      final List<Map<String, dynamic>> extraidos = [];
      map.forEach((key, val) {
        if (val is Map) {
          final cMap = Map<String, dynamic>.from(val);
          cMap['id_campo'] = cMap['id_campo'] ?? key;
          extraidos.add(cMap);
        }
      });
      if (extraidos.isNotEmpty) return extraidos;
    }

    return [];
  }

  bool _isVisible(Map<String, dynamic> campo) {
    final condicao = campo['condicao_visibilidade'];
    if (condicao == null || condicao is! Map) return true;
    final dependeDe = condicao['depende_de']?.toString();
    final valorEsperado = condicao['valor_esperado']?.toString();
    if (dependeDe == null || valorEsperado == null) return true;
    return _formData[dependeDe]?.toString() == valorEsperado;
  }

  void _updateField(String id, dynamic value) {
    setState(() {
      _formData[id] = value;
    });
    widget.onChanged(Map<String, dynamic>.from(_formData));
  }

  List<String> _parseOpcoes(dynamic raw) {
    if (raw == null) return [];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    if (raw is List) {
      return raw.map((e) => e.toString()).toSet().toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final campos = _campos;
    if (campos.isEmpty) return const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: campos
            .where(_isVisible)
            .map((campo) => Padding(
                  key: ValueKey(campo['id_campo'] ?? campo['id'] ?? campo['label'] ?? UniqueKey().toString()),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildField(campo),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> campo) {
    final id = campo['id_campo']?.toString() ?? campo['id']?.toString() ?? campo['key']?.toString() ?? '';
    final label = campo['label']?.toString() ?? campo['nome']?.toString() ?? id;
    final tipo = campo['tipo_input']?.toString() ?? campo['tipo']?.toString() ?? 'text';
    final obrigatorio = campo['obrigatorio'] == true || campo['required'] == true;
    final hint = campo['hint']?.toString() ?? campo['placeholder']?.toString();
    final opcoes = _parseOpcoes(campo['opcoes'] ?? campo['options']);

    switch (tipo.toLowerCase()) {
      case 'dropdown':
      case 'select':
        return _buildDropdown(id, label, obrigatorio, hint, opcoes);
      case 'radio':
        return _buildRadioGroup(id, label, obrigatorio, opcoes);
      case 'auto_relacionamento':
        return _buildAutoRelacionamento(id, label, obrigatorio, hint);
      case 'text_area':
      case 'textarea':
      case 'multiline':
        return _buildTextInput(id, label, obrigatorio, hint, maxLines: 3);
      case 'number':
      case 'numeric':
      case 'integer':
      case 'decimal':
        return _buildTextInput(id, label, obrigatorio, hint, isNumeric: true);
      default:
        return _buildTextInput(id, label, obrigatorio, hint);
    }
  }

  Widget _buildTextInput(
    String id,
    String label,
    bool obrigatorio,
    String? hint, {
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return TextFormField(
      initialValue: _formData[id]?.toString(),
      maxLines: maxLines,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: obrigatorio
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
          : null,
      onChanged: (v) => _updateField(id, v),
    );
  }

  Widget _buildDropdown(
    String id,
    String label,
    bool obrigatorio,
    String? hint,
    List<String> opcoes,
  ) {
    final currentValue = _formData[id]?.toString();
    final validValue =
        (currentValue != null && opcoes.contains(currentValue)) ? currentValue : null;

    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: opcoes
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => _updateField(id, v),
      validator: obrigatorio ? (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null : null,
    );
  }

  Widget _buildRadioGroup(
    String id,
    String label,
    bool obrigatorio,
    List<String> opcoes,
  ) {
    final currentValue = _formData[id]?.toString();

    return FormField<String>(
      initialValue: currentValue,
      validator: obrigatorio ? (v) => (v == null || v.isEmpty) ? 'Selecione uma opção' : null : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: opcoes.map((opcao) {
                final isSelected = state.value == opcao;
                return ChoiceChip(
                  label: Text(opcao),
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    final newValue = selected ? opcao : null;
                    state.didChange(newValue);
                    _updateField(id, newValue);
                  },
                );
              }).toList(),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAutoRelacionamento(
    String id,
    String label,
    bool obrigatorio,
    String? hint,
  ) {
    final entradas = widget.entradasDisponiveis;
    final currentValue = _formData[id]?.toString();
    final validValue =
        (currentValue != null && entradas.any((a) => a.uuid == currentValue))
            ? currentValue
            : null;

    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Selecione o achado de entrada',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: entradas
          .map((a) => DropdownMenuItem(
                value: a.uuid,
                child: Text('Achado #${a.numeroSequencial} - Entrada'),
              ))
          .toList(),
      onChanged: (v) => _updateField(id, v),
      validator: obrigatorio ? (v) => (v == null) ? 'Campo obrigatório' : null : null,
    );
  }
}

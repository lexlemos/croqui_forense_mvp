import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/core/exceptions/database_corrupted_exception.dart';

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
  final Map<String, ValueNotifier<dynamic>> _fieldNotifiers = {};
  String? _parseError;

  @override
  void initState() {
    super.initState();
    try {
      _formData = _parseMapData(widget.initialData);
      _syncFieldNotifiers();
    } on DatabaseCorruptedException catch (e) {
      _formData = {};
      _parseError = e.message;
    }
  }

  @override
  void didUpdateWidget(covariant DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData || oldWidget.schema != widget.schema) {
      try {
        _formData = _parseMapData(widget.initialData);
        _parseError = null;
        _syncFieldNotifiers();
      } on DatabaseCorruptedException catch (e) {
        _formData = {};
        _parseError = e.message;
      }
    }
  }

  @override
  void dispose() {
    for (final notifier in _fieldNotifiers.values) {
      notifier.dispose();
    }
    _fieldNotifiers.clear();
    super.dispose();
  }

  Map<String, dynamic> _parseMapData(dynamic raw) {
    if (raw == null) return {};
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw const FormatException('O JSON dos dados dinâmicos não é um objeto.');
      } catch (e) {
        throw DatabaseCorruptedException(
          'Dados dinâmicos do formulário estão corrompidos.',
          cause: e,
        );
      }
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isEmpty) return {};
    throw DatabaseCorruptedException('Formato inválido para os dados do formulário.');
  }

  List<Map<String, dynamic>> get _campos {
    return _parseCampos(widget.schema);
  }

  List<Map<String, dynamic>> _parseCampos(dynamic schemaRaw) {
    if (schemaRaw == null) return [];

    dynamic parsed = schemaRaw;
    if (parsed is String && parsed.trim().isEmpty) return [];
    if (parsed is String && parsed.trim().isNotEmpty) {
      try {
        parsed = jsonDecode(parsed);
      } catch (e) {
        throw DatabaseCorruptedException(
          'Schema do formulário está corrompido.',
          cause: e,
        );
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
      return [];
    }

    throw const DatabaseCorruptedException('Schema do formulário possui formato inválido.');
  }

  void _syncFieldNotifiers() {
    final campos = _parseCampos(widget.schema);
    final ids = <String>{};
    for (final campo in campos) {
      final id = _fieldId(campo);
      if (id.isNotEmpty) ids.add(id);
      final condicao = campo['condicao_visibilidade'];
      if (condicao is Map) {
        final dependeDe = condicao['depende_de']?.toString();
        if (dependeDe != null && dependeDe.isNotEmpty) ids.add(dependeDe);
      }
    }

    for (final id in ids) {
      _fieldNotifiers.putIfAbsent(id, () => ValueNotifier<dynamic>(_formData[id]));
      _fieldNotifiers[id]!.value = _formData[id];
    }

    final obsolete = _fieldNotifiers.keys.where((id) => !ids.contains(id)).toList();
    for (final id in obsolete) {
      _fieldNotifiers.remove(id)?.dispose();
    }
  }

  String _fieldId(Map<String, dynamic> campo) =>
      campo['id_campo']?.toString() ?? campo['id']?.toString() ?? campo['key']?.toString() ?? '';

  bool _isVisible(Map<String, dynamic> campo, dynamic dependencyValue) {
    final condicao = campo['condicao_visibilidade'];
    if (condicao == null || condicao is! Map) return true;
    final dependeDe = condicao['depende_de']?.toString();
    final valorEsperado = condicao['valor_esperado']?.toString();
    if (dependeDe == null || valorEsperado == null) return true;
    return dependencyValue?.toString() == valorEsperado;
  }

  void _updateField(String id, dynamic value) {
    _formData[id] = value;
    final notifier = _fieldNotifiers[id];
    if (notifier != null && notifier.value != value) notifier.value = value;
    widget.onChanged(Map<String, dynamic>.from(_formData));
  }

  List<String> _parseOpcoes(dynamic raw) {
    if (raw == null) return [];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (e) {
        if (raw.trimLeft().startsWith('[')) {
          throw DatabaseCorruptedException('Opções do campo estão corrompidas.', cause: e);
        }
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
    List<Map<String, dynamic>> campos;
    try {
      campos = _campos;
    } on DatabaseCorruptedException catch (e) {
      return _buildDatabaseCorruptedWarning(e.message);
    }
    if (_parseError != null) return _buildDatabaseCorruptedWarning(_parseError!);
    if (campos.isEmpty) return const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: campos.map(_buildFieldContainerSafely).toList(),
      ),
    );
  }

  Widget _buildDatabaseCorruptedWarning(String details) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      child: Text(
        'Banco de dados local corrompido.\n$details',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildFieldContainer(Map<String, dynamic> campo) {
    final id = _fieldId(campo);
    final field = Padding(
      key: ValueKey(id.isNotEmpty ? id : campo['label'] ?? UniqueKey()),
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildField(campo),
    );

    final condicao = campo['condicao_visibilidade'];
    final dependeDe = condicao is Map ? condicao['depende_de']?.toString() : null;
    final dependencyNotifier = dependeDe == null ? null : _fieldNotifiers[dependeDe];
    if (dependencyNotifier == null) return field;

    return ValueListenableBuilder<dynamic>(
      valueListenable: dependencyNotifier,
      builder: (context, value, child) => _isVisible(campo, value)
          ? child!
          : const SizedBox.shrink(),
      child: field,
    );
  }

  Widget _buildFieldContainerSafely(Map<String, dynamic> campo) {
    try {
      return _buildFieldContainer(campo);
    } on DatabaseCorruptedException catch (e) {
      return _buildDatabaseCorruptedWarning(e.message);
    }
  }

  Widget _buildField(Map<String, dynamic> campo) {
    final id = _fieldId(campo);
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

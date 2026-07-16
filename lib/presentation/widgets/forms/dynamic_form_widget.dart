import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class DynamicFormWidget extends StatefulWidget {
  final Map<String, dynamic> schema;
  final Map<String, dynamic> initialData;
  final List<Achado> entradasDisponiveis;
  final void Function(Map<String, dynamic> data) onChanged;

  const DynamicFormWidget({
    super.key,
    required this.schema,
    this.initialData = const {},
    this.entradasDisponiveis = const [],
    required this.onChanged,
  });

  @override
  State<DynamicFormWidget> createState() => DynamicFormWidgetState();
}

class DynamicFormWidgetState extends State<DynamicFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _formData;

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData);
  }

  @override
  void didUpdateWidget(covariant DynamicFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schema != widget.schema || oldWidget.initialData != widget.initialData) {
      _formData = Map<String, dynamic>.from(widget.initialData);
    }
  }

  bool validate() {
    if (_campos.isEmpty) return true;
    return _formKey.currentState?.validate() ?? false;
  }

  Map<String, dynamic> get formData => Map<String, dynamic>.from(_formData);

  List<Map<String, dynamic>> get _campos {
     final raw = widget.schema['campos'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
    widget.onChanged(_formData);
  }

  @override
  Widget build(BuildContext context) {
    final campos = _campos;
    if (campos.isEmpty) return const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: campos
            .where(_isVisible)
            .map((campo) => Padding(
                  key: ValueKey(campo['id_campo']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildField(campo),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> campo) {
    final id = campo['id_campo']?.toString() ?? '';
    final label = campo['label']?.toString() ?? '';
    final tipo = campo['tipo_input']?.toString() ?? 'text';
    final obrigatorio = campo['obrigatorio'] == true;
    final hint = campo['hint']?.toString();
    final opcoes = _parseOpcoes(campo['opcoes']);

    switch (tipo) {
      case 'dropdown':
        return _buildDropdown(id, label, obrigatorio, hint, opcoes);
      case 'auto_relacionamento':
        return _buildAutoRelacionamento(id, label, obrigatorio, hint);
      case 'text_area':
        return _buildTextInput(id, label, obrigatorio, hint, maxLines: 3);
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
  }) {
    return TextFormField(
      initialValue: _formData[id]?.toString(),
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: obrigatorio
          ? (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null
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
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      items: opcoes
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => _updateField(id, v),
      validator: obrigatorio ? (v) => (v == null) ? 'Obrigatório' : null : null,
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
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Selecione o achado de entrada',
        border: const OutlineInputBorder(),
      ),
      items: entradas
          .map((a) => DropdownMenuItem(
                value: a.uuid,
                child: Text('Achado #${a.numeroSequencial} - Entrada'),
              ))
          .toList(),
      onChanged: (v) => _updateField(id, v),
      validator: obrigatorio ? (v) => (v == null) ? 'Obrigatório' : null : null,
    );
  }

  List<String> _parseOpcoes(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toSet().toList();
    return [];
  }
}

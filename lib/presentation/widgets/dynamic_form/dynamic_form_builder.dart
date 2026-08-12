import 'package:flutter/material.dart';

class DynamicFormBuilder extends StatefulWidget {
  final Map<String, dynamic> schema;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const DynamicFormBuilder({
    super.key,
    required this.schema,
    required this.onChanged,
  });

  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  late Map<String, dynamic> _localData;

  @override
  void initState() {
    super.initState();
    _localData = _deepCopy(widget.schema);
  }

  @override
  void didUpdateWidget(DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Caso o schema seja atualizado externamente, podemos precisar refletir (opcional dependendo da arquitetura).
    // Aqui assumimos que o form é construído uma vez.
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    final copy = <String, dynamic>{};
    source.forEach((key, value) {
      if (value is Map) {
        copy[key] = _deepCopy(Map<String, dynamic>.from(value));
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  String _formatKey(String key) {
    if (key.isEmpty) return key;
    final words = key.split('_');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });
    return capitalizedWords.join(' ');
  }

  void _updateValue(List<String> path, dynamic value) {
    Map<String, dynamic> current = _localData;
    for (int i = 0; i < path.length - 1; i++) {
      current = current[path[i]] as Map<String, dynamic>;
    }
    current[path.last] = value;
    widget.onChanged(_localData);
  }

  Widget _buildNode(String key, dynamic value, List<String> path) {
    final currentPath = List<String>.from(path)..add(key);
    final formattedKey = _formatKey(key);

    if (value is Map) {
      final mapValue = Map<String, dynamic>.from(value);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedKey,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 12),
              ...mapValue.entries.map((e) => _buildNode(e.key, e.value, currentPath)),
            ],
          ),
        ),
      );
    } else {
      // Trata como String ou nulo
      final stringValue = value?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextFormField(
          initialValue: stringValue,
          minLines: 1,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: formattedKey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          onChanged: (newValue) {
            _updateValue(currentPath, newValue);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _localData.entries.map((e) => _buildNode(e.key, e.value, [])).toList(),
    );
  }
}

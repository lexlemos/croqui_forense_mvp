import 'package:flutter/material.dart';

enum QuestionType { text, boolean }

class _QuestionConfig {
  final String jsonKey;
  final String label;
  final IconData icon;
  final QuestionType type;
  final int maxLines;
  
  final TextEditingController? controller;
  
  bool? boolValue;

  _QuestionConfig({
    required this.jsonKey,
    required this.label,
    required this.icon,
    this.type = QuestionType.text,
    this.maxLines = 1,
  }) : controller = type == QuestionType.text ? TextEditingController() : null;
}

class FinalizeCaseDialog extends StatefulWidget {
  const FinalizeCaseDialog({super.key});

  @override
  State<FinalizeCaseDialog> createState() => _FinalizeCaseDialogState();
}

class _FinalizeCaseDialogState extends State<FinalizeCaseDialog> {
  late final List<_QuestionConfig> _questions;

  @override
  void initState() {
    super.initState();
    _questions = [
      _QuestionConfig(
        jsonKey: 'pergunta_1',
        label: '1. Houve morte?',
        icon: Icons.help_outline,
        type: QuestionType.boolean, 
      ),
      _QuestionConfig(
        jsonKey: 'pergunta_2',
        label: '2. Qual a causa?',
        icon: Icons.search,
      ),
      _QuestionConfig(
        jsonKey: 'pergunta_3',
        label: '3. Qual o instrumento ou meio que a produziu?',
        icon: Icons.handyman,
      ),
      _QuestionConfig(
        jsonKey: 'pergunta_4',
        label: '4. Foi produzido por meio de veneno, fogo, explosivo, asfixia ou meio insidioso cruel?',
        icon: Icons.warning_amber,
        maxLines: 3,
      ),
    ];
  }

  @override
  void dispose() {
    for (var q in _questions) {
      q.controller?.dispose();
    }
    super.dispose();
  }

  void _submit() {
    for (var q in _questions) {
      bool isValid = true;

      if (q.type == QuestionType.text) {
        if (q.controller!.text.trim().isEmpty) isValid = false;
      } else if (q.type == QuestionType.boolean) {
        if (q.boolValue == null) isValid = false;
      }

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('O campo "${q.label}" é obrigatório.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    final Map<String, dynamic> respostas = {};
    
    for (var q in _questions) {
      if (q.type == QuestionType.text) {
        respostas[q.jsonKey] = q.controller!.text.trim();
      } else if (q.type == QuestionType.boolean) {
        respostas[q.jsonKey] = q.boolValue == true ? 'Sim' : 'Não';
      }
    }
    
    respostas['data_finalizacao'] = DateTime.now().toIso8601String();

    final dadosFinais = {
      'conclusao': respostas
    };

    Navigator.pop(context, dadosFinais);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conclusão do Laudo'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Responda às questões finais para encerrar o caso:", 
                style: TextStyle(fontSize: 14, color: Colors.grey)
              ),
              const SizedBox(height: 20),

              ..._questions.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildInputForQuestion(q),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green[700],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.check_circle),
          label: const Text('FINALIZAR CASO'),
        ),
      ],
    );
  }
  Widget _buildInputForQuestion(_QuestionConfig q) {
    if (q.type == QuestionType.boolean) {
      return DropdownButtonFormField<bool>(
        decoration: InputDecoration(
          labelText: q.label,
          prefixIcon: Icon(q.icon, size: 20),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.star, size: 8, color: Colors.red),
          suffixIconConstraints: const BoxConstraints(minWidth: 16, minHeight: 0),
        ),
        initialValue: q.boolValue,
        items: const [
          DropdownMenuItem(value: true, child: Text("Sim")),
          DropdownMenuItem(value: false, child: Text("Não")),
        ],
        onChanged: (value) {
          setState(() {
            q.boolValue = value;
          });
        },
      );
    } 
    else {
      return TextField(
        controller: q.controller,
        maxLines: q.maxLines,
        decoration: InputDecoration(
          labelText: q.label,
          prefixIcon: Icon(q.icon, size: 20),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.star, size: 8, color: Colors.red),
          suffixIconConstraints: const BoxConstraints(minWidth: 16, minHeight: 0),
        ),
      );
    }
  }
}
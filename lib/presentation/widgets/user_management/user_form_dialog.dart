import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart';
import 'package:croqui_forense_mvp/presentation/providers/user_management_provider.dart';

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _pinController = TextEditingController();
  
  String? _selectedPapelId;
  bool _obscurePin = true;

  @override
  Widget build(BuildContext context) {
    final papeis = context.select<UserManagementProvider, List<Papel>>((p) => p.papeis);

    return AlertDialog(
      title: const Text('Novo Usuário'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400, 
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _matriculaController,
                        decoration: const InputDecoration(
                          labelText: 'Matrícula',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPapelId,
                        decoration: const InputDecoration(
                          labelText: 'Cargo / Função',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work),
                        ),
                        items: papeis.map((papel) {
                          return DropdownMenuItem<String>(
                            value: papel.id,
                            child: Text(papel.nome),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPapelId = val),
                        validator: (v) => v == null ? 'Selecione' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 4, 
                  decoration: InputDecoration(
                    labelText: 'PIN de Acesso Inicial',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    helperText: 'O usuário deverá trocar no primeiro acesso',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length != 4) return 'O PIN deve ter 4 dígitos';
                    if (int.tryParse(v) == null) return 'Apenas números';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Criar Usuário'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'nome': _nomeController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'papelId': _selectedPapelId,
        'pin': _pinController.text.trim(),
      });
    }
  }
}
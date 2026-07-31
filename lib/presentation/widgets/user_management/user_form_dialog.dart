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
  final _classeController = TextEditingController();
  final _crmController = TextEditingController();
  final _pinController = TextEditingController();
  
  String? _selectedPapelId;
  bool _obscurePin = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _classeController.dispose();
    _crmController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _checkIsPeritoOuMedico(List<Papel> papeis) {
    if (_selectedPapelId == null) return false;
    final papel = papeis.firstWhere(
      (p) => p.id == _selectedPapelId,
      orElse: () => Papel(id: '', nome: '', ePadrao: false, criadoEm: DateTime.now()),
    );
    final nomeUpper = papel.nome.toUpperCase();
    return nomeUpper.contains('PERITO') || nomeUpper.contains('MEDICO') || nomeUpper.contains('MÉDICO');
  }

  @override
  Widget build(BuildContext context) {
    final papeis = context.select<UserManagementProvider, List<Papel>>((p) => p.papeis);
    final isPeritoMedico = _checkIsPeritoOuMedico(papeis);

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
                        initialValue: _selectedPapelId,
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

                if (isPeritoMedico) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _classeController,
                          decoration: const InputDecoration(
                            labelText: 'Classe',
                            prefixIcon: Icon(Icons.stars),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!isPeritoMedico) return null;
                            if (v == null || v.trim().isEmpty) return 'Obrigatório';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _crmController,
                          decoration: const InputDecoration(
                            labelText: 'CRM',
                            prefixIcon: Icon(Icons.medical_information),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!isPeritoMedico) return null;
                            if (v == null || v.trim().isEmpty) return 'Obrigatório';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],

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
          onPressed: () => _submit(isPeritoMedico),
          child: const Text('Criar Usuário'),
        ),
      ],
    );
  }

  void _submit(bool isPeritoMedico) {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'nome': _nomeController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'papelId': _selectedPapelId,
        'classe': isPeritoMedico ? _classeController.text.trim() : null,
        'crm': isPeritoMedico ? _crmController.text.trim() : null,
        'pin': _pinController.text.trim(),
      });
    }
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/force_change_pin_controller.dart';

class ForceChangePinPage extends StatefulWidget {
  const ForceChangePinPage({super.key});

  @override
  State<ForceChangePinPage> createState() => _ForceChangePinPageState();
}

class _ForceChangePinPageState extends State<ForceChangePinPage> {
  late final ForceChangePinController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ForceChangePinController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segurança'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, size: 18, color: Colors.red),
            label: const Text('Sair', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _controller.formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset, size: 64, color: Colors.orange),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Troca de Senha Obrigatória',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Por segurança, defina um novo PIN pessoal de 4 dígitos para liberar seu acesso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _controller.pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Novo PIN',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                      counterText: "",
                    ),
                    validator: _controller.validarPin,
                    textInputAction: TextInputAction.next,
                  ),
                  
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _controller.confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Confirme o PIN',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.check_circle_outline),
                      counterText: "",
                    ),
                    validator: _controller.validarConfirmacao,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _controller.submitChange(context),
                  ),
                  
                  const SizedBox(height: 24),

                  Selector<AuthProvider, bool>(
                    selector: (_, provider) => provider.isLoading,
                    builder: (context, isLoading, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: isLoading ? null : () => _controller.submitChange(context),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : const Text('DEFINIR NOVA SENHA'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
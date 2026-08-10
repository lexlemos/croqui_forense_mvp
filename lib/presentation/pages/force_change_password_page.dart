import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/force_change_password_controller.dart';

class ForceChangePasswordPage extends StatefulWidget {
  const ForceChangePasswordPage({super.key});

  @override
  State<ForceChangePasswordPage> createState() => _ForceChangePasswordPageState();
}

class _ForceChangePasswordPageState extends State<ForceChangePasswordPage> {
  late final ForceChangePasswordController _controller;
  bool _obscureSenha = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _controller = ForceChangePasswordController();
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
            onPressed: () => context.read<AuthProvider>().logout(context),
            icon: const Icon(Icons.logout, size: 18, color: Colors.red),
            label: const Text('Sair', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Center(
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
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset, size: 64, color: Colors.orange),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Troca de Senha Obrigatória',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Por segurança, defina uma nova senha pessoal para liberar seu acesso ao sistema.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),

                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _controller.senhaController,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: _obscureSenha,
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSenha ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                          tooltip: _obscureSenha ? 'Mostrar senha' : 'Ocultar senha',
                        ),
                      ),
                      validator: _controller.validarSenha,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _controller.confirmController,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Nova Senha',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          tooltip: _obscureConfirm ? 'Mostrar senha' : 'Ocultar senha',
                        ),
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
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
      ),
    );
  }
}

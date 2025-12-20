import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

class ForceChangePinPage extends StatefulWidget {
  const ForceChangePinPage({super.key});

  @override
  State<ForceChangePinPage> createState() => _ForceChangePinPageState();
}

class _ForceChangePinPageState extends State<ForceChangePinPage> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segurança'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: Colors.orange),
                  const SizedBox(height: 24),
                  Text(
                    'Troca de Senha Obrigatória',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Por segurança, você deve definir um novo PIN pessoal para continuar acessando o sistema.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Novo PIN (4 dígitos)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) {
                      if (v == null || v.length != 4) return 'Deve ter 4 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Confirme o Novo PIN',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v != _pinController.text) return 'Os PINs não conferem';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _salvarNovoPin,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('DEFINIR NOVA SENHA'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvarNovoPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

     try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.atualizarPinPrimeiroAcesso(_pinController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _matriculaController = TextEditingController();
  final _pinController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _matriculaController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 24),
                  Text(
                    'Croqui Forense Digital',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 48),
                  
                  TextFormField(
                    controller: _matriculaController,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula Funcional',
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Ex: ADMIN001',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe a matrícula.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN de Acesso',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true, 
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitLogin(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o PIN.';
                      }
                      if (value.length < 4) {
                        return 'PIN deve ter no mínimo 4 dígitos.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  if (authProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    FilledButton(
                      onPressed: () => _submitLogin(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ENTRAR'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _submitLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await provider.login(
        _matriculaController.text.trim(),
        _pinController.text.trim(),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Erro inesperado. Tente novamente.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
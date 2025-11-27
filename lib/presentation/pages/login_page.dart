import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _matriculaController = TextEditingController(text: 'ADMIN001'); // Pré-preenchido para teste
  final _pinController = TextEditingController(text: '1234'); // Pré-preenchido
  final _formKey = GlobalKey<FormState>();

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
                  
                  // Campo Matrícula
                  TextFormField(
                    controller: _matriculaController,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula Funcional',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo PIN
                  TextFormField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN de Acesso',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.length < 4 ? 'PIN inválido' : null,
                  ),
                  const SizedBox(height: 32),

                  // Botão de Login
                  if (authProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    FilledButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final erro = await authProvider.login(
                            _matriculaController.text,
                            _pinController.text,
                          );

                          if (erro != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(erro), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
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
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _controller.formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Croqui Forense Digital',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  TextFormField(
                    controller: _controller.matriculaController,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula Funcional',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a matrícula.' : null,
                  ),
                  
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _controller.pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN de Acesso',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _controller.submitLogin(context),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe o PIN.';
                      if (v.length < 4) return 'PIN inválido.';
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),

                  Selector<AuthProvider, bool>(
                    selector: (_, provider) => provider.isLoading,
                    builder: (context, isLoading, child) {
                      return SizedBox(
                        height: 50,
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : FilledButton(
                                onPressed: () => _controller.submitLogin(context),
                                style: FilledButton.styleFrom(
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('ENTRAR'),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ✅ PRODUÇÃO: Controladores iniciam vazios
  final _matriculaController = TextEditingController();
  final _pinController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();

  // Boa prática: Descartar controladores ao sair da tela
  @override
  void dispose() {
    _matriculaController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o estado de autenticação (loading, erros)
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
                  
                  // --- Campo Matrícula ---
                  TextFormField(
                    controller: _matriculaController,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula Funcional',
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Ex: ADMIN001', // Dica visual, não valor
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
                  
                  // --- Campo PIN ---
                  TextFormField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN de Acesso',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true, // Senha oculta
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    // Submete ao dar Enter no teclado
                    onFieldSubmitted: (_) => _submitLogin(authProvider),
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

                  // --- Botão de Login ---
                  if (authProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    FilledButton(
                      onPressed: () => _submitLogin(authProvider),
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

  Future<void> _submitLogin(AuthProvider authProvider) async {
    // 1. Valida o formulário visualmente
    if (!_formKey.currentState!.validate()) return;

    // 2. Chama a camada de lógica (Provider -> Service -> Repo -> DB)
    // O banco já está populado com ADMIN001 / 1234 pelo Seeder.
    final erro = await authProvider.login(
      _matriculaController.text.trim(),
      _pinController.text.trim(),
    );

    // 3. Feedback visual em caso de erro
    if (erro != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Se sucesso, o AuthProvider notifica o main.dart, que troca a tela automaticamente.
  }
}
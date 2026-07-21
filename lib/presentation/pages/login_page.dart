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
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Image.asset(
                'assets/images/logo/logo-policia-se.jpeg',
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _controller.formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logo/logo-croqui.png',
                          height: 250, 
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 80, color: Colors.grey);
                          },
                        ),
                        
                        const SizedBox(height: 42),
                        
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
                              child: FilledButton(
                                onPressed: isLoading ? null : () => _controller.submitLogin(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A237E),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('ENTRAR'),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          "SECRETARIA DE SEGURANÇA PÚBLICA DO ESTADO DE SERGIPE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuario = context.watch<AuthProvider>().usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Casos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => authProvider.logout(),
            tooltip: 'Sair',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bem-vindo, ${usuario?.nomeCompleto ?? "Perito"}!'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navegar para criar novo caso (Fase 4.3)
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo Caso'),
            ),
          ],
        ),
      ),
    );
  }
}
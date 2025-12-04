import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart'; // Vamos criar este widget a seguir

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              usuario: authProvider.usuario,
              title: 'Configurações',
              isHome: false,
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Preferências do Aplicativo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Modo Escuro'),
                    subtitle: const Text('Habilitar tema escuro no aplicativo'),
                    value: false,
                    onChanged: (val) {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Alterar PIN de Acesso'),
                    onTap: () {
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Sobre o App'),
                    subtitle: const Text('Versão 1.0.0 (MVP)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
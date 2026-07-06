import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/pages/force_change_pin_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = "Carregando...";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.select((AuthProvider p) => p.usuario);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              usuario: usuario,
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
                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.indigo),
                    title: const Text('Alterar PIN de Acesso'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForceChangePinPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.indigo),
                    title: const Text('Sobre o App'),
                    subtitle: Text('Versão $_appVersion (Build $_buildNumber)'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Necropsia Digital',
                        applicationVersion: '$_appVersion+$_buildNumber',
                        applicationIcon: const FlutterLogo(size: 40), 
                        applicationLegalese: '© 2026 - IML-SE',
                        children: [
                          const Divider(),
                          const SizedBox(height: 10),
                          const Text(
                            'Desenvolvedor:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('Allex Lemos de Souza Pinheiro'),
                          const SizedBox(height: 10),
                          const Text(
                            'Instituição:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('Instituto Médico Legal de Sergipe (IML-SE)'),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Desenvolvido por Allex Lemos',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
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
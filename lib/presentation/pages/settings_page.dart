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
                    'Dados do Perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow(
                            context,
                            icon: Icons.person,
                            label: 'Nome Completo',
                            value: usuario?.nomeCompleto ?? 'Não disponível',
                          ),
                          const SizedBox(height: 12),
                          _buildProfileRow(
                            context,
                            icon: Icons.badge,
                            label: 'Matrícula Funcional',
                            value: usuario?.matriculaFuncional ?? 'Não disponível',
                          ),
                          const SizedBox(height: 12),
                          _buildProfileRow(
                            context,
                            icon: Icons.security,
                            label: 'Perfil / Função',
                            value: (usuario?.hasRole('ADMIN') ?? false)
                                ? 'Administrador'
                                : (usuario?.roles.isNotEmpty == true ? usuario!.roles.join(', ') : 'Médico Legista / Perito'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
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

  Widget _buildProfileRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.indigo.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
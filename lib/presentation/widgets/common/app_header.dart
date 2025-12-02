import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/settings_page.dart';

class AppHeader extends StatelessWidget {
  final Usuario? usuario;
  final String title;
  final bool isHome;

  const AppHeader({
    super.key,
    required this.usuario,
    this.title = 'Biblioteca de Casos',
    this.isHome = false,
  });

  String get _iniciais {
    if (usuario == null || usuario!.nomeCompleto.isEmpty) return "PN";
    var partes = usuario!.nomeCompleto.trim().split(' ');
    if (partes.length >= 2) {
      return "${partes.first[0]}${partes.last[0]}".toUpperCase();
    }
    return partes.first.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        children: [

          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFF0F0F0)),
                ),
                elevation: 10,
              ),
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50), 
              tooltip: 'Menu',

              icon: Container(
                padding: const EdgeInsets.all(10), 
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E1E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.menu, color: Colors.black, size: 20), // Ícone Preto
              ),
              onSelected: (value) => _handleMenuSelection(context, value),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[

                _buildMenuItem(
                  value: 'home',
                  icon: Icons.dashboard_outlined,
                  text: 'Início',
                  isActive: isHome,
                ),
                
                const PopupMenuDivider(height: 1),

                _buildMenuItem(
                  value: 'settings',
                  icon: Icons.settings_outlined,
                  text: 'Configurações',
                  isActive: !isHome && title == 'Configurações',
                ),
                
                const PopupMenuDivider(height: 1),

                const PopupMenuItem<String>(
                  value: 'logout',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Sair',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 20),

          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              fontFamily: 'Roboto',
            ),
          ),
          
          const Spacer(),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'DR. ${usuario?.nomeCompleto.toUpperCase() ?? "PERITO"}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'MÉDICO LEGISTA',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            alignment: Alignment.center,
            child: Text(
              _iniciais,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String text,
    bool isActive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF317FF5) : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF317FF5) : Colors.black87,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'home':
        if (!isHome) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
        break;
      case 'settings':
        if (title != 'Configurações') {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        }
        break;
      case 'logout':
        context.read<AuthProvider>().logout();
        break;
    }
  }
}
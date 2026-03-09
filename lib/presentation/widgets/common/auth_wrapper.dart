import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/force_change_pin_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF317FF5),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    if (!authProvider.isLogged) {
      return const LoginPage();
    }
    if (authProvider.usuario?.deveAlterarPin == true) {
      return const ForceChangePinPage();
    }
    return const HomePage();
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/force_change_pin_page.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final (:isLoading, :isLogged, :deveAlterarPin) = context.select(
      (AuthProvider p) => (
        isLoading: p.isLoading,
        isLogged: p.isLogged,
        deveAlterarPin: p.usuario?.deveAlterarPin ?? false,
      ),
    );

    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!isLogged) {
      return const LoginPage();
    }
    if (deveAlterarPin) {
      return const ForceChangePinPage();
    }
    return const HomePage();
  }
}
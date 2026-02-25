import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

class LoginController {
  final matriculaController = TextEditingController();
  final pinController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void dispose() {
    matriculaController.dispose();
    pinController.dispose();
  }

  Future<void> submitLogin(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final provider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await provider.login(
        matriculaController.text.trim(),
        pinController.text.trim(),
      );

    } on AuthException catch (e) {
      if (context.mounted) {
        _showSnack(context, e.message, isError: true);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Erro inesperado. Tente novamente.', isError: true);
      }
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
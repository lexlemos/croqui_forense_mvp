import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class LoginController {
  final loginController = TextEditingController();
  final senhaController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void dispose() {
    loginController.dispose();
    senhaController.dispose();
  }

  Future<void> submitLogin(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final provider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await provider.login(
        loginController.text.trim(),
        senhaController.text,
      );

    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(msg.isNotEmpty ? msg : 'Erro inesperado. Tente novamente.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    final messenger = globalMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
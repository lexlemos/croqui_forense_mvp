import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class LoginController {
  final loginController = TextEditingController();
  final senhaController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void dispose() {
    loginController.dispose();
    senhaController.dispose();
  }

  Future<void> carregarLoginSalvo(BuildContext context) async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final salvo = await provider.getSavedLogin();
    if (salvo != null && salvo.isNotEmpty) {
      loginController.text = salvo;
    }
  }

  Future<void> submitLogin(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final provider = Provider.of<AuthProvider>(context, listen: false);
    final loginText = loginController.text.trim();

    try {
      await provider.login(
        loginText,
        senhaController.text,
      );
      await provider.saveSavedLogin(loginText);
      
      try {
        final syncService = Provider.of<SyncService>(context, listen: false);
        await syncService.pullCasos();
      } catch (e) {
        debugPrint('Falha silenciosa ao realizar pullCasos pós-login: $e');
      }
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
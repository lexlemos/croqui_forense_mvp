import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class ForceChangePinController {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void dispose() {
    pinController.dispose();
    confirmController.dispose();
  }

  String? validarPin(String? v) {
    if (v == null || v.length != 4) return 'Deve ter 4 dígitos';
    return null;
  }

  String? validarConfirmacao(String? v) {
    if (v != pinController.text) return 'Os PINs não conferem';
    return null;
  }

  Future<void> submitChange(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.atualizarPinPrimeiroAcesso(pinController.text);
      
      globalMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Senha atualizada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: $e'), 
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class ForceChangePasswordController {
  final senhaController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void dispose() {
    senhaController.dispose();
    confirmController.dispose();
  }

  String? validarSenha(String? v) {
    if (v == null || v.trim().isEmpty) return 'A senha não pode ser vazia';
    if (v.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
    return null;
  }

  String? validarConfirmacao(String? v) {
    if (v == null || v.trim().isEmpty) return 'Confirme a nova senha';
    if (v != senhaController.text) return 'As senhas não conferem';
    return null;
  }

  Future<void> submitChange(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.atualizarSenhaPrimeiroAcesso(senhaController.text);

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

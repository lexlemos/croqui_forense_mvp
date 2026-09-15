import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';

/// Controlador de apresentação responsável pela orquestração do fluxo de autenticação,
/// validação de formulário de credenciais periciais e feedback visual ao usuário.
///
/// Atua no padrão arquitetural MVVM, desacoplando a camada de visualização ([LoginPage])
/// das regras de negócio executadas pelo [AuthProvider]. Garante a integridade do estado,
/// o gerenciamento do ciclo de vida dos controladores de entrada de texto e o disparo
/// da sincronização prévia de casos após o login bem-sucedido.
class LoginController {
  /// Controlador de edição para captura do identificador funcional (matrícula institucional ou e-mail).
  final TextEditingController loginController = TextEditingController();

  /// Controlador de edição para captura do PIN ou senha de segurança pericial.
  final TextEditingController senhaController = TextEditingController();

  /// Chave global de estado para validação estrutural do formulário de autenticação.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _isDisposed = false;

  /// Libera os recursos alocados pelos controladores de texto prevenindo vazamento de memória.
  void dispose() {
    _isDisposed = true;
    loginController.dispose();
    senhaController.dispose();
  }

  /// Recupera do armazenamento seguro o identificador funcional previamente registrado no dispositivo
  /// e preenche automaticamente o formulário para conferir celeridade à rotina de plantão pericial.
  Future<void> carregarLoginSalvo(BuildContext context) async {
    final AuthProvider provider = Provider.of<AuthProvider>(context, listen: false);
    final String? salvo = await provider.getSavedLogin();

    if (_isDisposed) return;

    if (salvo != null && salvo.trim().isNotEmpty) {
      loginController.text = salvo.trim();
    }
  }

  /// Submete as credenciais do perito para autenticação online ou fallback offline local.
  ///
  /// Em caso de sucesso, persiste o login para uso posterior e executa a carga inicial de casos periciais.
  /// Caso a autenticação seja rejeitada por regras de negócio ou pela trava de segurança RBAC
  /// (ex: usuário sem perfil de Perito, Médico Legista ou Administrador), captura a [AuthException]
  /// e apresenta um aviso visual amigável e explicativo.
  Future<void> submitLogin(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final AuthProvider provider = Provider.of<AuthProvider>(context, listen: false);
    final SyncService syncService = Provider.of<SyncService>(context, listen: false);
    final CaseListProvider caseListProvider = Provider.of<CaseListProvider>(context, listen: false);
    final String loginText = loginController.text.trim();

    try {
      await provider.login(
        loginText,
        senhaController.text,
      );
      await provider.saveSavedLogin(loginText);

      try {
        await syncService.pullCasos();
        await caseListProvider.carregarCasos();
      } on Object catch (e, stackTrace) {
        debugPrint('Falha ao realizar pullCasos pós-login: $e\n$stackTrace');
      }
    } on AuthException catch (e) {
      final bool isRestricaoAcesso = e.message.toLowerCase().contains('acesso restrito');
      _showSnack(
        e.message,
        isError: true,
        isWarning: isRestricaoAcesso,
      );
    } on Object catch (e) {
      final String msg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(
        msg.isNotEmpty ? msg : 'Ocorreu uma falha inesperada durante a autenticação. Tente novamente.',
        isError: true,
      );
    }
  }

  /// Apresenta um aviso visual flutuante (SnackBar) ao usuário com estilização semântica
  /// compatível com a severidade do evento (alerta de segurança RBAC, erro de validação ou sucesso).
  void _showSnack(String msg, {bool isError = false, bool isWarning = false}) {
    final ScaffoldMessengerState? messenger = globalMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final Color backgroundColor = isWarning
        ? const Color(0xFFC2410C)
        : (isError ? const Color(0xFFB91C1C) : const Color(0xFF15803D));

    final IconData icon = isWarning
        ? Icons.lock_person_outlined
        : (isError ? Icons.error_outline : Icons.check_circle_outline);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: isWarning ? const Duration(seconds: 5) : const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

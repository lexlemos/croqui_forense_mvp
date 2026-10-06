import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';

/// Badge compacto estilo "pílula" para exibir o status de confirmação do ATN.
class StatusAtnBadge extends StatelessWidget {
  final StatusConfirmacaoATN status;
  final bool showIcon;

  const StatusAtnBadge({
    super.key,
    required this.status,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final _BadgeConfig config = switch (status) {
      StatusConfirmacaoATN.PENDENTE => const _BadgeConfig(
          label: 'Pendente',
          icon: Icons.pending_actions,
          backgroundColor: Color(0xFFFFF3E0), // Orange 50
          borderColor: Color(0xFFFFCC80), // Orange 200
          textColor: Color(0xFFE65100), // Orange 900
        ),
      StatusConfirmacaoATN.VISUALIZADO => const _BadgeConfig(
          label: 'Visualizado',
          icon: Icons.visibility,
          backgroundColor: Color(0xFFE3F2FD), // Blue 50
          borderColor: Color(0xFF90CAF9), // Blue 200
          textColor: Color(0xFF0D47A1), // Blue 900
        ),
      StatusConfirmacaoATN.CONFIRMADO => const _BadgeConfig(
          label: 'Confirmado',
          icon: Icons.check_circle,
          backgroundColor: Color(0xFFE8F5E9), // Green 50
          borderColor: Color(0xFFA5D6A7), // Green 200
          textColor: Color(0xFF1B5E20), // Green 900
        ),
      StatusConfirmacaoATN.RECUSADO => const _BadgeConfig(
          label: 'Recusado',
          icon: Icons.cancel,
          backgroundColor: Color(0xFFFFEBEE), // Red 50
          borderColor: Color(0xFFEF9A9A), // Red 200
          textColor: Color(0xFFB71C1C), // Red 900
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(config.icon, size: 13, color: config.textColor),
            const SizedBox(width: 4),
          ],
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.textColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Container com borda vermelha e fundo avermelhado claro para exibir a justificativa de recusa.
class JustificativaRecusaBox extends StatelessWidget {
  final String justificativa;

  const JustificativaRecusaBox({
    super.key,
    required this.justificativa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // Red 50
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF5350), width: 1), // Red 400
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFC62828), // Red 800
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motivo da Recusa (A.T.N.):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB71C1C), // Red 900
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  justificativa,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB71C1C),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

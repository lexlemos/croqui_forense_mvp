import 'package:flutter/material.dart';

/// Componente visual do PIN (marcador de lesão) renderizado sobre o diagrama anatômico.
///
/// **Design & Acessibilidade:**
/// - **Tamanho Visual Reduzido:** Marcador compacto (padrão 15.0 px, ~37.5% menor que os 24px anteriores),
///   evitando a poluição visual das malhas anatômicas (faces frontais, dorsais e laterais).
/// - **Touch Target Garantido (WCAG / MD3):** Envolvido por uma área transparente de no mínimo 44x44 pixels
///   (`touchTargetSize`), permitindo toque fácil e preciso pelo perito em telas touch.
class InjuryPin extends StatelessWidget {
  /// Tamanho da área clicável de toque (Touch Target) para acessibilidade (Mínimo de 44.0 px).
  final double touchTargetSize;

  /// Tamanho visual do ícone do marcador (Reduzido para 15.0 px).
  final double visualSize;

  /// Cor principal do pino de lesão.
  final Color color;

  /// Callback opcional executado ao tocar no marcador.
  final VoidCallback? onTap;

  /// Rótulo ou número sequencial opcional para identificação no croqui.
  final String? label;

  const InjuryPin({
    super.key,
    this.touchTargetSize = 44.0,
    this.visualSize = 15.0,
    this.color = Colors.red,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: touchTargetSize,
        height: touchTargetSize,
        color: Colors.transparent, // Garante sensibilidade ao toque em toda a área de 44x44px
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.location_on,
              color: color,
              size: visualSize,
              shadows: const [
                Shadow(
                  blurRadius: 3,
                  color: Colors.black54,
                  offset: Offset(1.5, 1.5),
                ),
              ],
            ),
            if (label != null && label!.isNotEmpty)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Center(
                    child: Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

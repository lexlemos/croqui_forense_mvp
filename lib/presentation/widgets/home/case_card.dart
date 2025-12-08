import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';

class CaseCard extends StatelessWidget {
  final Caso caso;
  final VoidCallback onTap;

  const CaseCard({
    super.key,
    required this.caso,
    required this.onTap,
  });

  static const double _cardRadius = 12.0;
  static const double _shadowBlur = 6.0;
  static const Offset _shadowOffset = Offset(0, 3);
  static const double _contentPadding = 10.0;
  
  static const double _tagFontSize = 9.0;
  static const double _titleFontSize = 15.0;
  static const double _subtitleFontSize = 10.0;
  
  static const double _iconContainerSize = 28.0;
  static const double _iconSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final (Color corStatus, Color bgStatus, String textoStatus) = switch (caso.status) {
      StatusCaso.finalizado => (
        Colors.green[700]!,
        Colors.green.withOpacity(0.1),
        'FINALIZADO'
      ),
      StatusCaso.rascunho => (
        colorScheme.primary,
        colorScheme.primary.withOpacity(0.1),
        'RASCUNHO'
      ),
      StatusCaso.sincronizado => (
        Colors.indigo,
        Colors.indigo.withOpacity(0.1),
        'SINCRONIZADO'
      ),
      StatusCaso.arquivado => (
        Colors.grey[700]!,
        Colors.grey.withOpacity(0.1),
        'ARQUIVADO'
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: _shadowBlur,
            offset: _shadowOffset,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_cardRadius),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                top: _contentPadding,
                right: _contentPadding,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgStatus,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    textoStatus,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: _tagFontSize,
                      fontWeight: FontWeight.bold,
                      color: corStatus,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: _contentPadding,
                left: _contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caso.numeroLaudoExterno ?? '---',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: _titleFontSize,
                        color: colorScheme.onSurface, 
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Nº Laudo',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: _subtitleFontSize,
                        color: colorScheme.onSurfaceVariant, 
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: _contentPadding,
                right: _contentPadding,
                child: Container(
                  width: _iconContainerSize,
                  height: _iconContainerSize,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest, 
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: _iconSize,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              Positioned(
                bottom: _contentPadding,
                left: _contentPadding,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month, 
                      size: _subtitleFontSize, 
                      color: colorScheme.outline 
                    ),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd/MM/yy').format(caso.criadoEmDispositivo),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: _subtitleFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
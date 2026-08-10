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

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, Color statusBg, String statusLabel) = switch (caso.status) {
      StatusCaso.rascunho => (
        const Color(0xFF00838F),
        const Color(0xFFE0F7FA),
        'RASCUNHO',
      ),
      StatusCaso.laudo_pendente => (
        const Color(0xFFE65100),
        const Color(0xFFFFF3E0),
        'LAUDO PENDENTE',
      ),
      StatusCaso.finalizado => (
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
        'FINALIZADO',
      ),
      StatusCaso.sincronizado => (
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
        'FINALIZADO',
      ),
      StatusCaso.arquivado => (
        const Color(0xFF616161),
        const Color(0xFFF5F5F5),
        'ARQUIVADO',
      ),
    };

    final mainTitle = (caso.numeroPic.isNotEmpty) 
        ? 'N. PIC: ${caso.numeroPic}'
        : 'N. PIC: Não informado';
    
    final laudoSub = (caso.numeroLaudoExterno != null && caso.numeroLaudoExterno!.isNotEmpty)
        ? 'Laudo: ${caso.numeroLaudoExterno}'
        : 'Laudo: Pendente';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Topo: Número do Laudo (Esquerda) + Status e Ícone da Nuvem (Direita)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            laudoSub,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: caso.isDraftSynced
                              ? 'Sincronizado na nuvem'
                              : 'Sincronização pendente',
                          child: Icon(
                            caso.isDraftSynced
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_upload_rounded,
                            size: 18,
                            color: caso.isDraftSynced
                                ? Colors.teal.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Meio: Espaço limpo (Spacer)
                const Spacer(),

                // Rodapé: Data (Esquerda) + Botão de Seta Pastel (Direita)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd/MM/yyyy').format(caso.criadoEmDispositivo),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
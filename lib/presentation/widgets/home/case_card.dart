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
    final isFinalizado = caso.status == StatusCaso.finalizado;
    
    final corStatus = isFinalizado ? Colors.green[700]! : const Color(0xFF317FF5);
    final bgStatus = isFinalizado ? Colors.green.withOpacity(0.1) : const Color(0xFF317FF5).withOpacity(0.1);
    final textoStatus = isFinalizado ? 'FINALIZADO' : 'RASCUNHO';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgStatus,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    textoStatus,
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold,
                      color: corStatus,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 10,
                left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caso.numeroLaudoExterno ?? '---',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15, 
                        color: Color(0xFF2C3A4B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Nº Laudo',
                      style: TextStyle(
                        fontSize: 10, 
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 14, 
                    color: Color(0xFF317FF5),
                  ),
                ),
              ),

              Positioned(
                bottom: 10,
                left: 10,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 10, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd/MM/yy').format(caso.criadoEmDispositivo),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
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
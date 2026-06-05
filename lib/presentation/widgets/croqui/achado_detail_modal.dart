import 'dart:io';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class AchadoDetailModal extends StatelessWidget {
  final Achado achado;
  final VoidCallback? onEdit;

  const AchadoDetailModal({super.key, required this.achado, this.onEdit});

  static Future<void> show(BuildContext context, Achado achado) {
    return showDialog(
      context: context,
      builder: (context) => AchadoDetailModal(achado: achado),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = achado.dadosPreenchidos;
    final String tipo = (d['type_label'] ?? 'Indefinido').toString().toUpperCase();
    final String local = d['local_anatomico_nome'] ?? d['local_anatomico_id'] ?? '-';
    final String? photoPath = d['photo_path'];
    final Color tagColor = achado.isInterno ? Colors.orange : Colors.green;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(tipo, local, tagColor),
              _buildTechnicalInfo(d),
              _buildDynamicFields(d['dynamicFields'] is Map ? Map<String, dynamic>.from(d['dynamicFields']) : null),
              if (achado.observacoesTexto?.isNotEmpty == true) _buildObservations(achado.observacoesTexto!),
              if (photoPath != null && File(photoPath).existsSync()) _buildPhoto(photoPath),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String tipo, String local, Color tagColor) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                  Text(local, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
            _buildTag(achado.isInterno ? "INTERNO" : "EXTERNO", tagColor),
          ],
        ),
      );

  Widget _buildTechnicalInfo(Map d) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            _buildDetailItem(Icons.straighten, "TAMANHO", "${d['size'] ?? '-'} cm"),
            const SizedBox(width: 24),
            _buildDetailItem(Icons.vertical_align_bottom, "PROFUNDIDADE", "${d['depth'] ?? '-'}"),
          ],
        ),
      );

  Widget _buildObservations(String obs) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("OBSERVAÇÕES MÉDICAS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(obs, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _buildPhoto(String path) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("REGISTRO FOTOGRÁFICO:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(path), fit: BoxFit.cover, width: double.infinity, cacheWidth: 800, cacheHeight: 600),
            ),
          ],
        ),
      );

  Widget _buildFooter(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (onEdit != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("EDITAR"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, 
                  foregroundColor: Colors.white
                ),
                child: const Text("FECHAR"),
              ),
            ),
          ],
        ),
      );


  Widget _buildTag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _buildDetailItem(IconData icon, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          ]),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _buildDynamicFields(Map<String, dynamic>? dynamicFields) {
    final Map<String, dynamic> mapToShow = Map<String, dynamic>.from(dynamicFields ?? {});

    mapToShow.removeWhere((key, value) =>
      key.startsWith('_') ||
      value == null ||
      (value is String && value.trim().isEmpty) ||
      key == 'photo_path' ||
      key == 'photoPath' ||
      key == 'view' ||
      key == 'local_anatomico_id' ||
      key == 'local_anatomico_nome' ||
      key == 'type_label' ||
      key == 'typeId' ||
      key == 'is_interno' ||
      key == 'isInterno' ||
      key == 'achadoRelacionadoUuid'
    );

    if (achado.achadoRelacionadoUuid != null && achado.achadoRelacionadoUuid!.isNotEmpty) {
      final uuid = achado.achadoRelacionadoUuid!;
      mapToShow['orificio_entrada_vinculo'] = 'Vinculado (ID: ${uuid.length >= 8 ? uuid.substring(0, 8) : uuid})';
    }

    if (mapToShow.isEmpty) return const SizedBox.shrink();

    final Map<String, String> keyLabels = {
      'tipo_orificio': 'Tipo de Orifício',
      'orificio_entrada_vinculo': 'Orifício de Entrada Vinculado',
      'numero_orificios': 'Quantidade de Orifícios',
      'quantidade': 'Quantidade',
      'numero_lesoes': 'Quantidade de Lesões',
      'trajeto': 'Trajeto da Lesão',
      'zona_tatuagem': 'Zona de Tatuagem',
      'zona_esfumacamento': 'Zona de Esfumaçamento',
      'efeitos_secundarios': 'Efeitos Secundários',
      'vestigios': 'Vestígios de Pólvora/Chumbo',
    };

    String formatKey(String key) {
      if (keyLabels.containsKey(key)) return keyLabels[key]!;
      final words = key.split('_');
      return words.map((w) {
        if (w.isEmpty) return '';
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
    }

    String formatValue(dynamic val) {
      if (val is bool) {
        return val ? 'Sim' : 'Não';
      }
      return val?.toString() ?? '-';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CARACTERÍSTICAS DA LESÃO:",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...mapToShow.entries.map((entry) {
              final label = formatKey(entry.key);
              final val = formatValue(entry.value);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$label: ",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Expanded(
                      child: Text(
                        val,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
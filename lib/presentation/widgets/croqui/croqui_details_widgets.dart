import 'dart:io';
import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';

class AchadosSidebar extends StatelessWidget {
  final List<Achado> achados;
  final bool isReadOnly;
  final Function(Achado) onEdit;
  final Function(String) onDelete;

  const AchadosSidebar({
    super.key,
    required this.achados,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: achados.isEmpty ? _buildEmptyState() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(12),
        color: isReadOnly ? Colors.blueGrey[100] : Colors.indigo[50],
        width: double.infinity,
        child: Text("Achados (${achados.length})",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isReadOnly ? Colors.blueGrey[800] : Colors.indigo)),
      );

  Widget _buildEmptyState() => Center(
        child: Text(isReadOnly ? "Nenhum registro." : "Toque no corpo para adicionar",
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: achados.length,
        itemBuilder: (ctx, i) => _AchadoCard(
          achado: achados[i],
          isReadOnly: isReadOnly,
          onTap: () => onEdit(achados[i]),
          onDelete: () => onDelete(achados[i].uuid),
        ),
      );
}

class _AchadoCard extends StatelessWidget {
  final Achado achado;
  final bool isReadOnly;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AchadoCard({required this.achado, required this.isReadOnly, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = achado.dadosPreenchidos;
    final color = achado.isInterno ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: IntrinsicHeight( 
            child: Row(
              children: [
                _buildImageBadge(d['photo_path']),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoColumn(d, color)),
                if (!isReadOnly)
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBadge(String? path) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            child: path != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: 100,)) : const Icon(Icons.camera_alt, color: Colors.grey),
          ),
          Positioned(top: -5, left: -5, child: CircleAvatar(radius: 9, backgroundColor: Colors.red, child: Text(achado.numeroSequencial.toString(), style: const TextStyle(color: Colors.white, fontSize: 9)))),
        ],
      );

  Widget _buildInfoColumn(Map d, Color tagColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (d['type_label'] ?? '').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 12, 
                    color: Colors.indigo
                  ),
                  overflow: TextOverflow.ellipsis, 
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4), 
              _tag(achado.isInterno ? "INTERNO" : "EXTERNO", tagColor),
            ],
          ),
          Text(d['local_anatomico_nome'] ?? '-', 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, 
              maxLines: 1),
          const SizedBox(height: 4),
          Text("Tam: ${d['size'] ?? '-'}cm | Prof: ${d['depth'] ?? '-'}", 
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
          if (achado.observacoesTexto?.isNotEmpty == true)
            Text(
              achado.observacoesTexto!, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)
            ),
        ],
      );

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withAlpha(50))),
        child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
      );
}
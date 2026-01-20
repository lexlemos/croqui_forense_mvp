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
        Container(
          padding: const EdgeInsets.all(12),
          color: isReadOnly ? Colors.blueGrey[100] : Colors.indigo[50],
          width: double.infinity,
          child: Text(
            "Achados (${achados.length})",
            style: TextStyle(fontWeight: FontWeight.bold, color: isReadOnly ? Colors.black87 : Colors.indigo),
          ),
        ),
        Expanded(
          child: achados.isEmpty
              ? Center(
                  child: Text(
                    isReadOnly ? "Nenhum achado." : "Toque no corpo para adicionar",
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: achados.length,
                  itemBuilder: (ctx, i) => _AchadoCard(
                    achado: achados[i],
                    isReadOnly: isReadOnly,
                    onTap: () => onEdit(achados[i]),
                    onDelete: () => onDelete(achados[i].uuid),
                  ),
                ),
        )
      ],
    );
  }
}

class _AchadoCard extends StatelessWidget {
  final Achado achado;
  final bool isReadOnly;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AchadoCard({required this.achado, required this.isReadOnly, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dados = achado.dadosPreenchidos;
    final tipo = dados['type_label'] ?? 'Indefinido';
    final foto = dados['photo_path'];
    final String localNome = dados['local_anatomico_nome'] ?? dados['local_anatomico_id'] ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: GestureDetector(
          onTap: () => _showPhotoDetail(context, foto),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: foto != null
                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(foto), fit: BoxFit.cover))
                : const Icon(Icons.camera_alt, size: 20),
          ),
        ),
        title: Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(localNome, maxLines: 1, style: const TextStyle(fontSize: 11)),
        trailing: isReadOnly
            ? null
            : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
      ),
    );
  }

  void _showPhotoDetail(BuildContext context, String? path) {
    if (path == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (File(path).existsSync())
              Image.file(File(path))
            else
              const Padding(padding: EdgeInsets.all(20), child: Text("Imagem não encontrada")),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("FECHAR"))
          ],
        ),
      ),
    );
  }
}
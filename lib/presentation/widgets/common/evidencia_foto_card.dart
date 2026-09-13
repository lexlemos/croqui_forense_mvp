import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/presentation/utils/image_resolver.dart';

class EvidenciaFotoCard extends StatelessWidget {
  final String path;
  final String? descricao;
  final bool readOnly;
  final ValueChanged<String>? onDescriptionChanged;
  final VoidCallback? onDelete;
  final double width;

  const EvidenciaFotoCard({
    super.key,
    required this.path,
    this.descricao,
    required this.readOnly,
    this.onDescriptionChanged,
    this.onDelete,
    this.width = 160,
  });

  void _abrirModalLegenda(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _LegendaDialogContent(
          descricaoInicial: descricao,
          readOnly: readOnly,
          onSave: (val) => onDescriptionChanged?.call(val),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    final temDescricao = descricao != null && descricao!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageResolver.buildImage(path, fit: BoxFit.cover),
                  ),
                  if (!readOnly && onDelete != null)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 14, color: Colors.white),
                          onPressed: onDelete,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _abrirModalLegenda(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!temDescricao) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            readOnly ? Icons.visibility : Icons.edit,
                            size: 14,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            readOnly ? "Sem legenda" : "Adicionar Legenda",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.indigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        readOnly ? "Clique para ver" : "Clique para editar",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendaDialogContent extends StatefulWidget {
  final String? descricaoInicial;
  final bool readOnly;
  final ValueChanged<String>? onSave;

  const _LegendaDialogContent({
    required this.descricaoInicial,
    required this.readOnly,
    this.onSave,
  });

  @override
  State<_LegendaDialogContent> createState() => _LegendaDialogContentState();
}

class _LegendaDialogContentState extends State<_LegendaDialogContent> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.descricaoInicial ?? '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.readOnly ? "Visualizar Legenda" : "Legenda da Foto"),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _textCtrl,
          maxLines: 6,
          maxLength: 250,
          autofocus: !widget.readOnly,
          readOnly: widget.readOnly,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: "Digite a legenda ou observação detalhada para esta foto...",
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.readOnly ? "Fechar" : "Cancelar"),
        ),
        if (!widget.readOnly)
          ElevatedButton(
            onPressed: () {
              widget.onSave?.call(_textCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
      ],
    );
  }
}

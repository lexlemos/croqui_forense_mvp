import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/presentation/utils/image_resolver.dart';

class AchadosSidebar extends StatefulWidget {
  final List<Achado> achados;
  final List<EvidenciaMultimidia>? evidencias;
  final bool isReadOnly;
  final Function(Achado) onEdit;
  final Function(String) onDelete;
  final String? quickNotes;
  final ValueChanged<String>? onQuickNotesChanged;

  const AchadosSidebar({
    super.key,
    required this.achados,
    this.evidencias,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    this.quickNotes,
    this.onQuickNotesChanged,
  });

  @override
  State<AchadosSidebar> createState() => _AchadosSidebarState();
}

class _AchadosSidebarState extends State<AchadosSidebar> {
  int _selectedFace = 0; // 0: Achados (Face 1), 1: Anotações Rápidas (Face 2)
  late final TextEditingController _quickNotesCtrl;

  @override
  void initState() {
    super.initState();
    _quickNotesCtrl = TextEditingController(text: widget.quickNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant AchadosSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickNotes != oldWidget.quickNotes &&
        widget.quickNotes != _quickNotesCtrl.text) {
      _quickNotesCtrl.text = widget.quickNotes ?? '';
    }
  }

  @override
  void dispose() {
    _quickNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              final inAnimation = Tween<Offset>(
                begin: const Offset(0.05, 0.0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: inAnimation, child: child),
              );
            },
            child: _selectedFace == 0
                ? KeyedSubtree(
                    key: const ValueKey('face_achados'),
                    child: widget.achados.isEmpty
                        ? _buildEmptyState()
                        : _buildList(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('face_anotacoes'),
                    child: _buildQuickNotesView(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isReadOnly ? Colors.blueGrey[100] : Colors.indigo[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: ExcludeFocus(
              excluding: true,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: Text(
                      "Achados (${widget.achados.length})",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.note_alt_outlined, size: 16),
                    label: Text(
                      "Rascunho",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                selected: {_selectedFace},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedFace = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            widget.isReadOnly
                ? "Nenhum achado registrado neste croqui."
                : "Toque no modelo para adicionar um achado.",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  Widget _buildList() => ExcludeFocus(
    excluding: true,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.achados.length,
      itemBuilder: (ctx, i) => _AchadoCard(
        achado: widget.achados[i],
        evidencias: widget.evidencias,
        isReadOnly: widget.isReadOnly,
        onTap: () => widget.onEdit(widget.achados[i]),
        onDelete: () => widget.onDelete(widget.achados[i].uuid),
      ),
    ),
  );

  Widget _buildQuickNotesView() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                "Anotações Rápidas (Apenas local / Auto-save)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isReadOnly ? Colors.grey[100] : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: TextFormField(
                controller: _quickNotesCtrl,
                readOnly: widget.isReadOnly,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  hintText: widget.isReadOnly
                      ? "Nenhuma anotação rápida registrada."
                      : "Digite rascunhos, medidas preliminares ou notas rápidas...\n(Salvo automaticamente no tablet)",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  contentPadding: const EdgeInsets.all(12),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  widget.onQuickNotesChanged?.call(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchadoCard extends StatelessWidget {
  final Achado achado;
  final List<EvidenciaMultimidia>? evidencias;
  final bool isReadOnly;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AchadoCard({
    required this.achado,
    this.evidencias,
    required this.isReadOnly,
    required this.onTap,
    required this.onDelete,
  });

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
                _buildImageBadge(achado),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoColumn(d, color)),
                if (!isReadOnly)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBadge(Achado achado) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageResolver.buildAchadoImage(
              achado: achado,
              evidencias: evidencias,
              fit: BoxFit.cover,
              errorWidget: const Icon(Icons.camera_alt, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          top: -5,
          left: -5,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: Colors.red,
            child: Text(
              achado.numeroSequencial.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }

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
                color: Colors.indigo,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          _tag(achado.isInterno ? "INTERNO" : "EXTERNO", tagColor),
        ],
      ),
      Text(
        d['local_anatomico_nome'] ?? '-',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      const SizedBox(height: 4),
      Text(
        "Tam: ${achado.tamanho.isEmpty ? '-' : achado.tamanho}cm | Prof: ${achado.profundidade.isEmpty ? '-' : achado.profundidade}",
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      ),
      if (achado.observacoesTexto?.isNotEmpty == true)
        Text(
          achado.observacoesTexto!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
        ),
    ],
  );

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withAlpha(50)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
    ),
  );
}

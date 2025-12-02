import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';

enum SortCriteria { numero, data }
enum SortOrder { asc, desc }

class FilterResult {
  final SortCriteria sortCriteria;
  final SortOrder sortOrder;
  final List<StatusCaso> selectedStatuses;

  FilterResult({
    required this.sortCriteria,
    required this.sortOrder,
    required this.selectedStatuses,
  });
}

class CaseFilterDialog extends StatefulWidget {
  final SortCriteria currentCriteria;
  final SortOrder currentOrder;
  final List<StatusCaso> currentStatuses;

  const CaseFilterDialog({
    super.key,
    required this.currentCriteria,
    required this.currentOrder,
    required this.currentStatuses,
  });

  @override
  State<CaseFilterDialog> createState() => _CaseFilterDialogState();
}

class _CaseFilterDialogState extends State<CaseFilterDialog> {
  late SortCriteria _criteria;
  late SortOrder _order;
  late List<StatusCaso> _selectedStatuses;

  @override
  void initState() {
    super.initState();
    _criteria = widget.currentCriteria;
    _order = widget.currentOrder;
    _selectedStatuses = List.from(widget.currentStatuses);
  }

  void _handleSortClick(SortCriteria criteria) {
    setState(() {
      if (_criteria == criteria) {
        _order = _order == SortOrder.asc ? SortOrder.desc : SortOrder.asc;
      } else {
        _criteria = criteria;
        _order = SortOrder.asc;
      }
    });
  }

  void _toggleStatus(StatusCaso status) {
    setState(() {
      if (_selectedStatuses.contains(status)) {
        _selectedStatuses.remove(status);
      } else {
        _selectedStatuses.add(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, 
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtrar e Ordenar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'ORDENAR POR',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSortButton('Número do Caso', SortCriteria.numero),
                const SizedBox(width: 12),
                _buildSortButton('Data de Criação', SortCriteria.data),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'FILTRAR POR STATUS',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Em Andamento', StatusCaso.rascunho, Colors.orange),
                _buildFilterChip('Finalizado', StatusCaso.finalizado, Colors.green),
                _buildFilterChip('Arquivado', StatusCaso.arquivado, Colors.grey),
              ],
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _criteria = SortCriteria.data;
                      _order = SortOrder.desc;
                      _selectedStatuses = [StatusCaso.rascunho, StatusCaso.finalizado]; // Padrão
                    });
                  },
                  child: const Text('Limpar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF317FF5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      FilterResult(
                        sortCriteria: _criteria,
                        sortOrder: _order,
                        selectedStatuses: _selectedStatuses,
                      ),
                    );
                  },
                  child: const Text('APLICAR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(String label, SortCriteria criteria) {
    final isSelected = _criteria == criteria;
    return Expanded(
      child: InkWell(
        onTap: () => _handleSortClick(criteria),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF317FF5).withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF317FF5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF317FF5) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  _order == SortOrder.asc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: const Color(0xFF317FF5),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildFilterChip(String label, StatusCaso status, Color color) {
    final isSelected = _selectedStatuses.contains(status);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _toggleStatus(status),
      checkmarkColor: color,
      selectedColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[100],
      side: isSelected 
          ? BorderSide(color: color) 
          : BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
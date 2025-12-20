import 'package:flutter/material.dart'; 
class HomeActionBar extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onNovoCaso;
  final VoidCallback onFiltrar;

  const HomeActionBar({
    super.key, 
    required this.searchController, 
    required this.onNovoCaso,
    required this.onFiltrar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
  
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar laudo...',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8))
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          IconButton.filledTonal(
            onPressed: onFiltrar,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
          ),
          
          const SizedBox(width: 8),
          
          IconButton.filled(
            onPressed: onNovoCaso,
            icon: const Icon(Icons.add),
            tooltip: 'Novo Caso',
          ),
        ],
      ),
    );
  }
}
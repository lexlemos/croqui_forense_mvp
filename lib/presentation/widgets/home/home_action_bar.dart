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
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Campo de Busca
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar caso...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Botões
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNovoCaso,
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    'Novo Caso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF317FF5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onFiltrar,
                icon: const Icon(Icons.filter_list, size: 18, color: Colors.black),
                label: const Text(
                  'Filtrar',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  side: const BorderSide(color: Color(0xFFE1E1E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
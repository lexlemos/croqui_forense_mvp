import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? errorDetails;

  const EmptyState({
    super.key,
    this.message = 'Nenhum item encontrado.',
    this.icon = Icons.folder_open_outlined,
    this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (errorDetails != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                errorDetails!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            )
        ],
      ),
    );
  }
}
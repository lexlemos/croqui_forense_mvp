import 'package:flutter/material.dart';

class NewCaseDialog extends StatefulWidget {
  const NewCaseDialog({super.key});

  @override
  State<NewCaseDialog> createState() => _NewCaseDialogState();
}

class _NewCaseDialogState extends State<NewCaseDialog> {
  // --- Controladores dos Campos ---
  // Seção 1: Cabeçalho
  final _requisicaoController = TextEditingController();
  final _requisitanteController = TextEditingController();
  final _destinoController = TextEditingController();
  final _vitimaController = TextEditingController();
  
  // Seção 2: Identificação
  final _vestesController = TextEditingController();
  final _caracteristicasController = TextEditingController();
  final _tanatologiaController = TextEditingController();

  @override
  void dispose() {
    _requisicaoController.dispose();
    _requisitanteController.dispose();
    _destinoController.dispose();
    _vitimaController.dispose();
    _vestesController.dispose();
    _caracteristicasController.dispose();
    _tanatologiaController.dispose();
    super.dispose();
  }

  void _submit() {
    // Validação mínima: Precisa pelo menos do número da requisição ou nome da vítima
    if (_requisicaoController.text.isEmpty && _vitimaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha a Requisição ou o nome da Vítima.')),
      );
      return;
    }

    // Monta o JSON (Map) estruturado conforme sua especificação
    final dadosIniciais = {
      // Campos de controle rápido (usados na lista)
      'numero_laudo': _requisicaoController.text.trim(),
      
      // O formulário completo (dados_laudo_json)
      'dados_laudo': {
        'cabecalho': {
          'requisicao': _requisicaoController.text.trim(),
          'requisitante': _requisitanteController.text.trim(),
          'destino': _destinoController.text.trim(),
          'vitima': _vitimaController.text.trim(),
        },
        'identificacao': {
          'vestes': _vestesController.text.trim(),
          'caracteristicas': _caracteristicasController.text.trim(),
          'dados_tanatologicos': _tanatologiaController.text.trim(),
        },
        // Inicializa as outras seções vazias para evitar null safety errors depois
        'historico': '',
        'exame_externo': [], // Lista de achados virá daqui depois
        'exame_interno': {},
        'quesitos': {},
        'conclusao': ''
      }
    };

    // Retorna o mapa de dados para a HomePage
    Navigator.pop(context, dadosIniciais);
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Dialog simples mas com scroll
    return AlertDialog(
      title: const Text('Novo Laudo Pericial Cadavérico'),
      content: SizedBox(
        width: 600, // Largura maior para tablet
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Dados da Requisição'),
              _buildTextField(
                controller: _requisicaoController,
                label: 'Número da Requisição (Laudo)',
                icon: Icons.assignment_ind,
                autoFocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _requisitanteController,
                      label: 'Autoridade Requisitante',
                      icon: Icons.account_balance,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _destinoController,
                      label: 'Destino do Laudo',
                      icon: Icons.send,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _vitimaController,
                label: 'Nome da Vítima',
                icon: Icons.person,
              ),

              const Divider(height: 40),

              _buildSectionTitle('Subseção Identificação'),
              _buildTextField(
                controller: _vestesController,
                label: 'Vestes',
                icon: Icons.accessibility,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _caracteristicasController,
                label: 'Características de Identificação (Sinais, Tatuagens)',
                icon: Icons.fingerprint,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _tanatologiaController,
                label: 'Dados Tanatológicos (Rigidez, Livores)',
                icon: Icons.watch_later_outlined,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF317FF5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: _submit,
          child: const Text('INICIAR EXAME'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool autoFocus = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        isDense: true,
      ),
      maxLines: maxLines,
      autofocus: autoFocus,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
    );
  }
}
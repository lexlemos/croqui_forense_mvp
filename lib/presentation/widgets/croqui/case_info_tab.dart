import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

class CaseInfoTab extends StatelessWidget {
  final Caso caso;

  const CaseInfoTab({super.key, required this.caso});

  @override
  Widget build(BuildContext context) {
    final dados = caso.dadosLaudo;
    final cabecalho = _safeMap(dados['cabecalho']);
    final identificacao = _safeMap(dados['identificacao']);
    final conclusao = dados['conclusao'] != null ? _safeMap(dados['conclusao']) : null;

    final authProvider = context.watch<AuthProvider>();
    String responsavelNome = caso.idUsuarioCriador;

    if (authProvider.usuario != null && authProvider.usuario!.id == caso.idUsuarioCriador) {
      responsavelNome = authProvider.usuario!.nomeCompleto;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoSection("DADOS DA REQUISIÇÃO", [
            _InfoRow("Requisição:", cabecalho['requisicao']?.toString()),
            _InfoRow("Requisitante:", cabecalho['requisitante']?.toString()),
            _InfoRow("Destino:", cabecalho['destino']?.toString()),
            _InfoRow("Vítima:", cabecalho['vitima']?.toString()),
          ]),
          const SizedBox(height: 20),
          _InfoSection("IDENTIFICAÇÃO E EXAME", [
            _InfoRow("Vestes:", identificacao['vestes']?.toString()),
            _InfoRow("Características:", identificacao['caracteristicas']?.toString()),
            _InfoRow("Dados Tanatológicos:", identificacao['dados_tanatologicos']?.toString()),
          ]),
          const SizedBox(height: 20),
          if (conclusao != null && conclusao.isNotEmpty)
            _InfoSection(
              "CONCLUSÃO DO LAUDO",
              [
                _InfoRow("1. Houve morte?", conclusao['pergunta_1']?.toString()),
                _InfoRow("2. Causa:", conclusao['pergunta_2']?.toString()),
                _InfoRow("3. Instrumento:", conclusao['pergunta_3']?.toString()),
                _InfoRow("4. Meio insidioso/cruel?", conclusao['pergunta_4']?.toString()),
                const Divider(),
                _InfoRow("Data Finalização:", _formatDate(conclusao['data_finalizacao']?.toString())),
                _InfoRow("Perito Responsável:", responsavelNome),
              ],
              isDestak: true,
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200)),
              child: const Text("Laudo em andamento. Conclusão pendente.", style: TextStyle(color: Colors.brown)),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _safeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
  
  String _formatDate(String? iso) {
    if (iso == null) return "-";
    try {
      final dt = DateTime.parse(iso);
      return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} às ${dt.hour}:${dt.minute}";
    } catch (e) { return iso; }
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDestak;

  const _InfoSection(this.title, this.children, {this.isDestak = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDestak ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        border: isDestak ? Border.all(color: Colors.green.shade200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDestak ? Colors.green[800] : Colors.indigo,
                  fontSize: 14)),
          const Divider(),
          const SizedBox(height: 8),
          ...children
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(value ?? '-', style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }
}
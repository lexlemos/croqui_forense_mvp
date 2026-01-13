import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/components/croqui/croqui_viewer.dart';
import 'package:croqui_forense_mvp/components/forms/injury_form_modal.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/finalize_case_dialog.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart'; 

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

import 'package:croqui_forense_mvp/data/models/injury_marker_model.dart';

import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart';

class CroquiPage extends StatefulWidget {
  final Caso caso; 

  const CroquiPage({super.key, required this.caso});

  @override
  State<CroquiPage> createState() => _CroquiPageState();
}

class _CroquiPageState extends State<CroquiPage> {
  final AchadoService _achadoService = AchadoService.instance;
  List<Achado> _achados = [];
  
  late bool _isReadOnly;
  late Caso _casoAtual;

  @override
  void initState() {
    super.initState();
    _casoAtual = widget.caso;
    _checkStatus();
    _loadAchados();
  }

  void _checkStatus() {
    setState(() {
      _isReadOnly = _casoAtual.status == StatusCaso.finalizado;
    });
  }

  Future<void> _loadAchados() async {
    final lista = await _achadoService.listarAchados(_casoAtual.uuid);
    if (mounted) {
      setState(() {
        _achados = lista;
      });
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return "-";
    try {
      final dt = DateTime.parse(iso);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      
      return "$day/$month/$year às $hour:$minute";
    } catch (e) {
      return iso;
    }
  }

  String _mapNameToId(String name) {
    switch (name) {
      case 'Equimose': return 'equimose';
      case 'Escoriação': return 'escoriacao';
      case 'Ferida Contusa': return 'ferida_contusa';
      case 'Ferida Cortante': return 'ferida_cortante';
      case 'Perfuração': return 'perfuracao';
      case 'Hematoma': return 'hematoma';
      case 'Edema': return 'edema';
      case 'Fratura': return 'fratura';
      case 'Queimadura': return 'queimadura';
      default: return 'outro';
    }
  }

  String _resolveBodyPartName(String view, String partId) {
    if (view == 'frente' && kIdToDefinitionFrontMap.containsKey(partId)) return kIdToDefinitionFrontMap[partId]!.name;
    if (view == 'costas' && kIdToDefinitionBackMap.containsKey(partId)) return kIdToDefinitionBackMap[partId]!.name;
    if (view == 'lateral_dir' && kIdToDefinitionLateralRightMap.containsKey(partId)) return kIdToDefinitionLateralRightMap[partId]!.name;
    if (view == 'lateral_esq' && kIdToDefinitionLateralLeftMap.containsKey(partId)) return kIdToDefinitionLateralLeftMap[partId]!.name;
    return partId.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _addAchado(String viewType, String partId, String rawPartName, double x, double y) async {
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caso finalizado. Edição bloqueada.")));
      return;
    }
    
    final String realPartName = _resolveBodyPartName(viewType, partId);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InjuryFormModal(bodyPartName: realPartName),
    );

    if (result == null) return;

    final String tipoLesaoNome = result['type']; 
    final String tipoLesaoId = _mapNameToId(tipoLesaoNome); 

    final Map<String, dynamic> dadosExtras = {
      'view': viewType,
      'local_anatomico_id': partId,
      'local_anatomico_nome': realPartName,
      'type_label': tipoLesaoNome,
      'size': result['size'],
      'depth': result['depth'],
      'photo_path': result['photoPath'],
    };

    final novoAchadoTemporario = Achado.novo(
      diagramaCasoUuid: _casoAtual.uuid,
      tipoAchadoId: tipoLesaoId, 
      numeroSequencial: _achados.length + 1,
      posX: x,
      posY: y,
    );

    final achadoFinal = Achado(
      uuid: novoAchadoTemporario.uuid,
      diagramaCasoUuid: novoAchadoTemporario.diagramaCasoUuid,
      tipoAchadoId: novoAchadoTemporario.tipoAchadoId,
      numeroSequencial: novoAchadoTemporario.numeroSequencial,
      posX: novoAchadoTemporario.posX,
      posY: novoAchadoTemporario.posY,
      estaPendente: true,
      dadosPreenchidos: dadosExtras,
      observacoesTexto: result['description'],
      removido: false,
      versao: 1,
      criadoEm: DateTime.now(),
      proveniencia: 'APP_TABLET',
    );

    try {
      await _achadoService.salvarAchado(achadoFinal);
      await _loadAchados();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Achado adicionado!")));
    } catch (e) {
      print("❌ Erro: $e");
    }
  }

  Future<void> _editAchado(Achado achado) async {
    if (_isReadOnly) {
       _showAchadoDetails(achado);
       return;
    }

    final dados = achado.dadosPreenchidos;
    final String localNome = dados['local_anatomico_nome'] ?? _resolveBodyPartName(dados['view'], achado.tipoAchadoId);

    final markerAdapter = InjuryMarker(
      id: achado.uuid,
      caseId: achado.diagramaCasoUuid,
      croquiType: dados['view'] ?? 'frente',
      bodyPartId: dados['local_anatomico_id'] ?? 'desconhecido',
      xPercent: achado.posX,
      yPercent: achado.posY,
      type: dados['type_label'] ?? '',
      size: dados['size'] ?? '',
      depth: dados['depth'] ?? '',
      photoPath: dados['photo_path'],
      description: achado.observacoesTexto,
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InjuryFormModal(
        bodyPartName: localNome,
        markerToEdit: markerAdapter,
      ),
    );

    if (result == null) return;

    final String tipoLesaoNome = result['type'];
    final String tipoLesaoId = _mapNameToId(tipoLesaoNome);

    final Map<String, dynamic> novosDados = Map.from(achado.dadosPreenchidos);
    novosDados['type_label'] = tipoLesaoNome;
    novosDados['size'] = result['size'];
    novosDados['depth'] = result['depth'];
    novosDados['photo_path'] = result['photoPath'];

    final achadoAtualizado = Achado(
      uuid: achado.uuid,
      diagramaCasoUuid: achado.diagramaCasoUuid,
      tipoAchadoId: tipoLesaoId,
      numeroSequencial: achado.numeroSequencial,
      posX: achado.posX,
      posY: achado.posY,
      estaPendente: true,
      dadosPreenchidos: novosDados,
      observacoesTexto: result['description'],
      removido: false,
      versao: achado.versao + 1,
      criadoEm: achado.criadoEm,
      atualizadoEm: DateTime.now(),
      proveniencia: achado.proveniencia,
    );

    await _achadoService.atualizarAchado(achadoAtualizado);
    await _loadAchados();
  }

  void _showAchadoDetails(Achado achado) {
    final dados = achado.dadosPreenchidos;
    final String tipo = dados['type_label'] ?? 'Não especificado';
    final String local = dados['local_anatomico_nome'] ?? 'Local desconhecido';
    final String tamanho = dados['size'] ?? '-';
    final String profundidade = dados['depth'] ?? '-';
    final String obs = achado.observacoesTexto ?? 'Sem observações.';
    final String? photoPath = dados['photo_path'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tipo, style: const TextStyle(color: Colors.indigo)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SizedBox(
          width: 500, 
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(local, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.straighten, "Tamanho:", "$tamanho cm"),
                _buildDetailRow(Icons.layers, "Profundidade:", profundidade),
                const SizedBox(height: 12),
                const Text("Observações:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(obs, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 16),
                if (photoPath != null && File(photoPath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(photoPath), height: 250, width: double.infinity, fit: BoxFit.cover),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [Icon(Icons.no_photography, color: Colors.grey), SizedBox(width: 8), Text("Sem foto registrada")]),
                  )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$label ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteAchado(String uuid) async {
    if (_isReadOnly) return; 
    await _achadoService.removerAchado(uuid);
    await _loadAchados();
  }
  
  Future<void> _iniciarFinalizacao() async {
    final dadosConclusao = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const FinalizeCaseDialog(),
    );

    if (dadosConclusao == null) return;

    final caseService = context.read<CaseService>();

    try {
      await caseService.finalizarCaso(_casoAtual.uuid, dadosConclusao);
      final casosAtualizados = await caseService.listarCasos();
      
      if (!mounted) return;

      setState(() {
        _casoAtual = casosAtualizados.firstWhere((c) => c.uuid == _casoAtual.uuid);
        _checkStatus();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caso finalizado!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  Future<void> _reabrirCasoParaEdicao() async {
    final caseService = context.read<CaseService>();
    try {
      await caseService.reabrirCaso(_casoAtual.uuid);
      final casosAtualizados = await caseService.listarCasos();

      if (!mounted) return;

      setState(() {
        _casoAtual = casosAtualizados.firstWhere((c) => c.uuid == _casoAtual.uuid);
        _checkStatus();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modo de edição habilitado.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _exportarCaso() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funcionalidade de Exportação em desenvolvimento.")),
    );
  }

  List<InjuryMarker> _getMarkersForView(String view) {
    return _achados
        .where((a) => (a.dadosPreenchidos['view'] ?? '') == view)
        .map((a) {
          return InjuryMarker(
            id: a.uuid,
            caseId: a.diagramaCasoUuid,
            croquiType: view,
            bodyPartId: a.dadosPreenchidos['local_anatomico_id'] ?? 'desconhecido', 
            xPercent: a.posX,
            yPercent: a.posY,
            type: a.dadosPreenchidos['type_label'] ?? '', 
            photoPath: a.dadosPreenchidos['photo_path'],
          );
        }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const double sidebarWidth = 320.0;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Exame Corporal", style: TextStyle(fontSize: 16)),
                  if (_isReadOnly) 
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text("CONCLUÍDO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              Text("Laudo: ${_casoAtual.numeroLaudoExterno ?? 'Novo'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
            ],
          ),
          backgroundColor: _isReadOnly ? Colors.blueGrey[800] : Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
             if (_isReadOnly)
               PopupMenuButton<String>(
                 onSelected: (value) {
                   if (value == 'edit') _reabrirCasoParaEdicao();
                   if (value == 'export') _exportarCaso();
                 },
                 itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                   const PopupMenuItem<String>(
                     value: 'edit',
                     child: ListTile(
                       leading: Icon(Icons.edit, color: Colors.indigo),
                       title: Text('Editar Caso'),
                       contentPadding: EdgeInsets.zero,
                     ),
                   ),
                   const PopupMenuItem<String>(
                     value: 'export',
                     child: ListTile(
                       leading: Icon(Icons.share, color: Colors.indigo),
                       title: Text('Exportar'),
                       contentPadding: EdgeInsets.zero,
                     ),
                   ),
                 ],
               ),
             if (!_isReadOnly)
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                 child: ElevatedButton.icon(
                   onPressed: _iniciarFinalizacao, 
                   icon: const Icon(Icons.check_circle, size: 18),
                   label: const Text("CONCLUIR"),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.white,
                     foregroundColor: Colors.indigo,
                     elevation: 0,
                   ),
                 ),
               )
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: "Frente"), 
              Tab(text: "Costas"), 
              Tab(text: "Lat. Dir"), 
              Tab(text: "Lat. Esq"),
              Tab(text: "Dados", icon: Icon(Icons.description, size: 16)),
            ],
          ),
        ),
        body: Row(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCroquiTab('frente', 'assets/images/croqui-frente.svg', 'assets/images/croqui-frente-mask.png', kColorToIdFrontMap, kIdToDefinitionFrontMap),
                    _buildCroquiTab('costas', 'assets/images/croqui-costas.svg', 'assets/images/croqui-costas-mask.png', kColorToIdBackMap, kIdToDefinitionBackMap),
                    _buildCroquiTab('lateral_dir', 'assets/images/croqui-rosto-direito.svg', 'assets/images/croqui-rosto-direito-mask.png', kColorToIdLateralRightMap, kIdToDefinitionLateralRightMap),
                    _buildCroquiTab('lateral_esq', 'assets/images/croqui-rosto-frente.svg', 'assets/images/croqui-rosto-frente-mask.png', kColorToIdLateralLeftMap, kIdToDefinitionLateralLeftMap),
                    _buildInfoTab(),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: sidebarWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: _isReadOnly ? Colors.blueGrey[100] : Colors.indigo[50],
                    width: double.infinity,
                    child: Text("Achados (${_achados.length})", style: TextStyle(fontWeight: FontWeight.bold, color: _isReadOnly ? Colors.black87 : Colors.indigo)),
                  ),
                  Expanded(
                    child: _achados.isEmpty 
                    ? Center(child: Text(_isReadOnly ? "Nenhum achado." : "Toque no corpo para adicionar", style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                      itemCount: _achados.length,
                      itemBuilder: (ctx, i) => _buildAchadoCard(_achados[i]),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final dados = _casoAtual.dadosLaudo;
    final cabecalho = dados['cabecalho'] ?? {};
    final identificacao = dados['identificacao'] ?? {};
    final conclusao = dados['conclusao']; 

    final authProvider = context.watch<AuthProvider>();
    String responsavelNome = _casoAtual.idUsuarioCriador;
    
    if (authProvider.usuario != null && authProvider.usuario!.id == _casoAtual.idUsuarioCriador) {
      responsavelNome = authProvider.usuario!.nomeCompleto;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection("DADOS DA REQUISIÇÃO", [
            _buildInfoRow("Requisição:", cabecalho['requisicao']),
            _buildInfoRow("Requisitante:", cabecalho['requisitante']),
            _buildInfoRow("Destino:", cabecalho['destino']),
            _buildInfoRow("Vítima:", cabecalho['vitima']),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection("IDENTIFICAÇÃO E EXAME", [
            _buildInfoRow("Vestes:", identificacao['vestes']),
            _buildInfoRow("Características:", identificacao['caracteristicas']),
            _buildInfoRow("Dados Tanatológicos:", identificacao['dados_tanatologicos']),
          ]),
          const SizedBox(height: 20),
          
          if (conclusao != null)
             _buildInfoSection("CONCLUSÃO DO LAUDO", [
               _buildInfoRow("1. Houve morte?", conclusao['pergunta_1']),
               _buildInfoRow("2. Causa:", conclusao['pergunta_2']),
               _buildInfoRow("3. Instrumento:", conclusao['pergunta_3']),
               _buildInfoRow("4. Meio insidioso/cruel?", conclusao['pergunta_4']),
               const Divider(),
               _buildInfoRow("Data Finalização:", _formatDate(conclusao['data_finalizacao'])),
               _buildInfoRow("Perito Responsável:", responsavelNome),
             ], isDestak: true)
          else
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200)
              ),
              child: const Text("Laudo em andamento. Conclusão pendente.", style: TextStyle(color: Colors.brown)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {bool isDestak = false}) {
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
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestak ? Colors.green[800] : Colors.indigo, fontSize: 14)),
          const Divider(),
          const SizedBox(height: 8),
          ...children
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, 
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13))
          ),
          Expanded(
            child: Text(value ?? '-', style: const TextStyle(color: Colors.black87, fontSize: 13))
          ),
        ],
      ),
    );
  }

  Widget _buildCroquiTab(String view, String svg, String mask, Map<int, String> colors, Map<String, dynamic> defs) {
    return CroquiViewer(
      svgPath: svg,
      maskPath: mask,
      colorToIdMap: colors,
      idToDefMap: defs,
      markers: _getMarkersForView(view),
      onPartTap: (id, name, x, y) => _addAchado(view, id, name, x, y),
    );
  }

  Widget _buildAchadoCard(Achado achado) {
    final dados = achado.dadosPreenchidos;
    final tipo = dados['type_label'] ?? 'Indefinido';
    final foto = dados['photo_path'];
    final String localNome = dados['local_anatomico_nome'] ?? 
                             _resolveBodyPartName(dados['view'] ?? '', dados['local_anatomico_id'] ?? '') ;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: () => _editAchado(achado),
        leading: GestureDetector(
          onTap: () => _showPhotoDetail(foto),
          child: Container(
            width: 40, height: 40,
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
        trailing: _isReadOnly 
          ? null 
          : IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteAchado(achado.uuid),
            ),
      ),
    );
  }

  void _showPhotoDetail(String? path) {
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
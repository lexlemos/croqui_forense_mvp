import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';

class CaseInfoTab extends StatefulWidget {
  const CaseInfoTab({super.key});

  @override
  State<CaseInfoTab> createState() => _CaseInfoTabState();
}

class _CaseInfoTabState extends State<CaseInfoTab> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _reqNumeroCtrl;
  late final TextEditingController _reqOrigemCtrl;
  late final TextEditingController _reqDestinoCtrl;
  late final TextEditingController _nomeVitimaCtrl;

  late final TextEditingController _vestesCtrl;
  late final TextEditingController _caracteristicasCtrl;
  late final TextEditingController _tanatologiaCtrl;

  late final TextEditingController _anatomoCtrl;
  late final TextEditingController _toxicologicoCtrl;
  late final TextEditingController _outrosExamesCtrl;

  late final TextEditingController _discussaoCtrl;
  late final TextEditingController _conclusaoCtrl;

  late final TextEditingController _quesito1Ctrl;
  late final TextEditingController _quesito2Ctrl;
  late final TextEditingController _quesito3Ctrl;
  late final TextEditingController _quesito4Ctrl;

  List<String> _fotosIdentificacao = [];

  @override
  void initState() {
    super.initState();
    final controller = context.read<CroquiController>();
    final dados = controller.casoAtual.dadosLaudo;

    _fotosIdentificacao = List<String>.from(dados['identificacao']?['fotos_gerais'] ?? []);
    
    _reqNumeroCtrl = TextEditingController(text: controller.casoAtual.numeroLaudoExterno ?? '');
    _reqOrigemCtrl = TextEditingController(text: dados['cabecalho']?['requisitante'] ?? '');
    _reqDestinoCtrl = TextEditingController(text: dados['cabecalho']?['destino'] ?? '');
    _nomeVitimaCtrl = TextEditingController(text: dados['cabecalho']?['vitima'] ?? '');

    _vestesCtrl = TextEditingController(text: dados['identificacao']?['vestes'] ?? '');
    _caracteristicasCtrl = TextEditingController(text: dados['identificacao']?['caracteristicas'] ?? '');
    _tanatologiaCtrl = TextEditingController(text: dados['identificacao']?['dados_tanatologicos'] ?? '');

    _anatomoCtrl = TextEditingController(text: dados['exames_complementares']?['anatomo'] ?? '');
    _toxicologicoCtrl = TextEditingController(text: dados['exames_complementares']?['toxicologico'] ?? '');
    _outrosExamesCtrl = TextEditingController(text: dados['exames_complementares']?['outros'] ?? '');

    _discussaoCtrl = TextEditingController(text: dados['conclusao']?['discussao'] ?? '');
    _conclusaoCtrl = TextEditingController(text: dados['conclusao']?['conclusao_texto'] ?? '');

    _quesito1Ctrl = TextEditingController(text: dados['conclusao']?['quesito_1_morte'] ?? '');
    _quesito2Ctrl = TextEditingController(text: dados['conclusao']?['quesito_2_causa'] ?? '');
    _quesito3Ctrl = TextEditingController(text: dados['conclusao']?['quesito_3_instrumento'] ?? '');
    _quesito4Ctrl = TextEditingController(text: dados['conclusao']?['quesito_4_meio'] ?? '');
  }

  Future<void> _tirarFoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _fotosIdentificacao.add(photo.path);
      });
      _salvarDadosNoController();
    }
  }

  @override
  void dispose() {
    _salvarDadosNoController();
    _reqNumeroCtrl.dispose();
    _reqOrigemCtrl.dispose();
    _reqDestinoCtrl.dispose();
    _nomeVitimaCtrl.dispose();
    _vestesCtrl.dispose();
    _caracteristicasCtrl.dispose();
    _tanatologiaCtrl.dispose();
    _anatomoCtrl.dispose();
    _toxicologicoCtrl.dispose();
    _outrosExamesCtrl.dispose();
    _discussaoCtrl.dispose();
    _conclusaoCtrl.dispose();
    _quesito1Ctrl.dispose();
    _quesito2Ctrl.dispose();
    _quesito3Ctrl.dispose();
    _quesito4Ctrl.dispose();
    super.dispose();
  }

  void _salvarDadosNoController() {
    if (!mounted) return;

    final controller = context.read<CroquiController>();
    if (controller.isReadOnly) return;

    final Map<String, dynamic> novosDados = Map<String, dynamic>.from(controller.casoAtual.dadosLaudo);

    novosDados['cabecalho'] = {
      ...(novosDados['cabecalho'] as Map<String, dynamic>? ?? {}),
      'requisitante': _reqOrigemCtrl.text,
      'destino': _reqDestinoCtrl.text,
      'vitima': _nomeVitimaCtrl.text,
      'requisicao': _reqNumeroCtrl.text,
    };

    novosDados['identificacao'] = {
      ...(novosDados['identificacao'] as Map<String, dynamic>? ?? {}),
      'vestes': _vestesCtrl.text,
      'caracteristicas': _caracteristicasCtrl.text,
      'dados_tanatologicos': _tanatologiaCtrl.text,
      'fotos_gerais': _fotosIdentificacao,
    };

    novosDados['exames_complementares'] = {
      'anatomo': _anatomoCtrl.text,
      'toxicologico': _toxicologicoCtrl.text,
      'outros': _outrosExamesCtrl.text,
    };

    novosDados['conclusao'] = {
      ...(novosDados['conclusao'] as Map<String, dynamic>? ?? {}),
      'discussao': _discussaoCtrl.text,
      'conclusao_texto': _conclusaoCtrl.text,
      'quesito_1_morte': _quesito1Ctrl.text,
      'quesito_2_causa': _quesito2Ctrl.text,
      'quesito_3_instrumento': _quesito3Ctrl.text,
      'quesito_4_meio': _quesito4Ctrl.text,
      'data_finalizacao': DateTime.now().toIso8601String(),
    };

    controller.atualizarDadosLaudoMemoria(novosDados);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CroquiController>();
    final bool readOnly = controller.isReadOnly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: "1. Dados da Requisição", icon: Icons.description),
            const SizedBox(height: 16),
            _buildTextField("Número da Requisição", _reqNumeroCtrl, readOnly: true, isBold: true),
            _buildTextField("Vítima", _nomeVitimaCtrl, readOnly: readOnly),
            Row(
              children: [
                Expanded(child: _buildTextField("Requisitante / Origem", _reqOrigemCtrl, readOnly: readOnly)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Destino", _reqDestinoCtrl, readOnly: readOnly)),
              ],
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: "2. Identificação e Exame", icon: Icons.person_search),
            const SizedBox(height: 16),
            _buildTextField("Vestes", _vestesCtrl, readOnly: readOnly, maxLines: 2),
            _buildTextField("Características", _caracteristicasCtrl, readOnly: readOnly, maxLines: 2),
            _buildTextField("Dados Tanatológicos", _tanatologiaCtrl, readOnly: readOnly, maxLines: 2),
            const SizedBox(height: 24),
            const _SectionHeader(title: "Fotos de Identificação", icon: Icons.camera_alt),
            const SizedBox(height: 16),
            if (!readOnly)
              ElevatedButton.icon(
                onPressed: _tirarFoto,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("ADICIONAR FOTO GERAL"),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _fotosIdentificacao.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_fotosIdentificacao[index]),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!readOnly)
                          Positioned(
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() => _fotosIdentificacao.removeAt(index));
                                _salvarDadosNoController();
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: "3. Exames Complementares", icon: Icons.science),
            const SizedBox(height: 16),
            _buildTextField("Anátomo-Patológico", _anatomoCtrl, readOnly: readOnly, hint: "Ex: Material coletado para análise..."),
            _buildTextField("Toxicológico", _toxicologicoCtrl, readOnly: readOnly, hint: "Ex: Negativo / Aguardando laudo..."),
            _buildTextField("Outros Exames", _outrosExamesCtrl, readOnly: readOnly),
            const SizedBox(height: 32),
            const _SectionHeader(title: "4. Discussão / Comentário", icon: Icons.chat),
            const SizedBox(height: 16),
            _buildTextField("Discussão do Caso", _discussaoCtrl, readOnly: readOnly, maxLines: 5),
            const SizedBox(height: 24),
            const _SectionHeader(title: "5. Conclusão", icon: Icons.assignment_turned_in),
            const SizedBox(height: 16),
            _buildTextField("Conclusão Final", _conclusaoCtrl, readOnly: readOnly, maxLines: 3),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.indigo),
                      SizedBox(width: 10),
                      Text(
                        "Respostas aos Quesitos (Obrigatório)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                      )
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildTextField("1. Houve Morte?", _quesito1Ctrl, readOnly: readOnly, required: true),
                  _buildTextField("2. Qual a Causa?", _quesito2Ctrl, readOnly: readOnly, required: true),
                  _buildTextField("3. Qual o Instrumento?", _quesito3Ctrl, readOnly: readOnly, required: true),
                  _buildTextField("4. Qual o Meio?", _quesito4Ctrl, readOnly: readOnly, required: true),
                ],
              ),
            ),
            const SizedBox(height: 40),
            if (!readOnly)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "SALVAR DADOS E FINALIZAR CASO",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    _salvarDadosNoController();
                    if (_formKey.currentState!.validate()) {
                      await controller.finalizarCasoDireto(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Por favor, responda todos os quesitos obrigatórios."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ),
            if (readOnly)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "Caso Finalizado (Modo Leitura)",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {
    bool readOnly = false,
    int maxLines = 1,
    String? hint,
    bool required = false,
    bool isBold = false,
  }) {
    if (readOnly) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ctrl.text.isEmpty ? "-" : ctrl.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        readOnly: false,
        maxLines: maxLines,
        onChanged: (_) => _salvarDadosNoController(),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null : null,
        style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.indigo, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      ],
    );
  }
}
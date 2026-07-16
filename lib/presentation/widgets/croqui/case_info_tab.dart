import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class CaseInfoTab extends StatefulWidget {
  const CaseInfoTab({super.key});

  @override
  State<CaseInfoTab> createState() => _CaseInfoTabState();
}

class _CaseInfoTabState extends State<CaseInfoTab> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _numeroLaudoCtrl; 
  late final TextEditingController _boCtrl; 
  late final TextEditingController _picCtrl;
  
  late final TextEditingController _reqOrigemCtrl;
  late final TextEditingController _reqDestinoCtrl;
  late final TextEditingController _nomeVitimaCtrl;

  late final TextEditingController _historicoCtrl;

  late final TextEditingController _vestesCtrl;
  late final TextEditingController _caracteristicasCtrl;
  late final TextEditingController _tanatoImediatoCtrl;
  late final TextEditingController _tanatoConsecutivoCtrl;
  late final TextEditingController _tanatoObservacaoCtrl;

  late final TextEditingController _anatomoCtrl;
  late final TextEditingController _toxicologicoCtrl;
  late final TextEditingController _geneticaCtrl; 
  late final TextEditingController _outrosExamesCtrl;

  late final TextEditingController _discussaoCtrl;
  late final TextEditingController _conclusaoCtrl;

  late final TextEditingController _quesito1Ctrl;
  late final TextEditingController _quesito2Ctrl;
  late final TextEditingController _quesito3Ctrl;
  late final TextEditingController _quesito4Ctrl;

  late final CroquiController _croquiController;
  late final AuthProvider _authProvider;

  List<String> _fotosIdentificacao = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _croquiController = context.read<CroquiController>();
    _authProvider = context.read<AuthProvider>();
    final dados = _croquiController.casoAtual.dadosLaudo;

    _fotosIdentificacao = List<String>.from(dados['identificacao']?['fotos_gerais'] ?? []);
    
    _numeroLaudoCtrl = TextEditingController(text: _croquiController.casoAtual.numeroLaudoExterno ?? '');
    _boCtrl = TextEditingController(text: dados['cabecalho']?['bo'] ?? ''); 
    _picCtrl = TextEditingController(text: dados['cabecalho']?['pic'] ?? '');
    
    _reqOrigemCtrl = TextEditingController(text: dados['cabecalho']?['requisitante'] ?? '');
    _reqDestinoCtrl = TextEditingController(text: dados['cabecalho']?['destino'] ?? '');
    _nomeVitimaCtrl = TextEditingController(text: dados['cabecalho']?['vitima'] ?? '');

    _historicoCtrl = TextEditingController(
      text: dados['identificacao']?['historico'] ?? 
            "Consta em Boletim de Ocorrência de número XXX que às XX horas do dia XX de XXX do corrente ano. O fato descrito teria ocorrido na localidade conhecida como XXX."
    );

    _vestesCtrl = TextEditingController(text: dados['identificacao']?['vestes'] ?? 'Despido no momento da necrópsia.');
    _caracteristicasCtrl = TextEditingController(text: dados['identificacao']?['caracteristicas'] ?? 'Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.');
    
    _tanatoImediatoCtrl = TextEditingController(text: dados['identificacao']?['tanato_imediato'] ?? 'XXX');
    _tanatoConsecutivoCtrl = TextEditingController(text: dados['identificacao']?['tanato_consecutivo'] ?? 'XXX');
    _tanatoObservacaoCtrl = TextEditingController(text: dados['identificacao']?['tanato_observacao'] ?? 'XXX');

    _anatomoCtrl = TextEditingController(text: dados['exames_complementares']?['anatomo'] ?? '');
    _toxicologicoCtrl = TextEditingController(text: dados['exames_complementares']?['toxicologico'] ?? '');
    _geneticaCtrl = TextEditingController(text: dados['exames_complementares']?['genetica'] ?? '');
    _outrosExamesCtrl = TextEditingController(text: dados['exames_complementares']?['outros'] ?? '');
    
    _discussaoCtrl = TextEditingController(text: dados['conclusao']?['discussao'] ?? '');
    _conclusaoCtrl = TextEditingController(text: dados['conclusao']?['conclusao_texto'] ?? '');

    _quesito1Ctrl = TextEditingController(text: dados['conclusao']?['quesito_1_morte'] ?? '');
    _quesito2Ctrl = TextEditingController(text: dados['conclusao']?['quesito_2_causa'] ?? '');
    _quesito3Ctrl = TextEditingController(text: dados['conclusao']?['quesito_3_instrumento'] ?? '');
    _quesito4Ctrl = TextEditingController(text: dados['conclusao']?['quesito_4_meio'] ?? '');
  }

  @override
  void dispose() {
    _numeroLaudoCtrl.dispose();
    _boCtrl.dispose();
    _picCtrl.dispose(); 
    _reqOrigemCtrl.dispose();
    _reqDestinoCtrl.dispose();
    _nomeVitimaCtrl.dispose();
    _historicoCtrl.dispose();
    _vestesCtrl.dispose();
    _caracteristicasCtrl.dispose();
    _tanatoImediatoCtrl.dispose();
    _tanatoConsecutivoCtrl.dispose();
    _tanatoObservacaoCtrl.dispose();
    _anatomoCtrl.dispose();
    _toxicologicoCtrl.dispose();
    _geneticaCtrl.dispose();
    _outrosExamesCtrl.dispose();
    _discussaoCtrl.dispose();
    _conclusaoCtrl.dispose();
    _quesito1Ctrl.dispose();
    _quesito2Ctrl.dispose();
    _quesito3Ctrl.dispose();
    _quesito4Ctrl.dispose();
    super.dispose();
  }

  void _sincronizarDadosNaMemoria() {
    if (_croquiController.isReadOnly) return;

    final nomePerito = _authProvider.usuario?.nomeCompleto ?? "Perito não identificado";

    final Map<String, dynamic> novosDados = Map<String, dynamic>.from(_croquiController.casoAtual.dadosLaudo);

    novosDados['cabecalho'] = {
      ...(novosDados['cabecalho'] as Map<String, dynamic>? ?? {}),
      'requisitante': _reqOrigemCtrl.text,
      'destino': _reqDestinoCtrl.text,
      'vitima': _nomeVitimaCtrl.text,
      'requisicao': _numeroLaudoCtrl.text,
      'bo': _boCtrl.text, 
      'pic': _picCtrl.text, 
    };

    novosDados['identificacao'] = {
      ...(novosDados['identificacao'] as Map<String, dynamic>? ?? {}),
      'historico': _historicoCtrl.text,
      'vestes': _vestesCtrl.text,
      'caracteristicas': _caracteristicasCtrl.text,
      'tanato_imediato': _tanatoImediatoCtrl.text,
      'tanato_consecutivo': _tanatoConsecutivoCtrl.text,
      'tanato_observacao': _tanatoObservacaoCtrl.text,
      'fotos_gerais': _fotosIdentificacao,
    };

    novosDados['exames_complementares'] = {
      'anatomo': _anatomoCtrl.text,
      'toxicologico': _toxicologicoCtrl.text,
      'genetica': _geneticaCtrl.text, 
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
    };

    novosDados['auditoria'] = {
      ...(novosDados['auditoria'] as Map<String, dynamic>? ?? {}),
      'perito_responsavel': nomePerito,
      'data_finalizacao': DateTime.now().toIso8601String(),
    };

    _croquiController.atualizarDadosLaudoMemoria(novosDados);
  }

  Future<void> _tirarFoto() async {
    try {
        final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      
      if (photo != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final evidenciasDir = Directory('${appDir.path}/evidencias');

        await evidenciasDir.create(recursive: true);

        final localPath = '${evidenciasDir.path}/${const Uuid().v4()}.jpg';

        await File(photo.path).copy(localPath);
        setState(() => _fotosIdentificacao.add(localPath));
        _sincronizarDadosNaMemoria();
      }
    } catch(e){

      debugPrint("Erro ao tirar foto: $e");
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Erro ao acessar a câmera ou salvar a foto."), backgroundColor: Colors.red),
        );
    }
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
            
            _buildTextField("Número do Laudo / Requisição", _numeroLaudoCtrl, readOnly: true, isBold: true),

            Row(
              children: [
                Expanded(child: _buildTextField("Boletim de Ocorrência", _boCtrl, readOnly: readOnly)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Nº PIC", _picCtrl, readOnly: readOnly)),
              ],
            ),

            _buildTextField("Vítima", _nomeVitimaCtrl, readOnly: readOnly),

            Row(
              children: [
                Expanded(child: _buildTextField("Requisitante (Delegado)", _reqOrigemCtrl, readOnly: readOnly)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Destino", _reqDestinoCtrl, readOnly: readOnly)),
              ],
            ),
            
            const SizedBox(height: 32),
            const _SectionHeader(title: "1. Histórico", icon: Icons.history),
            const SizedBox(height: 16),
            _buildTextField("Histórico do Caso", _historicoCtrl, readOnly: readOnly, maxLines: null),

            const SizedBox(height: 32),
            const _SectionHeader(title: "2. Identificação e Exame", icon: Icons.person_search),
            const SizedBox(height: 16),
            _buildTextField("Vestes", _vestesCtrl, readOnly: readOnly, maxLines: null),
            _buildTextField("Características de Identificação", _caracteristicasCtrl, readOnly: readOnly, maxLines: null),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Dados Tanatológicos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  const SizedBox(height: 4),
                  const Text("A morte está evidenciada pela presença dos seguintes sinais:", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildTextField("A) Imediatos", _tanatoImediatoCtrl, readOnly: readOnly, maxLines: null),
                  _buildTextField("B) Consecutivos", _tanatoConsecutivoCtrl, readOnly: readOnly, maxLines: null),
                  _buildTextField("C) Comentários Adicionais", _tanatoObservacaoCtrl, readOnly: readOnly, maxLines: null),
                ],
              ),
            ),

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
                            cacheWidth: 200,
                            cacheHeight: 200,
                          ),
                        ),
                        if (!readOnly)
                          Positioned(
                            right: -6, top: -6,
                            child: IconButton(
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() => _fotosIdentificacao.removeAt(index));
                                _sincronizarDadosNaMemoria();
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
            _buildTextField("Genética", _geneticaCtrl, readOnly: readOnly, hint: "Ex: Coleta de material biológico para DNA..."), 
            _buildTextField("Outros Exames", _outrosExamesCtrl, readOnly: readOnly),
            
            const SizedBox(height: 32),
            const _SectionHeader(title: "4. Discussão / Comentário Forense", icon: Icons.chat),
            const SizedBox(height: 16),
            _buildTextField("Comentário Médico Forense", _discussaoCtrl, readOnly: readOnly, maxLines: null),
            
            const SizedBox(height: 24),
            const _SectionHeader(title: "5. Conclusão", icon: Icons.assignment_turned_in),
            const SizedBox(height: 16),
            _buildTextField("Conclusão Final", _conclusaoCtrl, readOnly: readOnly, maxLines: null),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withAlpha(13)),
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
                  label: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          "SALVAR DADOS E FINALIZAR CASO",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : () async {
                    _sincronizarDadosNaMemoria();
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isSaving = true);
                      await controller.finalizarCasoDireto(context);
                      if (mounted) {
                        setState(() => _isSaving = false);
                      }
                    } else {
                      globalMessengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text("Por favor, responda todos os quesitos obrigatórios."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ),
            if (readOnly) ...[
              Builder(
                builder: (context) {
                  final auditoria = controller.casoAtual.dadosLaudo['auditoria'];
                  final nomePerito = auditoria?['perito_responsavel'] ?? "Perito não identificado";
                  final dataIso = auditoria?['data_finalizacao'];
                  
                  String dataFormatada = "Data não registrada";
                  if (dataIso != null) {
                    final dataHora = DateTime.parse(dataIso);
                    dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.verified_user, color: Colors.green, size: 40),
                        const SizedBox(height: 16),
                        const Text(
                          "LAUDO FINALIZADO E BLOQUEADO",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nomePerito,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Em $dataFormatada",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.indigo),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Assinado digitalmente. Nenhuma alteração permitida.",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
            SizedBox(height: 40 + MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {
    bool readOnly = false,
    int? maxLines = 1,
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
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.withAlpha(178), letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(ctrl.text.isEmpty ? "-" : ctrl.text, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black87, height: 1.3)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        minLines: maxLines == null ? 3 : null,
        keyboardType: maxLines == null ? TextInputType.multiline : TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => _sincronizarDadosNaMemoria(),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null : null,
        style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines == null || maxLines > 1,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
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
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }
}
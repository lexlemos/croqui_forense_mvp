import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/evidencia_foto_card.dart';


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

  late final TextEditingController _discussaoCtrl;
  late final TextEditingController _conclusaoCtrl;

  late final TextEditingController _quesito1Ctrl;
  late final TextEditingController _quesito2Ctrl;
  late final TextEditingController _quesito3Ctrl;
  late final TextEditingController _quesito4Ctrl;

  late final CroquiController _croquiController;
  late final AuthProvider _authProvider;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _croquiController = context.read<CroquiController>();
    _authProvider = context.read<AuthProvider>();
    
    final caso = _croquiController.casoAtual;
    final dados = caso.dadosLaudo;

    _numeroLaudoCtrl = TextEditingController(text: caso.numeroRequisicao.isNotEmpty ? caso.numeroRequisicao : (caso.numeroLaudoExterno ?? ''));
    _boCtrl = TextEditingController(text: caso.numeroBo); 
    _picCtrl = TextEditingController(text: caso.numeroPic);
    
    _reqOrigemCtrl = TextEditingController(text: caso.requisitante);
    _reqDestinoCtrl = TextEditingController(text: caso.destino);
    _nomeVitimaCtrl = TextEditingController(text: caso.nomeVitima);

    _historicoCtrl = TextEditingController(
      text: dados['identificacao']?['historico'] ?? 
            "Consta em Boletim de Ocorrência de número ${caso.numeroBo} que às XX horas do dia XX de XXX do corrente ano. O fato descrito teria ocorrido na localidade conhecida como XXX."
    );

    _vestesCtrl = TextEditingController(text: dados['identificacao']?['vestes'] ?? 'Despido no momento da necrópsia.');
    _caracteristicasCtrl = TextEditingController(text: 'Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.');
    
    _tanatoImediatoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_imediato'] ?? 'XXX');
    _tanatoConsecutivoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_consecutivo'] ?? 'XXX');
    _tanatoObservacaoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_observacao'] ?? 'XXX');

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

    final Map<String, dynamic> novosDados = {};
    final auditoriaExistente = Map<String, dynamic>.from(_croquiController.casoAtual.dadosLaudo['auditoria'] as Map? ?? {});

    final selectedAtnNome = _croquiController.casoAtual.atnResponsavel ?? auditoriaExistente['atn_nome']?.toString();
    String? selectedAtnId = auditoriaExistente['atn_id']?.toString();

    if (selectedAtnNome != null && selectedAtnNome.isNotEmpty && selectedAtnId == null) {
      final match = _croquiController.atns.where((a) => a.nome == selectedAtnNome).firstOrNull;
      selectedAtnId = match?.id;
    }

    novosDados['auditoria'] = {
      'perito_responsavel': nomePerito,
      'data_finalizacao': DateTime.now().toIso8601String(),
    };

    novosDados['identificacao'] = {
      'vestes': _vestesCtrl.text,
      'historico': _historicoCtrl.text,
    };

    novosDados['caracteristicas'] = {
      'tanato_imediato': _tanatoImediatoCtrl.text,
      'tanato_observacao': _tanatoObservacaoCtrl.text,
      'tanato_consecutivo': _tanatoConsecutivoCtrl.text,
    };

    novosDados['conclusao'] = {
      'discussao': _discussaoCtrl.text,
      'quesito_1_morte': _quesito1Ctrl.text,
      'quesito_2_causa': _quesito2Ctrl.text,
      'quesito_3_instrumento': _quesito3Ctrl.text,
      'quesito_4_meio': _quesito4Ctrl.text,
      'conclusao_texto': _conclusaoCtrl.text,
    };

    _croquiController.atualizarCasoCamposEJson(
      numeroBo: _boCtrl.text,
      numeroPic: _picCtrl.text,
      numeroRequisicao: _numeroLaudoCtrl.text,
      nomeVitima: _nomeVitimaCtrl.text,
      destino: _reqDestinoCtrl.text,
      requisitante: _reqOrigemCtrl.text,
      novosDadosLaudo: novosDados,
    );
  }

  Future<void> _tirarFoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo != null) {
        final File compressedFile = await ImageHelper.compressImage(File(photo.path));
        await _croquiController.adicionarFotoGeral(compressedFile.path);
      }
    } on FileSystemException catch (e) {
      debugPrint("Erro de sistema de arquivos ao salvar foto: $e");
      final isDiskFull = e.osError?.errorCode == 28 || e.message.contains('No space left');
      final mensagem = isDiskFull
          ? "Armazenamento esgotado! Libere espaço no dispositivo para continuar salvando fotos."
          : "Falha ao gravar arquivo de imagem no disco.";
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade800, duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      debugPrint("Erro ao acessar câmera ou permissão negada: $e");
      globalMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Acesso à câmera negado ou indisponível. Verifique as permissões do dispositivo."),
          backgroundColor: Colors.red,
        ),
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
            
            _buildTextField("Nº PIC", _picCtrl, readOnly: readOnly, isBold: true),

            Row(
              children: [
                Expanded(child: _buildTextField("Número do Laudo / Requisição", _numeroLaudoCtrl, readOnly: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Boletim de Ocorrência", _boCtrl, readOnly: readOnly)),
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
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final selectedAtnId = controller.casoAtual.atnId;
                final selectedAtnNome = controller.casoAtual.atnResponsavel;
                final List<AtnModel> rawAtns = controller.atns;
                final List<AtnModel> atnsExibicao = List.from(rawAtns);

                AtnModel? matchedAtn;
                if (selectedAtnId != null && selectedAtnId.isNotEmpty) {
                  matchedAtn = atnsExibicao.where((a) => a.id == selectedAtnId).firstOrNull;
                }
                if (matchedAtn == null && selectedAtnNome != null && selectedAtnNome.isNotEmpty) {
                  matchedAtn = atnsExibicao.where((a) => a.nome == selectedAtnNome).firstOrNull;
                }

                if (matchedAtn == null && ((selectedAtnId != null && selectedAtnId.isNotEmpty) || (selectedAtnNome != null && selectedAtnNome.isNotEmpty))) {
                  final String fallbackId = selectedAtnId ?? selectedAtnNome!;
                  final String fallbackNome = selectedAtnNome ?? selectedAtnId!;
                  matchedAtn = AtnModel(id: fallbackId, nome: fallbackNome, ativo: false);
                  atnsExibicao.add(matchedAtn);
                }

                final String? dropdownValue = matchedAtn?.id;

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "A.T.N. Responsável",
                    border: const OutlineInputBorder(),
                    isDense: true,
                    enabled: !readOnly,
                  ),
                  value: (dropdownValue != null && atnsExibicao.any((a) => a.id == dropdownValue))
                      ? dropdownValue
                      : null,
                  items: atnsExibicao.map((atn) {
                    final bool isAtivo = atn.ativo;
                    final String labelText = isAtivo ? atn.nome : "${atn.nome} (Inativo)";
                    return DropdownMenuItem<String>(
                      value: atn.id,
                      child: Text(labelText),
                    );
                  }).toList(),
                  onChanged: readOnly
                      ? null
                      : (val) {
                          final selectedObj = atnsExibicao.where((a) => a.id == val).firstOrNull;
                          controller.atualizarAtnResponsavel(val, selectedObj?.nome);
                        },
                );
              },
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
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.evidenciasGerais.length,
                itemBuilder: (context, index) {
                  final ev = controller.evidenciasGerais[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: EvidenciaFotoCard(
                      key: ValueKey(ev.uuid),
                      path: ev.caminhoArquivoEncriptado ?? '',
                      descricao: ev.descricao,
                      readOnly: readOnly,
                      onDescriptionChanged: (val) async {
                        await controller.salvarDescricaoFotoGeral(ev.uuid, val.trim());
                      },
                      onDelete: () async {
                        await controller.removerFotoGeral(ev.uuid);
                      },
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            const _SectionHeader(title: "3. Discussão / Comentário Forense", icon: Icons.chat),
            const SizedBox(height: 16),
            _buildTextField("Comentário Médico Forense", _discussaoCtrl, readOnly: readOnly, maxLines: null),
            
            const SizedBox(height: 24),
            const _SectionHeader(title: "4. Conclusão", icon: Icons.assignment_turned_in),
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
                          "SALVAR DADOS E FINALIZAR EXAME",
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
            const SizedBox(height: 40),
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

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
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

  late final CroquiController _croquiController;
  late final AuthProvider _authProvider;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _croquiController = context.read<CroquiController>();
    _authProvider = context.read<AuthProvider>();

  }

  @override
  void dispose() {
    super.dispose();
  }

  void _sincronizarDadosNaMemoria() {
    _croquiController.sincronizarDadosEmMemoria(_authProvider);
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
        final String fotoUuid = const Uuid().v4();
        final originalFile = File(photo.path);
        final File compressedFile = await ImageHelper.compressImage(originalFile, fotoUuid);
        
        try {
          if (await originalFile.exists()) await originalFile.delete();
        } catch (e) {
          debugPrint('[CaseInfoTab] ⚠️ Falha ao apagar arquivo temporário da câmera: $e');
        }

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

  Future<void> _abrirSeletorAtn(BuildContext context, CroquiController controller, List<String> currentSelected, List<AtnModel> atns) async {
    final List<String> tempSelected = List.from(currentSelected);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        List filteredAtns = List.from(atns);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              bottom: true,
              child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Selecione A.T.N.s (Máximo 4)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar A.T.N...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final term = value.trim().toLowerCase();
                      setModalState(() {
                        if (term.isEmpty) {
                          filteredAtns = List.from(atns);
                        } else {
                          filteredAtns = atns.where((a) => a.nome.toLowerCase().contains(term)).toList();
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredAtns.length,
                    itemBuilder: (ctx, index) {
                      final atn = filteredAtns[index];
                      final isSelected = tempSelected.contains(atn.id);
                      return CheckboxListTile(
                        title: Text(atn.nome),
                        value: isSelected,
                        onChanged: (val) {
                          if (val == true) {
                            if (tempSelected.length >= 4) {
                              globalMessengerKey.currentState?.showSnackBar(
                                const SnackBar(content: Text("Você já selecionou o limite de 4 A.T.N.s.")),
                              );
                              return;
                            }
                            setModalState(() => tempSelected.add(atn.id));
                          } else {
                            setModalState(() => tempSelected.remove(atn.id));
                          }
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: 16.0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () {
                        controller.atualizarAtnsResponsaveis(tempSelected);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ),
                )
              ],
            ));
          },
        );
      },
    );
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
            
            _buildTextField("Nº PIC", controller.picCtrl, readOnly: readOnly, isBold: true),

            Row(
              children: [
                Expanded(child: _buildTextField("Número do Laudo / Requisição", controller.numeroLaudoCtrl, readOnly: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Boletim de Ocorrência", controller.boCtrl, readOnly: readOnly)),
              ],
            ),

            _buildTextField("Vítima", controller.nomeVitimaCtrl, readOnly: readOnly),

            Row(
              children: [
                Expanded(child: _buildTextField("Requisitante (Delegado)", controller.reqOrigemCtrl, readOnly: readOnly)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField("Destino", controller.reqDestinoCtrl, readOnly: readOnly)),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final List<String> selectedAtnsIds = controller.casoAtual.atnsIds;
                final List<AtnModel> atnsExibicao = controller.atns;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("A.T.N.s Responsáveis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
                        if (!readOnly)
                          TextButton.icon(
                            onPressed: () => _abrirSeletorAtn(context, controller, selectedAtnsIds, atnsExibicao),
                            icon: const Icon(Icons.add),
                            label: const Text("Adicionar A.T.N"),
                          )
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedAtnsIds.isEmpty)
                      const Text("Nenhum A.T.N selecionado", style: TextStyle(color: Colors.grey))
                    else
                      Wrap(
                        spacing: 8,
                        children: selectedAtnsIds.map((atnId) {
                          final atn = atnsExibicao.firstWhere((a) => a.id == atnId, orElse: () => AtnModel(id: atnId, nome: "ATN Desconhecido", ativo: false));
                          return Chip(
                            label: Text(atn.nome),
                            deleteIcon: readOnly ? null : const Icon(Icons.close, size: 18),
                            onDeleted: readOnly ? null : () {
                              final novosAtns = List<String>.from(selectedAtnsIds)..remove(atnId);
                              controller.atualizarAtnsResponsaveis(novosAtns);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32),
            const _SectionHeader(title: "1. Histórico", icon: Icons.history),
            const SizedBox(height: 16),
            _buildTextField("Histórico do Caso", controller.historicoCtrl, readOnly: readOnly, maxLines: null),

            const SizedBox(height: 32),
            const _SectionHeader(title: "2. Identificação e Exame", icon: Icons.person_search),
            const SizedBox(height: 16),
            _buildTextField("Vestes", controller.vestesCtrl, readOnly: readOnly, maxLines: null),
            _buildTextField("Características de Identificação", controller.caracteristicasCtrl, readOnly: readOnly, maxLines: null),
            
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
                  _buildTextField("A) Imediatos", controller.tanatoImediatoCtrl, readOnly: readOnly, maxLines: null),
                  _buildTextField("B) Consecutivos", controller.tanatoConsecutivoCtrl, readOnly: readOnly, maxLines: null),
                  _buildTextField("C) Comentários Adicionais", controller.tanatoObservacaoCtrl, readOnly: readOnly, maxLines: null),
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
            _buildTextField("Comentário Médico Forense", controller.discussaoCtrl, readOnly: readOnly, maxLines: null),
            
            const SizedBox(height: 24),
            const _SectionHeader(title: "4. Conclusão", icon: Icons.assignment_turned_in),
            const SizedBox(height: 16),
            _buildTextField("Conclusão Final", controller.conclusaoCtrl, readOnly: readOnly, maxLines: null),
            
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
                  _buildTextField("1. Houve Morte?", controller.quesito1Ctrl, readOnly: readOnly, required: true),
                  const SizedBox(height: 16),
                  const Text("2. Qual a Causa?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.causasMorteCtrls.length,
                    itemBuilder: (context, index) {
                      final causaCtrl = controller.causasMorteCtrls[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Causa #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                  if (!readOnly && controller.causasMorteCtrls.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => controller.removerCausaMorte(index),
                                      tooltip: "Remover esta causa",
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildTextField("Imediata", causaCtrl.imediataCtrl, readOnly: readOnly, required: true),
                              _buildTextField("Devido a", causaCtrl.devidoACtrl, readOnly: readOnly, required: true),
                              _buildTextField("Consequência", causaCtrl.consequenciaCtrl, readOnly: readOnly, required: true),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (!readOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Adicionar Causa da Morte"),
                        style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                        onPressed: () => controller.adicionarCausaMorte(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildTextField("3. Qual o Instrumento?", controller.quesito3Ctrl, readOnly: readOnly, required: true),
                  _buildTextField("4. Qual o Meio?", controller.quesito4Ctrl, readOnly: readOnly, required: true),
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


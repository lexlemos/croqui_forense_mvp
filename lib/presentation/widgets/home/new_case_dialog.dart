import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/evidencia_foto_card.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';

class NewCaseDialog extends StatefulWidget {
  const NewCaseDialog({super.key});

  @override
  State<NewCaseDialog> createState() => _NewCaseDialogState();
}

class _NewCaseDialogState extends State<NewCaseDialog> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  final _reqController = TextEditingController();
  final _boController = TextEditingController();
  final _picController = TextEditingController(); 
  final _requisitanteController = TextEditingController();
  final _destinoController = TextEditingController();
  final _vitimaController = TextEditingController();

  final _vestesController = TextEditingController();
  final _caracteristicasController = TextEditingController();
  final _tanatoImediatoController = TextEditingController();
  final _tanatoConsecutivoController = TextEditingController();
  final _tanatoObservacaoController = TextEditingController();

  final List<Map<String, String>> _fotosIdentificacao = [];
  final List<String> _selectedAtns = [];
  List<AtnModel> _atnsCache = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _reqController.dispose();
    _boController.dispose(); 
    _picController.dispose(); 
    _requisitanteController.dispose();
    _destinoController.dispose();
    _vitimaController.dispose();
    _vestesController.dispose();
    _caracteristicasController.dispose();
    _tanatoImediatoController.dispose();
    _tanatoConsecutivoController.dispose();
    _tanatoObservacaoController.dispose();
    super.dispose();
  }

  Future<void> _adicionarFoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) return;

      final String fotoUuid = const Uuid().v4();
      final originalFile = File(photo.path);
      final File compressedFile = await ImageHelper.compressImage(originalFile, fotoUuid);

      try {
        if (await originalFile.exists()) await originalFile.delete();
      } catch (e) {
        debugPrint('[NewCaseDialog] ⚠️ Falha ao apagar arquivo temporário da câmera: $e');
      }

      if (!mounted) return;
      setState(() => _fotosIdentificacao.add({'path': compressedFile.path, 'descricao': ''}));
    } catch (e) {
      debugPrint("Erro ao acessar câmera ou permissão negada: $e");
      if (mounted) {
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text("Acesso à câmera negado ou indisponível. Verifique as permissões do dispositivo."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removerFoto(int index) {
    setState(() => _fotosIdentificacao.removeAt(index));
  }

  bool _validarPassoAtual() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) {
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Preencha todos os campos obrigatórios.")),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _abrirSeletorAtn() async {
    final atns = await context.read<AtnRepository>().getAtns();
    if (!mounted) return;
    setState(() {
      _atnsCache = atns;
    });

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        List filteredAtns = List.from(atns);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Column(
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
                      final isSelected = _selectedAtns.contains(atn.id);
                      return CheckboxListTile(
                        title: Text(atn.nome),
                        value: isSelected,
                        onChanged: (val) {
                          if (val == true) {
                            if (_selectedAtns.length >= 4) {
                              globalMessengerKey.currentState?.showSnackBar(
                                const SnackBar(content: Text("Você já selecionou o limite de 4 A.T.N.s.")),
                              );
                              return;
                            }
                            setState(() => _selectedAtns.add(atn.id));
                            setModalState(() {});
                          } else {
                            setState(() => _selectedAtns.remove(atn.id));
                            setModalState(() {});
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final dadosLaudo = {
        'identificacao': {
          'vestes': _vestesController.text.trim(),
          'historico': "Consta em Boletim de Ocorrência de número ${_boController.text.trim()} que às XX horas do dia XX de XXX do corrente ano. O fato descrito teria ocorrido na localidade conhecida como XXX.",
        },
        'caracteristicas': {
          'tanato_imediato': _tanatoImediatoController.text.trim(),
          'tanato_consecutivo': _tanatoConsecutivoController.text.trim(),
          'tanato_observacao': _tanatoObservacaoController.text.trim(),
        },
        'conclusao': null,
        'auditoria': null,
      };

      Navigator.pop(context, {
        'numero_laudo': _reqController.text.trim(),
        'numero_pic': _picController.text.trim(),
        'numero_bo': _boController.text.trim(),
        'numero_requisicao': _reqController.text.trim(),
        'nome_vitima': _vitimaController.text.trim().isEmpty ? 'Não Identificado' : _vitimaController.text.trim(),
        'destino': _destinoController.text.trim(),
        'requisitante': _requisitanteController.text.trim(),
        'atns_ids': _selectedAtns,
        'dados_laudo': dadosLaudo,
        'fotos_gerais': _fotosIdentificacao,
      });
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepIndicatorItem(0, "Dados da Requisição"),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: _currentStep >= 1 ? Colors.indigo : Colors.grey[300],
          ),
        ),
        _buildStepIndicatorItem(1, "Identificação"),
      ],
    );
  }

  Widget _buildStepIndicatorItem(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
                ? Colors.indigo 
                : (isCompleted ? Colors.green : Colors.grey[100]),
            border: Border.all(
              color: isActive 
                  ? Colors.indigo 
                  : (isCompleted ? Colors.green : Colors.grey[400]!),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    "${stepIndex + 1}",
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.indigo : (isCompleted ? Colors.green : Colors.grey[600]),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _reqController, 
                    label: "Nº Requisição", 
                    icon: Icons.assignment, 
                    required: true,
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _boController,
                    label: "Nº B.O.",
                    icon: Icons.receipt_long,
                    keyboardType: TextInputType.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _picController, 
                    label: "Nº PIC", 
                    icon: Icons.gavel,
                    required: true,
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _requisitanteController, 
                    label: "Autoridade Requisitante", 
                    icon: Icons.account_balance,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _vitimaController, 
              label: "Nome da Vítima", 
              icon: Icons.person,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _destinoController, 
              label: "Destino do Laudo", 
              icon: Icons.place,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("A.T.N.s Responsáveis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
                TextButton.icon(
                  onPressed: _abrirSeletorAtn,
                  icon: const Icon(Icons.add),
                  label: const Text("Adicionar A.T.N"),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedAtns.isEmpty)
              const Text("Nenhum A.T.N selecionado", style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                children: _selectedAtns.map((atnId) {
                  final atnName = _atnsCache.firstWhere((a) => a.id == atnId, orElse: () => AtnModel(id: atnId, nome: "ATN Desconhecido", ativo: false)).nome;
                  return Chip(
                    label: Text(atnName),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedAtns.remove(atnId);
                      });
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(controller: _vestesController, label: "Vestes / Objetos", icon: Icons.checkroom, maxLines: null),
            const SizedBox(height: 24),
            _buildTextField(controller: _caracteristicasController, label: "Características Físicas", icon: Icons.accessibility, maxLines: null),
            
            const SizedBox(height: 28),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("Sinais Tanatológicos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
            ),
            _buildTextField(controller: _tanatoImediatoController, label: "Sinais Imediatos", icon: Icons.timer_outlined, maxLines: null),
            const SizedBox(height: 24),
            _buildTextField(controller: _tanatoConsecutivoController, label: "Sinais Consecutivos", icon: Icons.update, maxLines: null),
            const SizedBox(height: 24),
            _buildTextField(controller: _tanatoObservacaoController, label: "Comentários Tanatológicos", icon: Icons.comment_outlined, maxLines: null),
            
            const SizedBox(height: 28),
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fotos de Identificação", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 15)),
                TextButton.icon(
                  onPressed: _adicionarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Adicionar"),
                )
              ],
            ),
            const SizedBox(height: 12),
            
            if (_fotosIdentificacao.isEmpty)
              Container(
                height: 80,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!)
                ),
                child: const Text("Nenhuma foto adicionada", style: TextStyle(color: Colors.grey)),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotosIdentificacao.length,
                  itemBuilder: (context, index) {
                    final foto = _fotosIdentificacao[index];
                    final path = foto['path'] ?? '';
                    final descricao = foto['descricao'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: EvidenciaFotoCard(
                        key: ValueKey(path),
                        path: path,
                        descricao: descricao,
                        readOnly: false,
                        onDescriptionChanged: (val) {
                          setState(() {
                            _fotosIdentificacao[index]['descricao'] = val;
                          });
                        },
                        onDelete: () => _removerFoto(index),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Novo Caso",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildStepIndicator(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep -= 1);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(_currentStep == 0 ? "CANCELAR" : "VOLTAR"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      if (_currentStep < 1) {
                        if (_validarPassoAtual()) {
                          setState(() => _currentStep += 1);
                        }
                      } else {
                        _submit();
                      }
                    },
                    child: Text(_currentStep == 0 ? "PRÓXIMO" : "CRIAR CASO"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int? maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (maxLines == null ? TextInputType.multiline : TextInputType.text),
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: required 
          ? const Icon(Icons.star, size: 8, color: Colors.red) 
          : null,
      ),
      validator: required 
        ? (val) => (val == null || val.trim().isEmpty) ? 'Obrigatório' : null 
        : null,
    );
  }
}

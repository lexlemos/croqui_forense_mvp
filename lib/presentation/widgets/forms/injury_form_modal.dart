import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
import 'package:croqui_forense_mvp/presentation/widgets/dynamic_form/dynamic_form_builder.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/presentation/utils/image_resolver.dart';

class InjuryFormModal extends StatefulWidget {
  final String bodyPartName;
  final InjuryTypeRepository injuryTypeRepository;
  final AchadoRepository achadoRepository;
  final String casoUuid;
  final Achado? achadoToEdit;

  const InjuryFormModal({
    super.key,
    required this.bodyPartName,
    required this.injuryTypeRepository,
    required this.achadoRepository,
    required this.casoUuid,
    this.achadoToEdit,
  });

  @override
  State<InjuryFormModal> createState() => _InjuryFormModalState();
}

class _InjuryFormModalState extends State<InjuryFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customSizeController;
  late final TextEditingController _depthController;
  late final TextEditingController _obsController;

  String? _currentPhotoPath;
  InjuryType? _selectedType;
  String? _selectedParteCorpo;
  bool _isLoadingTypes = true;
  bool _isInterno = false;
  Map<String, dynamic> _currentFormData = {};

  static const List<String> _sizeOptions = ['0.5', '1.0', '1.5', '2.0', '2.5', 'Outro'];
  String? _selectedSize;
  bool _isCustomSize = false;
  
  final ImagePicker _picker = ImagePicker();
  List<InjuryType> _availableTypes = [];

  @override
  void initState() {
    super.initState();
    final m = widget.achadoToEdit;

    final existingSize = m?.tamanho ?? '';
    if (existingSize.isNotEmpty && _sizeOptions.contains(existingSize)) {
      _selectedSize = existingSize;
    } else if (existingSize.isNotEmpty) {
      _selectedSize = 'Outro';
      _isCustomSize = true;
    }
    _customSizeController = TextEditingController(text: _isCustomSize ? existingSize : '');
    _depthController = TextEditingController(text: m?.profundidade ?? '');
    _obsController = TextEditingController(text: m?.description ?? '');
    _currentPhotoPath = m?.photoPath;
    _isInterno = m?.isInterno ?? false;

    final existingDynamic = m?.dadosPreenchidos['dados_dinamicos_json'] ?? m?.dadosPreenchidos['dynamicFields'];
    if (existingDynamic is Map) {
      _currentFormData = Map<String, dynamic>.from(existingDynamic);
    } else if (existingDynamic is String && existingDynamic.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existingDynamic);
        if (decoded is Map) {
          _currentFormData = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('[InjuryFormModal] Erro ao decodificar dados_dinamicos_json: $e');
      }
    }

    _loadTypes(initialTypeLabel: m?.type);
    _loadEntradas();
  }

  String? _findAutoRelacionamentoKey() {
    final schema = _selectedType?.schemaFormulario;
    if (schema == null) return null;
    final campos = schema['campos'];
    if (campos is! List) return null;
    for (final campo in campos) {
      if (campo is Map &&
          campo['tipo_input'] == 'auto_relacionamento') {
        return campo['id_campo']?.toString();
      }
    }
    return null;
  }

  Future<void> _loadEntradas() async {
    // Mantido para não quebrar referências futuras caso precisem (mas sem usar a variável de estado)
  }

  Future<void> _loadTypes({String? initialTypeLabel}) async {
    try {
      final types = await widget.injuryTypeRepository.getAllTypes();
      if (!mounted) return;

      debugPrint("Types loaded: ${types.map((t) => '${t.label} (isInterno: ${t.isInterno}, parte: ${t.schemaFormulario['parte_corpo']})').toList()}");

      setState(() {
        _availableTypes = types;
        _isLoadingTypes = false;

        if (initialTypeLabel != null && initialTypeLabel.isNotEmpty) {
          _selectedType = _availableTypes.firstWhere(
            (t) => t.label == initialTypeLabel,
            orElse: () {
              final legacy = InjuryType(id: 'legacy', label: initialTypeLabel);
              _availableTypes.add(legacy);
              return legacy;
            },
          );

          if (_isInterno) {
            _selectedParteCorpo = _selectedType?.schemaFormulario['parte_corpo']?.toString();
          }

          final autoRelKey = _findAutoRelacionamentoKey();
          if (autoRelKey != null && widget.achadoToEdit?.achadoRelacionadoUuid != null) {
            _currentFormData[autoRelKey] = widget.achadoToEdit!.achadoRelacionadoUuid;
          }
        }
      });
    } catch(e) {
      debugPrint("Erro ao carregar tipos de lesão: $e");
      if (mounted) setState(() => _isLoadingTypes = false);
      globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Falha ao carregar tipos de lesão: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    _depthController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    final mainValid = _formKey.currentState?.validate() ?? false;

    if (mainValid) {
      final dadosDinamicos = Map<String, dynamic>.from(_currentFormData);

      String? achadoRelacionadoUuid;
      final autoRelKey = _findAutoRelacionamentoKey();
      if (autoRelKey != null && dadosDinamicos.containsKey(autoRelKey)) {
        achadoRelacionadoUuid = dadosDinamicos.remove(autoRelKey)?.toString();
      }

      final data = {
        'type': _selectedType?.label ?? 'Não especificado',
        'typeId': _selectedType?.id,
        'size': _isCustomSize ? _customSizeController.text.trim() : (_selectedSize ?? ''),
        'depth': _depthController.text.trim(),
        'description': _obsController.text.trim(),
        'photoPath': _currentPhotoPath,
        'isInterno': _isInterno,
        'dados_dinamicos_json': dadosDinamicos,
        'achadoRelacionadoUuid': achadoRelacionadoUuid,
      };
      Navigator.pop(context, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.achadoToEdit != null;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 16, right: 16, top: 16
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isEditing),
                const Divider(),
                const SizedBox(height: 16),
  
                _buildSectionLabel("CLASSIFICAÇÃO DO EXAME"),
                _buildClassificationToggle(),
                const SizedBox(height: 20),
  
                _buildSectionLabel("NATUREZA DA LESÃO"),
                _buildTypeDropdown(),
                if (_selectedType != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionLabel("DETALHES ESPECÍFICOS"),
                  DynamicFormBuilder(
                    schema: _selectedType?.schemaFormulario ?? {},
                    initialData: _currentFormData,
                    onChanged: (data) {
                      _currentFormData = data;
                    },
                  ),
                ],
                const SizedBox(height: 16),
  
                Row(
                  children: [
                    Expanded(child: _buildSizeDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_depthController, "Profundidade", Icons.vertical_align_bottom, false)),
                  ],
                ),
                if (_isCustomSize) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customSizeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.edit, size: 20),
                      labelText: "Valor personalizado (cm)",
                      border: OutlineInputBorder(),
                    ),
                    validator: null,
                  ),
                ],
                const SizedBox(height: 20),
  
                _buildSectionLabel("EVIDÊNCIA FOTOGRÁFICA"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60), // Aumente este valor para diminuir a foto
                  child: _buildPhotoPicker(),
                ),
                const SizedBox(height: 20),
  
                _buildSectionLabel("COMENTÁRIOS ADICIONAIS"),
                TextFormField(
                  controller: _obsController,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: "Descreva detalhes específicos da lesão...",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 24),
  
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saveForm,
                  icon: Icon(isEditing ? Icons.save : Icons.add_circle_outline),
                  label: Text(isEditing ? "ATUALIZAR REGISTRO" : "CONFIRMAR ACHADO"),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Colors.indigo.withAlpha(40),
        child: Icon(isEditing ? Icons.edit : Icons.add_location_alt, color: Colors.indigo),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? "Edição de Achado" : "Novo Registro",
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.bodyPartName.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ],
        ),
      ),
      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
    ],
  );

  Widget _buildSectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  Widget _buildClassificationToggle() => Container(
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Row(
      children: [
        _buildToggleItem("EXTERNO", !_isInterno, () => setState(() {
          _isInterno = false;
          _selectedType = null;
          _selectedParteCorpo = null;
        })),
        _buildToggleItem("INTERNO", _isInterno, () => setState(() {
          _isInterno = true;
          _selectedType = null;
          _selectedParteCorpo = null;
        })),
      ],
    ),
  );

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), 
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown, 
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12, 
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildTypeDropdown() {
    if (_isLoadingTypes) {
      return const LinearProgressIndicator();
    }

    if (_isInterno) {
      final partesDeCorpo = _availableTypes
          .where((t) => t.isInterno)
          .map((t) => t.schemaFormulario['parte_corpo']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final tiposFiltrados = _availableTypes
          .where((t) => t.isInterno && t.schemaFormulario['parte_corpo'] == _selectedParteCorpo)
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedParteCorpo,
            decoration: const InputDecoration(
              labelText: "Parte do Corpo",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: partesDeCorpo.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedParteCorpo = v;
                _selectedType = null;
                _currentFormData = {};
              });
            },
            validator: (v) => v == null ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<InjuryType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: "Natureza da Lesão Interna",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: tiposFiltrados.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
            onChanged: _selectedParteCorpo == null ? null : (v) => setState(() {
              if (v?.id != _selectedType?.id) {
                _currentFormData = {};
              }
              _selectedType = v;
            }),
            validator: (v) => v == null ? 'Obrigatório' : null,
          ),
        ],
      );
    } else {
      final tiposExternos = _availableTypes.where((t) => !t.isInterno).toList();

      return DropdownButtonFormField<InjuryType>(
        initialValue: _selectedType,
        decoration: const InputDecoration(
          labelText: "Natureza da Lesão",
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: tiposExternos.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
        onChanged: (v) => setState(() {
          if (v?.id != _selectedType?.id) {
            _currentFormData = {};
          }
          _selectedType = v;
        }),
        validator: (v) => v == null ? 'Obrigatório' : null,
      );
    }
  }

  Widget _buildSizeDropdown() => DropdownButtonFormField<String>(
    initialValue: _selectedSize,
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.straighten, size: 20),
      labelText: "Tamanho (cm)",
      border: OutlineInputBorder(),
    ),
    items: _sizeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() {
      _selectedSize = v;
      _isCustomSize = v == 'Outro';
      if (!_isCustomSize) _customSizeController.clear();
    }),
    validator: null,
  );

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, bool isNumeric) => TextFormField(
    controller: ctrl,
    keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _buildPhotoPicker() => AspectRatio(
    aspectRatio: 1,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _currentPhotoPath == null ? _takePhoto : () => _showPhotoOptions(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: _currentPhotoPath == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 32, color: Colors.indigo),
                  SizedBox(height: 8),
                  Text("Capturar Imagem", style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageResolver.buildImage(_currentPhotoPath, fit: BoxFit.cover),
                  ),
                  Container(color: Colors.black26),
                  const Center(child: Icon(Icons.sync, color: Colors.white, size: 30)),
                ],
              ),
      ),
    ),
  );

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Trocar Foto'), onTap: () { Navigator.pop(ctx); _takePhoto(); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remover Foto', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); setState(() => _currentPhotoPath = null); }),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
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
        debugPrint('[InjuryFormModal] ⚠️ Falha ao apagar arquivo temporário da câmera: $e');
      }

      if (!mounted) return;
      setState(() => _currentPhotoPath = compressedFile.path);
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
}

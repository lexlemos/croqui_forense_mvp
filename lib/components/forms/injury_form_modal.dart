import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';
import 'package:croqui_forense_mvp/components/forms/dynamic_form_widget.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

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
  final _dynamicFormKey = GlobalKey<DynamicFormWidgetState>();

  late final TextEditingController _customSizeController;
  late final TextEditingController _depthController;
  late final TextEditingController _obsController;

  String? _currentPhotoPath;
  InjuryType? _selectedType;
  bool _isLoadingTypes = true;
  bool _isInterno = false;
  Map<String, dynamic> _dynamicData = {};
  List<Achado> _entradasDisponiveis = [];

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

    final existingDynamic = m?.dadosPreenchidos['dynamicFields'];
    if (existingDynamic is Map<String, dynamic>) {
      _dynamicData = Map<String, dynamic>.from(existingDynamic);
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
    try {
      final entradas = await widget.achadoRepository.getAchadosDeEntradaPorCaso(widget.casoUuid);
      if (mounted) setState(() => _entradasDisponiveis = entradas);
    } catch (_) {}
  }

  Future<void> _loadTypes({String? initialTypeLabel}) async {
    try {
      final types = await widget.injuryTypeRepository.getAllTypes();
      if (!mounted) return;

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

          final autoRelKey = _findAutoRelacionamentoKey();
          if (autoRelKey != null && widget.achadoToEdit?.achadoRelacionadoUuid != null) {
            _dynamicData[autoRelKey] = widget.achadoToEdit!.achadoRelacionadoUuid;
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
    final dynamicValid = _dynamicFormKey.currentState?.validate() ?? true;

    if (mainValid && dynamicValid) {
      final dynamicFields = Map<String, dynamic>.from(
        _dynamicFormKey.currentState?.formData ?? _dynamicData,
      );

      String? achadoRelacionadoUuid;
      final autoRelKey = _findAutoRelacionamentoKey();
      if (autoRelKey != null && dynamicFields.containsKey(autoRelKey)) {
        achadoRelacionadoUuid = dynamicFields.remove(autoRelKey)?.toString();
      }

      final data = {
        'type': _selectedType?.label ?? 'Não especificado',
        'typeId': _selectedType?.id,
        'size': _isCustomSize ? _customSizeController.text.trim() : (_selectedSize ?? ''),
        'depth': _depthController.text.trim(),
        'description': _obsController.text.trim(),
        'photoPath': _currentPhotoPath,
        'isInterno': _isInterno,
        'dynamicFields': dynamicFields,
        'achadoRelacionadoUuid': achadoRelacionadoUuid,
      };
      Navigator.pop(context, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.achadoToEdit != null;

    return Padding(
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
              if (_selectedType != null && _selectedType!.schemaFormulario.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionLabel("DETALHES ESPECÍFICOS"),
                DynamicFormWidget(
                  key: _dynamicFormKey,
                  schema: _selectedType!.schemaFormulario,
                  initialData: _dynamicData,
                  entradasDisponiveis: _entradasDisponiveis,
                  onChanged: (data) => _dynamicData = data,
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o tamanho' : null,
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
        _buildToggleItem("EXTERNO", !_isInterno, () => setState(() => _isInterno = false)),
        _buildToggleItem("INTERNO", _isInterno, () => setState(() => _isInterno = true)),
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

  Widget _buildTypeDropdown() => _isLoadingTypes 
    ? const LinearProgressIndicator()
    : DropdownButtonFormField<InjuryType>(
        initialValue: _selectedType,
        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
        items: _availableTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
        onChanged: (v) => setState(() => _selectedType = v),
        validator: (v) => v == null ? 'Obrigatório' : null,
      );

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
    validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
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
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_currentPhotoPath!), fit: BoxFit.cover, cacheWidth: 300, cacheHeight: 300)),
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
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50, preferredCameraDevice: CameraDevice.rear);
      if (photo == null) return;
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/evidencias/${const Uuid().v4()}.jpg';
      await Directory('${appDir.path}/evidencias').create(recursive: true);
      await File(photo.path).copy(localPath);
      if (!mounted) return;
      setState(() => _currentPhotoPath = localPath);
    } catch (e) {
      debugPrint("Erro câmera: $e");
      if(mounted){
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Erro ao acessar câmera. Tente novamente."), backgroundColor: Colors.red)
        );
      }
    }
  }
}
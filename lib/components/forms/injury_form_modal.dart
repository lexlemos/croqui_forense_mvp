import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/data/models/injury_marker_model.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart'; 

class InjuryFormModal extends StatefulWidget {
  final String bodyPartName;
  final InjuryMarker? markerToEdit; 

  const InjuryFormModal({
    super.key,
    required this.bodyPartName,
    this.markerToEdit,
  });

  @override
  State<InjuryFormModal> createState() => _InjuryFormModalState();
}

class _InjuryFormModalState extends State<InjuryFormModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _sizeController;
  late TextEditingController _depthController;
  late TextEditingController _obsController;

  String? _currentPhotoPath;
  String? _selectedType;
  bool _isLoadingTypes = true; 
  
  final ImagePicker _picker = ImagePicker();
  final InjuryTypeRepository _repository = InjuryTypeRepository(); 

  List<InjuryType> _availableTypes = [];

  @override
  void initState() {
    super.initState();
    final m = widget.markerToEdit;

    _sizeController = TextEditingController(text: m?.size ?? '');
    _depthController = TextEditingController(text: m?.depth ?? '');
    _obsController = TextEditingController(text: m?.description ?? '');
    
    _currentPhotoPath = m?.photoPath;
    
    _loadTypes(initialType: m?.type);
  }

  Future<void> _loadTypes({String? initialType}) async {
    try {
      final types = await _repository.getAllTypes();
      
      if (mounted) {
        setState(() {
          _availableTypes = types;
          _isLoadingTypes = false;

          if (initialType != null) {
            final exists = _availableTypes.any((t) => t.label == initialType);
            
            if (exists) {
              _selectedType = initialType;
            } else {
              _availableTypes.add(InjuryType(id: 'legacy', label: initialType));
              _selectedType = initialType;
            }
          }
        });
      }
    } catch (e) {
      print("Erro ao carregar tipos de lesão: $e");
      if (mounted) {
        setState(() => _isLoadingTypes = false);
      }
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _depthController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, 
        maxWidth: 600,
        maxHeight: 600,
      );

      if (photo == null) return;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final evidenciasDir = Directory('${appDir.path}/evidencias');
      if (!await evidenciasDir.exists()) {
        await evidenciasDir.create(recursive: true);
      }

      final String fileName = '${const Uuid().v4()}.jpg';
      final String localPath = '${evidenciasDir.path}/$fileName';

      await File(photo.path).copy(localPath);

      setState(() {
        _currentPhotoPath = localPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na câmera: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tirar Nova Foto'),
            onTap: () {
              Navigator.pop(ctx);
              _takePhoto();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Remover Foto', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _currentPhotoPath = null);
            },
          ),
        ],
      ),
    );
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'type': _selectedType ?? 'Não especificado',
        'size': _sizeController.text,
        'depth': _depthController.text,
        'description': _obsController.text,
        'photoPath': _currentPhotoPath,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset, left: 16, right: 16, top: 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.markerToEdit == null 
                  ? "Novo Achado: ${widget.bodyPartName}" 
                  : "Editando: ${widget.bodyPartName}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 16),

              _isLoadingTypes 
                  ? const Center(child: LinearProgressIndicator()) 
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo de Lesão', border: OutlineInputBorder()),
                      items: [
                        for (final typeObj in _availableTypes)
                           DropdownMenuItem<String>(
                            value: typeObj.label,
                            child: Text(typeObj.label),
                          )
                      ],
                      onChanged: (v) => setState(() => _selectedType = v),
                      validator: (v) => v == null ? 'Selecione um tipo' : null,
                    ),
              
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sizeController,
                      decoration: const InputDecoration(labelText: 'Tamanho (cm)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _depthController,
                      decoration: const InputDecoration(labelText: 'Profundidade', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _currentPhotoPath == null
                          ? Center(
                              child: TextButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt, size: 30),
                                label: const Text("Adicionar Foto"),
                              ),
                            )
                          : InkWell(
                              onTap: _showPhotoOptions,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_currentPhotoPath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const Positioned(
                                    right: 4,
                                    top: 4,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      radius: 12,
                                      child: Icon(Icons.edit, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(labelText: 'Outras Observações', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveForm,
                child: Text(widget.markerToEdit == null ? "SALVAR ACHADO" : "ATUALIZAR ACHADO"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
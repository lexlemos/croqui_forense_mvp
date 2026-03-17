class InjuryMarker {
  final String id;
  final String caseId;  
  final String croquiType;
  final String bodyPartId; 
  final double xPercent;    
  final double yPercent;   
  final String? description; 
  final String? photoPath;  
  final bool isInterno;
  final String type;
  final String size;  
  final String depth; 

  InjuryMarker({
    required this.id,
    required this.caseId,
    required this.croquiType,
    required this.bodyPartId,
    required this.xPercent,
    required this.yPercent,
    required this.isInterno,
    this.description,
    this.photoPath,
    this.type = 'Não definido',
    this.size = '',
    this.depth = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_id': caseId,
      'croqui_type': croquiType,
      'body_part_id': bodyPartId,
      'x_percent': xPercent,
      'y_percent': yPercent,
      'is_interno': isInterno,
      'description': description,
      'photo_path': photoPath,
      'type': type,
      'size': size,
      'depth': depth,
    };
  }

  factory InjuryMarker.fromMap(Map<String, dynamic> map) {
    return InjuryMarker(
      id: map['id']?.toString() ?? '',
      caseId: map['case_id']?.toString() ?? '',
      croquiType: map['croqui_type']?.toString() ?? '',
      bodyPartId: map['body_part_id']?.toString() ?? '',
      xPercent: (map['x_percent'] as num?)?.toDouble() ?? 0.0,
      yPercent: (map['y_percent'] as num?)?.toDouble() ?? 0.0,
      isInterno: map['is_interno'] == true || map['is_interno'] == 1,
      description: map['description']?.toString(),
      photoPath: map['photo_path']?.toString(),
      type: map['type']?.toString() ?? 'Não definido',
      size: map['size']?.toString() ?? '',
      depth: map['depth']?.toString() ?? '',
    );
  }
}
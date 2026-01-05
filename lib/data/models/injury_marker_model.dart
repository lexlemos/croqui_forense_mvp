class InjuryMarker {
  final String id;
  final String caseId;  
  final String croquiType;
  final String bodyPartId; 
  final double xPercent;    
  final double yPercent;   
  final String? description; 
  final String? photoPath;  

  InjuryMarker({
    required this.id,
    required this.caseId,
    required this.croquiType,
    required this.bodyPartId,
    required this.xPercent,
    required this.yPercent,
    this.description,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_id': caseId,
      'croqui_type': croquiType,
      'body_part_id': bodyPartId,
      'x_percent': xPercent,
      'y_percent': yPercent,
      'description': description,
      'photo_path': photoPath,
    };
  }

  factory InjuryMarker.fromMap(Map<String, dynamic> map) {
    return InjuryMarker(
      id: map['id'],
      caseId: map['case_id'],
      croquiType: map['croqui_type'],
      bodyPartId: map['body_part_id'],
      xPercent: map['x_percent'],
      yPercent: map['y_percent'],
      description: map['description'],
      photoPath: map['photo_path'],
    );
  }
}
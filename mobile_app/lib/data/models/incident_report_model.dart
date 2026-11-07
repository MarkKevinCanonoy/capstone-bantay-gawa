class IncidentReportModel {
  final String reportId;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String? workareaId;
  final String? areaName;
  final String issueType;
  final String description;
  final String? imageUrl;
  final String status; // 'pending', 'settled_locally', 'escalated_to_admin', 'resolved'
  final bool isEscalated;
  final String? supervisorNotes;
  final String? settledBy;
  final DateTime? settledAt;
  final String? adminResolutionNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final bool isSynced;

  IncidentReportModel({
    required this.reportId,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    this.workareaId,
    this.areaName,
    required this.issueType,
    required this.description,
    this.imageUrl,
    this.status = 'pending',
    this.isEscalated = false,
    this.supervisorNotes,
    this.settledBy,
    this.settledAt,
    this.adminResolutionNotes,
    this.resolvedAt,
    required this.createdAt,
    this.isSynced = true,
  });

  IncidentReportModel copyWith({
    String? reportId,
    String? reporterId,
    String? reporterName,
    String? reportedId,
    String? reportedName,
    String? workareaId,
    String? areaName,
    String? issueType,
    String? description,
    String? imageUrl,
    String? status,
    bool? isEscalated,
    String? supervisorNotes,
    String? settledBy,
    DateTime? settledAt,
    String? adminResolutionNotes,
    DateTime? resolvedAt,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return IncidentReportModel(
      reportId: reportId ?? this.reportId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reportedId: reportedId ?? this.reportedId,
      reportedName: reportedName ?? this.reportedName,
      workareaId: workareaId ?? this.workareaId,
      areaName: areaName ?? this.areaName,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isEscalated: isEscalated ?? this.isEscalated,
      supervisorNotes: supervisorNotes ?? this.supervisorNotes,
      settledBy: settledBy ?? this.settledBy,
      settledAt: settledAt ?? this.settledAt,
      adminResolutionNotes: adminResolutionNotes ?? this.adminResolutionNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'report_id': reportId,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'reported_id': reportedId,
      'reported_name': reportedName,
      'workarea_id': workareaId,
      'area_name': areaName,
      'issue_type': issueType,
      'description': description,
      'image_url': imageUrl,
      'status': status,
      'is_escalated': isEscalated ? 1 : 0,
      'supervisor_notes': supervisorNotes,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory IncidentReportModel.fromMap(Map<String, dynamic> map) {
    return IncidentReportModel(
      reportId: map['report_id'] as String,
      reporterId: map['reporter_id'] as String,
      reporterName: map['reporter_name'] as String? ?? 'Reporter',
      reportedId: map['reported_id'] as String,
      reportedName: map['reported_name'] as String? ?? 'Worker',
      workareaId: map['workarea_id'] as String?,
      areaName: map['area_name'] as String?,
      issueType: map['issue_type'] as String,
      description: map['description'] as String,
      imageUrl: map['image_url'] as String?,
      status: map['status'] as String? ?? 'pending',
      isEscalated: (map['is_escalated'] is int ? map['is_escalated'] == 1 : map['is_escalated'] == true),
      supervisorNotes: map['supervisor_notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      isSynced: (map['is_synced'] is int ? map['is_synced'] == 1 : map['is_synced'] ?? true),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'report_id': reportId,
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'issue_type': issueType,
      'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'status': status,
    };
  }
}

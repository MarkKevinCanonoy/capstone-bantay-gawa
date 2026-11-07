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
    );
  }

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) {
    String rName = json['reporter_name']?.toString() ?? '';
    String dName = json['reported_name']?.toString() ?? '';
    if (json['reporter'] != null && json['reporter'] is Map) {
      final rep = json['reporter'];
      rName = '${rep['first_name'] ?? ''} ${rep['last_name'] ?? ''}'.trim();
    }
    if (json['reported'] != null && json['reported'] is Map) {
      final dep = json['reported'];
      dName = '${dep['first_name'] ?? ''} ${dep['last_name'] ?? ''}'.trim();
    }
    if (rName.isEmpty) rName = 'Field Worker';
    if (dName.isEmpty) dName = 'Reported Worker';

    String? aName = json['area_name']?.toString();
    if (aName == null && json['work_areas'] != null && json['work_areas'] is Map) {
      aName = json['work_areas']['name']?.toString();
    }

    final status = json['status']?.toString() ?? 'pending';

    return IncidentReportModel(
      reportId: json['report_id']?.toString() ?? '',
      reporterId: json['reporter_id']?.toString() ?? '',
      reporterName: rName,
      reportedId: json['reported_id']?.toString() ?? '',
      reportedName: dName,
      workareaId: json['workarea_id']?.toString(),
      areaName: aName,
      issueType: json['issue_type']?.toString() ?? 'General Issue',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      status: status,
      isEscalated: status == 'escalated_to_admin',
      supervisorNotes: json['supervisor_notes']?.toString(),
      settledBy: json['settled_by']?.toString(),
      settledAt: json['settled_at'] != null ? DateTime.tryParse(json['settled_at'].toString()) : null,
      adminResolutionNotes: json['admin_resolution_notes']?.toString(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
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

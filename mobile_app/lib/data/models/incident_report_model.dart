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
}

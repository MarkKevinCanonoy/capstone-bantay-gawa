class IncidentReportModel {
  final String reportId;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String issueType;
  final String description;
  final String? imageUrl;
  final String status; // 'pending', 'under_review', 'resolved'
  final DateTime createdAt;

  IncidentReportModel({
    required this.reportId,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    required this.issueType,
    required this.description,
    this.imageUrl,
    this.status = 'pending',
    required this.createdAt,
  });

  IncidentReportModel copyWith({
    String? reportId,
    String? reporterId,
    String? reporterName,
    String? reportedId,
    String? reportedName,
    String? issueType,
    String? description,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return IncidentReportModel(
      reportId: reportId ?? this.reportId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reportedId: reportedId ?? this.reportedId,
      reportedName: reportedName ?? this.reportedName,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

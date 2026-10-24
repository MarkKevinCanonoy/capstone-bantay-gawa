class AlertModel {
  final String alertId;
  final String? userId;
  final String? workerName;
  final String? workerEmpId;
  final String? workerContact;
  final int? creditScore;
  final int? absenceCount;
  final String? workareaId;
  final String? workareaName;
  final String? supervisorId;
  final String? supervisorName;
  final String type; // 'Geofence Breach', 'Consecutive Absences', 'Score Warning'
  final String title;
  final String description;
  final String severity; // 'critical', 'warning', 'info'
  final String timeAgo;
  final DateTime createdAt;
  final bool isResolved;
  final String? responseAction; // 'warning_sent', 'dismissed', 'acknowledged'
  final String? responseNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  AlertModel({
    required this.alertId,
    this.userId,
    this.workerName,
    this.workerEmpId,
    this.workerContact,
    this.creditScore,
    this.absenceCount,
    this.workareaId,
    this.workareaName,
    this.supervisorId,
    this.supervisorName,
    required this.type,
    required this.title,
    required this.description,
    this.severity = 'warning',
    required this.timeAgo,
    required this.createdAt,
    this.isResolved = false,
    this.responseAction,
    this.responseNote,
    this.resolvedAt,
    this.resolvedBy,
  });

  /// Helper to map type to normalized SRS category
  String get srsCategory {
    final lower = type.toLowerCase();
    if (lower.contains('absence')) return 'consecutive_absences';
    if (lower.contains('score') || lower.contains('credit')) return 'credit_warning';
    return 'breach';
  }

  AlertModel copyWith({
    String? alertId,
    String? userId,
    String? workerName,
    String? workerEmpId,
    String? workerContact,
    int? creditScore,
    int? absenceCount,
    String? workareaId,
    String? workareaName,
    String? supervisorId,
    String? supervisorName,
    String? type,
    String? title,
    String? description,
    String? severity,
    String? timeAgo,
    DateTime? createdAt,
    bool? isResolved,
    String? responseAction,
    String? responseNote,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return AlertModel(
      alertId: alertId ?? this.alertId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      workerEmpId: workerEmpId ?? this.workerEmpId,
      workerContact: workerContact ?? this.workerContact,
      creditScore: creditScore ?? this.creditScore,
      absenceCount: absenceCount ?? this.absenceCount,
      workareaId: workareaId ?? this.workareaId,
      workareaName: workareaName ?? this.workareaName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      timeAgo: timeAgo ?? this.timeAgo,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      responseAction: responseAction ?? this.responseAction,
      responseNote: responseNote ?? this.responseNote,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}

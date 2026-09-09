class AlertModel {
  final String alertId;
  final String? userId;
  final String? workerName;
  final String? workareaName;
  final String type; // 'Geofence Breach', 'Consecutive Absences', 'Score Warning'
  final String title;
  final String description;
  final String severity; // 'critical', 'warning', 'info'
  final String timeAgo;
  final DateTime createdAt;
  final bool isResolved;

  AlertModel({
    required this.alertId,
    this.userId,
    this.workerName,
    this.workareaName,
    required this.type,
    required this.title,
    required this.description,
    this.severity = 'warning',
    required this.timeAgo,
    required this.createdAt,
    this.isResolved = false,
  });

  AlertModel copyWith({
    String? alertId,
    String? userId,
    String? workerName,
    String? workareaName,
    String? type,
    String? title,
    String? description,
    String? severity,
    String? timeAgo,
    DateTime? createdAt,
    bool? isResolved,
  }) {
    return AlertModel(
      alertId: alertId ?? this.alertId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      workareaName: workareaName ?? this.workareaName,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      timeAgo: timeAgo ?? this.timeAgo,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

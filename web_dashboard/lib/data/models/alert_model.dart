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

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    String wName = json['worker_name']?.toString() ?? '';
    String empId = json['worker_emp_id']?.toString() ?? '';
    String contact = json['worker_contact']?.toString() ?? '';
    String? wAreaName = json['workarea_name']?.toString();
    int score = 100;
    if (json['credit_score'] != null) {
      score = (json['credit_score'] as num?)?.toInt() ?? 100;
    } else if (json['users'] != null && json['users'] is Map) {
      final u = json['users'];
      if (wName.isEmpty) wName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      if (empId.isEmpty) empId = u['qr_token']?.toString() ?? '';
      if (contact.isEmpty) contact = u['contact_number']?.toString() ?? '';
      if (u['credit_balance'] != null) {
        final cb = u['credit_balance'];
        if (cb is Map) {
          score = int.tryParse(cb['current_score']?.toString() ?? '100') ?? 100;
        } else if (cb is List && cb.isNotEmpty && cb.first is Map) {
          score = int.tryParse(cb.first['current_score']?.toString() ?? '100') ?? 100;
        }
      }
      if (wAreaName == null && u['work_area_assignments'] is List) {
        final assignments = u['work_area_assignments'] as List;
        if (assignments.isNotEmpty && assignments.first is Map && assignments.first['work_areas'] is Map) {
          wAreaName = assignments.first['work_areas']['name']?.toString();
        }
      }
    }

    final type = json['type']?.toString() ?? 'Geofence Breach';
    final isRes = json['resolved_at'] != null;
    final message = json['message']?.toString() ?? '';

    return AlertModel(
      alertId: json['alert_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      workerName: wName.isNotEmpty ? wName : 'Field Worker',
      workerEmpId: empId.isNotEmpty ? empId : 'WRK-001',
      workerContact: contact.isNotEmpty ? contact : '+63 917 000 0000',
      creditScore: score,
      absenceCount: (json['absence_count'] as num?)?.toInt() ?? 1,
      workareaId: json['workarea_id']?.toString(),
      workareaName: wAreaName ?? 'Ormoc Plaza',
      type: type,
      title: type,
      description: message,
      severity: type.toLowerCase().contains('absence') || type.toLowerCase().contains('breach') ? 'critical' : 'warning',
      timeAgo: 'Recently',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      isResolved: isRes,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      resolvedBy: json['resolved_by']?.toString(),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'alert_id': alertId,
      if (userId != null) 'user_id': userId,
      'type': type,
      'message': description.isNotEmpty ? description : title,
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
      if (resolvedBy != null) 'resolved_by': resolvedBy,
    };
  }
}

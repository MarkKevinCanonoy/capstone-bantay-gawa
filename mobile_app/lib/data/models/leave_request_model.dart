class LeaveRequestModel {
  final String leaveId;
  final String userId;
  final String workerName;
  final String? workareaId;
  final String areaName;
  final String type; // 'Emergency Leave', 'Sick Leave', 'Vacation Leave', 'Other'
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? imageUrl;
  final String status; // 'pending', 'approved', 'denied'
  final String? adminDecision;
  final DateTime? decisionAt;
  final String? rejectionReason;
  final String? supervisorEndorsement;
  final String? endorsedBy;
  final DateTime? endorsedAt;
  final bool isSynced;

  LeaveRequestModel({
    required this.leaveId,
    required this.userId,
    this.workerName = '',
    this.workareaId,
    this.areaName = '',
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.imageUrl,
    this.status = 'pending',
    this.adminDecision,
    this.decisionAt,
    this.rejectionReason,
    this.supervisorEndorsement,
    this.endorsedBy,
    this.endorsedAt,
    this.isSynced = true,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) return DateTime.tryParse(val.toString()) ?? DateTime.now();
      return DateTime.now();
    }

    return LeaveRequestModel(
      leaveId: map['leave_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      workerName: map['worker_name'] as String? ?? '',
      workareaId: map['workarea_id'] as String?,
      areaName: map['area_name'] as String? ?? '',
      type: map['type'] as String? ?? 'Sick Leave',
      startDate: parseDate(map['start_date']),
      endDate: parseDate(map['end_date']),
      reason: map['reason'] as String? ?? '',
      imageUrl: map['image_path'] as String? ?? map['image_url'] as String?,
      status: map['status'] as String? ?? 'pending',
      adminDecision: map['admin_decision'] as String?,
      decisionAt: map['decision_at'] != null ? DateTime.tryParse(map['decision_at'].toString()) : null,
      rejectionReason: map['rejection_reason'] as String?,
      supervisorEndorsement: map['supervisor_endorsement'] as String?,
      endorsedBy: map['endorsed_by'] as String?,
      endorsedAt: map['endorsed_at'] != null ? DateTime.tryParse(map['endorsed_at'].toString()) : null,
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    final sY = startDate.year.toString().padLeft(4, '0');
    final sM = startDate.month.toString().padLeft(2, '0');
    final sD = startDate.day.toString().padLeft(2, '0');
    final eY = endDate.year.toString().padLeft(4, '0');
    final eM = endDate.month.toString().padLeft(2, '0');
    final eD = endDate.day.toString().padLeft(2, '0');
    return {
      'leave_id': leaveId,
      'user_id': userId,
      'workarea_id': workareaId,
      'type': type,
      'start_date': '$sY-$sM-$sD',
      'end_date': '$eY-$eM-$eD',
      'reason': reason,
      'image_path': imageUrl,
      'image_url': imageUrl,
      'status': status,
      'admin_decision': adminDecision,
      'decision_at': decisionAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  LeaveRequestModel copyWith({
    String? leaveId,
    String? userId,
    String? workerName,
    String? workareaId,
    String? areaName,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? imageUrl,
    String? status,
    String? adminDecision,
    DateTime? decisionAt,
    String? rejectionReason,
    String? supervisorEndorsement,
    String? endorsedBy,
    DateTime? endorsedAt,
    bool? isSynced,
  }) {
    return LeaveRequestModel(
      leaveId: leaveId ?? this.leaveId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      workareaId: workareaId ?? this.workareaId,
      areaName: areaName ?? this.areaName,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      adminDecision: adminDecision ?? this.adminDecision,
      decisionAt: decisionAt ?? this.decisionAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      supervisorEndorsement: supervisorEndorsement ?? this.supervisorEndorsement,
      endorsedBy: endorsedBy ?? this.endorsedBy,
      endorsedAt: endorsedAt ?? this.endorsedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    final sY = startDate.year.toString().padLeft(4, '0');
    final sM = startDate.month.toString().padLeft(2, '0');
    final sD = startDate.day.toString().padLeft(2, '0');
    final eY = endDate.year.toString().padLeft(4, '0');
    final eM = endDate.month.toString().padLeft(2, '0');
    final eD = endDate.day.toString().padLeft(2, '0');
    return {
      'leave_id': leaveId,
      'user_id': userId,
      'type': type,
      'start_date': '$sY-$sM-$sD',
      'end_date': '$eY-$eM-$eD',
      'reason': reason,
      if (imageUrl != null) 'image_url': imageUrl,
      'status': status,
      'is_synced': true,
    };
  }
}

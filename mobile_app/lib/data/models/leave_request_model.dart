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
    this.workerName = 'Field Worker',
    this.workareaId,
    this.areaName = 'Sector 4 - Downtown Zone',
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
      workerName: map['worker_name'] as String? ?? 'Field Worker',
      workareaId: map['workarea_id'] as String?,
      areaName: map['area_name'] as String? ?? 'Sector 4 - Downtown Zone',
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
}

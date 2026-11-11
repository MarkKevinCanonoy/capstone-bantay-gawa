class LeaveRequestModel {
  final String leaveId;
  final String userId;
  final String workerName;
  final String? workareaId;
  final String areaName;
  final String type; // 'Emergency Leave', 'Sick Leave', 'Vacation Leave', 'Other'
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
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
  final DateTime? createdAt;

  LeaveRequestModel({
    required this.leaveId,
    required this.userId,
    required this.workerName,
    this.workareaId,
    required this.areaName,
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
    this.createdAt,
  });

  String get initials {
    final parts = workerName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'L';
  }

  LeaveRequestModel copyWith({
    String? leaveId,
    String? userId,
    String? workerName,
    String? workareaId,
    String? areaName,
    String? type,
    String? startDate,
    String? endDate,
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
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    String wName = json['worker_name']?.toString() ?? '';
    if (json['users'] != null && json['users'] is Map) {
      final u = json['users'];
      if (wName.isEmpty) wName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    }
    if (wName.isEmpty) wName = 'Field Worker';

    String aName = json['area_name']?.toString() ?? '';
    if (aName.isEmpty && json['work_areas'] != null && json['work_areas'] is Map) {
      aName = json['work_areas']['name']?.toString() ?? '';
    }
    if (aName.isEmpty && json['users'] != null && json['users'] is Map) {
      aName = json['users']['assigned_area_name']?.toString() ?? '';
    }
    if (aName.isEmpty) aName = 'Unassigned Sector';

    return LeaveRequestModel(
      leaveId: json['leave_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      workerName: wName,
      workareaId: json['workarea_id']?.toString(),
      areaName: aName,
      type: json['type']?.toString() ?? 'Sick Leave',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      adminDecision: json['admin_decision']?.toString(),
      decisionAt: json['decision_at'] != null ? DateTime.tryParse(json['decision_at'].toString()) : null,
      rejectionReason: json['rejection_reason']?.toString(),
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'leave_id': leaveId,
      'user_id': userId,
      'type': type,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      if (imageUrl != null) 'image_url': imageUrl,
      'status': status,
      if (adminDecision != null) 'admin_decision': adminDecision,
      if (decisionAt != null) 'decision_at': decisionAt!.toIso8601String(),
      'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

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
  final bool isSynced;

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
    this.isSynced = true,
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
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

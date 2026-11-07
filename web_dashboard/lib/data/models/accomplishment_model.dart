class AccomplishmentModel {
  final String accomplishmentId;
  final String userId;
  final String workerName;
  final String workareaId;
  final String areaName;
  final String imageUrl;
  final String capturedDate; // YYYY-MM-DD
  final String capturedTime; // HH:mm:ss
  final double capturedLat;
  final double capturedLng;
  final String message;
  final String status; // 'pending', 'approved', 'denied'
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final bool isSynced;

  AccomplishmentModel({
    required this.accomplishmentId,
    required this.userId,
    required this.workerName,
    required this.workareaId,
    required this.areaName,
    required this.imageUrl,
    required this.capturedDate,
    required this.capturedTime,
    required this.capturedLat,
    required this.capturedLng,
    required this.message,
    this.status = 'pending',
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.isSynced = true,
  });

  AccomplishmentModel copyWith({
    String? accomplishmentId,
    String? userId,
    String? workerName,
    String? workareaId,
    String? areaName,
    String? imageUrl,
    String? capturedDate,
    String? capturedTime,
    double? capturedLat,
    double? capturedLng,
    String? message,
    String? status,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
    bool? isSynced,
  }) {
    return AccomplishmentModel(
      accomplishmentId: accomplishmentId ?? this.accomplishmentId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      workareaId: workareaId ?? this.workareaId,
      areaName: areaName ?? this.areaName,
      imageUrl: imageUrl ?? this.imageUrl,
      capturedDate: capturedDate ?? this.capturedDate,
      capturedTime: capturedTime ?? this.capturedTime,
      capturedLat: capturedLat ?? this.capturedLat,
      capturedLng: capturedLng ?? this.capturedLng,
      message: message ?? this.message,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  factory AccomplishmentModel.fromJson(Map<String, dynamic> json) {
    String wName = json['worker_name']?.toString() ?? '';
    if (wName.isEmpty && json['users'] != null) {
      final u = json['users'];
      if (u is Map) {
        wName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      }
    }
    if (wName.isEmpty) wName = 'Field Worker';

    String aName = json['area_name']?.toString() ?? '';
    if (aName.isEmpty && json['work_areas'] != null) {
      final a = json['work_areas'];
      if (a is Map) {
        aName = a['name']?.toString() ?? '';
      }
    }
    if (aName.isEmpty) aName = 'Ormoc Plaza';

    String? approverName = json['approved_by_name']?.toString();
    if (approverName == null && json['approver'] != null) {
      final ap = json['approver'];
      if (ap is Map) {
        approverName = '${ap['first_name'] ?? ''} ${ap['last_name'] ?? ''}'.trim();
      }
    }

    return AccomplishmentModel(
      accomplishmentId: json['accomplishment_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      workerName: wName,
      workareaId: json['workarea_id']?.toString() ?? '',
      areaName: aName,
      imageUrl: json['image_url']?.toString() ?? '',
      capturedDate: json['captured_date']?.toString() ?? '',
      capturedTime: json['captured_time']?.toString() ?? '',
      capturedLat: (json['captured_lat'] as num?)?.toDouble() ?? 0.0,
      capturedLng: (json['captured_lng'] as num?)?.toDouble() ?? 0.0,
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      approvedBy: json['approved_by']?.toString(),
      approvedByName: approverName,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      rejectionReason: json['rejection_reason']?.toString(),
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accomplishment_id': accomplishmentId,
      'user_id': userId,
      if (workareaId.isNotEmpty) 'workarea_id': workareaId,
      'image_url': imageUrl,
      'captured_date': capturedDate,
      'captured_time': capturedTime,
      'captured_lat': capturedLat,
      'captured_lng': capturedLng,
      'message': message,
      'status': status,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      'is_synced': isSynced,
    };
  }
}

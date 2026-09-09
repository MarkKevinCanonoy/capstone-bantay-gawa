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
}

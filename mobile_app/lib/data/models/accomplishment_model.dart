class AccomplishmentModel {
  final String accomplishmentId;
  final String userId;
  final String workerName;
  final String workareaId;
  final String areaName;
  final String imageUrl;
  final DateTime capturedDate; // parsed DateTime
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
    this.workerName = 'Field Worker',
    required this.workareaId,
    this.areaName = 'Sector 4 - Downtown Zone',
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

  factory AccomplishmentModel.fromMap(Map<String, dynamic> map) {
    DateTime date;
    final rawDate = map['captured_date'];
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return AccomplishmentModel(
      accomplishmentId: map['accomplishment_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      workerName: map['worker_name'] as String? ?? 'Field Worker',
      workareaId: map['workarea_id'] as String? ?? '',
      areaName: map['area_name'] as String? ?? 'Sector 4 - Downtown Zone',
      imageUrl: map['image_path'] as String? ?? map['image_url'] as String? ?? '',
      capturedDate: date,
      capturedTime: map['captured_time'] as String? ?? '08:00 AM',
      capturedLat: (map['captured_lat'] as num?)?.toDouble() ?? 0.0,
      capturedLng: (map['captured_lng'] as num?)?.toDouble() ?? 0.0,
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      approvedBy: map['approved_by'] as String?,
      approvedByName: map['approved_by_name'] as String?,
      approvedAt: map['approved_at'] != null ? DateTime.tryParse(map['approved_at'].toString()) : null,
      rejectionReason: map['rejection_reason'] as String?,
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
    );
  }
}

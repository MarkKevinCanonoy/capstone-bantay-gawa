import 'package:intl/intl.dart';
import '../../core/utils/uuid_helper.dart';

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
    this.workerName = '',
    required this.workareaId,
    this.areaName = '',
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
    DateTime? capturedDate,
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
      workerName: map['worker_name'] as String? ?? '',
      workareaId: map['workarea_id'] as String? ?? '',
      areaName: map['area_name'] as String? ?? '',
      imageUrl: map['image_path'] as String? ?? map['image_url'] as String? ?? '',
      capturedDate: date,
      capturedTime: map['captured_time'] as String? ?? '',
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

  Map<String, dynamic> toMap() {
    final y = capturedDate.year.toString().padLeft(4, '0');
    final m = capturedDate.month.toString().padLeft(2, '0');
    final d = capturedDate.day.toString().padLeft(2, '0');
    return {
      'accomplishment_id': accomplishmentId,
      'user_id': userId,
      'workarea_id': workareaId,
      'image_path': imageUrl,
      'image_url': imageUrl,
      'captured_date': '$y-$m-$d',
      'captured_time': capturedTime,
      'captured_lat': capturedLat,
      'captured_lng': capturedLng,
      'message': message,
      'status': status,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    final y = capturedDate.year.toString().padLeft(4, '0');
    final m = capturedDate.month.toString().padLeft(2, '0');
    final d = capturedDate.day.toString().padLeft(2, '0');

    // Ensure captured_time strictly satisfies PostgreSQL TIME format (HH:mm:ss)
    String formattedTime = capturedTime.trim();
    if (formattedTime.toUpperCase().contains('AM') || formattedTime.toUpperCase().contains('PM')) {
      try {
        final parsed = DateFormat('hh:mm a').parse(formattedTime);
        formattedTime = DateFormat('HH:mm:ss').format(parsed);
      } catch (_) {
        try {
          final parsed = DateFormat('h:mm a').parse(formattedTime);
          formattedTime = DateFormat('HH:mm:ss').format(parsed);
        } catch (_) {
          formattedTime = DateFormat('HH:mm:ss').format(DateTime.now());
        }
      }
    } else if (!formattedTime.contains(':')) {
      formattedTime = DateFormat('HH:mm:ss').format(DateTime.now());
    }

    return {
      'accomplishment_id': accomplishmentId,
      'user_id': userId,
      if (UuidHelper.isValidUuid(workareaId)) 'workarea_id': workareaId,
      'image_url': imageUrl,
      'captured_date': '$y-$m-$d',
      'captured_time': formattedTime,
      'captured_lat': capturedLat,
      'captured_lng': capturedLng,
      'message': message,
      'status': status,
      'is_synced': true,
    };
  }
}

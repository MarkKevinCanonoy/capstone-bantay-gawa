import '../../core/utils/uuid_helper.dart';

class AttendanceModel {
  final String attendanceId;
  final String userId;
  final String workerName;
  final String workerEmpId;
  final String workareaId;
  final String areaName;
  final String actionType; // 'time-in', 'break-in', 'break-out', 'time-out'
  final DateTime timestamp;
  final double gpsLat;
  final double gpsLng;
  final String? imageUrl;
  final bool faceMatch;
  final bool isSynced;
  final bool isVerified;
  final bool hasWarning;
  final String timeIn;
  final String breakIn;
  final String breakOut;
  final String timeOut;

  AttendanceModel({
    required this.attendanceId,
    required this.userId,
    this.workerName = '',
    this.workerEmpId = '',
    required this.workareaId,
    this.areaName = '',
    this.actionType = 'time-in',
    required this.timestamp,
    required this.gpsLat,
    required this.gpsLng,
    this.imageUrl,
    this.faceMatch = true,
    this.isSynced = true,
    this.isVerified = true,
    this.hasWarning = false,
    this.timeIn = '--:--',
    this.breakIn = '--:--',
    this.breakOut = '--:--',
    this.timeOut = '--:--',
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      attendanceId: map['attendance_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      workerName: map['worker_name'] as String? ?? '',
      workerEmpId: map['worker_emp_id'] as String? ?? '',
      workareaId: map['workarea_id'] as String? ?? '',
      areaName: map['area_name'] as String? ?? '',
      actionType: map['action_type'] as String? ?? 'time-in',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      gpsLat: (map['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (map['gps_lng'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['image_path'] as String? ?? map['image_url'] as String?,
      faceMatch: (map['face_match'] == 1 || map['face_match'] == true),
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
      isVerified: (map['is_verified'] == 1 || map['is_verified'] == true),
      hasWarning: (map['has_warning'] == 1 || map['has_warning'] == true),
      timeIn: map['time_in'] as String? ?? '--:--',
      breakIn: map['break_in'] as String? ?? '--:--',
      breakOut: map['break_out'] as String? ?? '--:--',
      timeOut: map['time_out'] as String? ?? '--:--',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendance_id': attendanceId,
      'user_id': userId,
      'worker_name': workerName,
      'worker_emp_id': workerEmpId,
      'workarea_id': workareaId,
      'area_name': areaName,
      'action_type': actionType,
      'timestamp': timestamp.toIso8601String(),
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'image_url': imageUrl,
      'face_match': faceMatch ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'attendance_id': attendanceId,
      'user_id': userId,
      if (UuidHelper.isValidUuid(workareaId)) 'workarea_id': workareaId,
      'action_type': actionType,
      'timestamp': timestamp.toIso8601String(),
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      if (imageUrl != null) 'image_url': imageUrl,
      'face_match': faceMatch,
      'is_synced': true,
    };
  }
}

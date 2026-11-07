import 'package:intl/intl.dart';

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
    required this.workerName,
    required this.workerEmpId,
    required this.workareaId,
    required this.areaName,
    this.actionType = 'time-in',
    required this.timestamp,
    required this.gpsLat,
    required this.gpsLng,
    this.imageUrl,
    this.faceMatch = true,
    this.isSynced = true,
    this.isVerified = true,
    this.hasWarning = false,
    this.timeIn = '06:58 AM',
    this.breakIn = '12:02 PM',
    this.breakOut = '01:00 PM',
    this.timeOut = '04:05 PM',
  });

  String get initials {
    final parts = workerName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'W';
  }

  AttendanceModel copyWith({
    String? attendanceId,
    String? userId,
    String? workerName,
    String? workerEmpId,
    String? workareaId,
    String? areaName,
    String? actionType,
    DateTime? timestamp,
    double? gpsLat,
    double? gpsLng,
    String? imageUrl,
    bool? faceMatch,
    bool? isSynced,
    bool? isVerified,
    bool? hasWarning,
    String? timeIn,
    String? breakIn,
    String? breakOut,
    String? timeOut,
  }) {
    return AttendanceModel(
      attendanceId: attendanceId ?? this.attendanceId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      workerEmpId: workerEmpId ?? this.workerEmpId,
      workareaId: workareaId ?? this.workareaId,
      areaName: areaName ?? this.areaName,
      actionType: actionType ?? this.actionType,
      timestamp: timestamp ?? this.timestamp,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      imageUrl: imageUrl ?? this.imageUrl,
      faceMatch: faceMatch ?? this.faceMatch,
      isSynced: isSynced ?? this.isSynced,
      isVerified: isVerified ?? this.isVerified,
      hasWarning: hasWarning ?? this.hasWarning,
      timeIn: timeIn ?? this.timeIn,
      breakIn: breakIn ?? this.breakIn,
      breakOut: breakOut ?? this.breakOut,
      timeOut: timeOut ?? this.timeOut,
    );
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    String wName = json['worker_name']?.toString() ?? '';
    String empId = json['worker_emp_id']?.toString() ?? '';
    if (json['users'] != null && json['users'] is Map) {
      final u = json['users'];
      if (wName.isEmpty) wName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      if (empId.isEmpty) empId = u['qr_token']?.toString() ?? '';
    }
    if (wName.isEmpty) wName = 'Field Worker';
    if (empId.isEmpty) empId = 'WRK-001';

    String aName = json['area_name']?.toString() ?? '';
    if (aName.isEmpty && json['work_areas'] != null && json['work_areas'] is Map) {
      aName = json['work_areas']['name']?.toString() ?? '';
    }
    if (aName.isEmpty) aName = 'Ormoc Plaza';

    final ts = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
        : DateTime.now();

    return AttendanceModel(
      attendanceId: json['attendance_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      workerName: wName,
      workerEmpId: empId,
      workareaId: json['workarea_id']?.toString() ?? '',
      areaName: aName,
      actionType: json['action_type']?.toString() ?? 'time-in',
      timestamp: ts,
      gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      faceMatch: json['face_match'] == true || json['face_match'] == 1,
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      hasWarning: json['has_warning'] == true || json['has_warning'] == 1,
      timeIn: json['time_in']?.toString() ?? '07:00 AM',
      breakIn: json['break_in']?.toString() ?? '12:00 PM',
      breakOut: json['break_out']?.toString() ?? '01:00 PM',
      timeOut: json['time_out']?.toString() ?? '04:00 PM',
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'attendance_id': attendanceId,
      'user_id': userId,
      if (workareaId.isNotEmpty) 'workarea_id': workareaId,
      'action_type': actionType,
      'timestamp': timestamp.toIso8601String(),
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      if (imageUrl != null) 'image_url': imageUrl,
      'face_match': faceMatch,
      'is_synced': isSynced,
    };
  }
}

class DailyWorkerAttendance {
  final String userId;
  final String workerName;
  final String workerEmpId;
  final String workareaId;
  final String areaName;
  final String dateKey; // 'YYYY-MM-DD'
  final List<AttendanceModel> punches;

  DailyWorkerAttendance({
    required this.userId,
    required this.workerName,
    required this.workerEmpId,
    required this.workareaId,
    required this.areaName,
    required this.dateKey,
    required this.punches,
  });

  String get initials {
    final parts = workerName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'W';
  }

  AttendanceModel? get timeInPunch =>
      punches.cast<AttendanceModel?>().firstWhere((p) => p?.actionType == 'time-in', orElse: () => null);

  AttendanceModel? get breakInPunch =>
      punches.cast<AttendanceModel?>().firstWhere((p) => p?.actionType == 'break-in', orElse: () => null);

  AttendanceModel? get breakOutPunch =>
      punches.cast<AttendanceModel?>().firstWhere((p) => p?.actionType == 'break-out', orElse: () => null);

  AttendanceModel? get timeOutPunch =>
      punches.cast<AttendanceModel?>().firstWhere((p) => p?.actionType == 'time-out', orElse: () => null);

  String get formattedTimeIn {
    final p = timeInPunch;
    if (p == null) return '--:--';
    return DateFormat('hh:mm a').format(p.timestamp);
  }

  String get formattedBreakIn {
    final p = breakInPunch;
    if (p == null) return '--:--';
    return DateFormat('hh:mm a').format(p.timestamp);
  }

  String get formattedBreakOut {
    final p = breakOutPunch;
    if (p == null) return '--:--';
    return DateFormat('hh:mm a').format(p.timestamp);
  }

  String get formattedTimeOut {
    final p = timeOutPunch;
    if (p == null) return '--:--';
    return DateFormat('hh:mm a').format(p.timestamp);
  }

  /// Current overall duty status: 'ON DUTY', 'ON BREAK', 'SHIFT COMPLETE', 'TIMED IN'
  String get statusSummary {
    if (timeOutPunch != null) return 'SHIFT COMPLETE';
    if (breakInPunch != null && breakOutPunch == null) return 'ON BREAK';
    if (timeInPunch != null) return 'ON DUTY';
    return 'NO TIME-IN';
  }

  /// True if all punches passed face match
  bool get allFaceMatched => punches.every((p) => p.faceMatch);

  /// True if any punch had warning/breach
  bool get hasAnyBreach => punches.any((p) => p.hasWarning);

  /// True if all are verified
  bool get isAllVerified => punches.isNotEmpty && punches.every((p) => p.isVerified);

  /// Helper to group a flat list of AttendanceModel logs into DailyWorkerAttendance
  static List<DailyWorkerAttendance> groupLogs(List<AttendanceModel> logs) {
    final Map<String, List<AttendanceModel>> grouped = {};

    for (final log in logs) {
      final dateKey = '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')}';
      final groupKey = '${log.userId}_$dateKey';
      grouped.putIfAbsent(groupKey, () => []).add(log);
    }

    final List<DailyWorkerAttendance> result = [];
    for (final entry in grouped.entries) {
      final list = entry.value;
      // sort punches chronologically ascending
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final first = list.first;
      final dateKey = '${first.timestamp.year}-${first.timestamp.month.toString().padLeft(2, '0')}-${first.timestamp.day.toString().padLeft(2, '0')}';

      result.add(DailyWorkerAttendance(
        userId: first.userId,
        workerName: first.workerName,
        workerEmpId: first.workerEmpId,
        workareaId: first.workareaId,
        areaName: first.areaName,
        dateKey: dateKey,
        punches: list,
      ));
    }

    // Sort by latest punch timestamp descending
    result.sort((a, b) {
      final aLatest = a.punches.isNotEmpty ? a.punches.last.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      final bLatest = b.punches.isNotEmpty ? b.punches.last.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      return bLatest.compareTo(aLatest);
    });

    return result;
  }
}

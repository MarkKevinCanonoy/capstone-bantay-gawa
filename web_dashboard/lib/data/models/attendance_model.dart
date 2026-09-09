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
}

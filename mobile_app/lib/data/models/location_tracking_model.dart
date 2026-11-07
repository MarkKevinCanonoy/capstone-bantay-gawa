import 'package:latlong2/latlong.dart';
import '../../core/utils/uuid_helper.dart';

/// Represents a historical breadcrumb coordinate from `location_tracking` table.
/// In accordance with ENRO privacy rules:
/// - Only recorded while worker is inside their designated work area.
/// - Captured at 1-minute intervals. Coordinates outside the polygon are discarded for worker privacy.
class LocationTrackingModel {
  final String locationId;
  final String userId;
  final String? attendanceId;
  final double gpsLat;
  final double gpsLng;
  final DateTime timestamp;
  final bool isLastSeen;
  final bool isInsideGeofence;
  final bool isSynced;

  const LocationTrackingModel({
    required this.locationId,
    required this.userId,
    this.attendanceId,
    required this.gpsLat,
    required this.gpsLng,
    required this.timestamp,
    this.isLastSeen = false,
    this.isInsideGeofence = true,
    this.isSynced = false,
  });

  LatLng get point => LatLng(gpsLat, gpsLng);

  LocationTrackingModel copyWith({
    String? locationId,
    String? userId,
    String? attendanceId,
    double? gpsLat,
    double? gpsLng,
    DateTime? timestamp,
    bool? isLastSeen,
    bool? isInsideGeofence,
    bool? isSynced,
  }) {
    return LocationTrackingModel(
      locationId: locationId ?? this.locationId,
      userId: userId ?? this.userId,
      attendanceId: attendanceId ?? this.attendanceId,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      timestamp: timestamp ?? this.timestamp,
      isLastSeen: isLastSeen ?? this.isLastSeen,
      isInsideGeofence: isInsideGeofence ?? this.isInsideGeofence,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'user_id': userId,
      'attendance_id': attendanceId,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'timestamp': timestamp.toIso8601String(),
      'is_last_seen': isLastSeen,
      'is_inside_geofence': isInsideGeofence,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'location_id': locationId,
      'user_id': userId,
      if (UuidHelper.isValidUuid(attendanceId)) 'attendance_id': attendanceId,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'timestamp': timestamp.toIso8601String(),
      'is_last_seen': isLastSeen,
    };
  }

  factory LocationTrackingModel.fromJson(Map<String, dynamic> json) {
    final syncedVal = json['is_synced'];
    final bool parsedSynced = syncedVal is bool
        ? syncedVal
        : (syncedVal is int ? syncedVal == 1 : false);

    return LocationTrackingModel(
      locationId: json['location_id'] as String,
      userId: json['user_id'] as String,
      attendanceId: json['attendance_id'] as String?,
      gpsLat: (json['gps_lat'] as num).toDouble(),
      gpsLng: (json['gps_lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLastSeen: json['is_last_seen'] as bool? ?? false,
      isInsideGeofence: json['is_inside_geofence'] as bool? ?? true,
      isSynced: parsedSynced,
    );
  }
}

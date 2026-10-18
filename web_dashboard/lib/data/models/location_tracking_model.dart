import 'package:latlong2/latlong.dart';

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

  const LocationTrackingModel({
    required this.locationId,
    required this.userId,
    this.attendanceId,
    required this.gpsLat,
    required this.gpsLng,
    required this.timestamp,
    this.isLastSeen = false,
    this.isInsideGeofence = true,
  });

  LatLng get point => LatLng(gpsLat, gpsLng);

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
    };
  }

  factory LocationTrackingModel.fromJson(Map<String, dynamic> json) {
    return LocationTrackingModel(
      locationId: json['location_id'] as String,
      userId: json['user_id'] as String,
      attendanceId: json['attendance_id'] as String?,
      gpsLat: (json['gps_lat'] as num).toDouble(),
      gpsLng: (json['gps_lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLastSeen: json['is_last_seen'] as bool? ?? false,
      isInsideGeofence: json['is_inside_geofence'] as bool? ?? true,
    );
  }
}

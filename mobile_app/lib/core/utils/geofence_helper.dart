import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeofenceHelper {
  GeofenceHelper._();

  /// Ray-casting algorithm to determine if a point is inside a polygon.
  /// Standard GIS point-in-polygon algorithm (Jordan Curve Theorem).
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final LatLng vertex1 = polygon[i];
      final LatLng vertex2 = polygon[(i + 1) % polygon.length];

      // Check if point is collinear with horizontal ray
      if ((vertex1.latitude > point.latitude) != (vertex2.latitude > point.latitude)) {
        final double xIntersection = (vertex2.longitude - vertex1.longitude) *
                (point.latitude - vertex1.latitude) /
                (vertex2.latitude - vertex1.latitude) +
            vertex1.longitude;

        if (point.longitude < xIntersection) {
          intersectCount++;
        }
      }
    }

    return (intersectCount % 2) == 1;
  }

  /// Calculates the Haversine distance in meters between two coordinates.
  static double calculateDistanceMeters(LatLng point1, LatLng point2) {
    const double earthRadiusMeters = 6371000.0;
    final double lat1Rad = point1.latitude * (math.pi / 180.0);
    final double lat2Rad = point2.latitude * (math.pi / 180.0);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180.0);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180.0);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calculates the centroid of a polygon.
  static LatLng calculateCentroid(List<LatLng> polygon) {
    if (polygon.isEmpty) return const LatLng(11.0050, 124.6075);
    double latSum = 0;
    double lngSum = 0;
    for (final p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }
}

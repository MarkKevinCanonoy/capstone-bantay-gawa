import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/core/utils/geofence_helper.dart';

void main() {
  group('1-Minute Geofence Tracking Privacy Rule Tests', () {
    // Sector 4 boundary in Ormoc City
    const List<LatLng> sector4Polygon = [
      LatLng(11.0085, 124.6035),
      LatLng(11.0085, 124.6115),
      LatLng(11.0015, 124.6115),
      LatLng(11.0015, 124.6035),
    ];

    test('Inside boundary: validates true for coordinate recording', () {
      const workerInsidePos = LatLng(11.0050, 124.6075);
      final isInside = GeofenceHelper.isPointInPolygon(workerInsidePos, sector4Polygon);
      expect(isInside, isTrue, reason: 'Coordinates should be recorded when inside assigned zone');
    });

    test('Outside boundary: validates false to suppress coordinate recording for privacy', () {
      // Worker left Sector 4 (e.g., at home or outside Ormoc Downtown)
      const workerOutsidePos = LatLng(11.0350, 124.6400);
      final isInside = GeofenceHelper.isPointInPolygon(workerOutsidePos, sector4Polygon);
      expect(isInside, isFalse, reason: 'Coordinates must be suppressed when outside assigned zone');
    });

    test('Boundary edge point detection', () {
      const nearEdgePos = LatLng(11.0080, 124.6050);
      final isInside = GeofenceHelper.isPointInPolygon(nearEdgePos, sector4Polygon);
      expect(isInside, isTrue);
    });
  });
}

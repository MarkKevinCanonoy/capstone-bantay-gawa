import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/core/utils/geofence_helper.dart';

void main() {
  group('GeofenceHelper Point-in-Polygon Tests', () {
    // Sector 4 square boundary in Ormoc City
    const List<LatLng> sector4Polygon = [
      LatLng(11.0080, 124.6040), // Top-left
      LatLng(11.0080, 124.6110), // Top-right
      LatLng(11.0020, 124.6110), // Bottom-right
      LatLng(11.0020, 124.6040), // Bottom-left
    ];

    test('Point strictly inside polygon returns true', () {
      const centerPoint = LatLng(11.0050, 124.6075);
      final isInside = GeofenceHelper.isPointInPolygon(centerPoint, sector4Polygon);
      expect(isInside, isTrue);
    });

    test('Point clearly outside polygon returns false', () {
      const outsidePoint = LatLng(11.0200, 124.6200);
      final isInside = GeofenceHelper.isPointInPolygon(outsidePoint, sector4Polygon);
      expect(isInside, isFalse);
    });

    test('Centroid calculation returns valid midpoint', () {
      final centroid = GeofenceHelper.calculateCentroid(sector4Polygon);
      expect(centroid.latitude, closeTo(11.0050, 0.001));
      expect(centroid.longitude, closeTo(124.6075, 0.001));
    });

    test('Distance calculation between two Ormoc points returns non-zero meters', () {
      const p1 = LatLng(11.0050, 124.6075);
      const p2 = LatLng(11.0080, 124.6075);
      final dist = GeofenceHelper.calculateDistanceMeters(p1, p2);
      expect(dist, greaterThan(300.0));
      expect(dist, lessThan(400.0));
    });
  });
}

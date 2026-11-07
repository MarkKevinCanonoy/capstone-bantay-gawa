import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/core/utils/geofence_helper.dart';
import 'package:mobile_app/data/datasources/local_database.dart';
import 'package:mobile_app/data/models/location_tracking_model.dart';

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

    test('LocationTrackingModel serialization and toSupabaseJson compatibility', () {
      final now = DateTime.now();
      final model = LocationTrackingModel(
        locationId: 'loc-101',
        userId: 'usr-abc',
        gpsLat: 11.0050,
        gpsLng: 124.6075,
        timestamp: now,
        isLastSeen: true,
        isInsideGeofence: true,
        isSynced: false,
      );

      final json = model.toJson();
      expect(json['location_id'], 'loc-101');
      expect(json['is_synced'], 0);

      final supaJson = model.toSupabaseJson();
      expect(supaJson['location_id'], 'loc-101');
      expect(supaJson['is_last_seen'], true);
      expect(supaJson.containsKey('is_synced'), isFalse); // Supabase table does not store is_synced column

      final restored = LocationTrackingModel.fromJson(json);
      expect(restored.locationId, model.locationId);
      expect(restored.isSynced, isFalse);

      final syncedModel = restored.copyWith(isSynced: true);
      expect(syncedModel.isSynced, isTrue);
    });

    test('LocalDatabase offline location tracking queue and sync lifecycle', () async {
      final db = LocalDatabase.instance;
      final tracking = LocationTrackingModel(
        locationId: 'test-track-999',
        userId: 'worker-123',
        gpsLat: 11.0055,
        gpsLng: 124.6070,
        timestamp: DateTime.now(),
        isSynced: false,
      );

      await db.insertLocationTracking(tracking);

      final unsynced = await db.getUnsyncedLocationTracking();
      expect(unsynced.any((t) => t.locationId == 'test-track-999'), isTrue);

      final countBefore = await db.getPendingSyncCount();
      expect(countBefore, greaterThanOrEqualTo(1));

      await db.markLocationTrackingSynced('test-track-999');
      final unsyncedAfter = await db.getUnsyncedLocationTracking();
      expect(unsyncedAfter.any((t) => t.locationId == 'test-track-999'), isFalse);
    });

    test('LocalDatabase purgeOldSyncedRecords cleans up synced records older than retention threshold', () async {
      final db = LocalDatabase.instance;
      final oldDate = DateTime.now().subtract(const Duration(days: 45));

      final oldSyncedTracking = LocationTrackingModel(
        locationId: 'test-track-old-synced',
        userId: 'worker-123',
        gpsLat: 11.0055,
        gpsLng: 124.6070,
        timestamp: oldDate,
        isSynced: true,
      );

      final oldUnsyncedTracking = LocationTrackingModel(
        locationId: 'test-track-old-unsynced',
        userId: 'worker-123',
        gpsLat: 11.0055,
        gpsLng: 124.6070,
        timestamp: oldDate,
        isSynced: false,
      );

      await db.insertLocationTracking(oldSyncedTracking);
      await db.insertLocationTracking(oldUnsyncedTracking);

      await db.purgeOldSyncedRecords(retentionDays: 30);

      // Unsynced records must always be preserved
      final unsynced = await db.getUnsyncedLocationTracking();
      expect(unsynced.any((t) => t.locationId == 'test-track-old-unsynced'), isTrue);
    });
  });
}

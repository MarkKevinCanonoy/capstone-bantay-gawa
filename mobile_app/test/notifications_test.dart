import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/location_helper.dart';
import 'package:mobile_app/data/datasources/local_database.dart';
import 'package:mobile_app/data/models/broadcast_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Notifications & SQLite Persistence Tests', () {
    test('Records read notification and verifies persistence in LocalDatabase', () async {
      final db = LocalDatabase.instance;
      const testNotificationId = 'notif_test_123';

      await db.markNotificationAsRead(testNotificationId);
      final readIds = await db.getReadNotificationIds();

      expect(readIds, contains(testNotificationId));
    });

    test('Batch marks multiple notifications as read and retrieves full set', () async {
      final db = LocalDatabase.instance;
      final batchIds = ['notif_a', 'notif_b', 'notif_c'];

      await db.markAllNotificationsAsRead(batchIds);
      final readIds = await db.getReadNotificationIds();

      for (final id in batchIds) {
        expect(readIds, contains(id));
      }
    });

    test('BroadcastModel serialization parses alert notices with receiver_id correctly', () {
      final json = {
        'notification_id': 'notif-101',
        'sender_id': 'admin-uuid',
        'receiver_id': 'worker-uuid-1',
        'message': 'Official Warning: Geofence breach detected at Ormoc Plaza.',
        'type': 'alert',
        'is_read': false,
        'sent_at': '2026-11-03T01:00:00.000Z',
      };

      final model = BroadcastModel.fromJson(json);
      expect(model.notificationId, equals('notif-101'));
      expect(model.receiverId, equals('worker-uuid-1'));
      expect(model.type, equals('alert'));
      expect(model.subject, equals('Official Warning'));
      expect(model.message, equals('Geofence breach detected at Ormoc Plaza.'));

      final out = model.toSupabaseJson();
      expect(out['receiver_id'], equals('worker-uuid-1'));
      expect(out['type'], equals('alert'));
      expect(out['is_read'], isFalse);
    });
  });

  group('LocationHelper Tests', () {
    test('LocationHelper returns valid LatLng coordinates with sensible bounds', () async {
      final location = await LocationHelper.getCurrentLocation();
      expect(location, isNotNull);
      expect(location.latitude, inInclusiveRange(10.0, 12.0));
      expect(location.longitude, inInclusiveRange(123.0, 126.0));
    });
  });
}

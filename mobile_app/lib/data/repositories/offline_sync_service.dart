import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../datasources/local_database.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();
  OfflineSyncService._init();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingSyncCountNotifier = ValueNotifier<int>(0);

  void startListening() {
    _refreshPendingCount();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (isOnline) {
        debugPrint('Internet connectivity detected. Triggering auto-sync...');
        syncPendingData();
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _refreshPendingCount() async {
    final count = await LocalDatabase.instance.getPendingSyncCount();
    pendingSyncCountNotifier.value = count;
  }

  Future<int> syncPendingData() async {
    if (isSyncingNotifier.value) return 0;
    isSyncingNotifier.value = true;

    int syncedCount = 0;
    try {
      final unsyncedAttendance = await LocalDatabase.instance.getUnsyncedAttendance();
      for (final att in unsyncedAttendance) {
        // Here in production, write to Supabase table:
        // await Supabase.instance.client.from('attendance').insert(att.toMap());
        await LocalDatabase.instance.markAttendanceSynced(att.attendanceId);
        syncedCount++;
      }

      final unsyncedAccomplishments = await LocalDatabase.instance.getUnsyncedAccomplishments();
      for (final acc in unsyncedAccomplishments) {
        // In production: upload image to Supabase Storage bucket, then insert row
        // await Supabase.instance.client.from('accomplishments').insert(...);
        await LocalDatabase.instance.markAccomplishmentSynced(acc.accomplishmentId);
        syncedCount++;
      }

      debugPrint('Sync completed successfully: $syncedCount records synced.');
    } catch (e) {
      debugPrint('Sync failed or offline: $e');
    } finally {
      await _refreshPendingCount();
      isSyncingNotifier.value = false;
    }

    return syncedCount;
  }
}

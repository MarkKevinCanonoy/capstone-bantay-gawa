import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../datasources/local_database.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();
  OfflineSyncService._init();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingSyncCountNotifier = ValueNotifier<int>(0);

  void startListening() {
    _refreshPendingCount();
    // Proactively pull latest enrolled biometric profiles into local SQLite
    syncInboundPersonnel();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (isOnline) {
        debugPrint('Internet connectivity detected. Triggering auto-sync...');
        syncPendingData();
        syncInboundPersonnel();
      }
    });
  }

  Future<void> syncInboundPersonnel() async {
    try {
      final client = Supabase.instance.client;
      await LocalDatabase.instance.syncEnrolledWorkersFromCloud(client);
    } catch (e) {
      debugPrint('Inbound personnel sync notice: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _refreshPendingCount() async {
    final count = await LocalDatabase.instance.getPendingSyncCount();
    pendingSyncCountNotifier.value = count;
  }

  Future<String> resolveImageForUpload({
    required SupabaseClient client,
    required String rawPath,
    required String bucket,
    required String userId,
    required String fileId,
  }) async {
    return resolveFileForUpload(
      client: client,
      rawPath: rawPath,
      bucket: bucket,
      userId: userId,
      fileId: fileId,
    );
  }

  Future<String> resolveFileForUpload({
    required SupabaseClient client,
    required String rawPath,
    required String bucket,
    required String userId,
    required String fileId,
  }) async {
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://') || rawPath.startsWith('data:')) {
      return rawPath;
    }
    try {
      final file = File(rawPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ext = rawPath.contains('.') ? rawPath.split('.').last.toLowerCase() : 'jpg';

        String mimeType;
        switch (ext) {
          case 'pdf':
            mimeType = 'application/pdf';
            break;
          case 'docx':
            mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            break;
          case 'doc':
            mimeType = 'application/msword';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          case 'txt':
            mimeType = 'text/plain';
            break;
          case 'jpg':
          case 'jpeg':
          default:
            mimeType = 'image/jpeg';
            break;
        }

        String dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        String finalUrl = dataUrl;
        try {
          final fileName = '${userId.isNotEmpty ? userId : "anon"}/$fileId.$ext';
          await client.storage.from(bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
          final pub = client.storage.from(bucket).getPublicUrl(fileName);
          if (pub.isNotEmpty) finalUrl = pub;
        } catch (_) {}
        return finalUrl;
      }
    } catch (e) {
      debugPrint('Error resolving file for upload ($rawPath): $e');
    }
    return rawPath;
  }

  Future<int> syncPendingData() async {
    if (isSyncingNotifier.value) return 0;
    isSyncingNotifier.value = true;

    int syncedCount = 0;
    final client = Supabase.instance.client;

    try {
      final unsyncedAttendance = await LocalDatabase.instance.getUnsyncedAttendance();
      for (final att in unsyncedAttendance) {
        try {
          String? finalUrl = att.imageUrl;
          if (finalUrl != null && finalUrl.isNotEmpty) {
            finalUrl = await resolveImageForUpload(
              client: client,
              rawPath: finalUrl,
              bucket: AppConstants.bucketAttendance,
              userId: att.userId,
              fileId: att.attendanceId,
            );
          }
          final json = att.toSupabaseJson();
          if (finalUrl != null) json['image_url'] = finalUrl;
          await client.from('attendance').upsert(json);
          await LocalDatabase.instance.markAttendanceSynced(att.attendanceId);
          syncedCount++;
        } catch (e) {
          debugPrint('Error syncing attendance ${att.attendanceId}: $e');
        }
      }

      final unsyncedAccomplishments = await LocalDatabase.instance.getUnsyncedAccomplishments();
      for (final acc in unsyncedAccomplishments) {
        try {
          final finalUrl = await resolveImageForUpload(
            client: client,
            rawPath: acc.imageUrl,
            bucket: AppConstants.bucketAccomplishments,
            userId: acc.userId,
            fileId: acc.accomplishmentId,
          );
          final json = acc.toSupabaseJson();
          json['image_url'] = finalUrl;
          await client.from('accomplishments').upsert(json);
          await LocalDatabase.instance.markAccomplishmentSynced(acc.accomplishmentId);
          if (finalUrl != acc.imageUrl) {
            await LocalDatabase.instance.updateAccomplishmentImageUrl(acc.accomplishmentId, finalUrl);
          }
          syncedCount++;
        } catch (e) {
          debugPrint('Error syncing accomplishment ${acc.accomplishmentId}: $e');
        }
      }

      // Auto-heal legacy records: upgrade any local device paths (/data/user/...) to Base64/cloud URLs
      try {
        final allAcc = await LocalDatabase.instance.getAllAccomplishments();
        for (final acc in allAcc) {
          final path = acc.imageUrl.trim();
          if (path.startsWith('/data/') || path.startsWith('/storage/') || path.startsWith('/cache/') || path.startsWith('file://')) {
            final healedUrl = await resolveImageForUpload(
              client: client,
              rawPath: path,
              bucket: AppConstants.bucketAccomplishments,
              userId: acc.userId,
              fileId: acc.accomplishmentId,
            );
            if (healedUrl.startsWith('data:image') || healedUrl.startsWith('http')) {
              await client.from('accomplishments').update({'image_url': healedUrl}).eq('accomplishment_id', acc.accomplishmentId);
              await LocalDatabase.instance.updateAccomplishmentImageUrl(acc.accomplishmentId, healedUrl);
            }
          }
        }
      } catch (e) {
        debugPrint('Legacy image auto-heal notice: $e');
      }

      final unsyncedLeaves = await LocalDatabase.instance.getUnsyncedLeaves();
      for (final lve in unsyncedLeaves) {
        try {
          String? finalUrl = lve.imageUrl;
          if (finalUrl != null && finalUrl.isNotEmpty) {
            finalUrl = await resolveFileForUpload(
              client: client,
              rawPath: finalUrl,
              bucket: AppConstants.bucketAccomplishments,
              userId: lve.userId,
              fileId: lve.leaveId,
            );
          }
          final json = lve.toSupabaseJson();
          if (finalUrl != null) json['image_url'] = finalUrl;
          await client.from('leave_requests').upsert(json);
          await LocalDatabase.instance.markLeaveSynced(lve.leaveId);
          if (finalUrl != null && finalUrl != lve.imageUrl) {
            await LocalDatabase.instance.updateLeaveImageUrl(lve.leaveId, finalUrl);
          }
          syncedCount++;
        } catch (e) {
          debugPrint('Error syncing leave ${lve.leaveId}: $e');
        }
      }

      // Auto-heal legacy leave records: upgrade any local device paths (/data/user/...) to Base64/cloud URLs
      try {
        final allLeaves = await LocalDatabase.instance.getAllLeaveRequests();
        for (final lve in allLeaves) {
          final path = lve.imageUrl?.trim() ?? '';
          if (path.startsWith('/data/') || path.startsWith('/storage/') || path.startsWith('/cache/') || path.startsWith('file://')) {
            final healedUrl = await resolveFileForUpload(
              client: client,
              rawPath: path,
              bucket: AppConstants.bucketAccomplishments,
              userId: lve.userId,
              fileId: lve.leaveId,
            );
            if (healedUrl.startsWith('data:') || healedUrl.startsWith('http')) {
              await client.from('leave_requests').update({'image_url': healedUrl}).eq('leave_id', lve.leaveId);
              await LocalDatabase.instance.updateLeaveImageUrl(lve.leaveId, healedUrl);
            }
          }
        }
      } catch (e) {
        debugPrint('Legacy leave auto-heal notice: $e');
      }

      final unsyncedIncidents = await LocalDatabase.instance.getUnsyncedIncidentReports();
      for (final inc in unsyncedIncidents) {
        try {
          String? finalUrl = inc.imageUrl;
          if (finalUrl != null && finalUrl.isNotEmpty) {
            finalUrl = await resolveImageForUpload(
              client: client,
              rawPath: finalUrl,
              bucket: 'incidents',
              userId: inc.reporterId,
              fileId: inc.reportId,
            );
          }
          final json = inc.toSupabaseJson();
          if (finalUrl != null) json['image_url'] = finalUrl;
          await client.from('worker_reports').upsert(json);
          await LocalDatabase.instance.markIncidentReportSynced(inc.reportId);
          syncedCount++;
        } catch (e) {
          debugPrint('Error syncing incident report ${inc.reportId}: $e');
        }
      }

      final unsyncedLocations = await LocalDatabase.instance.getUnsyncedLocationTracking();
      for (final loc in unsyncedLocations) {
        try {
          await client.from('location_tracking').upsert(loc.toSupabaseJson());
          await LocalDatabase.instance.markLocationTrackingSynced(loc.locationId);
          syncedCount++;
        } catch (e) {
          debugPrint('Error syncing location tracking ${loc.locationId}: $e');
        }
      }

      debugPrint('Sync completed: $syncedCount records uploaded to Supabase.');
    } catch (e) {
      debugPrint('Sync process error: $e');
    } finally {
      await _refreshPendingCount();
      isSyncingNotifier.value = false;
    }

    return syncedCount;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/biometrics_helper.dart';
import '../datasources/local_database.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/credit_history_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import 'mobile_repository.dart';
import 'offline_sync_service.dart';

class SupabaseMobileRepository implements MobileRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _sessionKey = 'bantaygawa_session_user_id';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserModel?> getLoggedInUser() async {
    // 1. Check local session
    final userId = await _storage.read(key: _sessionKey);
    if (userId == null) return null;

    // 2. Fetch fresh user details from Supabase if online
    try {
      final res = await _client.from('users').select('''
        *,
        roles(name),
        credit_balance(current_score),
        work_area_assignments(workarea_id, is_active, work_areas(name)),
        schedules(schedule_id, start_time, end_time, days, created_at)
      ''').eq('user_id', userId).maybeSingle();

      if (res != null) {
        final user = UserModel.fromJson(res);
        await LocalDatabase.instance.cacheUser(user);
        return user;
      }
    } catch (e) {
      debugPrint('Online user fetch failed, falling back to local SQLite: $e');
    }

    // 3. Fallback to local SQLite cache
    return await LocalDatabase.instance.getCachedUser();
  }

  double _lastMatchSimilarity = 0.0;
  int _lastCandidateCount = 0;

  double get lastMatchSimilarity => _lastMatchSimilarity;
  int get lastCandidateCount => _lastCandidateCount;

  @override
  Future<UserModel?> authenticateWithFace(List<double> capturedFaceEmbedding) async {
    UserModel? matchedUser;
    _lastMatchSimilarity = 0.0;

    // 1. First, check SQLite local database (Offline-first per SRS Section 2.1, 2.5, 3.15)
    // Facial recognition happens on-device against stored worker profiles with zero network latency.
    List<UserModel> candidates = [];
    try {
      candidates = await LocalDatabase.instance.getEnrolledWorkers();
    } catch (e) {
      debugPrint('Error reading local enrolled workers: $e');
    }

    _lastCandidateCount = candidates.length;

    // 2. Perform On-Device Cosine Similarity Comparison on local candidates
    double bestSimilarity = -1.0;
    for (final candidate in candidates) {
      final registeredVector = BiometricsHelper.parseEmbeddingString(candidate.faceEmbedding ?? '');
      if (registeredVector.isNotEmpty && capturedFaceEmbedding.isNotEmpty) {
        final similarity = BiometricsHelper.cosineSimilarity(capturedFaceEmbedding, registeredVector);
        debugPrint('Local biometric comparison with ${candidate.fullName}: similarity=$similarity');
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
        }
        if (similarity >= BiometricsHelper.matchThreshold && similarity == bestSimilarity) {
          matchedUser = candidate;
        }
      }
    }

    // 3. If no match was found locally or local candidates were empty:
    // The user might be a NEW worker just enrolled on the web! Query Supabase for freshly created accounts.
    if (matchedUser == null) {
      try {
        debugPrint('No local match found (best was $bestSimilarity). Refreshing latest enrolled workers from Supabase...');
        final res = await _client.from('users').select('''
          *,
          roles(name),
          credit_balance(current_score),
          work_area_assignments(workarea_id, is_active, work_areas(name)),
          schedules(schedule_id, start_time, end_time, days, created_at)
        ''').not('face_embedding', 'is', null).timeout(const Duration(seconds: 8));

        final freshCandidates = (res as List).map((m) => UserModel.fromJson(m as Map<String, dynamic>)).toList();
        if (freshCandidates.isNotEmpty) {
          await LocalDatabase.instance.cacheEnrolledWorkers(freshCandidates);
          candidates = freshCandidates;
          _lastCandidateCount = candidates.length;

          for (final candidate in freshCandidates) {
            final registeredVector = BiometricsHelper.parseEmbeddingString(candidate.faceEmbedding ?? '');
            if (registeredVector.isNotEmpty && capturedFaceEmbedding.isNotEmpty) {
              final similarity = BiometricsHelper.cosineSimilarity(capturedFaceEmbedding, registeredVector);
              debugPrint('Cloud-refreshed comparison with ${candidate.fullName}: similarity=$similarity');
              if (similarity > bestSimilarity) {
                bestSimilarity = similarity;
              }
              if (similarity >= BiometricsHelper.matchThreshold && similarity == bestSimilarity) {
                matchedUser = candidate;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Cloud refresh notice (offline or server unreachable): $e');
      }
    }

    // 4. Fallback to cached single user if still unmatched
    if (matchedUser == null && candidates.isEmpty) {
      try {
        final cached = await LocalDatabase.instance.getCachedUser();
        if (cached != null && cached.faceEmbedding != null && cached.faceEmbedding!.trim().isNotEmpty) {
          final registeredVector = BiometricsHelper.parseEmbeddingString(cached.faceEmbedding!);
          final similarity = BiometricsHelper.cosineSimilarity(capturedFaceEmbedding, registeredVector);
          if (similarity > bestSimilarity) bestSimilarity = similarity;
          if (similarity >= BiometricsHelper.matchThreshold) {
            matchedUser = cached;
          }
        }
      } catch (_) {}
    }

    _lastMatchSimilarity = bestSimilarity > 0 ? bestSimilarity : 0.0;

    // 5. If matched, save session and cache locally
    if (matchedUser != null) {
      try {
        await _storage.write(key: _sessionKey, value: matchedUser.userId);
      } catch (_) {}

      try {
        await LocalDatabase.instance.cacheUser(matchedUser);
        final areas = await getAssignedWorkAreas(matchedUser.userId);
        if (areas.isNotEmpty) {
          await LocalDatabase.instance.cacheWorkAreas(areas);
        }
      } catch (_) {}

      return matchedUser;
    }

    // If candidate list was completely empty and network failed, provide helpful instructions
    if (candidates.isEmpty) {
      throw Exception('No enrolled personnel found on device or server. Please ensure face was enrolled in dashboard.');
    }

    return null;
  }

  @override
  Future<void> logout() async {
    await _storage.delete(key: _sessionKey);
    await LocalDatabase.instance.clearUserCache();
  }

  @override
  Future<List<WorkAreaModel>> getAssignedWorkAreas(String userId) async {
    // 1. Try network query
    try {
      final res = await _client.from('work_area_assignments').select('''
        workarea_id,
        work_areas(*, users!supervisor_id(first_name, last_name))
      ''').eq('user_id', userId).eq('is_active', true);

      final List<WorkAreaModel> areas = [];
      for (final row in (res as List)) {
        if (row['work_areas'] != null) {
          areas.add(WorkAreaModel.fromMap(row['work_areas'] as Map<String, dynamic>));
        }
      }

      if (areas.isNotEmpty) {
        await LocalDatabase.instance.cacheWorkAreas(areas);
        return areas;
      }

      // If no explicit assignment, fetch all active work areas
      final allRes = await _client.from('work_areas').select('*, users!supervisor_id(first_name, last_name)');
      final allAreas = (allRes as List).map((m) => WorkAreaModel.fromMap(m as Map<String, dynamic>)).toList();
      if (allAreas.isNotEmpty) {
        await LocalDatabase.instance.cacheWorkAreas(allAreas);
        return allAreas;
      }
    } catch (e) {
      debugPrint('Failed to fetch assigned work areas online: $e');
    }

    // 2. Fallback to local SQLite cache
    final cached = await LocalDatabase.instance.getCachedWorkAreas();
    return cached;
  }

  @override
  Future<List<WorkAreaModel>> getAllWorkAreas() async {
    try {
      final allRes = await _client.from('work_areas').select('*, users!supervisor_id(first_name, last_name)');
      final allAreas = (allRes as List).map((m) => WorkAreaModel.fromMap(m as Map<String, dynamic>)).toList();
      if (allAreas.isNotEmpty) {
        await LocalDatabase.instance.cacheWorkAreas(allAreas);
        return allAreas;
      }
    } catch (e) {
      debugPrint('Failed to fetch all work areas online: $e');
    }
    return await LocalDatabase.instance.getCachedWorkAreas();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceHistory(String userId) async {
    try {
      final res = await _client.from('attendance').select('''
        *,
        work_areas(name)
      ''').eq('user_id', userId).order('timestamp', ascending: false);

      final onlineLogs = (res as List).map((m) {
        String aName = m['area_name']?.toString() ?? '';
        if (m['work_areas'] is Map && m['work_areas']['name'] != null) {
          aName = m['work_areas']['name'].toString();
        }
        return AttendanceModel.fromMap({...m as Map<String, dynamic>, 'area_name': aName});
      }).toList();

      // Retrieve local unsynced punches to ensure offline actions (breaks, etc.) don't vanish upon reconnecting
      final unsynced = await LocalDatabase.instance.getUnsyncedAttendance();
      final onlineIds = onlineLogs.map((l) => l.attendanceId).toSet();

      final List<AttendanceModel> combined = [...onlineLogs];
      for (final local in unsynced) {
        if (!onlineIds.contains(local.attendanceId)) {
          combined.add(local);
        }
      }
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return combined;
    } catch (e) {
      debugPrint('Attendance online fetch error, using local database: $e');
    }

    return await LocalDatabase.instance.getAllAttendance();
  }

  @override
  Future<void> recordAttendance(AttendanceModel attendance) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertAttendance(attendance);

    // 2. Try immediate sync to Supabase
    try {
      await _client.from('attendance').insert(attendance.toSupabaseJson());
      await LocalDatabase.instance.markAttendanceSynced(attendance.attendanceId);
    } catch (e) {
      debugPrint('Immediate attendance sync failed, queued in offline SQLite: $e');
      OfflineSyncService.instance.syncPendingData();
    }
  }

  @override
  Future<List<AccomplishmentModel>> getAccomplishments(String userId) async {
    // Tier 1: With approver join
    try {
      final res = await _client.from('accomplishments').select('''
        *,
        work_areas(name),
        approver:users!approved_by(first_name, last_name)
      ''').eq('user_id', userId).order('created_at', ascending: false);

      final onlineList = (res as List).map((m) {
        String aName = m['area_name']?.toString() ?? '';
        if (m['work_areas'] is Map && m['work_areas']['name'] != null) {
          aName = m['work_areas']['name'].toString();
        }
        String? aprName;
        if (m['approver'] is Map) {
          aprName = '${m['approver']['first_name'] ?? ''} ${m['approver']['last_name'] ?? ''}'.trim();
        }
        return AccomplishmentModel.fromMap({
          ...m as Map<String, dynamic>,
          'area_name': aName,
          'approved_by_name': aprName,
        });
      }).toList();

      return onlineList;
    } catch (_) {}

    // Tier 2: With constraint-named approver join
    try {
      final res = await _client.from('accomplishments').select('''
        *,
        work_areas(name),
        approver:users!accomplishments_approved_by_fkey(first_name, last_name)
      ''').eq('user_id', userId).order('created_at', ascending: false);

      final onlineList = (res as List).map((m) {
        String aName = m['area_name']?.toString() ?? '';
        if (m['work_areas'] is Map && m['work_areas']['name'] != null) {
          aName = m['work_areas']['name'].toString();
        }
        String? aprName;
        if (m['approver'] is Map) {
          aprName = '${m['approver']['first_name'] ?? ''} ${m['approver']['last_name'] ?? ''}'.trim();
        }
        return AccomplishmentModel.fromMap({
          ...m as Map<String, dynamic>,
          'area_name': aName,
          'approved_by_name': aprName,
        });
      }).toList();

      return onlineList;
    } catch (_) {}

    // Tier 3: Work areas only
    try {
      final res = await _client.from('accomplishments').select('''
        *,
        work_areas(name)
      ''').eq('user_id', userId).order('created_at', ascending: false);

      return (res as List).map((m) {
        String aName = m['area_name']?.toString() ?? '';
        if (m['work_areas'] is Map && m['work_areas']['name'] != null) {
          aName = m['work_areas']['name'].toString();
        }
        return AccomplishmentModel.fromMap({...m as Map<String, dynamic>, 'area_name': aName});
      }).toList();
    } catch (e) {
      debugPrint('Accomplishments online fetch error, using local database: $e');
    }

    return await LocalDatabase.instance.getAllAccomplishments();
  }

  @override
  Future<bool> submitAccomplishment(AccomplishmentModel accomplishment) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertAccomplishment(accomplishment);

    // 2. Try immediate sync to Supabase
    try {
      String cloudUrl = accomplishment.imageUrl;
      if (!cloudUrl.startsWith('http://') && !cloudUrl.startsWith('https://') && !cloudUrl.startsWith('data:image')) {
        cloudUrl = await OfflineSyncService.instance.resolveImageForUpload(
          client: _client,
          rawPath: accomplishment.imageUrl,
          bucket: AppConstants.bucketAccomplishments,
          userId: accomplishment.userId,
          fileId: accomplishment.accomplishmentId,
        );
      }
      final json = accomplishment.toSupabaseJson();
      json['image_url'] = cloudUrl;
      await _client.from('accomplishments').insert(json);
      await LocalDatabase.instance.markAccomplishmentSynced(accomplishment.accomplishmentId);
      if (cloudUrl != accomplishment.imageUrl) {
        await LocalDatabase.instance.updateAccomplishmentImageUrl(accomplishment.accomplishmentId, cloudUrl);
      }
      return true;
    } catch (e) {
      debugPrint('Immediate accomplishment sync failed, queued in offline SQLite: $e');
      OfflineSyncService.instance.syncPendingData();
      return false;
    }
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests(String userId) async {
    try {
      final res = await _client
          .from('leave_requests')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final onlineLeaves = (res as List).map((m) {
        return LeaveRequestModel.fromMap(m as Map<String, dynamic>);
      }).toList();

      // Update local SQLite queue with server decision status
      for (final l in onlineLeaves) {
        await LocalDatabase.instance.updateLeaveStatus(l.leaveId, l.status);
      }

      return onlineLeaves;
    } catch (e) {
      debugPrint('Leave requests online fetch error, using local database: $e');
    }

    return await LocalDatabase.instance.getAllLeaveRequests();
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequestModel leave) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertLeaveRequest(leave);

    // 2. Try immediate sync to Supabase
    try {
      String? cloudUrl = leave.imageUrl;
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        cloudUrl = await OfflineSyncService.instance.resolveFileForUpload(
          client: _client,
          rawPath: cloudUrl,
          bucket: AppConstants.bucketAccomplishments,
          userId: leave.userId,
          fileId: leave.leaveId,
        );
      }
      final supabaseJson = leave.toSupabaseJson();
      if (cloudUrl != null) supabaseJson['image_url'] = cloudUrl;

      await _client.from('leave_requests').insert(supabaseJson);
      await LocalDatabase.instance.markLeaveSynced(leave.leaveId);
      if (cloudUrl != null && cloudUrl != leave.imageUrl) {
        await LocalDatabase.instance.updateLeaveImageUrl(leave.leaveId, cloudUrl);
      }
    } catch (e) {
      debugPrint('Immediate leave sync failed, queued in offline SQLite: $e');
      OfflineSyncService.instance.syncPendingData();
    }
  }

  @override
  Future<List<CreditHistoryModel>> getCreditHistory(String userId) async {
    try {
      final res = await _client
          .from('credit_history')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (res as List).map((m) => CreditHistoryModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Credit history fetch error: $e');
      return [];
    }
  }

  @override
  Future<List<BroadcastModel>> getNotifications(String userId) async {
    try {
      final res = await _client
          .from('notifications')
          .select('*')
          .or('receiver_id.is.null,receiver_id.eq.$userId')
          .order('sent_at', ascending: false);

      return (res as List).map((m) => BroadcastModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Notifications fetch error: $e');
      return [];
    }
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('markNotificationAsRead error: $e');
    }
  }

  @override
  Future<List<UserModel>> getPeerWorkers(String workareaId) async {
    try {
      final res = await _client.from('users').select('''
        *,
        roles(name),
        credit_balance(current_score),
        work_area_assignments(workarea_id, is_active, work_areas(name))
      ''').eq('role_id', AppConstants.roleWorkerId).order('first_name');

      return (res as List).map((m) => UserModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Peer workers fetch error: $e');
      return [];
    }
  }

  @override
  Future<List<IncidentReportModel>> getIncidentReports(String userId) async {
    try {
      final res = await _client.from('worker_reports').select('''
        *,
        reporter:users!worker_reports_reporter_id_fkey(first_name, last_name),
        reported:users!worker_reports_reported_id_fkey(first_name, last_name)
      ''').eq('reporter_id', userId).order('created_at', ascending: false);

      final onlineReports = (res as List).map((m) {
        String rName = '';
        String dName = '';
        if (m['reporter'] is Map) {
          rName = '${m['reporter']['first_name'] ?? ''} ${m['reporter']['last_name'] ?? ''}'.trim();
        }
        if (m['reported'] is Map) {
          dName = '${m['reported']['first_name'] ?? ''} ${m['reported']['last_name'] ?? ''}'.trim();
        }
        return IncidentReportModel.fromMap({
          ...m as Map<String, dynamic>,
          'reporter_name': rName,
          'reported_name': dName,
        });
      }).toList();

      return onlineReports;
    } catch (e) {
      debugPrint('Incident reports online fetch error: $e');
    }

    return await LocalDatabase.instance.getAllIncidentReports();
  }

  @override
  Future<void> submitIncidentReport(IncidentReportModel report) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertIncidentReport(report);

    // 2. Try immediate sync to Supabase
    try {
      await _client.from('worker_reports').insert(report.toSupabaseJson());
      await LocalDatabase.instance.markIncidentReportSynced(report.reportId);
    } catch (e) {
      debugPrint('Immediate incident report sync failed, queued in offline SQLite: $e');
      OfflineSyncService.instance.syncPendingData();
    }
  }

  @override
  Future<int> getUnsyncedCount() async {
    return await LocalDatabase.instance.getPendingSyncCount();
  }

  @override
  Future<void> syncOfflineData() async {
    await OfflineSyncService.instance.syncPendingData();
  }

  @override
  Future<bool> registerFaceEmbedding(String userId, String faceEmbedding) async {
    try {
      await _client.from('users').update({
        'face_embedding': faceEmbedding,
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('registerFaceEmbedding Supabase update failed (will cache locally): $e');
    }

    try {
      final cached = await LocalDatabase.instance.getCachedUser();
      if (cached != null && cached.userId == userId) {
        final updated = cached.copyWith(faceEmbedding: faceEmbedding);
        await LocalDatabase.instance.cacheUser(updated);
      }
      return true;
    } catch (e) {
      debugPrint('Local SQLite user update failed: $e');
      return false;
    }
  }
}

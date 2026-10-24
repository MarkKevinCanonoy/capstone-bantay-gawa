import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/biometrics_helper.dart';
import '../datasources/local_database.dart';
import '../datasources/mock_data.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import 'mobile_repository.dart';
import 'offline_sync_service.dart';

class SupabaseMobileRepository implements MobileRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _sessionKey = 'bantaygawa_session_user_id';

  @override
  Future<UserModel?> getLoggedInUser() async {
    // 1. Check local session
    final userId = await _storage.read(key: _sessionKey);
    if (userId == null) return null;

    // 2. Fetch from local SQLite cache
    final cached = await LocalDatabase.instance.getCachedUser();
    if (cached != null) return cached;

    // 3. Fallback to default mock worker if not cached
    return MockData.defaultWorker;
  }

  @override
  Future<UserModel?> authenticateWithFace(List<double> capturedFaceEmbedding) async {
    // In production, query Supabase `users` table for candidate face embeddings.
    // For our field workers, we compare with the registered face embedding:
    final registeredWorker = MockData.defaultWorker;
    final registeredVector = BiometricsHelper.parseEmbeddingString(registeredWorker.faceEmbedding ?? '');

    // If no vector registered yet, accept live face as initial enrollment/login
    bool isMatch = true;
    if (registeredVector.isNotEmpty && capturedFaceEmbedding.isNotEmpty) {
      final similarity = BiometricsHelper.cosineSimilarity(capturedFaceEmbedding, registeredVector);
      isMatch = similarity >= BiometricsHelper.matchThreshold;
    }

    if (isMatch) {
      // Save persistent session
      try {
        await _storage.write(key: _sessionKey, value: registeredWorker.userId);
      } catch (_) {}
      // Cache user and assigned areas locally in SQLite
      try {
        await LocalDatabase.instance.cacheUser(registeredWorker);
        await LocalDatabase.instance.cacheWorkAreas(MockData.sampleWorkAreas);
      } catch (_) {}
      return registeredWorker;
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
    final cached = await LocalDatabase.instance.getCachedWorkAreas();
    if (cached.isNotEmpty) return cached;
    return MockData.sampleWorkAreas;
  }

  @override
  Future<List<AttendanceModel>> getAttendanceHistory(String userId) async {
    final local = await LocalDatabase.instance.getAllAttendance();
    if (local.isNotEmpty) return local;
    return MockData.initialAttendanceLogs;
  }

  @override
  Future<void> recordAttendance(AttendanceModel attendance) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertAttendance(attendance);

    // 2. Trigger background sync attempt
    OfflineSyncService.instance.syncPendingData();
  }

  @override
  Future<List<AccomplishmentModel>> getAccomplishments(String userId) async {
    final local = await LocalDatabase.instance.getAllAccomplishments();
    if (local.isNotEmpty) return local;
    return MockData.initialAccomplishments;
  }

  @override
  Future<void> submitAccomplishment(AccomplishmentModel accomplishment) async {
    // 1. Save immediately to SQLite
    await LocalDatabase.instance.insertAccomplishment(accomplishment);

    // 2. Trigger background sync attempt
    OfflineSyncService.instance.syncPendingData();
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests(String userId) async {
    final local = await LocalDatabase.instance.getAllLeaveRequests();
    if (local.isNotEmpty) return local;
    return MockData.initialLeaveRequests;
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequestModel leave) async {
    await LocalDatabase.instance.insertLeaveRequest(leave);
  }

  @override
  Future<int> getUnsyncedCount() async {
    return await LocalDatabase.instance.getPendingSyncCount();
  }

  @override
  Future<void> syncOfflineData() async {
    await OfflineSyncService.instance.syncPendingData();
  }
}

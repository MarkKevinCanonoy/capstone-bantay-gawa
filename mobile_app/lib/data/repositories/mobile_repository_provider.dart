import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'supabase_mobile_repository.dart';

final mobileRepositoryProvider = Provider<MobileRepository>((ref) {
  return SupabaseMobileRepository();
});

class CurrentUserNotifier extends AsyncNotifier<UserModel?> {
  RealtimeChannel? _creditChannel;
  Timer? _pollingTimer;

  @override
  Future<UserModel?> build() async {
    final repo = ref.watch(mobileRepositoryProvider);
    final user = await repo.getLoggedInUser();

    ref.onDispose(() {
      _pollingTimer?.cancel();
      if (_creditChannel != null) {
        try {
          Supabase.instance.client.removeChannel(_creditChannel!);
        } catch (_) {}
      }
    });

    if (user != null) {
      _setupRealtime(user.userId);
    }
    return user;
  }

  void _setupRealtime(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        final fresh = await repo.getLoggedInUser();
        if (fresh != null) {
          final currentScore = state.value?.creditScore;
          if (fresh.creditScore != currentScore) {
            state = AsyncValue.data(fresh);
            ref.invalidate(creditHistoryProvider);
          }
        }
      } catch (_) {}
    });

    try {
      _creditChannel = Supabase.instance.client
          .channel('public:credit_balance:mobile:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'credit_balance',
            callback: (_) async {
              final repo = ref.read(mobileRepositoryProvider);
              final fresh = await repo.getLoggedInUser();
              if (fresh != null) {
                state = AsyncValue.data(fresh);
              }
              ref.invalidate(creditHistoryProvider);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime credit_balance mobile listener note: $e');
    }
  }

  Future<bool> loginWithFace(List<double> faceVector) async {
    final repo = ref.read(mobileRepositoryProvider);
    final user = await repo.authenticateWithFace(faceVector);
    if (user != null) {
      state = AsyncValue.data(user);
      _setupRealtime(user.userId);
      return true;
    }
    return false;
  }

  Future<bool> updateFaceEmbedding(String faceEmbedding) async {
    final user = state.value;
    if (user == null) return false;
    final repo = ref.read(mobileRepositoryProvider);
    final success = await repo.registerFaceEmbedding(user.userId, faceEmbedding);
    if (success) {
      state = AsyncValue.data(user.copyWith(faceEmbedding: faceEmbedding));
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _pollingTimer?.cancel();
    if (_creditChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_creditChannel!);
      } catch (_) {}
    }
    final repo = ref.read(mobileRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(null);
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, UserModel?>(() {
  return CurrentUserNotifier();
});

final assignedWorkAreaProvider = FutureProvider<WorkAreaModel?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  final repo = ref.watch(mobileRepositoryProvider);
  final areas = await repo.getAssignedWorkAreas(user.userId);
  return areas.isNotEmpty ? areas.first : null;
});

final allWorkAreasProvider = FutureProvider<List<WorkAreaModel>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  final repo = ref.watch(mobileRepositoryProvider);
  return await repo.getAllWorkAreas();
});

class AttendanceListNotifier extends AsyncNotifier<List<AttendanceModel>> {
  @override
  Future<List<AttendanceModel>> build() async {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return [];
    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getAttendanceHistory(user.userId);
  }

  Future<void> record(AttendanceModel log) async {
    final repo = ref.read(mobileRepositoryProvider);
    await repo.recordAttendance(log);
    ref.invalidateSelf();
  }
}

final attendanceListProvider = AsyncNotifierProvider<AttendanceListNotifier, List<AttendanceModel>>(() {
  return AttendanceListNotifier();
});

class AccomplishmentListNotifier extends AsyncNotifier<List<AccomplishmentModel>> {
  @override
  Future<List<AccomplishmentModel>> build() async {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return [];
    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getAccomplishments(user.userId);
  }

  Future<bool> submit(AccomplishmentModel accomplishment) async {
    final repo = ref.read(mobileRepositoryProvider);
    final wasSynced = await repo.submitAccomplishment(accomplishment);
    ref.invalidateSelf();
    return wasSynced;
  }
}

final accomplishmentListProvider = AsyncNotifierProvider<AccomplishmentListNotifier, List<AccomplishmentModel>>(() {
  return AccomplishmentListNotifier();
});

class LeaveRequestListNotifier extends AsyncNotifier<List<LeaveRequestModel>> {
  @override
  Future<List<LeaveRequestModel>> build() async {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return [];
    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getLeaveRequests(user.userId);
  }

  Future<void> submit(LeaveRequestModel leave) async {
    final repo = ref.read(mobileRepositoryProvider);
    await repo.submitLeaveRequest(leave);
    ref.invalidateSelf();
  }
}

final leaveRequestListProvider = AsyncNotifierProvider<LeaveRequestListNotifier, List<LeaveRequestModel>>(() {
  return LeaveRequestListNotifier();
});

// Credit History Provider
final creditHistoryProvider = FutureProvider<List<CreditHistoryModel>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  final repo = ref.watch(mobileRepositoryProvider);
  return await repo.getCreditHistory(user.userId);
});

// Notifications List Notifier
class NotificationListNotifier extends AsyncNotifier<List<BroadcastModel>> {
  RealtimeChannel? _notificationChannel;
  Timer? _pollingTimer;

  @override
  Future<List<BroadcastModel>> build() async {
    final user = ref.watch(currentUserProvider).value;

    ref.onDispose(() {
      _pollingTimer?.cancel();
      if (_notificationChannel != null) {
        try {
          Supabase.instance.client.removeChannel(_notificationChannel!);
        } catch (_) {}
      }
    });

    if (user == null) return [];

    _setupRealtime(user.userId);

    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getNotifications(user.userId);
  }

  void _setupRealtime(String userId) {
    _pollingTimer?.cancel();
    // 10-second polling fallback so field notifications arrive in near real-time
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        final fresh = await repo.getNotifications(userId);
        state = AsyncValue.data(fresh);
      } catch (_) {}
    });

    try {
      _notificationChannel = Supabase.instance.client
          .channel('public:notifications:mobile:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (_) async {
              final repo = ref.read(mobileRepositoryProvider);
              final fresh = await repo.getNotifications(userId);
              state = AsyncValue.data(fresh);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime notifications mobile listener note: $e');
    }
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      final repo = ref.read(mobileRepositoryProvider);
      final fresh = await repo.getNotifications(user.userId);
      state = AsyncValue.data(fresh);
    }
  }

  Future<void> markAsRead(String id) async {
    await ref.read(readNotificationsProvider.notifier).markAsRead(id);
    final repo = ref.read(mobileRepositoryProvider);
    await repo.markNotificationAsRead(id);
  }
}

final notificationListProvider = AsyncNotifierProvider<NotificationListNotifier, List<BroadcastModel>>(() {
  return NotificationListNotifier();
});

class ReadNotificationsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return await LocalDatabase.instance.getReadNotificationIds();
  }

  Future<void> markAsRead(String id) async {
    await LocalDatabase.instance.markNotificationAsRead(id);
    final current = state.value ?? {};
    state = AsyncValue.data({...current, id});
  }

  Future<void> markAllAsRead(List<String> ids) async {
    await LocalDatabase.instance.markAllNotificationsAsRead(ids);
    final current = state.value ?? {};
    state = AsyncValue.data({...current, ...ids});
  }
}

final readNotificationsProvider = AsyncNotifierProvider<ReadNotificationsNotifier, Set<String>>(() {
  return ReadNotificationsNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final all = ref.watch(notificationListProvider).value ?? [];
  final readIds = ref.watch(readNotificationsProvider).value ?? {};
  return all.where((n) => !readIds.contains(n.notificationId)).length;
});

// Peer Workers Provider (for reporting)
final peerWorkersProvider = FutureProvider<List<UserModel>>((ref) async {
  final area = ref.watch(assignedWorkAreaProvider).value;
  if (area == null || area.workareaId.isEmpty) return [];
  final repo = ref.watch(mobileRepositoryProvider);
  return await repo.getPeerWorkers(area.workareaId);
});

// Incident Report List Notifier
class IncidentReportListNotifier extends AsyncNotifier<List<IncidentReportModel>> {
  @override
  Future<List<IncidentReportModel>> build() async {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return [];
    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getIncidentReports(user.userId);
  }

  Future<void> submit(IncidentReportModel report) async {
    final repo = ref.read(mobileRepositoryProvider);
    await repo.submitIncidentReport(report);
    ref.invalidateSelf();
  }
}

final incidentReportListProvider = AsyncNotifierProvider<IncidentReportListNotifier, List<IncidentReportModel>>(() {
  return IncidentReportListNotifier();
});


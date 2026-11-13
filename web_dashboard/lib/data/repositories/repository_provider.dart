import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_repository.dart';
import 'mock_repository.dart';
import 'supabase_repository.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/worker_schedule_sheet_model.dart';
import '../models/time_preset_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';

// Master Repository Provider
// Uses SupabaseRepository for live app; MockRepository for headless unit tests
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  try {
    Supabase.instance.client;
    return SupabaseRepository();
  } catch (_) {
    return MockRepository();
  }
});

// Current User State Provider (Riverpod 3 NotifierProvider)
class CurrentUserNotifier extends Notifier<UserModel> {
  @override
  UserModel build() {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) {
        return UserModel(
          userId: supaUser.id,
          username: supaUser.email ?? 'admin',
          firstName: supaUser.userMetadata?['first_name']?.toString() ?? 'Administrator',
          lastName: supaUser.userMetadata?['last_name']?.toString() ?? '',
          contactNumber: supaUser.phone ?? '',
          role: UserRole.admin,
          status: 'active',
          schedule: 'Unassigned',
        );
      }
    } catch (_) {}

    return UserModel(
      userId: '',
      username: '',
      firstName: 'Administrator',
      lastName: '',
      contactNumber: '',
      role: UserRole.admin,
      status: 'active',
      schedule: 'Unassigned',
    );
  }

  @override
  set state(UserModel value) => super.state = value;
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, UserModel>(CurrentUserNotifier.new);

// Active Navigation Tab (Riverpod 3 NotifierProvider)
class ActiveNavNotifier extends Notifier<String> {
  @override
  String build() => 'login';

  @override
  set state(String value) => super.state = value;
}

final activeNavProvider = NotifierProvider<ActiveNavNotifier, String>(ActiveNavNotifier.new);

// Global Search Query (Riverpod 3 NotifierProvider)
class GlobalSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

final globalSearchProvider = NotifierProvider<GlobalSearchNotifier, String>(GlobalSearchNotifier.new);

// Selected Alert Category Filter (Riverpod 3 NotifierProvider)
class AlertCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  @override
  set state(String value) => super.state = value;
}

final alertCategoryFilterProvider = NotifierProvider<AlertCategoryFilterNotifier, String>(AlertCategoryFilterNotifier.new);

// Data Providers (Auto-refreshable)
final workAreasProvider = FutureProvider.autoDispose<List<WorkAreaModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final supId = user.role == UserRole.supervisor ? user.userId : null;

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:work_areas:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'work_areas',
            callback: (_) => ref.invalidateSelf(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'work_area_assignments',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime work_areas subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getWorkAreas(supervisorId: supId);
});

final employeesProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:employees:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (_) => ref.invalidateSelf(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'credit_balance',
            callback: (_) => ref.invalidateSelf(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'work_area_assignments',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime employees subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getUsers(areaId: areaId);
});

final supervisorsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:supervisors:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime supervisors subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getUsers(role: UserRole.supervisor);
});

final attendanceProvider = FutureProvider.autoDispose<List<AttendanceModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:attendance:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendance',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime attendance subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getAttendanceLogs(areaId: areaId);
});

class ScheduleSheetsQuery {
  final int month;
  final int year;

  const ScheduleSheetsQuery({required this.month, required this.year});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleSheetsQuery &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => month.hashCode ^ year.hashCode;
}

final scheduleSheetsProvider = FutureProvider.autoDispose.family<List<ScheduleSheetModel>, ScheduleSheetsQuery>((ref, query) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getScheduleSheets(month: query.month, year: query.year);
});

final timePresetsProvider = FutureProvider.autoDispose<List<TimePresetModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getTimePresets();
});

final accomplishmentsProvider = FutureProvider.autoDispose<List<AccomplishmentModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:accomplishments:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'accomplishments',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime accomplishments subscription note: $e');
    }

    // Polling fallback to ensure field accomplishments appear promptly
    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getAccomplishments(areaId: areaId);
});

final leaveRequestsProvider = FutureProvider.autoDispose<List<LeaveRequestModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:leave_requests:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'leave_requests',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime leave_requests subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getLeaveRequests(areaId: areaId);
});

final alertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final category = ref.watch(alertCategoryFilterProvider);

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:alerts:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime alerts subscription note: $e');
    }

    // Polling fallback to ensure breach alerts from mobile appear promptly
    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getAlerts(category: category);
});

final locationBreadcrumbsProvider = FutureProvider.autoDispose.family<List<LocationTrackingModel>, String?>((ref, workerId) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getLocationBreadcrumbs(userId: workerId);
});

final broadcastsProvider = FutureProvider.autoDispose<List<BroadcastModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:notifications:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime broadcasts subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  return repo.getBroadcasts();
});

final incidentsProvider = FutureProvider.autoDispose<List<IncidentReportModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repo is SupabaseRepository) {
    try {
      final channel = Supabase.instance.client
          .channel('public:worker_reports:web')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'worker_reports',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        Supabase.instance.client.removeChannel(channel);
      });
    } catch (e) {
      debugPrint('Realtime incidents subscription note: $e');
    }

    final timer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  if (user.role == UserRole.supervisor) {
    return repo.getIncidents(workareaId: user.assignedAreaId);
  }
  return repo.getIncidents();
});


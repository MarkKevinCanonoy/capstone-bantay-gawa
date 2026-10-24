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
    return UserModel(
      userId: '11111111-1111-1111-1111-111111111111',
      username: 'admin_enro',
      firstName: 'Roberto',
      lastName: 'Del Rosario',
      contactNumber: '+63 917 111 0001',
      role: UserRole.admin,
      status: 'active',
    );
  }

  @override
  set state(UserModel value) => super.state = value;
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, UserModel>(CurrentUserNotifier.new);

// Active Navigation Tab (Riverpod 3 NotifierProvider)
class ActiveNavNotifier extends Notifier<String> {
  @override
  String build() => 'dashboard';

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
  return repo.getWorkAreas(supervisorId: supId);
});

final employeesProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;
  return repo.getUsers(areaId: areaId);
});

final attendanceProvider = FutureProvider.autoDispose<List<AttendanceModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;
  return repo.getAttendanceLogs(areaId: areaId);
});

final accomplishmentsProvider = FutureProvider.autoDispose<List<AccomplishmentModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;
  return repo.getAccomplishments(areaId: areaId);
});

final leaveRequestsProvider = FutureProvider.autoDispose<List<LeaveRequestModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final areaId = user.role == UserRole.supervisor ? user.assignedAreaId : null;
  return repo.getLeaveRequests(areaId: areaId);
});

final alertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final category = ref.watch(alertCategoryFilterProvider);
  return repo.getAlerts(category: category);
});

final locationBreadcrumbsProvider = FutureProvider.autoDispose.family<List<LocationTrackingModel>, String?>((ref, workerId) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getLocationBreadcrumbs(userId: workerId);
});

final broadcastsProvider = FutureProvider.autoDispose<List<BroadcastModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getBroadcasts();
});

final incidentsProvider = FutureProvider.autoDispose<List<IncidentReportModel>>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (user.role == UserRole.supervisor) {
    return repo.getIncidents(workareaId: user.assignedAreaId);
  }
  return repo.getIncidents();
});


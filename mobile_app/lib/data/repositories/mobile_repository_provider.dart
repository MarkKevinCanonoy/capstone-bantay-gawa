import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import 'mobile_repository.dart';
import 'supabase_mobile_repository.dart';

final mobileRepositoryProvider = Provider<MobileRepository>((ref) {
  return SupabaseMobileRepository();
});

class CurrentUserNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final repo = ref.watch(mobileRepositoryProvider);
    return await repo.getLoggedInUser();
  }

  Future<bool> loginWithFace(List<double> faceVector) async {
    final repo = ref.read(mobileRepositoryProvider);
    final user = await repo.authenticateWithFace(faceVector);
    if (user != null) {
      state = AsyncValue.data(user);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
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

  Future<void> submit(AccomplishmentModel accomplishment) async {
    final repo = ref.read(mobileRepositoryProvider);
    await repo.submitAccomplishment(accomplishment);
    ref.invalidateSelf();
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

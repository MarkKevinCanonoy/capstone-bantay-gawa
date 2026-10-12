import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../datasources/mock_data.dart';
import 'data_repository.dart';

class MockRepository implements DataRepository {
  final List<WorkAreaModel> _workAreas = List.from(MockData.workAreas);
  final List<UserModel> _users = List.from(MockData.users);
  final List<AttendanceModel> _attendanceLogs = List.from(MockData.attendanceLogs);
  final List<AccomplishmentModel> _accomplishments = List.from(MockData.accomplishments);
  final List<LeaveRequestModel> _leaveRequests = List.from(MockData.leaveRequests);
  final List<AlertModel> _alerts = List.from(MockData.alerts);
  final List<BroadcastModel> _broadcasts = List.from(MockData.broadcasts);
  final List<IncidentReportModel> _incidents = List.from(MockData.incidents);

  int _countWorkersInArea(String areaId) {
    return _users.where((u) => u.role == UserRole.worker && u.assignedAreaId == areaId).length;
  }

  // Work Areas
  @override
  Future<List<WorkAreaModel>> getWorkAreas({String? supervisorId}) async {
    var list = _workAreas.map((a) {
      final count = _countWorkersInArea(a.workareaId);
      return a.copyWith(assignedCount: count);
    }).toList();

    if (supervisorId != null && supervisorId.isNotEmpty) {
      list = list.where((a) => a.supervisorId == supervisorId).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> addWorkArea(WorkAreaModel area) async {
    final count = _countWorkersInArea(area.workareaId);
    _workAreas.insert(0, area.copyWith(assignedCount: count));
  }

  @override
  Future<void> updateWorkArea(WorkAreaModel area) async {
    final idx = _workAreas.indexWhere((a) => a.workareaId == area.workareaId);
    if (idx != -1) {
      final count = _countWorkersInArea(area.workareaId);
      _workAreas[idx] = area.copyWith(assignedCount: count);
    }
  }

  @override
  Future<void> deleteWorkArea(String areaId) async {
    _workAreas.removeWhere((a) => a.workareaId == areaId);
  }

  // Users
  @override
  Future<List<UserModel>> getUsers({String? areaId, UserRole? role}) async {
    var list = _users;
    if (areaId != null && areaId.isNotEmpty) {
      list = list.where((u) => u.assignedAreaId == areaId).toList();
    }
    if (role != null) {
      list = list.where((u) => u.role == role).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> addUser(UserModel user) async {
    _users.insert(0, user);
  }

  @override
  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.userId == userId);
  }

  @override
  Future<void> assignWorkerToArea({
    required String workerId,
    required String? areaId,
    String? areaName,
  }) async {
    final idx = _users.indexWhere((u) => u.userId == workerId);
    if (idx != -1) {
      if (areaId == null) {
        _users[idx] = _users[idx].copyWith(clearAssignedArea: true);
      } else {
        _users[idx] = _users[idx].copyWith(
          assignedAreaId: areaId,
          assignedAreaName: areaName,
        );
      }
      // Synchronize assignedCount for all work areas
      for (int i = 0; i < _workAreas.length; i++) {
        final count = _countWorkersInArea(_workAreas[i].workareaId);
        _workAreas[i] = _workAreas[i].copyWith(assignedCount: count);
      }
    }
  }

  // Attendance
  @override
  Future<List<AttendanceModel>> getAttendanceLogs({String? areaId, String? workerId}) async {
    var list = _attendanceLogs;
    if (areaId != null && areaId.isNotEmpty) {
      list = list.where((a) => a.workareaId == areaId).toList();
    }
    if (workerId != null && workerId.isNotEmpty) {
      list = list.where((a) => a.userId == workerId).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> toggleAttendanceVerify(String attendanceId) async {
    final idx = _attendanceLogs.indexWhere((a) => a.attendanceId == attendanceId);
    if (idx != -1) {
      final current = _attendanceLogs[idx];
      _attendanceLogs[idx] = current.copyWith(isVerified: !current.isVerified);
    }
  }

  // Accomplishments
  @override
  Future<List<AccomplishmentModel>> getAccomplishments({String? areaId}) async {
    if (areaId != null && areaId.isNotEmpty) {
      return _accomplishments.where((a) => a.workareaId == areaId).toList();
    }
    return List.unmodifiable(_accomplishments);
  }

  @override
  Future<void> updateAccomplishmentStatus(
    String accomplishmentId,
    String status, {
    String? rejectionReason,
    String? approvedBy,
    String? approvedByName,
  }) async {
    final idx = _accomplishments.indexWhere((a) => a.accomplishmentId == accomplishmentId);
    if (idx != -1) {
      final current = _accomplishments[idx];
      _accomplishments[idx] = current.copyWith(
        status: status,
        rejectionReason: rejectionReason,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        approvedAt: DateTime.now(),
      );
    }
  }

  // Leaves
  @override
  Future<List<LeaveRequestModel>> getLeaveRequests({String? areaId}) async {
    if (areaId != null && areaId.isNotEmpty) {
      return _leaveRequests.where((l) => l.workareaId == areaId).toList();
    }
    return List.unmodifiable(_leaveRequests);
  }

  @override
  Future<void> updateLeaveStatus(
    String leaveId,
    String status, {
    String? adminId,
    String? rejectionReason,
  }) async {
    final idx = _leaveRequests.indexWhere((l) => l.leaveId == leaveId);
    if (idx != -1) {
      final current = _leaveRequests[idx];
      _leaveRequests[idx] = current.copyWith(
        status: status,
        adminDecision: adminId,
        decisionAt: DateTime.now(),
        rejectionReason: rejectionReason,
      );
    }
  }

  // Alerts
  @override
  Future<List<AlertModel>> getAlerts({String? areaId}) async {
    return List.unmodifiable(_alerts);
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(isResolved: true);
    }
  }

  // Broadcasts
  @override
  Future<List<BroadcastModel>> getBroadcasts() async {
    return List.unmodifiable(_broadcasts);
  }

  @override
  Future<void> addBroadcast(BroadcastModel broadcast) async {
    _broadcasts.insert(0, broadcast);
  }

  // Incidents
  @override
  Future<List<IncidentReportModel>> getIncidents({String? reporterId}) async {
    if (reporterId != null && reporterId.isNotEmpty) {
      return _incidents.where((i) => i.reporterId == reporterId).toList();
    }
    return List.unmodifiable(_incidents);
  }

  @override
  Future<void> addIncident(IncidentReportModel incident) async {
    _incidents.insert(0, incident);
  }

  @override
  Future<void> resolveIncident(String reportId) async {
    final idx = _incidents.indexWhere((i) => i.reportId == reportId);
    if (idx != -1) {
      _incidents[idx] = _incidents[idx].copyWith(status: 'resolved');
    }
  }
}

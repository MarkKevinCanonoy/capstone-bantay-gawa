import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';
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
  final List<LocationTrackingModel> _locationTracking = List.from(MockData.locationTracking);

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

  // Users & Worker Assignments (UC-07)
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
      final previousArea = _users[idx].assignedAreaName;
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

      // Main Flow Step 8: System dispatches assignment notification to worker
      if (areaId != null) {
        _broadcasts.insert(
          0,
          BroadcastModel(
            notificationId: 'notif-assign-${DateTime.now().millisecondsSinceEpoch}',
            senderId: 'user-admin-1',
            recipients: _users[idx].fullName,
            subject: 'New Work Area Assignment',
            message: 'You have been assigned to $areaName${previousArea != null ? " (transferred from $previousArea)" : ""}. Please report to your sector for upcoming shifts.',
            isConfidential: true,
            deliveredCount: 1,
            sentAt: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  Future<void> bulkAssignWorkers(Map<String, String?> assignments) async {
    for (final entry in assignments.entries) {
      final workerId = entry.key;
      final areaId = entry.value;
      String? areaName;
      if (areaId != null) {
        final found = _workAreas.firstWhere((a) => a.workareaId == areaId, orElse: () => _workAreas.first);
        areaName = found.name;
      }
      await assignWorkerToArea(workerId: workerId, areaId: areaId, areaName: areaName);
    }
  }

  // Attendance & Location Tracking (UC-08)
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

  @override
  Future<List<LocationTrackingModel>> getLocationBreadcrumbs({String? userId, String? areaId}) async {
    var list = _locationTracking;
    if (userId != null && userId.isNotEmpty) {
      list = list.where((b) => b.userId == userId).toList();
    }
    return List.unmodifiable(list);
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

  // Leaves (UC-03 & UC-13)
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

  @override
  Future<void> endorseLeaveRequest(
    String leaveId, {
    required String supervisorId,
    required String supervisorName,
    required String comments,
  }) async {
    final idx = _leaveRequests.indexWhere((l) => l.leaveId == leaveId);
    if (idx != -1) {
      final current = _leaveRequests[idx];
      _leaveRequests[idx] = current.copyWith(
        supervisorEndorsement: comments,
        endorsedBy: supervisorName,
        endorsedAt: DateTime.now(),
      );
    }
  }

  // Alerts (UC-09)
  @override
  Future<List<AlertModel>> getAlerts({String? areaId, String? category}) async {
    var list = _alerts;
    if (areaId != null && areaId.isNotEmpty) {
      list = list.where((a) => a.workareaId == areaId).toList();
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      list = list.where((a) => a.srsCategory == category).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(
        isResolved: true,
        resolvedAt: DateTime.now(),
        responseAction: 'acknowledged',
      );
    }
  }

  @override
  Future<void> sendWarningForAlert({
    required String alertId,
    required String workerId,
    required String message,
    String? supervisorId,
  }) async {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx != -1) {
      final current = _alerts[idx];
      _alerts[idx] = current.copyWith(
        isResolved: true,
        resolvedAt: DateTime.now(),
        responseAction: 'warning_sent',
        responseNote: message,
      );

      // UC-09 Main Flow Step 5: Send warning notification to the worker and Supervisor
      final targetName = current.workerName ?? 'Worker';
      _broadcasts.insert(
        0,
        BroadcastModel(
          notificationId: 'warn-${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'user-admin-1',
          recipients: '$targetName & Supervisor ${current.supervisorName ?? "In-charge"}',
          subject: 'Official Warning: ${current.title}',
          message: message,
          isConfidential: true,
          deliveredCount: 2,
          sentAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> dismissAlert({
    required String alertId,
    required String adminId,
    String? reason,
  }) async {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(
        isResolved: true,
        resolvedAt: DateTime.now(),
        resolvedBy: adminId,
        responseAction: 'dismissed',
        responseNote: reason ?? 'Dismissed without punitive action (Logged for audit).',
      );
    }
  }

  // Broadcasts & Supervisor Report Transmittal (UC-06 & UC-12)
  @override
  Future<List<BroadcastModel>> getBroadcasts() async {
    return List.unmodifiable(_broadcasts);
  }

  @override
  Future<void> addBroadcast(BroadcastModel broadcast) async {
    _broadcasts.insert(0, broadcast);
  }

  @override
  Future<void> sendReportToAdmin({
    required String reportType,
    required String summary,
    String? note,
    required String supervisorId,
    required String supervisorName,
  }) async {
    final memo = BroadcastModel(
      notificationId: 'rpt-admin-${DateTime.now().millisecondsSinceEpoch}',
      senderId: supervisorId,
      recipients: 'City Administration',
      subject: 'Field Supervisor Report Transmittal: $reportType',
      message: 'Supervisor $supervisorName submitted official report audit.\nSummary: $summary${(note != null && note.isNotEmpty) ? '\nTransmittal Note: $note' : ''}',
      isConfidential: false,
      deliveredCount: 1,
      sentAt: DateTime.now(),
    );
    _broadcasts.insert(0, memo);
  }

  // Incidents (UC-11)
  @override
  Future<List<IncidentReportModel>> getIncidents({
    String? reporterId,
    String? workareaId,
    String? status,
  }) async {
    var list = _incidents;
    if (reporterId != null && reporterId.isNotEmpty) {
      list = list.where((i) => i.reporterId == reporterId).toList();
    }
    if (workareaId != null && workareaId.isNotEmpty && workareaId != 'all') {
      list = list.where((i) => i.workareaId == workareaId).toList();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      list = list.where((i) => i.status == status).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> addIncident(IncidentReportModel incident) async {
    _incidents.insert(0, incident);
  }

  @override
  Future<void> resolveIncident(String reportId) async {
    final idx = _incidents.indexWhere((i) => i.reportId == reportId);
    if (idx != -1) {
      _incidents[idx] = _incidents[idx].copyWith(status: 'resolved', resolvedAt: DateTime.now());
    }
  }

  @override
  Future<void> settleIncidentLocally(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {
    final idx = _incidents.indexWhere((i) => i.reportId == reportId);
    if (idx != -1) {
      _incidents[idx] = _incidents[idx].copyWith(
        status: 'settled_locally',
        settledBy: supervisorName,
        settledAt: DateTime.now(),
        supervisorNotes: notes,
      );
    }
  }

  @override
  Future<void> escalateIncidentToAdmin(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {
    final idx = _incidents.indexWhere((i) => i.reportId == reportId);
    if (idx != -1) {
      final current = _incidents[idx];
      _incidents[idx] = current.copyWith(
        status: 'escalated_to_admin',
        isEscalated: true,
        supervisorNotes: notes,
      );

      // Notify Admin
      _broadcasts.insert(
        0,
        BroadcastModel(
          notificationId: 'esc-${DateTime.now().millisecondsSinceEpoch}',
          senderId: supervisorId,
          recipients: 'Central Admin',
          subject: 'Escalated Worker Issue: ${current.reportedName} (${current.issueType})',
          message: 'Supervisor $supervisorName escalated field incident for worker ${current.reportedName}.\nSupervisor Remarks: $notes\nOriginal Description: ${current.description}',
          isConfidential: true,
          deliveredCount: 1,
          sentAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> resolveIncidentByAdmin(
    String reportId, {
    required String adminId,
    required String resolutionNotes,
  }) async {
    final idx = _incidents.indexWhere((i) => i.reportId == reportId);
    if (idx != -1) {
      _incidents[idx] = _incidents[idx].copyWith(
        status: 'resolved',
        resolvedAt: DateTime.now(),
        adminResolutionNotes: resolutionNotes,
      );
    }
  }
}

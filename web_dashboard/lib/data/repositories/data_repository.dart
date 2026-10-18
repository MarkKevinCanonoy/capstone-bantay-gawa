import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';

abstract class DataRepository {
  // Work Areas
  Future<List<WorkAreaModel>> getWorkAreas({String? supervisorId});
  Future<void> addWorkArea(WorkAreaModel area);
  Future<void> updateWorkArea(WorkAreaModel area);
  Future<void> deleteWorkArea(String areaId);

  // Users / Employees & Worker Assignments (UC-07)
  Future<List<UserModel>> getUsers({String? areaId, UserRole? role});
  Future<void> addUser(UserModel user);
  Future<void> deleteUser(String userId);
  Future<void> assignWorkerToArea({
    required String workerId,
    required String? areaId,
    String? areaName,
  });
  Future<void> bulkAssignWorkers(Map<String, String?> assignments);

  // Attendance & Location Tracking (UC-08)
  Future<List<AttendanceModel>> getAttendanceLogs({String? areaId, String? workerId});
  Future<void> toggleAttendanceVerify(String attendanceId);
  Future<List<LocationTrackingModel>> getLocationBreadcrumbs({String? userId, String? areaId});

  // Accomplishments
  Future<List<AccomplishmentModel>> getAccomplishments({String? areaId});
  Future<void> updateAccomplishmentStatus(
    String accomplishmentId,
    String status, {
    String? rejectionReason,
    String? approvedBy,
    String? approvedByName,
  });

  // Leaves (UC-03 & UC-13)
  Future<List<LeaveRequestModel>> getLeaveRequests({String? areaId});
  Future<void> updateLeaveStatus(
    String leaveId,
    String status, {
    String? adminId,
    String? rejectionReason,
  });
  Future<void> endorseLeaveRequest(
    String leaveId, {
    required String supervisorId,
    required String supervisorName,
    required String comments,
  });

  // Alerts & Warnings (UC-06 & UC-09)
  Future<List<AlertModel>> getAlerts({String? areaId, String? category});
  Future<void> resolveAlert(String alertId);
  Future<void> sendWarningForAlert({
    required String alertId,
    required String workerId,
    required String message,
    String? supervisorId,
  });
  Future<void> dismissAlert({
    required String alertId,
    required String adminId,
    String? reason,
  });

  // Broadcasts & Supervisor Report Transmittal (UC-06 & UC-12)
  Future<List<BroadcastModel>> getBroadcasts();
  Future<void> addBroadcast(BroadcastModel broadcast);
  Future<void> sendReportToAdmin({
    required String reportType,
    required String summary,
    String? note,
    required String supervisorId,
    required String supervisorName,
  });

  // Incidents (UC-11)
  Future<List<IncidentReportModel>> getIncidents({String? reporterId, String? workareaId, String? status});
  Future<void> addIncident(IncidentReportModel incident);
  Future<void> resolveIncident(String reportId);
  Future<void> settleIncidentLocally(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  });
  Future<void> escalateIncidentToAdmin(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  });
  Future<void> resolveIncidentByAdmin(
    String reportId, {
    required String adminId,
    required String resolutionNotes,
  });
}

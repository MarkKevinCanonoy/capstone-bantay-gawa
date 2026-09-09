import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';

abstract class DataRepository {
  // Work Areas
  Future<List<WorkAreaModel>> getWorkAreas({String? supervisorId});
  Future<void> addWorkArea(WorkAreaModel area);
  Future<void> updateWorkArea(WorkAreaModel area);
  Future<void> deleteWorkArea(String areaId);

  // Users / Employees
  Future<List<UserModel>> getUsers({String? areaId, UserRole? role});
  Future<void> addUser(UserModel user);
  Future<void> deleteUser(String userId);

  // Attendance
  Future<List<AttendanceModel>> getAttendanceLogs({String? areaId, String? workerId});
  Future<void> toggleAttendanceVerify(String attendanceId);

  // Accomplishments
  Future<List<AccomplishmentModel>> getAccomplishments({String? areaId});
  Future<void> updateAccomplishmentStatus(
    String accomplishmentId,
    String status, {
    String? rejectionReason,
    String? approvedBy,
    String? approvedByName,
  });

  // Leaves
  Future<List<LeaveRequestModel>> getLeaveRequests({String? areaId});
  Future<void> updateLeaveStatus(
    String leaveId,
    String status, {
    String? adminId,
    String? rejectionReason,
  });

  // Alerts
  Future<List<AlertModel>> getAlerts({String? areaId});
  Future<void> resolveAlert(String alertId);

  // Broadcasts
  Future<List<BroadcastModel>> getBroadcasts();
  Future<void> addBroadcast(BroadcastModel broadcast);

  // Incidents
  Future<List<IncidentReportModel>> getIncidents({String? reporterId});
  Future<void> addIncident(IncidentReportModel incident);
  Future<void> resolveIncident(String reportId);
}

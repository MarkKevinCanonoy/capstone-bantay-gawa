import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/credit_history_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';

abstract class MobileRepository {
  Future<UserModel?> getLoggedInUser();
  Future<UserModel?> authenticateWithFace(List<double> capturedFaceEmbedding);
  Future<void> logout();

  Future<List<WorkAreaModel>> getAssignedWorkAreas(String userId);
  Future<List<WorkAreaModel>> getAllWorkAreas();

  Future<List<AttendanceModel>> getAttendanceHistory(String userId);
  Future<void> recordAttendance(AttendanceModel attendance);

  Future<List<AccomplishmentModel>> getAccomplishments(String userId);
  Future<bool> submitAccomplishment(AccomplishmentModel accomplishment);

  Future<List<LeaveRequestModel>> getLeaveRequests(String userId);
  Future<void> submitLeaveRequest(LeaveRequestModel leave);

  Future<List<CreditHistoryModel>> getCreditHistory(String userId);

  Future<List<BroadcastModel>> getNotifications(String userId);
  Future<void> markNotificationAsRead(String notificationId);

  Future<List<UserModel>> getPeerWorkers(String workareaId);
  Future<List<IncidentReportModel>> getIncidentReports(String userId);
  Future<void> submitIncidentReport(IncidentReportModel report);

  Future<int> getUnsyncedCount();
  Future<void> syncOfflineData();

  Future<bool> registerFaceEmbedding(String userId, String faceEmbedding);
}


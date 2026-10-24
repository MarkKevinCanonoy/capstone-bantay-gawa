import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';

abstract class MobileRepository {
  Future<UserModel?> getLoggedInUser();
  Future<UserModel?> authenticateWithFace(List<double> capturedFaceEmbedding);
  Future<void> logout();

  Future<List<WorkAreaModel>> getAssignedWorkAreas(String userId);

  Future<List<AttendanceModel>> getAttendanceHistory(String userId);
  Future<void> recordAttendance(AttendanceModel attendance);

  Future<List<AccomplishmentModel>> getAccomplishments(String userId);
  Future<void> submitAccomplishment(AccomplishmentModel accomplishment);

  Future<List<LeaveRequestModel>> getLeaveRequests(String userId);
  Future<void> submitLeaveRequest(LeaveRequestModel leave);

  Future<int> getUnsyncedCount();
  Future<void> syncOfflineData();
}

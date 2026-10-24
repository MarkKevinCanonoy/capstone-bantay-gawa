import 'package:latlong2/latlong.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';

class MockData {
  MockData._();

  // Mock 128-d face embedding for worker Juan Dela Cruz
  static final String sampleFaceEmbedding = List.generate(128, (index) => (0.05 * (index % 10))).join(',');

  static final UserModel defaultWorker = UserModel(
    userId: 'usr-wkr-001',
    username: 'jdelacruz',
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    contactNumber: '+63 917 123 4567',
    roleId: 'role-wkr-001',
    roleName: 'Field Worker',
    faceEmbedding: sampleFaceEmbedding,
    performanceScore: 88,
    status: 'active',
    isActive: true,
  );

  static final List<WorkAreaModel> sampleWorkAreas = [
    WorkAreaModel(
      workareaId: 'area-sec-004',
      name: 'Sector 4 - Downtown Zone',
      description: 'Downtown commercial corridor, Rizal St. to City Hall',
      supervisorId: 'usr-sup-001',
      supervisorName: 'Engr. Roberto Gomez',
      polygonCoordinates: const [
        LatLng(11.0085, 124.6035),
        LatLng(11.0085, 124.6115),
        LatLng(11.0015, 124.6115),
        LatLng(11.0015, 124.6035),
      ],
      assignedCount: 14,
      status: 'Active',
      areaSqKm: '1.4 km²',
    ),
    WorkAreaModel(
      workareaId: 'area-sec-001',
      name: 'Sector 1 - Port & Coastal Park',
      description: 'Ormoc Port area and coastal reclamation boardwalk',
      supervisorId: 'usr-sup-001',
      supervisorName: 'Engr. Roberto Gomez',
      polygonCoordinates: const [
        LatLng(11.0040, 124.5980),
        LatLng(11.0040, 124.6040),
        LatLng(10.9980, 124.6040),
        LatLng(10.9980, 124.5980),
      ],
      assignedCount: 8,
      status: 'Active',
      areaSqKm: '0.9 km²',
    ),
  ];

  static final List<AttendanceModel> initialAttendanceLogs = [
    AttendanceModel(
      attendanceId: 'att-log-001',
      userId: 'usr-wkr-001',
      workerName: 'Juan Dela Cruz',
      workareaId: 'area-sec-004',
      areaName: 'Sector 4 - Downtown Zone',
      actionType: 'time-in',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      gpsLat: 11.0050,
      gpsLng: 124.6075,
      faceMatch: true,
      isSynced: true,
      timeIn: '07:00 AM',
    ),
  ];

  static final List<AccomplishmentModel> initialAccomplishments = [
    AccomplishmentModel(
      accomplishmentId: 'acc-rep-001',
      userId: 'usr-wkr-001',
      workerName: 'Juan Dela Cruz',
      workareaId: 'area-sec-004',
      areaName: 'Sector 4 - Downtown Zone',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?w=600',
      capturedDate: DateTime.now().subtract(const Duration(days: 1)),
      capturedTime: '02:30 PM',
      capturedLat: 11.0051,
      capturedLng: 124.6072,
      message: 'Completed canal declogging along Bonifacio St. 15 sacks of debris removed.',
      status: 'approved',
      approvedByName: 'Engr. Roberto Gomez',
      isSynced: true,
    ),
  ];

  static final List<LeaveRequestModel> initialLeaveRequests = [
    LeaveRequestModel(
      leaveId: 'lev-req-001',
      userId: 'usr-wkr-001',
      workerName: 'Juan Dela Cruz',
      workareaId: 'area-sec-004',
      areaName: 'Sector 4 - Downtown Zone',
      type: 'Sick Leave',
      startDate: DateTime.now().subtract(const Duration(days: 14)),
      endDate: DateTime.now().subtract(const Duration(days: 13)),
      reason: 'Flu and severe cough (medical certificate submitted).',
      status: 'approved',
      adminDecision: 'Approved by ENRO Head',
      isSynced: true,
    ),
  ];
}

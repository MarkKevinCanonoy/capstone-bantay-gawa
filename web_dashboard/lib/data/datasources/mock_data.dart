import 'package:latlong2/latlong.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';

class MockData {
  MockData._();

  static final List<WorkAreaModel> workAreas = [
    WorkAreaModel(
      workareaId: '4b106dc7-8a37-42cf-af39-b80b55cc156f',
      name: 'Ormoc Plaza',
      description: 'Ormoc City Plaza public park and administrative perimeter.',
      supervisorId: null,
      supervisorName: 'Unassigned',
      assignedCount: 0,
      status: 'Active',
      areaSqKm: '1.20 km²',
      polygon: const [
        LatLng(11.0050, 124.6060),
        LatLng(11.0070, 124.6060),
        LatLng(11.0070, 124.6090),
        LatLng(11.0050, 124.6090),
      ],
    ),
  ];

  static final List<UserModel> users = [
    UserModel(
      userId: '11111111-1111-1111-1111-111111111111',
      username: 'markkevin.canonoy@evsu.edu.ph',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      contactNumber: '+63 917 555 0199',
      role: UserRole.admin,
      status: 'active',
      schedule: 'Mon-Fri 08:00 - 17:00',
    ),
    UserModel(
      userId: '11111111-1111-1111-1111-111111111112',
      username: 'markkevincanonoy99@gmail.com',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      contactNumber: '+63 917 555 0199',
      role: UserRole.admin,
      status: 'active',
      schedule: 'Mon-Fri 08:00 - 17:00',
    ),
  ];

  static final List<AttendanceModel> attendanceLogs = [];
  static final List<AccomplishmentModel> accomplishments = [];
  static final List<LeaveRequestModel> leaveRequests = [];
  static final List<AlertModel> alerts = [];
  static final List<LocationTrackingModel> locationTracking = [
    // 1-minute tracking pings for worker moving towards breach location
    LocationTrackingModel(
      locationId: 'loc-track-1',
      userId: 'user-w-1',
      gpsLat: 11.0050,
      gpsLng: 124.6062,
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
      isInsideGeofence: true,
    ),
    LocationTrackingModel(
      locationId: 'loc-track-2',
      userId: 'user-w-1',
      gpsLat: 11.0055,
      gpsLng: 124.6064,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isInsideGeofence: true,
    ),
    LocationTrackingModel(
      locationId: 'loc-track-3',
      userId: 'user-w-1',
      gpsLat: 11.0062,
      gpsLng: 124.6066,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      isInsideGeofence: true,
    ),
    LocationTrackingModel(
      locationId: 'loc-track-4',
      userId: 'user-w-1',
      gpsLat: 11.0069,
      gpsLng: 124.6068,
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      isInsideGeofence: true,
    ),
    LocationTrackingModel(
      locationId: 'loc-track-5',
      userId: 'user-w-1',
      gpsLat: 11.0075,
      gpsLng: 124.6069,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      isInsideGeofence: false,
    ),
    LocationTrackingModel(
      locationId: 'loc-track-6',
      userId: 'user-w-1',
      gpsLat: 11.0080,
      gpsLng: 124.6070,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      isInsideGeofence: false,
      isLastSeen: true,
    ),
  ];
  static final List<BroadcastModel> broadcasts = [];
  static final List<IncidentReportModel> incidents = [];
}

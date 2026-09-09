import 'package:latlong2/latlong.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'BantayGawaMobile';
  static const String officeName = 'ENRO Ormoc City';

  // Geographic Defaults for Ormoc City
  static const LatLng ormocCityCenter = LatLng(11.0050, 124.6075);
  static const double defaultMapZoom = 14.0;

  // Roles
  static const String roleAdmin = 'Admin';
  static const String roleSupervisor = 'Field Supervisor';
  static const String roleWorker = 'Field Worker';

  // Navigation Keys
  static const String navDashboard = 'dashboard';
  static const String navEmployees = 'employees';
  static const String navWorkAreas = 'work-areas';
  static const String navAttendance = 'attendance';
  static const String navAccomplishments = 'accomplishments';
  static const String navLeaves = 'leaves';
  static const String navIncidents = 'incidents';
  static const String navReports = 'reports';
  static const String navNotifications = 'notifications';
  static const String navProfile = 'profile';
}

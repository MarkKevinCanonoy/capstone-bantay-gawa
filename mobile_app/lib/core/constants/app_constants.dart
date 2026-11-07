import 'package:latlong2/latlong.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'BantayGawa';
  static const String officeName = 'ENRO Ormoc City';

  // Geographic Defaults for Ormoc City City Hall & ENRO
  static const LatLng ormocCityCenter = LatLng(11.0050, 124.6075);
  static const double defaultMapZoom = 15.0;

  // Roles
  static const String roleWorker = 'Field Worker';
  static const String roleSupervisor = 'Field Supervisor';
  static const String roleAdmin = 'Admin';

  // Privacy Location Tracking Interval: exactly 1 minute
  static const Duration locationTrackingInterval = Duration(minutes: 1);

  // Performance Credit Score Tiers (SRS Section 3.18)
  static const int creditScoreGoodThreshold = 80;    // 80 - 100: Green (Good)
  static const int creditScoreWarningThreshold = 50; // 50 - 79: Yellow (Warning)
  // 0 - 49: Red (Critical)

  // Supabase Configuration
  static const String supabaseUrl = 'https://tltqottawkrpidnijdqo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRsdHFvdHRhd2tycGlkbmlqZHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2Nzc4NzYsImV4cCI6MjEwODI1Mzg3Nn0.wAkPP2s1CPQ19pBvGZ4BoAdJaQn3K7e0yUDUnSO0OW4';

  // Database Role UUIDs
  static const String roleAdminId = '00000000-0000-0000-0000-000000000001';
  static const String roleSupervisorId = '00000000-0000-0000-0000-000000000002';
  static const String roleWorkerId = '00000000-0000-0000-0000-000000000003';

  // Storage Buckets
  static const String bucketAccomplishments = 'accomplishments';
  static const String bucketAttendance = 'attendance';
}

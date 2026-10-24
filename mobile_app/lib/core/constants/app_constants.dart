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
  static const String supabaseUrl = 'https://bantaygawa.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_anon_key';

  // Storage Buckets
  static const String bucketAccomplishments = 'accomplishments';
  static const String bucketAttendance = 'attendance';
}

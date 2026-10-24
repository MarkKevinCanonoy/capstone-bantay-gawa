import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/geofence_helper.dart';
import '../datasources/local_database.dart';
import '../models/location_tracking_model.dart';
import '../models/work_area_model.dart';

class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._init();
  LocationTrackingService._init();

  Timer? _timer;
  bool _isTracking = false;
  WorkAreaModel? _assignedArea;
  String? _userId;

  // Real-time observable state
  final ValueNotifier<bool> isInsideGeofenceNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hasGeofenceBreachNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> breachStartTimeNotifier = ValueNotifier<DateTime?>(null);
  final ValueNotifier<LatLng?> currentPositionNotifier = ValueNotifier<LatLng?>(null);

  bool get isTracking => _isTracking;

  void startTracking({
    required String userId,
    required WorkAreaModel assignedArea,
  }) {
    if (_isTracking) return;
    _userId = userId;
    _assignedArea = assignedArea;
    _isTracking = true;

    // Run first check immediately
    _performLocationCheck();

    // Periodic check every 1 minute
    _timer = Timer.periodic(AppConstants.locationTrackingInterval, (_) {
      _performLocationCheck();
    });

    debugPrint('Location tracking started (Interval: 1 min). Privacy rule active.');
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
    hasGeofenceBreachNotifier.value = false;
    breachStartTimeNotifier.value = null;
    debugPrint('Location tracking stopped.');
  }

  Future<void> _performLocationCheck() async {
    if (!_isTracking || _assignedArea == null || _userId == null) return;

    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final currentPoint = LatLng(position.latitude, position.longitude);
      currentPositionNotifier.value = currentPoint;

      final isInside = GeofenceHelper.isPointInPolygon(
        currentPoint,
        _assignedArea!.polygonCoordinates,
      );

      isInsideGeofenceNotifier.value = isInside;

      if (isInside) {
        // WORKER IS INSIDE ASSIGNED GEOFENCE:
        // 1. Clear any active breach warning
        hasGeofenceBreachNotifier.value = false;
        breachStartTimeNotifier.value = null;

        // 2. Record coordinate point to database
        final trackingModel = LocationTrackingModel(
          locationId: 'loc-${DateTime.now().millisecondsSinceEpoch}',
          userId: _userId!,
          gpsLat: currentPoint.latitude,
          gpsLng: currentPoint.longitude,
          timestamp: DateTime.now(),
        );

        await LocalDatabase.instance.insertLocationTracking(trackingModel);
        debugPrint('Location recorded [INSIDE GEOFENCE]: ${currentPoint.latitude}, ${currentPoint.longitude}');
      } else {
        // WORKER IS OUTSIDE GEOFENCE:
        // The app DOES KNOW they are outside, but DOES NOT record exact GPS coordinates for privacy!
        if (!hasGeofenceBreachNotifier.value) {
          hasGeofenceBreachNotifier.value = true;
          breachStartTimeNotifier.value = DateTime.now();
        }

        debugPrint('⚠️ BREACH DETECTED: Worker is OUTSIDE geofence boundary.');
        debugPrint('🔒 PRIVACY RULE: Exact coordinates are NOT recorded while outside.');
      }
    } catch (e) {
      debugPrint('Error during periodic location check: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }
}

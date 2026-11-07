import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/geofence_helper.dart';
import '../../core/utils/location_helper.dart';
import '../../core/utils/uuid_helper.dart';
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
  final ValueNotifier<bool> isInsideGeofenceNotifier = ValueNotifier<bool>(false);
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

  /// Evaluates current position against assigned work area and updates notifiers.
  /// Used across Home, Attendance, and Map tabs to guarantee 100% geofence consistency.
  Future<bool> evaluateCurrentLocation({
    WorkAreaModel? assignedArea,
    String? userId,
  }) async {
    if (assignedArea != null) _assignedArea = assignedArea;
    if (userId != null && userId.isNotEmpty) _userId = userId;

    try {
      final currentPoint = await LocationHelper.getCurrentLocation();
      currentPositionNotifier.value = currentPoint;

      bool isInside = false;
      if (_assignedArea != null && _assignedArea!.polygonCoordinates.isNotEmpty) {
        isInside = GeofenceHelper.isPointInPolygon(
          currentPoint,
          _assignedArea!.polygonCoordinates,
        );
      }

      isInsideGeofenceNotifier.value = isInside;

      if (_isTracking) {
        await _processLocationEvaluation(currentPoint, isInside);
      }

      return isInside;
    } catch (e) {
      debugPrint('Error evaluating location: $e');
      return isInsideGeofenceNotifier.value;
    }
  }

  /// Manually simulates a location for developer/demonstration testing
  Future<void> simulateLocation(
    LatLng point, {
    String? userId,
    WorkAreaModel? assignedArea,
  }) async {
    if (userId != null && userId.isNotEmpty) _userId = userId;
    if (assignedArea != null) _assignedArea = assignedArea;
    currentPositionNotifier.value = point;
    if (_assignedArea == null) return;
    final isInside = GeofenceHelper.isPointInPolygon(
      point,
      _assignedArea!.polygonCoordinates,
    );
    await _processLocationEvaluation(point, isInside);
  }

  void clearSimulation() {
    currentPositionNotifier.value = null;
    hasGeofenceBreachNotifier.value = false;
    breachStartTimeNotifier.value = null;
    isInsideGeofenceNotifier.value = false;
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

      await _processLocationEvaluation(currentPoint, isInside);
    } catch (e) {
      debugPrint('Error during periodic location check: $e');
    }
  }

  Future<void> _processLocationEvaluation(LatLng currentPoint, bool isInside) async {
    isInsideGeofenceNotifier.value = isInside;

    if (isInside) {
      // WORKER IS INSIDE ASSIGNED GEOFENCE:
      // 1. Clear any active breach warning
      hasGeofenceBreachNotifier.value = false;
      breachStartTimeNotifier.value = null;

      // 2. Record coordinate point to database
      final trackingModel = LocationTrackingModel(
        locationId: UuidHelper.generate(),
        userId: _userId ?? '',
        gpsLat: currentPoint.latitude,
        gpsLng: currentPoint.longitude,
        timestamp: DateTime.now(),
        isLastSeen: true,
        isInsideGeofence: true,
        isSynced: false,
      );

      await LocalDatabase.instance.insertLocationTracking(trackingModel);
      debugPrint('Location recorded [INSIDE GEOFENCE]: ${currentPoint.latitude}, ${currentPoint.longitude}');

      // 3. Sync to Supabase location_tracking if online
      try {
        await Supabase.instance.client.from('location_tracking').insert(trackingModel.toSupabaseJson());
        await LocalDatabase.instance.markLocationTrackingSynced(trackingModel.locationId);
        debugPrint('Location synced immediately to Supabase.');
      } catch (e) {
        debugPrint('Supabase location_tracking upload fallback (offline queue preserved): $e');
      }
    } else {
      // WORKER IS OUTSIDE GEOFENCE:
      // The app DOES KNOW they are outside, but DOES NOT record exact GPS coordinates for privacy!
      if (!hasGeofenceBreachNotifier.value) {
        hasGeofenceBreachNotifier.value = true;
        breachStartTimeNotifier.value = DateTime.now();

        // Push real breach alert to Supabase alerts table so Web Dashboard receives it immediately
        try {
          if (_userId != null && _userId!.isNotEmpty) {
            await Supabase.instance.client.from('alerts').insert({
              'alert_id': UuidHelper.generate(),
              'user_id': _userId!,
              'type': 'breach',
              'message': 'Geofence Breach: Worker has moved outside assigned work area (${_assignedArea?.name ?? "Assigned Area"}).',
              'created_at': DateTime.now().toIso8601String(),
            });
            debugPrint('⚠️ BREACH ALERT uploaded to Supabase alerts table.');
          }
        } catch (e) {
          debugPrint('Supabase breach alert insert fallback: $e');
        }
      }

      debugPrint('⚠️ BREACH DETECTED: Worker is OUTSIDE geofence boundary.');
      debugPrint('🔒 PRIVACY RULE: Exact coordinates are NOT recorded while outside.');
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

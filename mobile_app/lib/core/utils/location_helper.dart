import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';

class LocationHelper {
  LocationHelper._();

  /// Gets the real device GPS position with full permission handling and fallback
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied or denied forever: $permission');
        return AppConstants.ormocCityCenter;
      }

      // Try quick last known position first
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Fetch fresh position with high accuracy (GPS satellites) and sensible timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return LatLng(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('High accuracy GPS acquisition timeout/error: $e. Trying medium accuracy.');
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
          return LatLng(position.latitude, position.longitude);
        } catch (_) {}
      }

      if (lastKnown != null) {
        debugPrint('Using last known GPS position as fallback: (${lastKnown.latitude}, ${lastKnown.longitude})');
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
    } catch (e) {
      debugPrint('LocationHelper general exception: $e');
    }

    return AppConstants.ormocCityCenter;
  }
}

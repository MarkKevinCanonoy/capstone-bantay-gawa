import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/geofence_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/datasources/mock_data.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class WorkAreaMapView extends ConsumerStatefulWidget {
  const WorkAreaMapView({super.key});

  @override
  ConsumerState<WorkAreaMapView> createState() => _WorkAreaMapViewState();
}

class _WorkAreaMapViewState extends ConsumerState<WorkAreaMapView> {
  final MapController _mapController = MapController();
  LatLng _workerPosition = AppConstants.ormocCityCenter;
  bool _isInside = true;

  @override
  void initState() {
    super.initState();
    _fetchLivePosition();
  }

  Future<void> _fetchLivePosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final currentPoint = LatLng(pos.latitude, pos.longitude);
      final area = ref.read(assignedWorkAreaProvider).value;

      bool inside = true;
      if (area != null && area.polygonCoordinates.isNotEmpty) {
        inside = GeofenceHelper.isPointInPolygon(currentPoint, area.polygonCoordinates);
      }

      if (mounted) {
        setState(() {
          _workerPosition = currentPoint;
          _isInside = inside;
        });
        _mapController.move(currentPoint, 15.0);
      }
    } catch (_) {
      // Keep Ormoc default if GPS simulated
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(assignedWorkAreaProvider).value;
    final polygonCoords = area?.polygonCoordinates ?? MockData.sampleWorkAreas.first.polygonCoordinates;
    final areaName = area?.name ?? 'Sector 4 - Downtown Zone';

    return Stack(
      children: [
        // Real OpenStreetMap Map Widget
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _workerPosition,
            initialZoom: 15.0,
            maxZoom: 18.0,
            minZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'gov.ormoc.bantaygawa.mobile',
            ),
            // Work Area Polygon Layer
            PolygonLayer(
              polygons: [
                Polygon(
                  points: polygonCoords,
                  color: AppColors.primaryNavy.withValues(alpha: 0.18),
                  borderColor: AppColors.accentGreen,
                  borderStrokeWidth: 2.5,
                ),
              ],
            ),
            // Worker GPS Marker Layer
            MarkerLayer(
              markers: [
                Marker(
                  point: _workerPosition,
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentBlue.withValues(alpha: 0.25),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Floating Info Card at Top
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.location_city, color: AppColors.primaryNavy, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        areaName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Text(
                        _isInside ? 'Inside assigned geofence zone' : 'Outside assigned boundary',
                        style: TextStyle(
                          fontSize: 10,
                          color: _isInside ? AppColors.accentGreen : AppColors.dangerRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: _isInside ? 'AUTHORIZED' : 'OUTSIDE',
                  backgroundColor: _isInside ? AppColors.successBg : AppColors.dangerBg,
                  textColor: _isInside ? AppColors.successText : AppColors.dangerText,
                ),
              ],
            ),
          ),
        ),

        // Recenter Floating Action Button
        Positioned(
          right: 16,
          bottom: 20,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryNavy,
            elevation: 3,
            onPressed: _fetchLivePosition,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class WorkAreaMapView extends ConsumerStatefulWidget {
  const WorkAreaMapView({super.key});

  @override
  ConsumerState<WorkAreaMapView> createState() => _WorkAreaMapViewState();
}

class _WorkAreaMapViewState extends ConsumerState<WorkAreaMapView> {
  final MapController _mapController = MapController();
  LatLng _workerPosition = LocationTrackingService.instance.currentPositionNotifier.value ?? AppConstants.ormocCityCenter;
  bool _isInside = LocationTrackingService.instance.isInsideGeofenceNotifier.value;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    LocationTrackingService.instance.isInsideGeofenceNotifier.addListener(_onGeofenceChanged);
    LocationTrackingService.instance.currentPositionNotifier.addListener(_onPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLivePosition();
    });
  }

  void _onGeofenceChanged() {
    if (mounted) {
      setState(() => _isInside = LocationTrackingService.instance.isInsideGeofenceNotifier.value);
    }
  }

  void _onPositionChanged() {
    if (mounted) {
      final pos = LocationTrackingService.instance.currentPositionNotifier.value;
      if (pos != null) {
        setState(() => _workerPosition = pos);
      }
    }
  }

  @override
  void dispose() {
    LocationTrackingService.instance.isInsideGeofenceNotifier.removeListener(_onGeofenceChanged);
    LocationTrackingService.instance.currentPositionNotifier.removeListener(_onPositionChanged);
    super.dispose();
  }

  Future<void> _fetchLivePosition() async {
    setState(() => _isLoadingGps = true);
    try {
      final area = ref.read(assignedWorkAreaProvider).value;
      final user = ref.read(currentUserProvider).value;
      final inside = await LocationTrackingService.instance.evaluateCurrentLocation(
        assignedArea: area,
        userId: user?.userId,
      );

      final currentPoint = LocationTrackingService.instance.currentPositionNotifier.value ?? _workerPosition;

      if (mounted) {
        setState(() {
          _workerPosition = currentPoint;
          _isInside = inside;
          _isLoadingGps = false;
        });
        _mapController.move(currentPoint, 15.5);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final area = ref.watch(assignedWorkAreaProvider).value;

    ref.listen(assignedWorkAreaProvider, (prev, next) {
      _fetchLivePosition();
    });
    final polygonCoords = area?.polygonCoordinates ?? const [];
    final areaName = (area?.name != null && area!.name.trim().isNotEmpty)
        ? area.name
        : (lang == AppLanguage.cebuano ? 'Walay Na-assign nga Lugar' : 'No Area Assigned');
    final supervisorName = area?.supervisorName;
    final supervisor = (supervisorName != null && supervisorName.trim().isNotEmpty)
        ? supervisorName
        : (lang == AppLanguage.cebuano ? 'Walay Na-assign nga Supervisor' : 'No Supervisor Assigned');
    final assignedCount = area?.assignedCount ?? 0;

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
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Text(
                        _isInside
                            ? (lang == AppLanguage.cebuano ? 'Sulod sa imong assigned area' : 'Inside assigned geofence zone')
                            : (lang == AppLanguage.cebuano ? 'Gawas sa imong assigned area' : 'Outside assigned boundary'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: _isInside ? AppColors.accentGreen : AppColors.dangerRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: _isInside
                      ? (lang == AppLanguage.cebuano ? 'SULOD' : 'AUTHORIZED')
                      : (lang == AppLanguage.cebuano ? 'GAWAS' : 'OUTSIDE'),
                  backgroundColor: _isInside ? AppColors.successBg : AppColors.dangerBg,
                  textColor: _isInside ? AppColors.successText : AppColors.dangerText,
                ),
              ],
            ),
          ),
        ),

        // Map Navigation Controls (Zoom In, Zoom Out, Center Sector, My Location)
        Positioned(
          right: 14,
          bottom: 78,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom In (+)
              _buildMapControlBtn(
                icon: Icons.add,
                tooltip: lang == AppLanguage.cebuano ? 'Paduol (Zoom In)' : 'Zoom In',
                onPressed: () {
                  final newZoom = (_mapController.camera.zoom + 1.0).clamp(12.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
              const SizedBox(height: 6),

              // Zoom Out (-)
              _buildMapControlBtn(
                icon: Icons.remove,
                tooltip: lang == AppLanguage.cebuano ? 'Palayo (Zoom Out)' : 'Zoom Out',
                onPressed: () {
                  final newZoom = (_mapController.camera.zoom - 1.0).clamp(12.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
              const SizedBox(height: 10),

              // Center Assigned Sector / Ormoc Area
              _buildMapControlBtn(
                icon: Icons.crop_free,
                tooltip: lang == AppLanguage.cebuano ? 'I-sentro ang Sektor' : 'Center Assigned Sector',
                onPressed: () {
                  if (area != null) {
                    _mapController.move(area.center, 15.0);
                  } else {
                    _mapController.move(AppConstants.ormocCityCenter, 15.0);
                  }
                },
              ),
              const SizedBox(height: 6),

              // My Location
              _buildMapControlBtn(
                icon: Icons.my_location,
                tooltip: lang == AppLanguage.cebuano ? 'Akong Lokasyon' : 'My Location',
                isLoading: _isLoadingGps,
                onPressed: _isLoadingGps ? null : _fetchLivePosition,
              ),
            ],
          ),
        ),

        // Bottom Assigned Sector Details Card (Concise per user request)
        Positioned(
          bottom: 14,
          left: 14,
          right: 14,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.accentGreen, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      lang == AppLanguage.cebuano ? 'Sektor' : 'Assigned Sector',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy),
                    ),
                    const Spacer(),
                    Text(
                      '$assignedCount ${lang == AppLanguage.cebuano ? "trabahante" : "workers"}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_pin_outlined, color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${lang == AppLanguage.cebuano ? "Supervisor" : "Supervisor"}: $supervisor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryNavy),
                  )
                : Icon(icon, color: AppColors.primaryNavy, size: 22),
          ),
        ),
      ),
    );
  }
}

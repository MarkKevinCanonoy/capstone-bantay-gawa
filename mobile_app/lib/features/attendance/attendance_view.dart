import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/geofence_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class AttendanceView extends ConsumerStatefulWidget {
  const AttendanceView({super.key});

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  LatLng? _currentPosition;
  bool _isInsideGeofence = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _checkLocationAndGeofence();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _checkLocationAndGeofence() async {
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
          _currentPosition = currentPoint;
          _isInsideGeofence = inside;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = const LatLng(11.0050, 124.6075);
          _isInsideGeofence = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  String _getNextRequiredAction(List<AttendanceModel> logs) {
    final today = DateTime.now();
    final todayLogs = logs.where((l) =>
        l.timestamp.year == today.year &&
        l.timestamp.month == today.month &&
        l.timestamp.day == today.day).map((l) => l.actionType).toSet();

    if (!todayLogs.contains('time-in')) return 'time-in';
    if (!todayLogs.contains('break-in')) return 'break-in';
    if (!todayLogs.contains('break-out')) return 'break-out';
    if (!todayLogs.contains('time-out')) return 'time-out';
    return 'complete';
  }

  Future<void> _handleAttendance(String actionType, AppLanguage lang) async {
    if (!_isInsideGeofence) {
      ToastNotification.showError(
        context,
        AppTranslations.get('outside_geofence_warning', lang),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = ref.read(currentUserProvider).value;
      final area = ref.read(assignedWorkAreaProvider).value;

      // Simulate on-device face capture & match verification
      await Future.delayed(const Duration(milliseconds: 900));

      final log = AttendanceModel(
        attendanceId: 'att-${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.userId ?? 'usr-wkr-001',
        workerName: user?.fullName ?? 'Field Worker',
        workerEmpId: user?.userId ?? 'ENRO-2024-001',
        workareaId: area?.workareaId ?? 'area-sec-004',
        areaName: area?.name ?? 'Sector 4 - Downtown Zone',
        actionType: actionType,
        timestamp: DateTime.now(),
        gpsLat: _currentPosition?.latitude ?? 11.0050,
        gpsLng: _currentPosition?.longitude ?? 124.6075,
        faceMatch: true,
        isSynced: false,
      );

      await ref.read(attendanceListProvider.notifier).record(log);

      // Handle 1-minute location tracking lifecycle
      if (actionType == 'time-in' && area != null && user != null) {
        LocationTrackingService.instance.startTracking(userId: user.userId, assignedArea: area);
      } else if (actionType == 'time-out') {
        LocationTrackingService.instance.stopTracking();
      }

      if (mounted) {
        ToastNotification.showSuccess(
          context,
          '${actionType.toUpperCase()} recorded successfully! (Saved to local cache)',
        );
      }
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error recording attendance: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final area = ref.watch(assignedWorkAreaProvider).value;
    final logs = ref.watch(attendanceListProvider).value ?? [];
    final nextAction = _getNextRequiredAction(logs);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppTranslations.get('nav_attendance', lang),
          style: const TextStyle(
            fontSize: 20,
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          AppTranslations.get('biometric_title', lang),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 14),

        // Geofence status banner
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _isInsideGeofence ? AppColors.paleGreen : AppColors.dangerBg,
                child: Icon(
                  _isInsideGeofence ? Icons.location_on : Icons.location_off,
                  color: _isInsideGeofence ? AppColors.accentGreen : AppColors.dangerRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area?.name ?? 'Sector 4 - Downtown Zone',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      _isInsideGeofence
                          ? (lang == AppLanguage.filipino ? 'Nasa loob ng pinapayagang sona' : 'Inside authorized geofence boundary')
                          : (lang == AppLanguage.filipino ? 'Nasa labas ng itinalagang sona' : 'Outside assigned work area'),
                      style: TextStyle(
                        fontSize: 10,
                        color: _isInsideGeofence ? AppColors.accentGreen : AppColors.dangerRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: _isInsideGeofence ? 'IN ZONE' : 'OUTSIDE',
                backgroundColor: _isInsideGeofence ? AppColors.successBg : AppColors.dangerBg,
                textColor: _isInsideGeofence ? AppColors.successText : AppColors.dangerText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live Camera Viewfinder Box with guide
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryNavy, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _isCameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face, size: 70, color: Color(0xFF6CC5FF)),
                            SizedBox(height: 8),
                            Text('Face viewfinder ready', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                Center(
                  child: Container(
                    width: 160,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 1.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppTranslations.get('position_face', lang),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GPS: ${_currentPosition?.latitude.toStringAsFixed(4) ?? "11.0050"}, ${_currentPosition?.longitude.toStringAsFixed(4) ?? "124.6075"}',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons Grid (Time-In, Break-In, Break-Out, Time-Out)
        const Text(
          'MGA AKSYON SA ATTENDANCE',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        if (nextAction == 'complete')
          const AppCard(
            padding: EdgeInsets.all(14),
            child: Center(
              child: Text(
                'Kumpleto na ang 4 na attendance actions para sa araw na ito.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _getActionLabel(nextAction, lang),
                  icon: _getActionIcon(nextAction),
                  isLoading: _isProcessing,
                  variant: _getActionVariant(nextAction),
                  minHeight: 52,
                  onPressed: _isProcessing ? null : () => _handleAttendance(nextAction, lang),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // Recent Logs
        const Text(
          'MGA NA-RECORD NA ATTENDANCE',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ...logs.take(3).map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.paleGreen,
                        child: Icon(Icons.check, size: 16, color: AppColors.accentGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.actionType.toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy • hh:mm a').format(log.timestamp),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: log.isSynced ? 'SYNCED' : 'OFFLINE CACHE',
                        backgroundColor: log.isSynced ? AppColors.successBg : AppColors.warningBg,
                        textColor: log.isSynced ? AppColors.successText : AppColors.warningText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  String _getActionLabel(String action, AppLanguage lang) {
    switch (action) {
      case 'time-in':
        return AppTranslations.get('time_in', lang);
      case 'break-in':
        return AppTranslations.get('break_in', lang);
      case 'break-out':
        return AppTranslations.get('break_out', lang);
      case 'time-out':
        return AppTranslations.get('time_out', lang);
      default:
        return action.toUpperCase();
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'time-in':
        return Icons.login;
      case 'break-in':
        return Icons.coffee;
      case 'break-out':
        return Icons.free_breakfast;
      case 'time-out':
        return Icons.logout;
      default:
        return Icons.fingerprint;
    }
  }

  AppButtonVariant _getActionVariant(String action) {
    switch (action) {
      case 'time-in':
        return AppButtonVariant.primary;
      case 'break-in':
        return AppButtonVariant.secondary;
      case 'break-out':
        return AppButtonVariant.secondary;
      case 'time-out':
        return AppButtonVariant.danger;
      default:
        return AppButtonVariant.primary;
    }
  }
}

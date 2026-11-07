import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/biometrics_helper.dart';
import '../../core/utils/image_watermark_helper.dart';
import '../../core/utils/schedule_helper.dart';
import '../../core/utils/uuid_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class AttendanceView extends ConsumerStatefulWidget {
  final bool isActive;
  const AttendanceView({super.key, this.isActive = true});

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView> {
  CameraController? _cameraController;
  CameraLensDirection _currentLens = CameraLensDirection.front;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  LatLng? _currentPosition = LocationTrackingService.instance.currentPositionNotifier.value;
  bool _isInsideGeofence = LocationTrackingService.instance.isInsideGeofenceNotifier.value;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initCamera();
    }
    LocationTrackingService.instance.isInsideGeofenceNotifier.addListener(_onGeofenceChanged);
    LocationTrackingService.instance.currentPositionNotifier.addListener(_onPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationAndGeofence();
    });
  }

  @override
  void didUpdateWidget(AttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initCamera();
        _checkLocationAndGeofence();
      } else {
        _disposeCamera();
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() => _isCameraReady = false);
    }
    await controller?.dispose();
  }

  void _onGeofenceChanged() {
    if (mounted) {
      setState(() {
        _isInsideGeofence = LocationTrackingService.instance.isInsideGeofenceNotifier.value;
      });
    }
  }

  void _onPositionChanged() {
    if (mounted) {
      setState(() {
        _currentPosition = LocationTrackingService.instance.currentPositionNotifier.value;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _currentLens,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_isProcessing) return;
    final nextLens = _currentLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    setState(() {
      _currentLens = nextLens;
      _isCameraReady = false;
    });
    await _cameraController?.dispose();
    await _initCamera();
  }

  Future<void> _checkLocationAndGeofence() async {
    final area = ref.read(assignedWorkAreaProvider).value;
    final user = ref.read(currentUserProvider).value;
    final inside = await LocationTrackingService.instance.evaluateCurrentLocation(
      assignedArea: area,
      userId: user?.userId,
    );

    if (mounted) {
      setState(() {
        _currentPosition = LocationTrackingService.instance.currentPositionNotifier.value;
        _isInsideGeofence = inside;
      });
    }
  }

  @override
  void dispose() {
    LocationTrackingService.instance.isInsideGeofenceNotifier.removeListener(_onGeofenceChanged);
    LocationTrackingService.instance.currentPositionNotifier.removeListener(_onPositionChanged);
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

    final user = ref.read(currentUserProvider).value;

    // Shift Schedule Enforcement: Verify worker is logging within scheduled shift window
    if (actionType == 'time-in' && user?.schedule != null && user!.schedule.isNotEmpty && user.schedule != 'Unassigned') {
      final shiftEval = ScheduleHelper.evaluateShift(schedule: user.schedule);
      final validation = ScheduleHelper.canTimeInNow(shiftEval);
      if (!validation.allowed) {
        final reason = validation.getReason(lang == AppLanguage.cebuano);
        ToastNotification.showWarning(context, reason);
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      final area = ref.read(assignedWorkAreaProvider).value;

      // 1. Capture live photo from camera
      Uint8List rawBytes;
      if (_isCameraReady && _cameraController != null) {
        final XFile photo = await _cameraController!.takePicture();
        rawBytes = await photo.readAsBytes();
      } else {
        rawBytes = Uint8List.fromList(List.generate(200 * 200 * 3, (i) => 100));
      }

      // 2. Strict Biometric Enrollment Check
      if (user?.faceEmbedding == null || user!.faceEmbedding!.trim().isEmpty) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final enrollNow = await _showNoFaceEnrolledDialog(context);
          if (enrollNow == true && mounted) {
            await _handleEnrollFaceNow(rawBytes);
          }
        }
        return;
      }

      // 3. Strict Biometric Matching against registered face_embedding
      final registeredVector = BiometricsHelper.parseEmbeddingString(user.faceEmbedding!);
      final capturedVector = BiometricsHelper.extractFeatureVector(rawBytes);
      final similarity = BiometricsHelper.cosineSimilarity(capturedVector, registeredVector);
      debugPrint('Attendance verification: similarity=$similarity (threshold=${BiometricsHelper.matchThreshold})');

      if (similarity < BiometricsHelper.matchThreshold) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final pct = (similarity * 100).clamp(0, 99).toInt();
          _showFaceMismatchDialog(context, pct);
        }
        return;
      }

      // 4. Burn watermark onto proof photo
      String? savedSelfiePath;
      String? cloudSelfieUrl;
      try {
        final watermarked = ImageWatermarkHelper.burnWatermark(
          rawImageBytes: rawBytes,
          latitude: _currentPosition?.latitude ?? 11.0050,
          longitude: _currentPosition?.longitude ?? 124.6075,
          workerName: user.fullName,
          workAreaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
          timestamp: DateTime.now(),
        );

        cloudSelfieUrl = 'data:image/jpeg;base64,${base64Encode(watermarked)}';

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/attendance_${actionType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(watermarked);
        savedSelfiePath = filePath;
      } catch (e) {
        debugPrint('Selfie proof capture exception: $e');
      }

      final log = AttendanceModel(
        attendanceId: UuidHelper.generate(),
        userId: user.userId,
        workerName: user.fullName,
        workerEmpId: (user.username.isNotEmpty ? user.username : user.userId).toUpperCase(),
        workareaId: area?.workareaId ?? '',
        areaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
        actionType: actionType,
        timestamp: DateTime.now(),
        gpsLat: _currentPosition?.latitude ?? 11.0050,
        gpsLng: _currentPosition?.longitude ?? 124.6075,
        imageUrl: cloudSelfieUrl ?? savedSelfiePath,
        faceMatch: true,
        isSynced: false,
      );

      await ref.read(attendanceListProvider.notifier).record(log);

      // Handle 1-minute location tracking lifecycle
      if (actionType == 'time-in' && area != null) {
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

    final user = ref.watch(currentUserProvider).value;
    final shiftEval = ScheduleHelper.evaluateShift(schedule: user?.schedule);
    final shiftValidation = ScheduleHelper.canTimeInNow(shiftEval);

    ref.listen(assignedWorkAreaProvider, (prev, next) {
      _checkLocationAndGeofence();
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(assignedWorkAreaProvider);
        ref.invalidate(attendanceListProvider);
        await _checkLocationAndGeofence();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
        Text(
          AppTranslations.get('nav_attendance', lang),
          style: const TextStyle(
            fontSize: 24,
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppTranslations.get('biometric_title', lang),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),

        // Geofence status banner (Compact & Concise with Shift info)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isInsideGeofence ? AppColors.paleGreen : AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isInsideGeofence ? Icons.location_on : Icons.location_off,
                      color: _isInsideGeofence ? AppColors.accentGreen : AppColors.dangerRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      area?.name ?? (lang == AppLanguage.cebuano ? 'Walay Assigned Area' : 'No Work Area Assigned'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: _isInsideGeofence
                        ? (lang == AppLanguage.cebuano ? 'SULOD' : 'IN ZONE')
                        : (lang == AppLanguage.cebuano ? 'GAWAS' : 'OUTSIDE'),
                    backgroundColor: _isInsideGeofence ? AppColors.successBg : AppColors.dangerBg,
                    textColor: _isInsideGeofence ? AppColors.successText : AppColors.dangerText,
                  ),
                ],
              ),
              if (user?.schedule != null && user!.schedule.isNotEmpty && user.schedule != 'Unassigned') ...[
                const Divider(height: 16, color: AppColors.border),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${lang == AppLanguage.cebuano ? "Iskedyul" : "Shift"}: ${user.schedule}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Camera Viewfinder Box with guide (FittedBox with aspect ratio to prevent squashing)
        Container(
          height: (MediaQuery.sizeOf(context).height * 0.28).clamp(180.0, 240.0),
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
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 300,
                          height: _cameraController!.value.previewSize?.width ?? 400,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural, size: 76, color: Color(0xFF6CC5FF)),
                            SizedBox(height: 8),
                            Text('Face viewfinder ready', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                if (_currentLens == CameraLensDirection.front) ...[
                  Center(
                    child: Container(
                      width: 170,
                      height: 205,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white60, width: 2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppTranslations.get('position_face', lang),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  top: 12,
                  right: 14,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _toggleCamera,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flip_camera_android, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'FLIP',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GPS: ${_currentPosition?.latitude.toStringAsFixed(4) ?? "11.0050"}, ${_currentPosition?.longitude.toStringAsFixed(4) ?? "124.6075"}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Shift Progress Timeline (Clear Visual Overview for Elderly Workers)
        _buildShiftTimeline(logs, lang),
        const SizedBox(height: 16),

        // Primary Action Button (Time-In, Break-In, Break-Out, Time-Out)
        if (nextAction == 'complete')
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.accentGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTranslations.get('all_actions_complete', lang),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (nextAction == 'time-in' && !shiftValidation.allowed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warningOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shiftValidation.getReason(lang == AppLanguage.cebuano),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
                    ),
                  ),
                ],
              ),
            ),
          AppButton(
            label: _getActionLabel(nextAction, lang),
            icon: _getActionIcon(nextAction),
            isLoading: _isProcessing,
            variant: (nextAction == 'time-in' && !shiftValidation.allowed)
                ? AppButtonVariant.secondary
                : _getActionVariant(nextAction),
            minHeight: 56,
            onPressed: _isProcessing
                ? null
                : () {
                    if (nextAction == 'time-in' && !shiftValidation.allowed) {
                      ToastNotification.showWarning(context, shiftValidation.getReason(lang == AppLanguage.cebuano));
                      return;
                    }
                    _handleAttendance(nextAction, lang);
                  },
          ),
        ],
        const SizedBox(height: 24),

        // Recent Logs Section
        Text(
          AppTranslations.get('recent_attendance', lang),
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        if (logs.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                AppTranslations.get('no_attendance_today', lang),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...logs.take(3).map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: log.isSynced ? AppColors.paleGreen : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            log.isSynced ? Icons.check_circle_outline : Icons.sync,
                            size: 20,
                            color: log.isSynced ? AppColors.accentGreen : AppColors.warningOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.actionType.toUpperCase(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM d, yyyy • hh:mm a').format(log.timestamp),
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
      ),
    );
  }

  Widget _buildShiftTimeline(List<AttendanceModel> logs, AppLanguage lang) {
    final today = DateTime.now();
    final todayLogs = logs
        .where((l) =>
            l.timestamp.year == today.year &&
            l.timestamp.month == today.month &&
            l.timestamp.day == today.day)
        .map((l) => l.actionType)
        .toSet();

    final phases = [
      {'key': 'time-in', 'ceb': 'Pagsulod', 'eng': 'Time-In'},
      {'key': 'break-in', 'ceb': 'Pahuway', 'eng': 'Break'},
      {'key': 'break-out', 'ceb': 'Balik', 'eng': 'Resume'},
      {'key': 'time-out', 'ceb': 'Paggawas', 'eng': 'Time-Out'},
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: phases.map((phase) {
          final isDone = todayLogs.contains(phase['key']);
          final label = lang == AppLanguage.cebuano ? phase['ceb']! : phase['eng']!;

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.accentGreen : AppColors.surfaceSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? AppColors.accentGreen : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.circle_outlined,
                    color: isDone ? Colors.white : AppColors.textLight,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                      color: isDone ? AppColors.primaryNavy : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
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

  Future<bool?> _showNoFaceEnrolledDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.face_retouching_off, color: AppColors.warningOrange),
            SizedBox(width: 8),
            Text('No Face Enrolled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your account does not have registered face biometric credentials yet. Biometric verification is required for all attendance actions.\n\nWould you like to register the face currently in front of the camera as your biometric identity?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Register Face Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEnrollFaceNow(Uint8List rawBytes) async {
    setState(() => _isProcessing = true);
    try {
      final vector = BiometricsHelper.extractFeatureVector(rawBytes);
      final embeddingStr = BiometricsHelper.formatEmbeddingString(vector);
      final success = await ref.read(currentUserProvider.notifier).updateFaceEmbedding(embeddingStr);
      if (mounted) {
        if (success) {
          ToastNotification.showSuccess(
            context,
            'Face profile enrolled successfully! You can now verify attendance with your face.',
          );
        } else {
          ToastNotification.showError(
            context,
            'Failed to save face profile. Please check connection and try again.',
          );
        }
      }
    } catch (e) {
      debugPrint('Face enrollment error: $e');
      if (mounted) {
        ToastNotification.showError(context, 'Face enrollment error: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showFaceMismatchDialog(BuildContext context, int matchPct) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad_rounded, color: AppColors.dangerRed),
            SizedBox(width: 8),
            Text('Face Verification Failed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.dangerRed)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The captured face does not match your registered biometric profile.\n\nMatch Score: $matchPct% (65% required).\n\nAttendance was NOT recorded. Please align your face inside the circle with good lighting and try again.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK, Try Again'),
          ),
        ],
      ),
    );
  }
}


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
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/leave_request_model.dart';
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
  bool _isCameraEnabled = false;
  bool _isCameraInitializing = false;
  bool _isProcessing = false;
  LatLng? _currentPosition = LocationTrackingService.instance.currentPositionNotifier.value;
  bool _isInsideGeofence = LocationTrackingService.instance.isInsideGeofenceNotifier.value;

  @override
  void initState() {
    super.initState();
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
        _checkLocationAndGeofence();
      } else {
        _disposeCamera();
      }
    }
  }

  Future<void> _openCamera() async {
    if (_isCameraInitializing || _isCameraReady) return;
    setState(() {
      _isCameraEnabled = true;
      _isCameraInitializing = true;
    });
    await _initCamera();
    if (mounted) {
      setState(() => _isCameraInitializing = false);
    }
  }

  Future<void> _closeCamera() async {
    setState(() {
      _isCameraEnabled = false;
      _isCameraInitializing = false;
    });
    await _disposeCamera();
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraReady = false;
        _isCameraInitializing = false;
      });
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

  /// Helper to get today's punches in ascending chronological order
  List<AttendanceModel> _getTodayLogs(List<AttendanceModel> logs) {
    final today = DateTime.now();
    final todayLogs = logs.where((l) =>
        l.timestamp.year == today.year &&
        l.timestamp.month == today.month &&
        l.timestamp.day == today.day).toList();
    todayLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return todayLogs;
  }

  /// Returns current status: 'not_started', 'on_duty', 'on_break', 'completed'
  String _getShiftState(List<AttendanceModel> logs) {
    final todayLogs = _getTodayLogs(logs);
    final hasTimeIn = todayLogs.any((l) => l.actionType == 'time-in');
    final hasTimeOut = todayLogs.any((l) => l.actionType == 'time-out');

    if (hasTimeOut) return 'completed';
    if (!hasTimeIn) return 'not_started';

    final lastAction = todayLogs.last.actionType;
    if (lastAction == 'break-in') return 'on_break';
    return 'on_duty';
  }

  /// Calculate total break duration for today's logs
  Duration _getTodayBreakDuration(List<AttendanceModel> logs) {
    final todayLogs = _getTodayLogs(logs);
    Duration total = Duration.zero;
    DateTime? currentBreakStart;

    for (final p in todayLogs) {
      if (p.actionType == 'break-in') {
        currentBreakStart = p.timestamp;
      } else if (p.actionType == 'break-out' && currentBreakStart != null) {
        total += p.timestamp.difference(currentBreakStart);
        currentBreakStart = null;
      }
    }
    if (currentBreakStart != null && !todayLogs.any((l) => l.actionType == 'time-out')) {
      total += DateTime.now().difference(currentBreakStart);
    }
    return total;
  }

  /// Total worked hours (Time In to Time Out/Now minus total breaks)
  Duration _getTodayWorkedDuration(List<AttendanceModel> logs) {
    final todayLogs = _getTodayLogs(logs);
    final timeIn = todayLogs.cast<AttendanceModel?>().firstWhere(
      (l) => l?.actionType == 'time-in',
      orElse: () => null,
    );
    if (timeIn == null) return Duration.zero;

    final timeOut = todayLogs.cast<AttendanceModel?>().firstWhere(
      (l) => l?.actionType == 'time-out',
      orElse: () => null,
    );
    final end = timeOut?.timestamp ?? DateTime.now();
    final gross = end.difference(timeIn.timestamp);
    final net = gross - _getTodayBreakDuration(logs);
    return net.isNegative ? Duration.zero : net;
  }

  String _formatDuration(Duration dur) {
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  int _getTodayBreakCount(List<AttendanceModel> logs) {
    final todayLogs = _getTodayLogs(logs);
    return todayLogs.where((l) => l.actionType == 'break-in').length;
  }

  Future<void> _handleAttendance(String actionType, AppLanguage lang, {bool isSubstitute = false}) async {
    if (!_isInsideGeofence) {
      ToastNotification.showError(
        context,
        AppTranslations.get('outside_geofence_warning', lang),
      );
      return;
    }

    final user = ref.read(currentUserProvider).value;
    String? lateReason;

    // Shift Schedule Enforcement: Verify worker is logging within scheduled shift window
    if (actionType == 'time-in' && user?.schedule != null && user!.schedule.isNotEmpty && user.schedule != 'Unassigned') {
      final shiftEval = ScheduleHelper.evaluateShift(schedule: user.schedule);
      final validation = ScheduleHelper.canTimeInNow(shiftEval);
      if (!validation.allowed) {
        final reason = validation.getReason(lang == AppLanguage.cebuano);
        ToastNotification.showWarning(context, reason);
        return;
      }
      if (validation.isLate) {
        lateReason = validation.lateFormatted;
      }
    }

    setState(() => _isProcessing = true);
    try {
      final area = ref.read(assignedWorkAreaProvider).value;

      String? savedSelfiePath;
      String? cloudSelfieUrl;
      bool faceMatchPassed = true;

      // Photo and Biometrics verification is required ONLY during time-in (skip biometric match if substitute)
      if (actionType == 'time-in') {
        if (!_isCameraEnabled || !_isCameraReady || _cameraController == null) {
          ToastNotification.showInfo(
            context,
            lang == AppLanguage.cebuano
                ? 'Gipasiga ang kamera alang sa verification. Palihog iposisyon ang imong nawong sa viewfinder.'
                : 'Opening camera for facial verification. Please position your face in the viewfinder.',
          );
          await _openCamera();
          setState(() => _isProcessing = false);
          return;
        }

        // 1. Capture live photo from camera
        Uint8List rawBytes;
        final XFile photo = await _cameraController!.takePicture();
        rawBytes = await photo.readAsBytes();

        if (!isSubstitute) {
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
        }

        // 4. Burn watermark onto proof photo
        try {
          final watermarked = ImageWatermarkHelper.burnWatermark(
            rawImageBytes: rawBytes,
            latitude: _currentPosition?.latitude ?? 11.0050,
            longitude: _currentPosition?.longitude ?? 124.6075,
            workerName: isSubstitute ? '${user?.fullName ?? 'Worker'} (Substitute)' : (user?.fullName ?? 'Worker'),
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
      }

      final log = AttendanceModel(
        attendanceId: UuidHelper.generate(),
        userId: user!.userId,
        workerName: isSubstitute ? '${user.fullName} (Substitute)' : user.fullName,
        workerEmpId: (user.username.isNotEmpty ? user.username : user.userId).toUpperCase(),
        workareaId: area?.workareaId ?? '',
        areaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
        actionType: actionType,
        timestamp: DateTime.now(),
        gpsLat: _currentPosition?.latitude ?? 11.0050,
        gpsLng: _currentPosition?.longitude ?? 124.6075,
        imageUrl: cloudSelfieUrl ?? savedSelfiePath,
        faceMatch: faceMatchPassed,
        isSynced: false,
        isSubstitute: isSubstitute,
        lateReason: lateReason,
      );

      await ref.read(attendanceListProvider.notifier).record(log);

      // Handle 1-minute location tracking lifecycle
      if (actionType == 'time-in' && area != null) {
        LocationTrackingService.instance.startTracking(userId: user.userId, assignedArea: area);
      } else if (actionType == 'time-out') {
        LocationTrackingService.instance.stopTracking();
      }

      if (mounted) {
        final displayLabel = isSubstitute
            ? (lang == AppLanguage.cebuano ? 'Pagsulod isip Halili (Substitute)' : 'Time-In as Substitute')
            : _getActionLabel(actionType, lang);
        final lateNotice = lateReason != null ? ' ($lateReason)' : '';
        ToastNotification.showSuccess(
          context,
          '$displayLabel recorded successfully!$lateNotice',
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
    final shiftState = _getShiftState(logs);

    final user = ref.watch(currentUserProvider).value;
    final shiftEval = ScheduleHelper.evaluateShift(schedule: user?.schedule);
    final shiftValidation = ScheduleHelper.canTimeInNow(shiftEval);

    final leaves = ref.watch(leaveRequestListProvider).value ?? [];
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final approvedLeaveToday = leaves.cast<LeaveRequestModel?>().firstWhere(
      (l) {
        if (l == null || l.status.toLowerCase() != 'approved') return false;
        final sMidnight = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
        final eMidnight = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
        return !todayMidnight.isBefore(sMidnight) && !todayMidnight.isAfter(eMidnight);
      },
      orElse: () => null,
    );

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

        // Live Camera Viewfinder Box with on-demand standby mode
        Container(
          height: (MediaQuery.sizeOf(context).height * 0.28).clamp(180.0, 240.0),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryNavy, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: !_isCameraEnabled
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_outlined, size: 44, color: Color(0xFF6CC5FF)),
                          const SizedBox(height: 8),
                          Text(
                            AppTranslations.get('camera_standby_hint', lang),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _openCamera,
                            icon: _isCameraInitializing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.videocam_rounded, size: 18),
                            label: Text(
                              _isCameraInitializing
                                  ? (lang == AppLanguage.cebuano ? 'Gi-ablihan...' : 'Opening...')
                                  : AppTranslations.get('open_camera', lang),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
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
                                  CircularProgressIndicator(color: AppColors.accentBlue),
                                  SizedBox(height: 10),
                                  Text('Starting camera...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                      if (_currentLens == CameraLensDirection.front)
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
                      // Top-right: FLIP camera button only
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
                                  Icon(Icons.flip_camera_android, color: Colors.white, size: 16),
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
                      // Bottom-right: Close camera button (no collision with top labels)
                      Positioned(
                        bottom: 12,
                        right: 14,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _closeCamera,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppTranslations.get('close_camera', lang),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (approvedLeaveToday != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == AppLanguage.cebuano
                            ? 'OPISYAL NGA NAKA-BAKASYON KARON'
                            : 'OFFICIALLY ON APPROVED LEAVE TODAY',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${approvedLeaveToday.type}: ${approvedLeaveToday.reason}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Shift Progress & Stats Card (Live Shift Status, Net Worked Hours, Breaks Count)
        _buildShiftStatusCard(logs, lang),
        const SizedBox(height: 16),

        if (shiftState == 'not_started' && shiftValidation.isLate)
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
                const Icon(Icons.access_time_filled_rounded, color: AppColors.warningOrange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shiftValidation.getReason(lang == AppLanguage.cebuano),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
                  ),
                ),
              ],
            ),
          )
        else if (shiftState == 'not_started' && !shiftValidation.allowed)
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

        // 2x2 Attendance Action Buttons Grid
        _buildActionGrid(shiftState, shiftValidation.allowed, lang),
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

  Widget _buildShiftStatusCard(List<AttendanceModel> logs, AppLanguage lang) {
    final shiftState = _getShiftState(logs);
    final workedDur = _getTodayWorkedDuration(logs);
    final workedStr = _formatDuration(workedDur);
    final breaksCount = _getTodayBreakCount(logs);
    final breakDur = _getTodayBreakDuration(logs);
    final breakDurStr = _formatDuration(breakDur);

    String statusLabel;
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    switch (shiftState) {
      case 'on_duty':
        statusLabel = AppTranslations.get('status_on_duty', lang);
        statusBg = AppColors.successBg;
        statusFg = AppColors.successText;
        statusIcon = Icons.work_outline;
        break;
      case 'on_break':
        statusLabel = '${AppTranslations.get("status_on_break", lang)} (#$breaksCount)';
        statusBg = AppColors.warningBg;
        statusFg = AppColors.warningText;
        statusIcon = Icons.coffee_outlined;
        break;
      case 'completed':
        statusLabel = AppTranslations.get('status_shift_complete', lang);
        statusBg = const Color(0xFFE0E7FF);
        statusFg = const Color(0xFF3730A3);
        statusIcon = Icons.verified_outlined;
        break;
      default:
        statusLabel = AppTranslations.get('status_not_started', lang);
        statusBg = AppColors.surfaceSubtle;
        statusFg = AppColors.textMuted;
        statusIcon = Icons.schedule_outlined;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 16, color: statusFg),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusFg,
                    ),
                  ),
                ],
              ),
              if (shiftState != 'not_started')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.paleGreen,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        '${AppTranslations.get("worked_hours", lang)}: $workedStr',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (shiftState != 'not_started') ...[
            const Divider(height: 16, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      AppTranslations.get('breaks_taken', lang),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$breaksCount ${breaksCount == 1 ? "break" : "breaks"} ($breakDurStr)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Column(
                  children: [
                    Text(
                      AppTranslations.get('worked_hours', lang),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workedStr,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionGrid(String shiftState, bool canTimeInShift, AppLanguage lang) {
    // Determine enabled state per action according to rules:
    // 1. Not started: only time-in is clickable
    // 2. On duty: break and time-out are clickable
    // 3. On break: only resume (break-out) is clickable
    // 4. Completed: all buttons greyed out
    final bool canTimeIn = (shiftState == 'not_started') && canTimeInShift;
    final bool canBreak = (shiftState == 'on_duty');
    final bool canResume = (shiftState == 'on_break');
    final bool canTimeOut = (shiftState == 'on_duty');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAttendanceButton(
                label: AppTranslations.get('time_in', lang),
                icon: Icons.login_rounded,
                isEnabled: canTimeIn,
                activeColor: const Color(0xFF10B981), // Emerald Green
                onPressed: () => _handleAttendance('time-in', lang),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAttendanceButton(
                label: AppTranslations.get('break_in', lang),
                icon: Icons.coffee_rounded,
                isEnabled: canBreak,
                activeColor: const Color(0xFFD97706), // Warm Amber
                onPressed: () => _handleAttendance('break-in', lang),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAttendanceButton(
                label: AppTranslations.get('break_out', lang),
                icon: Icons.play_arrow_rounded,
                isEnabled: canResume,
                activeColor: const Color(0xFF2563EB), // Vibrant Blue
                onPressed: () => _handleAttendance('break-out', lang),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAttendanceButton(
                label: AppTranslations.get('time_out', lang),
                icon: Icons.logout_rounded,
                isEnabled: canTimeOut,
                activeColor: const Color(0xFFDC2626), // Danger Red
                onPressed: () => _handleAttendance('time-out', lang),
              ),
            ),
          ],
        ),
        if (shiftState == 'not_started') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.05),
            ),
            icon: const Icon(Icons.people_alt_outlined, color: Color(0xFF0D9488), size: 20),
            label: Text(
              lang == AppLanguage.cebuano
                  ? 'PAGSULOD ISIP HALILI (SUBSTITUTE)'
                  : 'TIME-IN AS SUBSTITUTE',
              style: const TextStyle(
                color: Color(0xFF0D9488),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            onPressed: _isProcessing ? null : () => _handleAttendance('time-in', lang, isSubstitute: true),
          ),
        ],
      ],
    );
  }

  Widget _buildAttendanceButton({
    required String label,
    required IconData icon,
    required bool isEnabled,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    final bool disabled = !isEnabled || _isProcessing;

    return Material(
      color: disabled ? const Color(0xFFE2E8F0) : activeColor,
      borderRadius: BorderRadius.circular(12),
      elevation: disabled ? 0 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disabled ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled ? const Color(0xFFCBD5E1) : activeColor,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: disabled ? const Color(0xFF94A3B8) : Colors.white,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: disabled ? const Color(0xFF94A3B8) : Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
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


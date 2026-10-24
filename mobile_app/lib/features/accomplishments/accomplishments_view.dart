import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/image_watermark_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class AccomplishmentsView extends ConsumerStatefulWidget {
  const AccomplishmentsView({super.key});

  @override
  ConsumerState<AccomplishmentsView> createState() => _AccomplishmentsViewState();
}

class _AccomplishmentsViewState extends ConsumerState<AccomplishmentsView> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  Uint8List? _watermarkedImageBytes;
  String? _savedImagePath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(backCamera, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndWatermark() async {
    setState(() => _isCapturing = true);
    try {
      final user = ref.read(currentUserProvider).value;
      final area = ref.read(assignedWorkAreaProvider).value;

      double lat = 11.0050;
      double lng = 124.6075;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      Uint8List rawBytes;
      if (_isCameraReady && _cameraController != null) {
        final XFile photo = await _cameraController!.takePicture();
        rawBytes = await photo.readAsBytes();
      } else {
        // Fallback placeholder image when camera is unavailable in desktop/emulator
        rawBytes = Uint8List.fromList(List.generate(200 * 200 * 3, (i) => 120));
      }

      // Burn metadata directly into image pixels (Rule 4 of GEMINI.md)
      final watermarked = ImageWatermarkHelper.burnWatermark(
        rawImageBytes: rawBytes,
        latitude: lat,
        longitude: lng,
        workerName: user?.fullName ?? 'Juan Dela Cruz',
        workAreaName: area?.name ?? 'Sector 4 - Downtown Zone',
        timestamp: DateTime.now(),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/acc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(watermarked);

      if (mounted) {
        setState(() {
          _watermarkedImageBytes = watermarked;
          _savedImagePath = filePath;
        });
        ToastNotification.showSuccess(context, 'Field photo captured with burned timestamp & GPS coordinates!');
      }
    } catch (e) {
      if (mounted) ToastNotification.showError(context, 'Error capturing proof: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _submitReport() async {
    final title = _taskController.text.trim();
    final details = _descController.text.trim();

    if (title.isEmpty || details.isEmpty) {
      ToastNotification.showWarning(context, 'Please enter a task title and details.');
      return;
    }

    if (_savedImagePath == null) {
      ToastNotification.showWarning(context, 'Please capture a photo proof first.');
      return;
    }

    final user = ref.read(currentUserProvider).value;
    final area = ref.read(assignedWorkAreaProvider).value;

    final accomplishment = AccomplishmentModel(
      accomplishmentId: 'acc-${DateTime.now().millisecondsSinceEpoch}',
      userId: user?.userId ?? 'usr-wkr-001',
      workerName: user?.fullName ?? 'Field Worker',
      workareaId: area?.workareaId ?? 'area-sec-004',
      areaName: area?.name ?? 'Sector 4 - Downtown Zone',
      imageUrl: _savedImagePath!,
      capturedDate: DateTime.now(),
      capturedTime: DateFormat('hh:mm a').format(DateTime.now()),
      capturedLat: 11.0050,
      capturedLng: 124.6075,
      message: '$title — $details',
      status: 'pending',
      isSynced: false,
    );

    await ref.read(accomplishmentListProvider.notifier).submit(accomplishment);

    _taskController.clear();
    _descController.clear();
    setState(() {
      _watermarkedImageBytes = null;
      _savedImagePath = null;
    });

    if (mounted) {
      ToastNotification.showSuccess(context, 'Accomplishment saved locally! Enqueued for sync.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final reports = ref.watch(accomplishmentListProvider).value ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppTranslations.get('nav_reports', lang),
          style: const TextStyle(fontSize: 20, color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Geotagged proof of completed field work',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 14),

        // Input Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('task_title', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _taskController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Drainage Clearing, Waste Collection',
                  hintStyle: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                AppTranslations.get('task_photo_required', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),

              GestureDetector(
                onTap: _isCapturing ? null : _captureAndWatermark,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _watermarkedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_watermarkedImageBytes!, fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Tap to retake',
                                    style: TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isCapturing ? Icons.hourglass_top : Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isCapturing
                                    ? 'Burning Watermark...'
                                    : AppTranslations.get('tap_to_capture', lang),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Burns timestamp & GPS coordinates directly on image',
                                style: TextStyle(color: Colors.white54, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                AppTranslations.get('task_details', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the specific accomplishments and areas covered...',
                  hintStyle: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),

              AppButton(
                label: 'Submit Accomplishment Proof',
                icon: Icons.cloud_upload_outlined,
                onPressed: _submitReport,
                variant: AppButtonVariant.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submitted Reports List
        const Text(
          'MGA NAISUMITENG REPORT',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(16),
            child: Text(
              'Wala pang accomplishment report.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          )
        else
          ...reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Field Accomplishment',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy),
                              ),
                            ),
                            StatusBadge(
                              label: report.status.toUpperCase(),
                              backgroundColor: report.status == 'approved'
                                  ? AppColors.successBg
                                  : report.status == 'denied'
                                      ? AppColors.dangerBg
                                      : AppColors.warningBg,
                              textColor: report.status == 'approved'
                                  ? AppColors.successText
                                  : report.status == 'denied'
                                      ? AppColors.dangerText
                                      : AppColors.warningText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.message,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy • hh:mm a').format(report.capturedDate),
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                            ),
                            const Spacer(),
                            StatusBadge(
                              label: report.isSynced ? 'SYNCED' : 'LOCAL CACHE',
                              backgroundColor: report.isSynced ? AppColors.paleGreen : AppColors.neutralBg,
                              textColor: report.isSynced ? AppColors.accentGreen : AppColors.neutralText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

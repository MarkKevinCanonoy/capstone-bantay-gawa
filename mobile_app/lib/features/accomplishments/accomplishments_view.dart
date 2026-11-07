import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/image_watermark_helper.dart';
import '../../core/utils/location_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/geofence_helper.dart';
import '../../core/widgets/toast_notification.dart';
import '../../core/utils/uuid_helper.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class AccomplishmentsView extends ConsumerStatefulWidget {
  final bool isActive;
  const AccomplishmentsView({super.key, this.isActive = true});

  @override
  ConsumerState<AccomplishmentsView> createState() => _AccomplishmentsViewState();
}

class _AccomplishmentsViewState extends ConsumerState<AccomplishmentsView> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  CameraController? _cameraController;
  CameraLensDirection _currentLens = CameraLensDirection.back;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  Uint8List? _watermarkedImageBytes;
  String? _savedImagePath;
  double? _capturedLat;
  double? _capturedLng;
  String? _selectedWorkAreaId;
  bool _showPastReports = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initCamera();
    }
  }

  @override
  void didUpdateWidget(AccomplishmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_watermarkedImageBytes == null) {
          _initCamera();
        }
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

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == _currentLens,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(selectedCamera, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_isCapturing) return;
    final nextLens = _currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    setState(() {
      _currentLens = nextLens;
      _isCameraReady = false;
    });
    await _cameraController?.dispose();
    if (widget.isActive) {
      await _initCamera();
    }
  }

  void _clearAndRetake() {
    setState(() {
      _watermarkedImageBytes = null;
      _savedImagePath = null;
      _capturedLat = null;
      _capturedLng = null;
    });
    if (widget.isActive && (!_isCameraReady || _cameraController == null)) {
      _initCamera();
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
      final allAreas = ref.read(allWorkAreasProvider).value ?? [];
      final defaultArea = ref.read(assignedWorkAreaProvider).value;
      final chosenArea = allAreas.firstWhere(
        (a) => a.workareaId == _selectedWorkAreaId,
        orElse: () => defaultArea ?? (allAreas.isNotEmpty ? allAreas.first : WorkAreaModel(workareaId: '', name: 'Unassigned Area', polygonCoordinates: const [])),
      );

      // Verify device location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ToastNotification.showWarning(context, 'Please enable device GPS/Location for accurate field proof coordinates.');
      }

      final currentLoc = await LocationHelper.getCurrentLocation();
      final lat = currentLoc.latitude;
      final lng = currentLoc.longitude;

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
        workerName: user?.fullName ?? '',
        workAreaName: chosenArea.name.isNotEmpty ? chosenArea.name : 'Unassigned Area',
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
          _capturedLat = lat;
          _capturedLng = lng;
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
    final allAreas = ref.read(allWorkAreasProvider).value ?? [];
    final defaultArea = ref.read(assignedWorkAreaProvider).value;
    final chosenArea = allAreas.firstWhere(
      (a) => a.workareaId == _selectedWorkAreaId,
      orElse: () => defaultArea ?? (allAreas.isNotEmpty ? allAreas.first : WorkAreaModel(workareaId: '', name: 'Unassigned Area', polygonCoordinates: const [])),
    );

    final finalMessage = '$title — $details';

    final accId = UuidHelper.generate();

    // 1. Prepare self-contained Base64 Data URI from watermarked image bytes
    String cloudImageUrl = '';
    if (_watermarkedImageBytes != null && _watermarkedImageBytes!.isNotEmpty) {
      cloudImageUrl = 'data:image/jpeg;base64,${base64Encode(_watermarkedImageBytes!)}';
    } else if (_savedImagePath != null && File(_savedImagePath!).existsSync()) {
      final bytes = await File(_savedImagePath!).readAsBytes();
      cloudImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    // 2. Attempt Supabase Storage upload if online
    try {
      final client = Supabase.instance.client;
      final fileName = '${user?.userId ?? "anon"}/$accId.jpg';
      final uploadBytes = _watermarkedImageBytes ?? (await File(_savedImagePath!).readAsBytes());
      await client.storage.from(AppConstants.bucketAccomplishments).uploadBinary(
        fileName,
        uploadBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final publicUrl = client.storage.from(AppConstants.bucketAccomplishments).getPublicUrl(fileName);
      if (publicUrl.isNotEmpty) {
        cloudImageUrl = publicUrl;
      }
    } catch (e) {
      debugPrint('Supabase storage upload skipped/failed ($e), using self-contained base64 data URI');
    }

    final accomplishment = AccomplishmentModel(
      accomplishmentId: accId,
      userId: user?.userId ?? '',
      workerName: user?.fullName ?? '',
      workareaId: chosenArea.workareaId,
      areaName: chosenArea.name.isNotEmpty ? chosenArea.name : 'Unassigned Area',
      imageUrl: cloudImageUrl.isNotEmpty ? cloudImageUrl : _savedImagePath!,
      capturedDate: DateTime.now(),
      capturedTime: DateFormat('HH:mm:ss').format(DateTime.now()),
      capturedLat: _capturedLat ?? 11.0050,
      capturedLng: _capturedLng ?? 124.6075,
      message: finalMessage,
      status: 'pending',
      isSynced: false,
    );

    final isOutsideZone = _capturedLat != null &&
        _capturedLng != null &&
        chosenArea.polygonCoordinates.isNotEmpty &&
        !GeofenceHelper.isPointInPolygon(LatLng(_capturedLat!, _capturedLng!), chosenArea.polygonCoordinates);

    final wasCloudSynced = await ref.read(accomplishmentListProvider.notifier).submit(accomplishment);

    _taskController.clear();
    _descController.clear();
    setState(() {
      _watermarkedImageBytes = null;
      _savedImagePath = null;
      _capturedLat = null;
      _capturedLng = null;
    });

    if (mounted) {
      final lang = ref.read(localeProvider);
      if (wasCloudSynced) {
        ToastNotification.showSuccess(
          context,
          isOutsideZone
              ? (lang == AppLanguage.cebuano
                  ? 'Napadala! (Na-flag: Gawas sa Zone)'
                  : 'Submitted! (Flagged: Outside Zone)')
              : (lang == AppLanguage.cebuano ? 'Malampusong na-upload!' : 'Successfully uploaded!'),
        );
      } else {
        ToastNotification.showInfo(
          context,
          isOutsideZone
              ? (lang == AppLanguage.cebuano
                  ? 'Na-save offline (Na-flag: Gawas sa Zone).'
                  : 'Saved offline (Flagged: Outside Zone).')
              : (lang == AppLanguage.cebuano
                  ? 'Na-save offline. I-upload kini kung aduna nay koneksyon sa internet.'
                  : 'Saved offline. Will upload when connected to the internet.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final reports = ref.watch(accomplishmentListProvider).value ?? [];
    final allAreas = ref.watch(allWorkAreasProvider).value ?? [];
    final defaultArea = ref.watch(assignedWorkAreaProvider).value;

    final chosenArea = allAreas.firstWhere(
      (a) => a.workareaId == (_selectedWorkAreaId ?? defaultArea?.workareaId ?? (allAreas.isNotEmpty ? allAreas.first.workareaId : null)),
      orElse: () => defaultArea ?? (allAreas.isNotEmpty ? allAreas.first : WorkAreaModel(workareaId: '', name: 'Unassigned Area', polygonCoordinates: const [])),
    );
    final isOutsideZone = _capturedLat != null &&
        _capturedLng != null &&
        chosenArea.polygonCoordinates.isNotEmpty &&
        !GeofenceHelper.isPointInPolygon(LatLng(_capturedLat!, _capturedLng!), chosenArea.polygonCoordinates);

    final now = DateTime.now();
    int statusPriority(String status) {
      switch (status.toLowerCase()) {
        case 'pending':
          return 0;
        case 'approved':
          return 1;
        case 'denied':
          return 2;
        default:
          return 3;
      }
    }

    final todayReports = reports.where((r) {
      return r.capturedDate.year == now.year &&
          r.capturedDate.month == now.month &&
          r.capturedDate.day == now.day;
    }).toList()
      ..sort((a, b) {
        final pA = statusPriority(a.status);
        final pB = statusPriority(b.status);
        if (pA != pB) return pA.compareTo(pB);
        return b.capturedDate.compareTo(a.capturedDate);
      });

    final olderReports = reports.where((r) {
      return !(r.capturedDate.year == now.year &&
          r.capturedDate.month == now.month &&
          r.capturedDate.day == now.day);
    }).toList()
      ..sort((a, b) {
        final pA = statusPriority(a.status);
        final pB = statusPriority(b.status);
        if (pA != pB) return pA.compareTo(pB);
        return b.capturedDate.compareTo(a.capturedDate);
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(assignedWorkAreaProvider);
        ref.invalidate(allWorkAreasProvider);
        ref.invalidate(accomplishmentListProvider);
      },
      child: ListView(
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
              // Work Area Selector (US-25)
              Text(
                lang == AppLanguage.cebuano ? 'Lugar sa Trabaho / Work Area' : 'Work Area Sector',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedWorkAreaId ?? defaultArea?.workareaId ?? (allAreas.isNotEmpty ? allAreas.first.workareaId : null),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primaryNavy, size: 20),
                ),
                items: allAreas.map((area) {
                  final isAssigned = area.workareaId == defaultArea?.workareaId;
                  return DropdownMenuItem<String>(
                    value: area.workareaId,
                    child: Text(
                      '${area.name}${isAssigned ? " (Imong Assigned Zone)" : " (Alternate Area)"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                        color: isAssigned ? AppColors.primaryNavy : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWorkAreaId = val);
                },
              ),
              const SizedBox(height: 14),

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

              // Camera Viewfinder Box with flip and capture (Proportional responsive height)
              Container(
                height: (MediaQuery.sizeOf(context).height * 0.26).clamp(170.0, 220.0),
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
                            Image.memory(
                              _watermarkedImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.primaryDark,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_outlined, color: Colors.white54, size: 36),
                                      SizedBox(height: 6),
                                      Text('Invalid image data. Please retake photo.',
                                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: _clearAndRetake,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Kuha Pag-usab / Retake',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
                            // Camera Flip button in top-right (US-29)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _toggleCamera,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flip_camera_android, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text('FLIP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Capture trigger button at bottom
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  onPressed: _isCapturing ? null : _captureAndWatermark,
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: Text(
                                    _isCapturing
                                        ? 'Saving...'
                                        : (lang == AppLanguage.cebuano ? 'Kuhaa ang Litrato' : 'Take Proof Photo'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (_watermarkedImageBytes != null && isOutsideZone) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppTranslations.get('report_outside_zone_alert', lang),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              Text(
                AppTranslations.get('task_details', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: lang == AppLanguage.cebuano
                      ? 'I-detalye ang nahuman nga trabaho ug mga lugar nga nalimpyohan...'
                      : 'Describe the specific accomplishments and areas covered...',
                  hintStyle: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),

              AppButton(
                label: lang == AppLanguage.cebuano ? 'I-sumiter ang Accomplishment' : 'Submit Accomplishment Proof',
                icon: Icons.cloud_upload_outlined,
                onPressed: _submitReport,
                variant: AppButtonVariant.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Today's Accomplishments Section
        Text(
          AppTranslations.get('today_reports', lang).toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        if (todayReports.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppTranslations.get('no_reports_today', lang),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          )
        else
          ...todayReports.map((report) => _buildReportCard(report, lang, allAreas)),

        // Collapsible Past Reports Section (Prevents history clogging)
        if (olderReports.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showPastReports = !_showPastReports),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _showPastReports ? Icons.keyboard_arrow_up : Icons.history,
                    color: AppColors.primaryNavy,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showPastReports
                          ? AppTranslations.get('hide_past_reports', lang)
                          : '${AppTranslations.get('view_past_reports', lang)} (${olderReports.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  Icon(
                    _showPastReports ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryNavy,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_showPastReports) ...[
            const SizedBox(height: 10),
            ...olderReports.map((report) => _buildReportCard(report, lang, allAreas)),
          ],
        ],
      ],
      ),
    );
  }

  Widget _buildReportCard(AccomplishmentModel report, AppLanguage lang, List<WorkAreaModel> allAreas) {
    final isApproved = report.status == 'approved';
    final isDenied = report.status == 'denied';

    final matchingArea = allAreas.firstWhere(
      (a) => a.workareaId == report.workareaId,
      orElse: () => WorkAreaModel(workareaId: '', name: '', polygonCoordinates: const []),
    );
    final isReportOutside = matchingArea.polygonCoordinates.isNotEmpty &&
        !GeofenceHelper.isPointInPolygon(LatLng(report.capturedLat, report.capturedLng), matchingArea.polygonCoordinates);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          report.areaName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isReportOutside) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            AppTranslations.get('outside_zone_badge', lang),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusBadge(
                  label: report.status.toUpperCase(),
                  backgroundColor: isApproved
                      ? AppColors.successBg
                      : isDenied
                          ? AppColors.dangerBg
                          : AppColors.warningBg,
                  textColor: isApproved
                      ? AppColors.successText
                      : isDenied
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
            // Supervisor Rejection Remark display if denied (FR-22)
            if (isDenied && report.rejectionReason != null && report.rejectionReason!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppColors.dangerText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${lang == AppLanguage.cebuano ? "Rason sa Pagbalibad" : "Rejection Reason"}: ${report.rejectionReason}',
                            style: const TextStyle(fontSize: 11, color: AppColors.dangerText, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.get('retake_proof_hint', lang),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
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
    );
  }
}

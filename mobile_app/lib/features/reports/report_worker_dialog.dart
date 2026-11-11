import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/image_watermark_helper.dart';
import '../../core/utils/uuid_helper.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/camera_capture_modal.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/incident_report_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

Future<void> showReportWorkerDialog(BuildContext context, WidgetRef ref) async {
  final peerWorkers = await ref.read(peerWorkersProvider.future);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _ReportWorkerDialogContent(peerWorkers: peerWorkers),
  );
}

class _ReportWorkerDialogContent extends ConsumerStatefulWidget {
  final List<UserModel> peerWorkers;

  const _ReportWorkerDialogContent({
    required this.peerWorkers,
  });

  @override
  ConsumerState<_ReportWorkerDialogContent> createState() => _ReportWorkerDialogContentState();
}

class _ReportWorkerDialogContentState extends ConsumerState<_ReportWorkerDialogContent> {
  final TextEditingController _descController = TextEditingController();
  UserModel? _selectedWorker;
  String _selectedIssue = 'Not Working / Idle';
  String? _attachedProofPath;
  bool _isSubmitting = false;

  final List<String> _issueTypes = const [
    'Not Working / Idle',
    'Outside Assigned Area',
    'Poor Performance / Abandonment',
    'Misconduct / Insubordination',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.peerWorkers.isNotEmpty) {
      _selectedWorker = widget.peerWorkers.first;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleAttachProof(AppLanguage lang) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                lang == AppLanguage.cebuano ? 'Pilia ang gigikanan sa litrato' : 'Select Photo Source',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryNavy),
              title: Text(lang == AppLanguage.cebuano ? 'Pagkuha og Litrato (Kamera)' : 'Take Photo (Camera)'),
              subtitle: Text(lang == AppLanguage.cebuano ? 'Adunay live preview' : 'Live camera preview'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.accentBlue),
              title: Text(lang == AppLanguage.cebuano ? 'Pili gikan sa Gallery' : 'Choose from Gallery'),
              subtitle: Text(lang == AppLanguage.cebuano ? 'I-upload ang litrato gikan sa cellphone' : 'Select photo from device storage'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final currentUser = ref.read(currentUserProvider).value;
      final area = ref.read(assignedWorkAreaProvider).value;

      double lat = 11.0050;
      double lng = 124.6075;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (locErr) {
        debugPrint('Location fetch notice: $locErr');
      }

      Uint8List? rawBytes;

      if (source == 'camera') {
        if (!mounted) return;
        final capturedPath = await showCameraCaptureModal(
          context,
          title: lang == AppLanguage.cebuano ? 'Pagkuha og Patunay' : 'Capture Incident Proof',
        );
        if (capturedPath != null && File(capturedPath).existsSync()) {
          rawBytes = await File(capturedPath).readAsBytes();
        }
      } else if (source == 'gallery') {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty && result.first.path != null) {
          final f = File(result.first.path!);
          final sizeInBytes = await f.length();
          if (sizeInBytes > 10 * 1024 * 1024) {
            if (mounted) {
              ToastNotification.showWarning(context, 'Image exceeds maximum allowed size of 10 MB.');
            }
            return;
          }
          rawBytes = await f.readAsBytes();
        }
      }

      if (rawBytes != null && mounted) {
        final watermarked = ImageWatermarkHelper.burnWatermark(
          rawImageBytes: rawBytes,
          latitude: lat,
          longitude: lng,
          workerName: currentUser?.fullName ?? '',
          workAreaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
          timestamp: DateTime.now(),
        );

        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/incident_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(watermarked);

        setState(() => _attachedProofPath = filePath);
        if (mounted) {
          ToastNotification.showSuccess(
            context,
            lang == AppLanguage.cebuano ? 'Nalukop ang litrato.' : 'Photo attached successfully.',
          );
        }
      }
    } catch (err) {
      debugPrint('Error attaching proof photo: $err');
      if (mounted) {
        ToastNotification.showError(
          context,
          lang == AppLanguage.cebuano
              ? 'Adunay problema sa paglakip sa litrato: $err'
              : 'Failed to attach photo: $err',
        );
      }
    }
  }

  Future<void> _handleSubmit(AppLanguage lang) async {
    final description = _descController.text.trim();
    if (description.isEmpty) {
      ToastNotification.showWarning(
        context,
        lang == AppLanguage.cebuano
            ? 'Palihog isulat ang deskripsyon sa problema.'
            : 'Please provide a description of the incident.',
      );
      return;
    }

    if (_selectedWorker == null) {
      ToastNotification.showWarning(
        context,
        lang == AppLanguage.cebuano
            ? 'Palihog pagpili og trabahante nga i-report.'
            : 'Please select a worker to report.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      final area = ref.read(assignedWorkAreaProvider).value;

      String? cloudImageUrl;
      if (_attachedProofPath != null && File(_attachedProofPath!).existsSync()) {
        final bytes = await File(_attachedProofPath!).readAsBytes();
        cloudImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final report = IncidentReportModel(
        reportId: UuidHelper.generate(),
        reporterId: currentUser?.userId ?? '',
        reporterName: currentUser?.fullName ?? '',
        reportedId: _selectedWorker!.userId,
        reportedName: _selectedWorker!.fullName,
        workareaId: area?.workareaId,
        areaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
        issueType: _selectedIssue,
        description: description,
        imageUrl: cloudImageUrl ?? _attachedProofPath,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await ref.read(incidentReportListProvider.notifier).submit(report);

      if (mounted) {
        Navigator.pop(context);
        ToastNotification.showSuccess(
          context,
          lang == AppLanguage.cebuano
              ? 'Napadala na ang imong taho sa Supervisor.'
              : 'Incident report submitted to supervisor.',
        );
      }
    } catch (e) {
      debugPrint('Error submitting incident report: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastNotification.showError(
          context,
          lang == AppLanguage.cebuano
              ? 'Napakyas ang pagpadala sa taho: $e'
              : 'Failed to submit report: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: (availableHeight - 32).clamp(200.0, double.infinity),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: AppColors.dangerRed, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == AppLanguage.cebuano ? 'I-report ang Trabahante' : 'Report Worker Issue',
                          style: const TextStyle(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lang == AppLanguage.cebuano ? 'Opisyal nga taho sa Supervisor' : 'Official report to ENRO supervisor',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),

              // Dynamic Scrollable Body including Form & Actions
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Worker Selection
                      Text(
                        lang == AppLanguage.cebuano ? 'Pilia ang Trabahante' : 'Select Worker',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<UserModel>(
                        initialValue: _selectedWorker,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        hint: Text(
                          widget.peerWorkers.isEmpty
                              ? (lang == AppLanguage.cebuano ? 'Walay kaubang trabahante nakita' : 'No peer workers found')
                              : (lang == AppLanguage.cebuano ? 'Pili og trabahante' : 'Choose a worker'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        items: widget.peerWorkers.map((w) {
                          return DropdownMenuItem<UserModel>(
                            value: w,
                            child: Text(
                              w.fullName,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) setState(() => _selectedWorker = val);
                              },
                      ),
                      const SizedBox(height: 14),

                      // Issue Type
                      Text(
                        lang == AppLanguage.cebuano ? 'Klase sa Problema / Issue Type' : 'Issue Type',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedIssue,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _issueTypes.map((issue) {
                          return DropdownMenuItem(
                            value: issue,
                            child: Text(issue, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) setState(() => _selectedIssue = val);
                              },
                      ),
                      const SizedBox(height: 14),

                      // Description
                      Text(
                        lang == AppLanguage.cebuano ? 'Deskripsyon (Gikinahanglan)' : 'Incident Description (Required)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descController,
                        maxLines: 3,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          hintText: lang == AppLanguage.cebuano
                              ? 'Ipatin-aw ang nahitabo, oras, ug dapit...'
                              : 'Describe what occurred, time, and specific location...',
                          hintStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Proof Attachment
                      Text(
                        lang == AppLanguage.cebuano ? 'Ebidensya o Litrato (Optional)' : 'Proof Attachment (Optional)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),

                      if (_attachedProofPath != null && File(_attachedProofPath!).existsSync()) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(_attachedProofPath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 32),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lang == AppLanguage.cebuano ? 'Patunay nga Litrato' : 'Photo Proof Attached',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 20),
                                tooltip: 'Remove photo',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(() => _attachedProofPath = null),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: AppColors.primaryNavy),
                          ),
                          onPressed: _isSubmitting ? null : () => _handleAttachProof(lang),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primaryNavy),
                          label: Text(
                            lang == AppLanguage.cebuano ? 'Pagpili og Litrato / Ebidensya' : 'Attach Proof Photo',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 14),

                      // Responsive Action Buttons (always scrollable, never cut off)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                              child: Text(
                                lang == AppLanguage.cebuano ? 'Kanselahon' : 'Cancel',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: AppButton(
                              label: lang == AppLanguage.cebuano ? 'Ipadala ang Taho' : 'Submit Report',
                              variant: AppButtonVariant.danger,
                              isLoading: _isSubmitting,
                              onPressed: () => _handleSubmit(lang),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

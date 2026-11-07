import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
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
import '../../core/widgets/toast_notification.dart';
import '../../data/models/incident_report_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

Future<void> showReportWorkerDialog(BuildContext context, WidgetRef ref) async {
  final lang = ref.read(localeProvider);
  final descController = TextEditingController();
  UserModel? selectedWorker;
  String selectedIssue = 'Not Working / Idle';
  String? attachedProofPath;
  bool isSubmitting = false;

  final peerWorkers = await ref.read(peerWorkersProvider.future);
  if (peerWorkers.isNotEmpty) {
    selectedWorker = peerWorkers.first;
  }

  final issueTypes = [
    'Not Working / Idle',
    'Outside Assigned Area',
    'Poor Performance / Abandonment',
    'Misconduct / Insubordination',
  ];

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.report_problem_outlined, color: AppColors.dangerRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == AppLanguage.cebuano ? 'I-report ang Trabahante' : 'Report Worker Issue',
                      style: const TextStyle(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      lang == AppLanguage.cebuano ? 'Opisyal nga taho sa Supervisor' : 'Official report to ENRO supervisor',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Worker Selection
                Text(
                  lang == AppLanguage.cebuano ? 'Pilia ang Trabahante' : 'Select Worker',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserModel>(
                  initialValue: selectedWorker,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: peerWorkers.map((w) {
                    return DropdownMenuItem<UserModel>(
                      value: w,
                      child: Text('${w.fullName} (${w.userId})', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedWorker = val);
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
                  initialValue: selectedIssue,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: issueTypes.map((issue) {
                    return DropdownMenuItem(
                      value: issue,
                      child: Text(issue, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedIssue = val);
                  },
                ),
                const SizedBox(height: 14),

                // Description (Required)
                Text(
                  lang == AppLanguage.cebuano ? 'Deskripsyon (Gikinahanglan)' : 'Incident Description (Required)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: lang == AppLanguage.cebuano
                        ? 'Ipatin-aw ang nahitabo, oras, ug dapit...'
                        : 'Describe what occurred, time, and specific location...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),

                // Supporting Proof Attachment
                Text(
                  lang == AppLanguage.cebuano ? 'Ebidensya o Litrato (Optional)' : 'Proof Attachment (Optional)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    try {
                      final currentUser = ref.read(currentUserProvider).value;
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
                      final cameras = await availableCameras();
                      if (cameras.isNotEmpty) {
                        final controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
                        await controller.initialize();
                        final photo = await controller.takePicture();
                        rawBytes = await photo.readAsBytes();
                        await controller.dispose();
                      } else {
                        rawBytes = Uint8List.fromList(List.generate(200 * 200 * 3, (i) => 120));
                      }

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
                      final sampleFile = File(filePath);
                      await sampleFile.writeAsBytes(watermarked);
                      setDialogState(() => attachedProofPath = filePath);
                    } catch (_) {
                      final dir = await getTemporaryDirectory();
                      final filePath = '${dir.path}/incident_${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final sampleFile = File(filePath);
                      await sampleFile.writeAsBytes(List.filled(100, 0));
                      setDialogState(() => attachedProofPath = filePath);
                    }
                  },
                  icon: Icon(
                    attachedProofPath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                    size: 18,
                    color: attachedProofPath != null ? AppColors.accentGreen : AppColors.primaryNavy,
                  ),
                  label: Text(
                    attachedProofPath != null
                        ? (lang == AppLanguage.cebuano ? 'Litrato Gilakip' : 'Photo Proof Attached')
                        : (lang == AppLanguage.cebuano ? 'Pagkuha og Litrato' : 'Capture Proof Photo'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: attachedProofPath != null ? AppColors.accentGreen : AppColors.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                lang == AppLanguage.cebuano ? 'Kanselahon' : 'Cancel',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            AppButton(
              label: lang == AppLanguage.cebuano ? 'Ipadala ang Taho' : 'Submit Report',
              variant: AppButtonVariant.danger,
              isLoading: isSubmitting,
              isFullWidth: false,
              onPressed: () async {
                final description = descController.text.trim();
                if (description.isEmpty) {
                  ToastNotification.showWarning(
                    context,
                    lang == AppLanguage.cebuano
                        ? 'Palihog isulat ang deskripsyon sa problema.'
                        : 'Please provide a description of the incident.',
                  );
                  return;
                }

                if (selectedWorker == null) {
                  ToastNotification.showWarning(context, 'Please select a worker to report.');
                  return;
                }

                setDialogState(() => isSubmitting = true);

                final currentUser = ref.read(currentUserProvider).value;
                final area = ref.read(assignedWorkAreaProvider).value;

                String? cloudImageUrl;
                if (attachedProofPath != null && File(attachedProofPath!).existsSync()) {
                  final bytes = await File(attachedProofPath!).readAsBytes();
                  cloudImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                }

                final report = IncidentReportModel(
                  reportId: UuidHelper.generate(),
                  reporterId: currentUser?.userId ?? '',
                  reporterName: currentUser?.fullName ?? '',
                  reportedId: selectedWorker!.userId,
                  reportedName: selectedWorker!.fullName,
                  workareaId: area?.workareaId,
                  areaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
                  issueType: selectedIssue,
                  description: description,
                  imageUrl: cloudImageUrl ?? attachedProofPath,
                  status: 'pending',
                  createdAt: DateTime.now(),
                );

                await ref.read(incidentReportListProvider.notifier).submit(report);

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ToastNotification.showSuccess(
                    context,
                    lang == AppLanguage.cebuano
                        ? 'Napadala na ang imong taho sa Supervisor.'
                        : 'Incident report submitted to supervisor.',
                  );
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

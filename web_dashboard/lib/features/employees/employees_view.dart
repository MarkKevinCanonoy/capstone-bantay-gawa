import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/web_camera_helper.dart';
import '../../core/utils/uuid_helper.dart';
import '../../core/utils/biometrics_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';
import 'widgets/web_camera_dialog.dart';

class EmployeesView extends ConsumerStatefulWidget {
  const EmployeesView({super.key});

  @override
  ConsumerState<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends ConsumerState<EmployeesView> {
  String _selectedAreaFilter = 'all';
  bool _showAdmins = false;

  void _showAddEmployeeDialog() {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final usernameController = TextEditingController();
    final contactController = TextEditingController();
    UserRole role = UserRole.worker;
    String shiftPreset = 'AM';
    String shiftStartTime = '06:00';
    String shiftEndTime = '11:00';
    String shiftDays = 'Mon-Fri';
    bool isCustomShift = false;
    final shiftStartController = TextEditingController(text: '06:00');
    final shiftEndController = TextEditingController(text: '11:00');
    final shiftDaysController = TextEditingController(text: 'Mon-Fri');

    bool faceCaptured = false;
    String? faceEmbedding;
    Uint8List? capturedImageBytes;
    String? captureSource;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              child: Container(
                width: 680,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Title & Close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Register New Personnel',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Create a system account with facial biometric enrollment and credential token.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 20),

                      // First & Last Name Side by Side
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('First Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(' *', style: TextStyle(color: AppColors.brightRed)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: firstController,
                                  decoration: const InputDecoration(hintText: 'e.g. Juan'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('Last Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(' *', style: TextStyle(color: AppColors.brightRed)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: lastController,
                                  decoration: const InputDecoration(hintText: 'e.g. Dela Cruz'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Username & Contact Number Side by Side
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('Email / Username', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(' *', style: TextStyle(color: AppColors.brightRed)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: usernameController,
                                  decoration: const InputDecoration(hintText: 'e.g. employee@gmail.com'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Contact Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(controller: contactController, decoration: const InputDecoration(hintText: '+63 918 000 0000')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown with Clean Padding and Icons
                      const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserRole>(
                            value: role,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(
                                value: UserRole.worker,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.badge_outlined, size: 16, color: AppColors.textMuted),
                                      SizedBox(width: 10),
                                      Text('Field Worker'),
                                    ],
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: UserRole.supervisor,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.textMuted),
                                      SizedBox(width: 10),
                                      Text('Field Supervisor'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => role = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Shift Schedule Selection for Field Workers (SRS FR-12)
                      if (role == UserRole.worker) ...[
                        const Row(
                          children: [
                            Text('Assigned Shift Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(' *', style: TextStyle(color: AppColors.brightRed)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    shiftPreset = 'AM';
                                    isCustomShift = false;
                                    shiftStartTime = '06:00';
                                    shiftEndTime = '11:00';
                                    shiftDays = 'Mon-Fri';
                                    shiftStartController.text = shiftStartTime;
                                    shiftEndController.text = shiftEndTime;
                                    shiftDaysController.text = shiftDays;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: shiftPreset == 'AM' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                    border: Border.all(
                                      color: shiftPreset == 'AM' ? AppColors.accentBlue : AppColors.border,
                                      width: shiftPreset == 'AM' ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.wb_sunny_outlined, size: 18, color: shiftPreset == 'AM' ? AppColors.accentBlue : AppColors.textMuted),
                                      const SizedBox(height: 4),
                                      const Text('Morning (AM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      const Text('06:00 - 11:00', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    shiftPreset = 'PM';
                                    isCustomShift = false;
                                    shiftStartTime = '13:00';
                                    shiftEndTime = '17:00';
                                    shiftDays = 'Mon-Fri';
                                    shiftStartController.text = shiftStartTime;
                                    shiftEndController.text = shiftEndTime;
                                    shiftDaysController.text = shiftDays;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: shiftPreset == 'PM' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                    border: Border.all(
                                      color: shiftPreset == 'PM' ? AppColors.accentBlue : AppColors.border,
                                      width: shiftPreset == 'PM' ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.wb_twilight_outlined, size: 18, color: shiftPreset == 'PM' ? AppColors.accentBlue : AppColors.textMuted),
                                      const SizedBox(height: 4),
                                      const Text('Afternoon (PM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      const Text('13:00 - 17:00', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    shiftPreset = 'Full';
                                    isCustomShift = false;
                                    shiftStartTime = '08:00';
                                    shiftEndTime = '17:00';
                                    shiftDays = 'Mon-Fri';
                                    shiftStartController.text = shiftStartTime;
                                    shiftEndController.text = shiftEndTime;
                                    shiftDaysController.text = shiftDays;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: shiftPreset == 'Full' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                    border: Border.all(
                                      color: shiftPreset == 'Full' ? AppColors.accentBlue : AppColors.border,
                                      width: shiftPreset == 'Full' ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.apartment_outlined, size: 18, color: shiftPreset == 'Full' ? AppColors.accentBlue : AppColors.textMuted),
                                      const SizedBox(height: 4),
                                      const Text('Whole Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      const Text('08:00 - 17:00', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              isCustomShift = !isCustomShift;
                              if (isCustomShift) shiftPreset = 'Custom';
                            });
                          },
                          child: Row(
                            children: [
                              Icon(isCustomShift ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 16, color: AppColors.accentBlue),
                              const SizedBox(width: 6),
                              const Text('Custom Hours & Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (isCustomShift) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(controller: shiftStartController, decoration: const InputDecoration(hintText: 'Start (06:00)', isDense: true)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(controller: shiftEndController, decoration: const InputDecoration(hintText: 'End (11:00)', isDense: true)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(controller: shiftDaysController, decoration: const InputDecoration(hintText: 'Days (Mon-Fri)', isDense: true)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: faceCaptured ? AppColors.successBg : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: faceCaptured ? AppColors.accentEmerald : AppColors.border,
                            width: faceCaptured ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      faceCaptured ? Icons.check_circle_rounded : Icons.face_retouching_natural_rounded,
                                      size: 18,
                                      color: faceCaptured ? AppColors.successText : AppColors.accentBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Biometric Facial Enrollment',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                StatusBadge(
                                  label: faceCaptured ? 'FACE ENROLLED' : 'PENDING CAPTURE',
                                  type: faceCaptured ? BadgeType.success : BadgeType.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              faceCaptured
                                  ? 'Face photo verified and enrolled from $captureSource.'
                                  : 'Capture using your webcam (laptop / USB) or upload a portrait image file (.jpg, .png, .webp).',
                              style: TextStyle(
                                fontSize: 12,
                                color: faceCaptured ? AppColors.successText : AppColors.textMuted,
                              ),
                            ),
                            if (capturedImageBytes != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      capturedImageBytes!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Verified Face Photo',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Source: $captureSource',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.videocam_rounded, size: 15),
                                  label: Text(faceCaptured && captureSource == 'Webcam' ? 'Retake via Webcam' : 'Use Webcam (Laptop / USB)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final bytes = await WebCameraDialog.show(context);
                                    if (bytes != null && bytes.isNotEmpty) {
                                      final vector = BiometricsHelper.extractFeatureVector(bytes);
                                      final embeddingString = BiometricsHelper.formatEmbeddingString(vector);
                                      setDialogState(() {
                                        faceCaptured = true;
                                        capturedImageBytes = bytes;
                                        captureSource = 'Webcam';
                                        faceEmbedding = embeddingString;
                                      });
                                      if (context.mounted) {
                                        ToastNotification.show(context, message: 'Face photo captured and verified successfully.', type: ToastType.success);
                                      }
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_file_rounded, size: 15),
                                  label: const Text('Upload Image File'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(color: AppColors.border),
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    final bytes = await WebCameraHelper.pickImageFile(
                                      onError: (msg) {
                                        if (context.mounted) {
                                          ToastNotification.show(context, message: msg, type: ToastType.error);
                                        }
                                      },
                                    );
                                    if (bytes != null && bytes.isNotEmpty) {
                                      final vector = BiometricsHelper.extractFeatureVector(bytes);
                                      final embeddingString = BiometricsHelper.formatEmbeddingString(vector);
                                      setDialogState(() {
                                        faceCaptured = true;
                                        capturedImageBytes = bytes;
                                        captureSource = 'File Upload';
                                        faceEmbedding = embeddingString;
                                      });
                                      if (context.mounted) {
                                        ToastNotification.show(context, message: 'Face photo uploaded and verified successfully.', type: ToastType.success);
                                      }
                                    }
                                  },
                                ),
                                if (faceCaptured)
                                  TextButton.icon(
                                    icon: const Icon(Icons.close, size: 14, color: AppColors.brightRed),
                                    label: const Text('Clear', style: TextStyle(color: AppColors.brightRed, fontSize: 12)),
                                    onPressed: () {
                                      setDialogState(() {
                                        faceCaptured = false;
                                        capturedImageBytes = null;
                                        captureSource = null;
                                        faceEmbedding = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dialog Buttons: Cancel on Left, Register on Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: ButtonVariant.outline,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                          ),
                          AppButton(
                            label: isSubmitting ? 'Registering...' : 'Register & Enroll Account',
                            variant: ButtonVariant.primary,
                            isLoading: isSubmitting,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (firstController.text.trim().isEmpty || lastController.text.trim().isEmpty) {
                                      ToastNotification.show(context, message: 'Please fill in required name fields.', type: ToastType.error);
                                      return;
                                    }

                                    if (usernameController.text.trim().isEmpty) {
                                      ToastNotification.show(context, message: 'Please enter an email or username.', type: ToastType.error);
                                      return;
                                    }

                                    final generatedQrToken = 'BW-ORMC-${DateTime.now().millisecondsSinceEpoch}';
                                    final newUserId = UuidHelper.generate();

                                    String? finalEmbedding = faceEmbedding;
                                    if (finalEmbedding == null && capturedImageBytes != null && capturedImageBytes!.isNotEmpty) {
                                      final vector = BiometricsHelper.extractFeatureVector(capturedImageBytes!);
                                      finalEmbedding = BiometricsHelper.formatEmbeddingString(vector);
                                    }

                                    final newUser = UserModel(
                                      userId: newUserId,
                                      username: usernameController.text.trim().toLowerCase(),
                                      firstName: firstController.text.trim(),
                                      lastName: lastController.text.trim(),
                                      contactNumber: contactController.text.trim().isNotEmpty ? contactController.text.trim() : '+63 900 000 0000',
                                      qrToken: generatedQrToken,
                                      role: role,
                                      status: role == UserRole.supervisor ? 'pending' : 'active',
                                      assignedAreaId: null,
                                      assignedAreaName: 'Unassigned',
                                      faceEmbedding: finalEmbedding,
                                      photoUrl: capturedImageBytes != null
                                          ? 'data:image/jpeg;base64,${base64Encode(capturedImageBytes!)}'
                                          : null,
                                      schedule: role == UserRole.worker
                                          ? (isCustomShift
                                              ? '${shiftDaysController.text.trim().isNotEmpty ? shiftDaysController.text.trim() : "Mon-Fri"} ${shiftStartController.text.trim().isNotEmpty ? shiftStartController.text.trim() : "06:00"} - ${shiftEndController.text.trim().isNotEmpty ? shiftEndController.text.trim() : "11:00"}'
                                              : '$shiftDays $shiftStartTime - $shiftEndTime')
                                          : 'Unassigned',
                                      creditScore: 100,
                                    );

                                    setDialogState(() => isSubmitting = true);
                                    try {
                                      await ref.read(dataRepositoryProvider).addUser(newUser);
                                      ref.invalidate(employeesProvider);
                                      ref.invalidate(supervisorsProvider);
                                      ref.invalidate(workAreasProvider);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        ToastNotification.show(
                                          context,
                                          message: 'Personnel ${newUser.fullName} registered successfully!',
                                          type: ToastType.success,
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Registration error: $e');
                                      if (context.mounted) {
                                        setDialogState(() => isSubmitting = false);
                                        ToastNotification.show(
                                          context,
                                          message: 'Registration failed: ${e.toString().replaceAll("Exception: ", "")}',
                                          type: ToastType.error,
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmployeeDetailsModal(UserModel emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryNavy,
              child: Text(emp.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('@${emp.username} • ${emp.roleDisplayName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Assigned Area', emp.assignedAreaName ?? 'Unassigned'),
              _buildDetailRow('Contact Number', emp.contactNumber),
              _buildDetailRow('Account Status', emp.status.toUpperCase()),
              if (emp.role == UserRole.worker) ...[
                const SizedBox(height: 12),
                const Text('Workforce Standing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: emp.creditScore >= 80
                        ? AppColors.successBg
                        : emp.creditScore >= 50
                            ? AppColors.warningBg
                            : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            emp.creditScore >= 80
                                ? Icons.verified_user_rounded
                                : emp.creditScore >= 50
                                    ? Icons.warning_amber_rounded
                                    : Icons.error_outline_rounded,
                            size: 18,
                            color: emp.creditScore >= 80
                                ? AppColors.successText
                                : emp.creditScore >= 50
                                    ? AppColors.warningText
                                    : AppColors.dangerText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            emp.creditScore >= 80
                                ? 'Good Standing'
                                : emp.creditScore >= 50
                                    ? 'Under Review'
                                    : 'Disciplinary Action',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: emp.creditScore >= 80
                                  ? AppColors.successText
                                  : emp.creditScore >= 50
                                      ? AppColors.warningText
                                      : AppColors.dangerText,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        emp.creditScore >= 80
                            ? 'ACTIVE & COMPLIANT'
                            : emp.creditScore >= 50
                                ? 'POLICY REVIEW REQUIRED'
                                : 'CRITICAL NON-COMPLIANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: emp.creditScore >= 80
                              ? AppColors.successText
                              : emp.creditScore >= 50
                                  ? AppColors.warningText
                                  : AppColors.dangerText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text('Biometric Facial Enrollment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: emp.faceEmbedding != null ? AppColors.successBg : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: emp.faceEmbedding != null ? AppColors.accentEmerald.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      emp.faceEmbedding != null ? Icons.verified_user_rounded : Icons.face_retouching_natural_rounded,
                      size: 28,
                      color: emp.faceEmbedding != null ? AppColors.accentEmerald : AppColors.warningText,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.faceEmbedding != null ? 'Face Biometrics Enrolled' : 'Pending Facial Enrollment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: emp.faceEmbedding != null ? AppColors.successText : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emp.faceEmbedding != null
                                ? 'Facial biometric template is verified and registered in the system.'
                                : 'No biometric facial template has been enrolled for this account.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final employees = employeesAsync.value ?? [];
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;

    final totalAdmins = employees.where((u) => u.role == UserRole.admin).length;
    final selectedWorkArea = _selectedAreaFilter == 'all'
        ? null
        : workAreas.where((a) => a.workareaId == _selectedAreaFilter).firstOrNull;

    final filteredEmployees = employees.where((emp) {
      // 1. Role / Visibility filtering:
      // Supervisors can never see Admins and only see workers in their assigned sectors (specs/roles_matrix.md, UC-01)
      if (currentUser.role == UserRole.supervisor) {
        if (emp.role == UserRole.admin) return false;
        if (emp.role == UserRole.supervisor && emp.userId != currentUser.userId) {
          return false;
        }
        final isAssignedToSupervisor = workAreas.any((a) =>
            a.workareaId == emp.assignedAreaId ||
            (emp.assignedAreaName != null && a.name.toLowerCase() == emp.assignedAreaName!.toLowerCase()) ||
            (emp.role == UserRole.supervisor && emp.userId == currentUser.userId));
        if (!isAssignedToSupervisor) return false;
      }
      // Admins can toggle showing other admins; hidden by default
      if (currentUser.role == UserRole.admin && !_showAdmins && emp.role == UserRole.admin) {
        return false;
      }

      // 2. Global search matching:
      final supervisorArea = workAreas.where((a) =>
        a.supervisorId == emp.userId ||
        (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == emp.fullName.toLowerCase()) ||
        a.workareaId == emp.assignedAreaId,
      ).firstOrNull;
      final displayAreaName = (emp.assignedAreaName != null && emp.assignedAreaName != 'Unassigned')
          ? emp.assignedAreaName!
          : (supervisorArea?.name ?? '');

      final matchesSearch = emp.fullName.toLowerCase().contains(globalSearch) ||
          emp.username.toLowerCase().contains(globalSearch) ||
          displayAreaName.toLowerCase().contains(globalSearch);

      if (!matchesSearch) return false;

      // 3. Area filtering:
      if (_selectedAreaFilter == 'all') {
        return true;
      }

      final matchesDirectArea = emp.assignedAreaId == _selectedAreaFilter ||
          (selectedWorkArea != null && emp.assignedAreaName == selectedWorkArea.name);

      final matchesSupervisorArea = emp.role == UserRole.supervisor &&
          selectedWorkArea != null &&
          ((selectedWorkArea.supervisorId != null && selectedWorkArea.supervisorId == emp.userId) ||
           (selectedWorkArea.supervisorName.isNotEmpty && selectedWorkArea.supervisorName.toLowerCase() == emp.fullName.toLowerCase()) ||
           emp.assignedAreaId == selectedWorkArea.workareaId);

      return matchesDirectArea || matchesSupervisorArea;
    }).toList();

    // Priority sorting: Supervisor always on top (#1), followed by workers, then admins
    filteredEmployees.sort((a, b) {
      final aIsSup = a.role == UserRole.supervisor;
      final bIsSup = b.role == UserRole.supervisor;
      if (aIsSup && !bIsSup) return -1;
      if (!aIsSup && bIsSup) return 1;

      final aIsAdmin = a.role == UserRole.admin;
      final bIsAdmin = b.role == UserRole.admin;
      if (aIsAdmin && !bIsAdmin) return 1;
      if (!aIsAdmin && bIsAdmin) return -1;

      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personnel Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    currentUser.role == UserRole.admin
                        ? 'Manage all field workers, supervisors, face registrations, and workforce standing.'
                        : 'Field staff assigned to your supervisory sector.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              if (currentUser.role == UserRole.admin)
                AppButton(
                  label: '+ Add Personnel',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: _showAddEmployeeDialog,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Bar
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.accentBlue),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredEmployees.length} registered personnel',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentUser.role == UserRole.admin) ...[
                      InkWell(
                        onTap: () => setState(() => _showAdmins = !_showAdmins),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _showAdmins ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showAdmins ? AppColors.accentBlue : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showAdmins ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                                size: 15,
                                color: _showAdmins ? AppColors.accentBlue : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showAdmins ? 'Hide Admins' : 'Show Admins ($totalAdmins)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _showAdmins ? AppColors.accentBlue : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.tune_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Filter by Area:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: workAreas.any((a) => a.workareaId == _selectedAreaFilter) || _selectedAreaFilter == 'all'
                              ? _selectedAreaFilter
                              : 'all',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(currentUser.role == UserRole.supervisor ? 'All Assigned Sectors' : 'All Work Areas'),
                            ),
                            ...workAreas.map((a) => DropdownMenuItem(value: a.workareaId, child: Text(a.name))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedAreaFilter = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Directory Table (Stretched across full width)
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: filteredEmployees.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.people_outline_rounded, size: 32, color: AppColors.textLight),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No personnel records found',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try adjusting your search query or area filter.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const minWidth = 850.0;
                        final isWide = constraints.maxWidth >= minWidth;

                        Widget tableWidget = Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(2.6), // PERSONNEL
                            1: FlexColumnWidth(1.6), // ROLE
                            2: FlexColumnWidth(2.0), // ASSIGNED AREA
                            3: FlexColumnWidth(1.4), // WORKFORCE STANDING
                            4: FlexColumnWidth(1.0), // ACTIONS
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  bottom: BorderSide(color: AppColors.border, width: 1.5),
                                ),
                              ),
                              children: [
                                _buildHeaderCell('PERSONNEL'),
                                _buildHeaderCell('ROLE'),
                                _buildHeaderCell('ASSIGNED AREA'),
                                _buildHeaderCell('WORKFORCE STANDING'),
                                _buildHeaderCell('ACTIONS'),
                              ],
                            ),
                            ...filteredEmployees.map((emp) {
                              final isSupervisor = emp.role == UserRole.supervisor;
                              final supervisorArea = workAreas.where((a) =>
                                a.supervisorId == emp.userId ||
                                (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == emp.fullName.toLowerCase()) ||
                                a.workareaId == emp.assignedAreaId,
                              ).firstOrNull;
                              final displayAreaName = (emp.assignedAreaName != null && emp.assignedAreaName != 'Unassigned')
                                  ? emp.assignedAreaName!
                                  : (supervisorArea?.name ?? 'Unassigned');

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isSupervisor ? const Color(0xFFF0FDF4) : null,
                                  border: const Border(
                                    bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSupervisor ? AppColors.accentEmerald : AppColors.border,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 15,
                                            backgroundColor: isSupervisor ? AppColors.accentEmerald : AppColors.primaryNavy,
                                            child: Text(
                                              emp.initials,
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      emp.fullName,
                                                      style: TextStyle(
                                                        fontWeight: isSupervisor ? FontWeight.w800 : FontWeight.w700,
                                                        fontSize: 13,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (emp.faceEmbedding != null) ...[
                                                    const SizedBox(width: 6),
                                                    Tooltip(
                                                      message: 'Facial Biometric Enrolled',
                                                      child: Container(
                                                        padding: const EdgeInsets.all(2),
                                                        decoration: const BoxDecoration(
                                                          color: AppColors.successBg,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(Icons.verified_rounded, size: 13, color: AppColors.accentEmerald),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                emp.contactNumber,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: emp.roleDisplayName,
                                        type: emp.role == UserRole.admin
                                            ? BadgeType.optimal
                                            : emp.role == UserRole.supervisor
                                                ? BadgeType.success
                                                : BadgeType.neutral,
                                        icon: emp.role == UserRole.supervisor
                                            ? Icons.shield_outlined
                                            : emp.role == UserRole.admin
                                                ? Icons.admin_panel_settings_outlined
                                                : null,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: displayAreaName != 'Unassigned' ? AppColors.accentBlue : AppColors.textLight,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            displayAreaName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSupervisor ? FontWeight.w600 : FontWeight.w500,
                                              color: displayAreaName != 'Unassigned' ? AppColors.textPrimary : AppColors.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: emp.role == UserRole.worker
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: emp.creditScore >= 80
                                                    ? AppColors.successBg
                                                    : emp.creditScore >= 50
                                                        ? AppColors.warningBg
                                                        : AppColors.dangerBg,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: emp.creditScore >= 80
                                                      ? AppColors.accentEmerald.withValues(alpha: 0.25)
                                                      : emp.creditScore >= 50
                                                          ? AppColors.warningText.withValues(alpha: 0.25)
                                                          : AppColors.dangerText.withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    emp.creditScore >= 80
                                                        ? Icons.check_circle_outline
                                                        : emp.creditScore >= 50
                                                            ? Icons.warning_amber_rounded
                                                            : Icons.error_outline_rounded,
                                                    size: 13,
                                                    color: emp.creditScore >= 80
                                                        ? AppColors.successText
                                                        : emp.creditScore >= 50
                                                            ? AppColors.warningText
                                                            : AppColors.dangerText,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    emp.creditScore >= 80
                                                        ? 'Good Standing'
                                                        : emp.creditScore >= 50
                                                            ? 'Under Review'
                                                            : 'Action Required',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: emp.creditScore >= 80
                                                          ? AppColors.successText
                                                          : emp.creditScore >= 50
                                                              ? AppColors.warningText
                                                              : AppColors.dangerText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const Text(
                                              '—',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.accentBlue),
                                            tooltip: 'View Profile',
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _showEmployeeDetailsModal(emp),
                                          ),
                                        ),
                                        if (currentUser.role == UserRole.admin) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.dangerBg.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.dangerBg),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.brightRed),
                                              tooltip: 'Delete User',
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                ConfirmationDialog.show(
                                                  context,
                                                  title: 'Delete User Account',
                                                  message: 'Are you sure you want to delete ${emp.fullName}? This will revoke system access.',
                                                  confirmLabel: 'Delete',
                                                  confirmVariant: ButtonVariant.danger,
                                                  onConfirm: () async {
                                                    await ref.read(dataRepositoryProvider).deleteUser(emp.userId);
                                                    ref.invalidate(employeesProvider);
                                                    ref.invalidate(supervisorsProvider);
                                                    ref.invalidate(workAreasProvider);
                                                    if (context.mounted) {
                                                      ToastNotification.show(context, message: 'User ${emp.fullName} removed.', type: ToastType.info);
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );

                        if (!isWide) {
                          tableWidget = SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: minWidth,
                              child: tableWidget,
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: tableWidget,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

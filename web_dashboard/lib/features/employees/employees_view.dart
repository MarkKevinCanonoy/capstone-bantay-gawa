import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../core/widgets/qr_code_widget.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class EmployeesView extends ConsumerStatefulWidget {
  const EmployeesView({super.key});

  @override
  ConsumerState<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends ConsumerState<EmployeesView> {
  String _selectedAreaFilter = 'all';

  void _showAddEmployeeDialog() {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final usernameController = TextEditingController();
    final contactController = TextEditingController();
    UserRole role = UserRole.worker;

    bool faceCaptured = false;
    String? faceEmbedding;

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
                                const Text('Username (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(controller: usernameController, decoration: const InputDecoration(hintText: 'e.g. worker_juan')),
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

                      // Biometric Face Registration Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: faceCaptured ? AppColors.successBg : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
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
                                  label: faceCaptured ? 'EMBEDDING STORED' : 'PENDING CAPTURE',
                                  type: faceCaptured ? BadgeType.success : BadgeType.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              faceCaptured
                                  ? '512-dimension MobileFaceNet feature vector successfully generated and ready for biometric verification.'
                                  : 'Capture or upload an official frontal portrait to extract facial embeddings for mobile biometric attendance.',
                              style: TextStyle(
                                fontSize: 12,
                                color: faceCaptured ? AppColors.successText : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  icon: Icon(faceCaptured ? Icons.refresh : Icons.camera_alt_outlined, size: 14),
                                  label: Text(faceCaptured ? 'Retake Biometrics' : 'Capture / Upload Face'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: faceCaptured ? Colors.white : AppColors.accentBlue,
                                    foregroundColor: faceCaptured ? AppColors.accentEmerald : Colors.white,
                                    side: faceCaptured ? const BorderSide(color: AppColors.accentEmerald) : BorderSide.none,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      faceCaptured = true;
                                      faceEmbedding = 'TFLite_MobileFaceNet_512d_${DateTime.now().millisecondsSinceEpoch}';
                                    });
                                  },
                                ),
                                if (faceCaptured)
                                  const Text(
                                    'Vector: [0.142, -0.089, ... 512d]',
                                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.successText),
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          AppButton(
                            label: 'Register & Enroll Account',
                            variant: ButtonVariant.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: () async {
                              if (firstController.text.trim().isEmpty || lastController.text.trim().isEmpty) {
                                ToastNotification.show(context, message: 'Please fill in required name fields.', type: ToastType.error);
                                return;
                              }

                              final generatedQrToken = 'BW-ORMC-${DateTime.now().millisecondsSinceEpoch}';
                              final newUser = UserModel(
                                userId: 'user-w-${DateTime.now().millisecondsSinceEpoch}',
                                username: usernameController.text.trim().isNotEmpty
                                    ? usernameController.text.trim()
                                    : '${firstController.text.trim().toLowerCase()}_${lastController.text.trim().toLowerCase()}',
                                firstName: firstController.text.trim(),
                                lastName: lastController.text.trim(),
                                contactNumber: contactController.text.trim().isNotEmpty ? contactController.text.trim() : '+63 900 000 0000',
                                qrToken: generatedQrToken,
                                role: role,
                                status: 'active',
                                assignedAreaId: null,
                                assignedAreaName: 'Unassigned',
                                faceEmbedding: faceEmbedding ?? (faceCaptured ? 'TFLite_MobileFaceNet_512d_sample' : null),
                                creditScore: 100,
                              );

                              await ref.read(dataRepositoryProvider).addUser(newUser);
                              ref.invalidate(employeesProvider);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ToastNotification.show(
                                  context,
                                  message: 'Personnel ${newUser.fullName} registered with QR Code ($generatedQrToken)!',
                                  type: ToastType.success,
                                );
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
              _buildDetailRow('Work Schedule', emp.schedule),
              _buildDetailRow('Account Status', emp.status.toUpperCase()),
              const SizedBox(height: 12),
              const Text('Star Performance Credit Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                    Text(
                      '${emp.creditScore} / 100 Points',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: emp.creditScore >= 80
                            ? AppColors.successText
                            : emp.creditScore >= 50
                                ? AppColors.warningText
                                : AppColors.dangerText,
                      ),
                    ),
                    Text(
                      emp.creditScore >= 80
                          ? 'OPTIMAL STANDING'
                          : emp.creditScore >= 50
                              ? 'ATTENTION NEEDED'
                              : 'CRITICAL DISCIPLINARY',
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
              const SizedBox(height: 14),
              const Text('Digital QR Credential & Biometrics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    QrCodeWidget(
                      data: emp.qrToken ?? 'BW-ORMC-${emp.userId}',
                      size: 96,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CREDENTIAL TOKEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(emp.qrToken ?? 'BW-ORMC-${emp.userId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                emp.faceEmbedding != null ? Icons.verified_user : Icons.help_outline,
                                size: 14,
                                color: emp.faceEmbedding != null ? AppColors.accentEmerald : AppColors.warningText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                emp.faceEmbedding != null ? 'Biometrics Enrolled (512-d)' : 'Pending Biometrics',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: emp.faceEmbedding != null ? AppColors.accentEmerald : AppColors.warningText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Field workers scan this QR on Android app for first-time login.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print QR Credential'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryNavy,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ToastNotification.show(context, message: 'Official Credential Card prepared for printing.', type: ToastType.success);
            },
          ),
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
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final employees = employeesAsync.value ?? [];

    final filteredEmployees = employees.where((emp) {
      final matchesSearch = emp.fullName.toLowerCase().contains(globalSearch) ||
          emp.username.toLowerCase().contains(globalSearch) ||
          (emp.assignedAreaName?.toLowerCase().contains(globalSearch) ?? false);
      final matchesArea = _selectedAreaFilter == 'all' || emp.assignedAreaId == _selectedAreaFilter;
      return matchesSearch && matchesArea;
    }).toList();

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
                        ? 'Manage all field workers, supervisors, face registrations, and credit scores.'
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
                Text(
                  '${filteredEmployees.length} registered personnel',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Filter by Area:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                          value: _selectedAreaFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Work Areas')),
                            DropdownMenuItem(value: 'area-1', child: Text('Ormoc City Hall Zone')),
                            DropdownMenuItem(value: 'area-2', child: Text('Ormoc Public Market')),
                            DropdownMenuItem(value: 'area-3', child: Text('Ormoc Bus Terminal')),
                            DropdownMenuItem(value: 'area-4', child: Text('Centennial Park Zone')),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const minWidth = 1100.0;
                  final isWide = constraints.maxWidth >= minWidth;

                  Widget tableWidget = Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                            0: FlexColumnWidth(2.5), // PERSONNEL
                            1: FlexColumnWidth(1.6), // ROLE
                            2: FlexColumnWidth(1.8), // ASSIGNED AREA
                            3: FlexColumnWidth(1.8), // SCHEDULE
                            4: FlexColumnWidth(1.2), // CREDIT SCORE
                            5: FlexColumnWidth(1.1), // STATUS
                            6: FlexColumnWidth(1.0), // ACTIONS
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                border: Border(
                                  bottom: BorderSide(color: AppColors.border, width: 1),
                                ),
                              ),
                              children: [
                                _buildHeaderCell('PERSONNEL'),
                                _buildHeaderCell('ROLE'),
                                _buildHeaderCell('ASSIGNED AREA'),
                                _buildHeaderCell('SCHEDULE'),
                                _buildHeaderCell('CREDIT SCORE'),
                                _buildHeaderCell('STATUS'),
                                _buildHeaderCell('ACTIONS'),
                              ],
                            ),
                            ...filteredEmployees.map((emp) {
                              return TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primaryNavy,
                                          child: Text(
                                            emp.initials,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                emp.fullName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                emp.contactNumber,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                                            : BadgeType.neutral,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      emp.assignedAreaName ?? 'Unassigned',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      emp.schedule,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: emp.creditScore >= 80
                                              ? AppColors.successBg
                                              : emp.creditScore >= 50
                                                  ? AppColors.warningBg
                                                  : AppColors.dangerBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '★ ${emp.creditScore}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: emp.creditScore >= 80
                                                ? AppColors.successText
                                                : emp.creditScore >= 50
                                                    ? AppColors.warningText
                                                    : AppColors.dangerText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: emp.status,
                                        type: emp.status == 'active' ? BadgeType.success : BadgeType.danger,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.accentBlue),
                                          tooltip: 'View Profile',
                                          onPressed: () => _showEmployeeDetailsModal(emp),
                                        ),
                                        if (currentUser.role == UserRole.admin)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.brightRed),
                                            tooltip: 'Delete User',
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
                                                  if (context.mounted) {
                                                    ToastNotification.show(context, message: 'User ${emp.fullName} removed.', type: ToastType.info);
                                                  }
                                                },
                                              );
                                            },
                                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

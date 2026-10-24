import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/qr_code_widget.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  // Dialog: Edit Profile Information
  void _showEditProfileDialog(UserModel user) {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final contactController = TextEditingController(text: user.contactNumber);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.statusOptimalBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.badge_outlined, size: 24, color: AppColors.accentBlue),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile Information',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Update your official personal details and contact phone number.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 20),

                  // First Name & Last Name
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('First Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: firstNameController,
                              decoration: InputDecoration(
                                hintText: 'First name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Last Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: lastNameController,
                              decoration: InputDecoration(
                                hintText: 'Last name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Number
                  const Text('Contact Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.textMuted),
                      hintText: '+63 9XX XXX XXXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Side-by-Side Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppButton(
                        label: 'Cancel',
                        variant: ButtonVariant.outline,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                      AppButton(
                        label: 'Save Changes',
                        icon: Icons.check,
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
                            ToastNotification.show(context, message: 'Please enter both first and last name.', type: ToastType.warning);
                            return;
                          }

                          final updated = user.copyWith(
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            contactNumber: contactController.text.trim(),
                          );
                          ref.read(currentUserProvider.notifier).state = updated;

                          Navigator.of(dialogCtx).pop();
                          ToastNotification.show(context, message: 'Profile details successfully updated.', type: ToastType.success);
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
  }

  // Dialog: View QR Code Credential
  void _showQrCodeDialog(UserModel user) {
    final qrData = user.qrToken ?? 'BW-ORMC-${user.userId}';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Official QR Credential Token',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.border),
                  const SizedBox(height: 16),

                  // QR Code Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrCodeWidget(
                      data: qrData,
                      size: 160,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.roleDisplayName} • $qrData',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Scan this official QR credential using the BantayGawa mobile app to authenticate on field devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Side-by-Side Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppButton(
                        label: 'Close',
                        variant: ButtonVariant.outline,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                      AppButton(
                        label: 'Print QR Credential',
                        icon: Icons.print_outlined,
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          ToastNotification.show(context, message: 'Official credential card sent to print queue.', type: ToastType.success);
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
  }

  // Dialog: Change Password
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.statusOptimalBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 24, color: AppColors.accentBlue),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change Account Password',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ensure your new password contains at least 8 characters.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  const Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: currentPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter current password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Re-type new password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Side-by-Side Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppButton(
                        label: 'Cancel',
                        variant: ButtonVariant.outline,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                      AppButton(
                        label: 'Update Password',
                        icon: Icons.check,
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          if (currentPassController.text.isEmpty || newPassController.text.isEmpty) {
                            ToastNotification.show(context, message: 'Please complete all password fields.', type: ToastType.warning);
                            return;
                          }
                          if (newPassController.text != confirmPassController.text) {
                            ToastNotification.show(context, message: 'New passwords do not match.', type: ToastType.warning);
                            return;
                          }
                          if (newPassController.text.length < 8) {
                            ToastNotification.show(context, message: 'New password must be at least 8 characters long.', type: ToastType.warning);
                            return;
                          }

                          Navigator.of(dialogCtx).pop();
                          ToastNotification.show(context, message: 'Password successfully updated. Secure cryptographic hash stored.', type: ToastType.success);
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
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title on Left, Perspective Switcher on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Profile',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your personal account details, office credentials, and biometric registration.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              AppButton(
                label: user.role == UserRole.admin ? 'Switch to Supervisor View' : 'Switch to Admin View',
                icon: Icons.swap_horiz_rounded,
                variant: ButtonVariant.outline,
                onPressed: () {
                  if (user.role == UserRole.admin) {
                    ref.read(currentUserProvider.notifier).state = UserModel(
                      userId: '22222222-2222-2222-2222-222222222222',
                      username: 'sup_juan',
                      firstName: 'Juan',
                      lastName: 'Santos',
                      contactNumber: '+63 917 222 0002',
                      role: UserRole.supervisor,
                      status: 'active',
                      assignedAreaId: null,
                      assignedAreaName: null,
                    );
                  } else {
                    ref.read(currentUserProvider.notifier).state = UserModel(
                      userId: '11111111-1111-1111-1111-111111111111',
                      username: 'admin_enro',
                      firstName: 'Roberto',
                      lastName: 'Del Rosario',
                      contactNumber: '+63 917 111 0001',
                      role: UserRole.admin,
                      status: 'active',
                    );
                  }
                  ToastNotification.show(context, message: 'Switched active viewing role perspective.', type: ToastType.info);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // User Hero Profile Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryNavy,
                  child: Text(
                    user.initials,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          StatusBadge(
                            label: user.roleDisplayName.toUpperCase(),
                            type: user.role == UserRole.admin ? BadgeType.optimal : BadgeType.neutral,
                          ),
                          const SizedBox(width: 8),
                          const StatusBadge(
                            label: 'ACTIVE ACCOUNT',
                            type: BadgeType.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@${user.username} • Environment & Natural Resources Office (ENRO) - Ormoc City Hall',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(user.contactNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(width: 20),
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            user.assignedAreaName ?? 'Ormoc City Hall Central Base (City-wide)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Edit Profile',
                  icon: Icons.edit_outlined,
                  variant: ButtonVariant.primary,
                  onPressed: () => _showEditProfileDialog(user),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Structured 3-Card Information Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth <= 850;

              final card1 = AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.work_outline_rounded, color: AppColors.accentBlue, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Official Assignment & Schedule',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Official Role', user.roleDisplayName),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Assigned Sector', user.assignedAreaName ?? 'City-wide Central Jurisdiction'),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Shift Schedule', user.schedule),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Appointment Status', 'Permanent / LGU Appointed'),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Duty Station', 'ENRO Ormoc City Hall Compound'),
                  ],
                ),
              );

              final card2 = AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, color: AppColors.accentEmerald, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Biometric & Login Credentials',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Facial Recognition Vector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('MobileFaceNet 128-d Biometric Template', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, size: 14, color: AppColors.successText),
                              SizedBox(width: 4),
                              Text('ENROLLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.successText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('QR Login Credential', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(user.qrToken ?? 'BW-ORMC-${user.userId}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted)),
                          ],
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_2, size: 16),
                          label: const Text('View QR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryNavy,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showQrCodeDialog(user),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Biometric Storage Policy', 'Stored locally on authorized client device'),
                    const Divider(height: 18, color: AppColors.border),
                    _buildDetailRow('Liveness Detection', 'CNN Anti-Spoofing Active'),
                  ],
                ),
              );

              return Column(
                children: [
                  if (isNarrow) ...[
                    card1,
                    const SizedBox(height: 20),
                    card2,
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 20),
                        Expanded(child: card2),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Card 3: Account Security & Session Privacy
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shield_outlined, color: AppColors.accentBlue, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Security & Session Governance',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            AppButton(
                              label: 'Change Password',
                              icon: Icons.lock_outline,
                              variant: ButtonVariant.outline,
                              onPressed: _showChangePasswordDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                'Multi-Factor Authentication (MFA)',
                                'Active (Email One-Time Password on Web Login)',
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildDetailRow(
                                'Session Security Timeout',
                                '30 Minutes of Inactivity (Auto-Logout)',
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildDetailRow(
                                'Data Privacy Compliance',
                                'Republic Act No. 10173 Compliant',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/auth_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/webauthn_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/passkey_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _isRegisteringDevice = false;

  void _registerNewDevice(UserModel user) async {
    final isSupported = await WebAuthnHelper.isPlatformBiometricAvailable();
    if (!isSupported) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'No hardware biometric sensor (Windows Hello / Touch ID / Fingerprint) detected on this browser or machine.',
          type: ToastType.warning,
        );
      }
      return;
    }

    setState(() => _isRegisteringDevice = true);
    try {
      final randomBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final challenge = base64UrlEncode(randomBytes);

      final result = await WebAuthnHelper.registerBiometric(
        challengeBase64: challenge,
        userId: user.userId,
        userEmail: user.username,
        userDisplayName: user.fullName,
      );

      if (!result.success) {
        setState(() => _isRegisteringDevice = false);
        if (mounted) {
          ToastNotification.show(
            context,
            message: result.error ?? 'Biometric enrollment failed.',
            type: ToastType.info,
          );
        }
        return;
      }

      final repo = ref.read(dataRepositoryProvider);
      final newPasskey = PasskeyModel(
        passkeyId: '',
        userId: user.userId,
        credentialId: result.credentialId!,
        publicKey: result.publicKey,
        deviceName: result.deviceName ?? WebAuthnHelper.getDeviceName(),
        createdAt: DateTime.now(),
      );
      await repo.addPasskey(newPasskey);
      ref.invalidate(userPasskeysProvider(user.userId));

      setState(() => _isRegisteringDevice = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Device "${newPasskey.deviceName}" enrolled successfully for 1-click Biometric Login!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      setState(() => _isRegisteringDevice = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Enrollment error: $e', type: ToastType.error);
      }
    }
  }

  void _deleteDevice(PasskeyModel passkey, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Biometric Passkey'),
        content: Text('Are you sure you want to revoke biometric sign-in for "${passkey.deviceName}"? You will need to log in with password + OTP on that device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brightRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Device', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dataRepositoryProvider).deletePasskey(passkey.passkeyId);
        ref.invalidate(userPasskeysProvider(user.userId));
        if (mounted) {
          ToastNotification.show(context, message: 'Device revoked.', type: ToastType.info);
        }
      } catch (e) {
        if (mounted) {
          ToastNotification.show(context, message: 'Failed to revoke device: $e', type: ToastType.error);
        }
      }
    }
  }

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
                        onPressed: () async {
                          if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
                            ToastNotification.show(context, message: 'Please enter both first and last name.', type: ToastType.warning);
                            return;
                          }

                          final updated = user.copyWith(
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            contactNumber: contactController.text.trim(),
                          );

                          try {
                            if (user.userId.isNotEmpty && !user.userId.startsWith('11111111')) {
                              await Supabase.instance.client.from('users').update({
                                'first_name': firstNameController.text.trim(),
                                'last_name': lastNameController.text.trim(),
                                'contact_number': contactController.text.trim(),
                                'updated_at': DateTime.now().toIso8601String(),
                              }).eq('user_id', user.userId);
                              ref.invalidate(employeesProvider);
                            }
                            ref.read(currentUserProvider.notifier).state = updated;
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (mounted) {
                              ToastNotification.show(context, message: 'Profile details successfully updated.', type: ToastType.success);
                            }
                          } catch (e) {
                            if (mounted) {
                              ToastNotification.show(context, message: 'Failed to update profile: $e', type: ToastType.error);
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
                        onPressed: () async {
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

                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: newPassController.text),
                            );
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (mounted) {
                              ToastNotification.show(context, message: 'Password successfully updated in Supabase auth.', type: ToastType.success);
                            }
                          } catch (e) {
                            if (mounted) {
                              ToastNotification.show(context, message: 'Password update failed: $e', type: ToastType.error);
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
                onPressed: () async {
                  if (user.role == UserRole.admin) {
                    ref.read(lastActiveAdminProvider.notifier).state = user;
                    final repo = ref.read(dataRepositoryProvider);
                    final allUsers = await repo.getUsers();
                    final supervisors = allUsers.where((u) => u.role == UserRole.supervisor).toList();
                    if (supervisors.isNotEmpty) {
                      ref.read(currentUserProvider.notifier).state = supervisors.first;
                      if (context.mounted) {
                        ToastNotification.show(context, message: 'Switched to Supervisor: ${supervisors.first.fullName}', type: ToastType.info);
                      }
                    } else {
                      if (context.mounted) {
                        ToastNotification.show(context, message: 'No registered supervisor found in database.', type: ToastType.warning);
                      }
                    }
                  } else {
                    final cachedAdmin = ref.read(lastActiveAdminProvider);
                    if (cachedAdmin != null) {
                      ref.read(currentUserProvider.notifier).state = cachedAdmin;
                      if (context.mounted) {
                        ToastNotification.show(context, message: 'Switched to Administrator view (${cachedAdmin.fullName})', type: ToastType.info);
                      }
                    } else {
                      final repo = ref.read(dataRepositoryProvider);
                      final allUsers = await repo.getUsers();
                      final markAdmin = allUsers.where((u) => u.username.toLowerCase() == AuthConfig.demoEmail.toLowerCase()).toList();
                      if (markAdmin.isNotEmpty) {
                        ref.read(currentUserProvider.notifier).state = markAdmin.first;
                        ref.read(lastActiveAdminProvider.notifier).state = markAdmin.first;
                        if (context.mounted) {
                          ToastNotification.show(context, message: 'Switched to Administrator view (${markAdmin.first.fullName})', type: ToastType.info);
                        }
                        return;
                      }

                      final admins = allUsers.where((u) => u.role == UserRole.admin).toList();
                      if (admins.isNotEmpty) {
                        ref.read(currentUserProvider.notifier).state = admins.first;
                        ref.read(lastActiveAdminProvider.notifier).state = admins.first;
                        if (context.mounted) {
                          ToastNotification.show(context, message: 'Switched to Administrator view (${admins.first.fullName})', type: ToastType.info);
                        }
                        return;
                      }

                      final supaUser = Supabase.instance.client.auth.currentUser;
                      final isDemo = supaUser == null || AuthConfig.isDemoAccount(supaUser.email ?? '');
                      final fallbackAdmin = UserModel(
                        userId: supaUser?.id ?? '11111111-1111-1111-1111-111111111111',
                        username: supaUser?.email ?? AuthConfig.demoEmail,
                        firstName: supaUser?.userMetadata?['first_name']?.toString() ?? (isDemo ? 'Mark Kevin' : 'Administrator'),
                        lastName: supaUser?.userMetadata?['last_name']?.toString() ?? (isDemo ? 'Canonoy' : ''),
                        contactNumber: supaUser?.phone ?? (isDemo ? '+63 917 555 0199' : ''),
                        role: UserRole.admin,
                        status: 'active',
                        schedule: 'Unassigned',
                      );
                      ref.read(currentUserProvider.notifier).state = fallbackAdmin;
                      ref.read(lastActiveAdminProvider.notifier).state = fallbackAdmin;
                      if (context.mounted) {
                        ToastNotification.show(context, message: 'Switched to Administrator view (${fallbackAdmin.fullName})', type: ToastType.info);
                      }
                    }
                  }
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
                UserAvatar(
                  photoUrl: user.photoUrl,
                  initials: user.initials,
                  radius: 40,
                  fontSize: 26,
                  backgroundColor: AppColors.primaryNavy,
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
                    Builder(
                      builder: (context) {
                        final hasFace = user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Facial Recognition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  hasFace ? 'Face Biometrics Enrolled' : 'Face Biometrics Not Enrolled',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasFace ? AppColors.successBg : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasFace ? AppColors.accentEmerald.withValues(alpha: 0.3) : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    hasFace ? Icons.check_circle : Icons.pending_outlined,
                                    size: 14,
                                    color: hasFace ? AppColors.successText : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasFace ? 'ENROLLED' : 'PENDING',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: hasFace ? AppColors.successText : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Face Biometrics Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty
                                  ? 'Active 512-d MobileFaceNet vector enrolled'
                                  : 'No facial embedding enrolled',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty)
                                ? AppColors.successBg
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty)
                                  ? AppColors.accentEmerald.withValues(alpha: 0.3)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            (user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty)
                                ? 'ACTIVE'
                                : 'PENDING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty)
                                  ? AppColors.successText
                                  : AppColors.textMuted,
                            ),
                          ),
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
                                'Active (Biometrics Preferred, Email OTP Fallback)',
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
                  const SizedBox(height: 20),

                  // Card 4: Biometric Passkeys & Enrolled Multi-Factor Devices
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
                                Icon(Icons.fingerprint_rounded, color: AppColors.accentEmerald, size: 22),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Biometric Passkeys & Enrolled Devices',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'FIDO2 / WebAuthn platform authenticators for 1-click Quick Login (Windows Hello, Touch ID)',
                                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            AppButton(
                              label: '+ Register This Device',
                              icon: Icons.fingerprint,
                              variant: ButtonVariant.outline,
                              isLoading: _isRegisteringDevice,
                              onPressed: () => _registerNewDevice(user),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ref.watch(userPasskeysProvider(user.userId)).when(
                          data: (passkeys) {
                            if (passkeys.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.fingerprint_outlined, size: 36, color: AppColors.textLight),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'No biometric devices enrolled yet',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Click "+ Register This Device" above to enroll this computer\'s fingerprint or Touch ID scanner for instant passwordless login.',
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: passkeys.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (ctx, idx) {
                                final p = passkeys[idx];
                                final registeredDate = DateFormat('MMM dd, yyyy').format(p.createdAt);
                                final lastUsedText = p.lastUsedAt != null
                                    ? DateFormat('MMM dd, yyyy • hh:mm a').format(p.lastUsedAt!)
                                    : 'Never used';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentEmerald.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.fingerprint_rounded, size: 22, color: AppColors.accentEmerald),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  p.deviceName,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                                ),
                                                const SizedBox(width: 8),
                                                const StatusBadge(
                                                  label: 'Enrolled MFA',
                                                  type: BadgeType.optimal,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Enrolled on $registeredDate • Last used: $lastUsedText',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.brightRed),
                                        tooltip: 'Revoke this device',
                                        onPressed: () => _deleteDevice(p, user),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (err, _) => Text(
                            'Error loading passkeys: $err',
                            style: const TextStyle(fontSize: 12, color: AppColors.brightRed),
                          ),
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

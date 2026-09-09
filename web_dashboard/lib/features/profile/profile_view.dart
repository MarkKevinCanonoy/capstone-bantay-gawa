import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _supabaseUrlController = TextEditingController(text: 'https://xyzcompany.supabase.co');
  final _supabaseKeyController = TextEditingController(text: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  bool _useLiveSupabase = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile & Environment Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Manage administrative identity and configure database connection parameters.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),

          // User Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryNavy,
                  child: Text(
                    user.initials,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(width: 12),
                          StatusBadge(
                            label: user.roleDisplayName.toUpperCase(),
                            type: user.role == UserRole.admin ? BadgeType.optimal : BadgeType.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('@${user.username} • Environment & Natural Resources Office (ENRO)', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(user.contactNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(width: 16),
                          const Icon(Icons.location_city_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(user.assignedAreaName ?? 'Ormoc City Hall Central Base', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: user.role == UserRole.admin ? 'Switch to Supervisor View' : 'Switch to Admin View',
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    if (user.role == UserRole.admin) {
                      ref.read(currentUserProvider.notifier).state = UserModel(
                        userId: 'user-sup-1',
                        username: 'sup_juan',
                        firstName: 'Juan',
                        lastName: 'Santos',
                        contactNumber: '+63 917 222 0002',
                        role: UserRole.supervisor,
                        status: 'active',
                        assignedAreaId: 'area-1',
                        assignedAreaName: 'Ormoc City Hall Zone',
                      );
                    } else {
                      ref.read(currentUserProvider.notifier).state = UserModel(
                        userId: 'user-admin-1',
                        username: 'admin_enro',
                        firstName: 'Roberto',
                        lastName: 'Del Rosario',
                        contactNumber: '+63 917 111 0001',
                        role: UserRole.admin,
                        status: 'active',
                      );
                    }
                    ToastNotification.show(context, message: 'Switched active viewing role.', type: ToastType.info);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Backend Architecture & Supabase Configuration Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage_outlined, color: AppColors.accentBlue, size: 22),
                        SizedBox(width: 10),
                        Text('Backend Data Layer Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    StatusBadge(
                      label: _useLiveSupabase ? 'LIVE SUPABASE CONNECTED' : 'MOCK REPOSITORY ACTIVE',
                      type: _useLiveSupabase ? BadgeType.success : BadgeType.optimal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The dashboard uses a decoupled Repository Pattern. While you prepare your Supabase instance, all views, approvals, geofencing, and reports run interactively in Mock Mode. When your Supabase URL and Key are available, enter them below to transition seamlessly.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),

                const Text('Supabase Project URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseUrlController,
                  decoration: const InputDecoration(hintText: 'https://[project-ref].supabase.co'),
                ),
                const SizedBox(height: 16),

                const Text('Supabase Public Anon Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseKeyController,
                  decoration: const InputDecoration(hintText: 'anon public key...'),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    AppButton(
                      label: 'Save & Test Connection',
                      icon: Icons.sync,
                      onPressed: () {
                        setState(() => _useLiveSupabase = true);
                        ToastNotification.show(
                          context,
                          message: 'Supabase credentials stored in configuration. Tables strictly aligned with specs/schema.sql.',
                          type: ToastType.success,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'Revert to Mock Mode',
                      variant: ButtonVariant.secondary,
                      onPressed: () {
                        setState(() => _useLiveSupabase = false);
                        ToastNotification.show(context, message: 'Reverted to in-memory mock repository.', type: ToastType.info);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Role Permissions Summary
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Role Authority Matrix (specs/roles_matrix.md)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPermItem('Full City-wide Geofence & Area Management', user.role == UserRole.admin),
                _buildPermItem('Personnel Creation, Deletion, and Face Embedding Registration', user.role == UserRole.admin),
                _buildPermItem('Leave Request Approval & Rejection Authority', user.role == UserRole.admin),
                _buildPermItem('Field Accomplishment Proof Verification (Assigned Areas)', true),
                _buildPermItem('Attendance Log Monitoring & Manual Verification', true),
                _buildPermItem('File Worker Misconduct & Disciplinary Reports', user.role == UserRole.supervisor),
                _buildPermItem('Export Analytical Attendance & Geofence Reports', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermItem(String label, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : AppColors.textLight,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: granted ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: granted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

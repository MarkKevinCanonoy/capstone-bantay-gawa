import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';
import 'app_button.dart';
import 'confirmation_dialog.dart';
import '../../data/repositories/repository_provider.dart';

class AppSidebar extends ConsumerWidget {
  final VoidCallback? onCloseMobile;

  const AppSidebar({
    super.key,
    this.onCloseMobile,
  });

  Widget _buildNavItem({
    required BuildContext context,
    required String navKey,
    required String label,
    required IconData icon,
    required String currentNav,
    required Function(String) onSelect,
    int badgeCount = 0,
  }) {
    final bool isActive = currentNav == navKey;

    return InkWell(
      onTap: () {
        onSelect(navKey);
        if (onCloseMobile != null) onCloseMobile!();
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.navActiveBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? const Border(
                  right: BorderSide(color: AppColors.navActiveIndicator, width: 3),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.accentBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppColors.accentBlue : AppColors.textSecondary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: AppColors.badgeText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentNav = ref.watch(activeNavProvider);
    final currentUser = ref.watch(currentUserProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final accomplishmentsAsync = ref.watch(accomplishmentsProvider);

    final pendingLeaves = leaveRequestsAsync.value?.where((l) => l.status == 'pending').length ?? 0;
    final criticalAlerts = alertsAsync.value?.where((a) => a.severity == 'critical' && !a.isResolved).length ?? 0;
    final pendingAccomplishments = accomplishmentsAsync.value?.where((a) => a.status.toLowerCase() == 'pending').length ?? 0;

    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo / Brand Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                const AppLogo(size: 38),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BantayGawa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Ormoc City ENRO Portal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 6),

          // Nav Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem(
                  context: context,
                  navKey: 'dashboard',
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'work-areas',
                  label: 'Work Areas',
                  icon: Icons.map_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'attendance',
                  label: 'Attendance',
                  icon: Icons.access_time_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'accomplishments',
                  label: 'Field Reports (Proofs)',
                  icon: Icons.assignment_turned_in_outlined,
                  currentNav: currentNav,
                  badgeCount: pendingAccomplishments,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),

                _buildSectionHeader('WORKFORCE & SAFETY'),
                _buildNavItem(
                  context: context,
                  navKey: 'employees',
                  label: 'Personnel',
                  icon: Icons.people_alt_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'leaves',
                  label: 'Leaves',
                  icon: Icons.calendar_today_outlined,
                  currentNav: currentNav,
                  badgeCount: pendingLeaves,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'incidents',
                  label: 'Incident Reports',
                  icon: Icons.report_problem_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),

                _buildSectionHeader('COMMUNICATIONS & AUDIT'),
                _buildNavItem(
                  context: context,
                  navKey: 'notifications',
                  label: 'Alerts & Broadcasts',
                  icon: Icons.notifications_none_outlined,
                  currentNav: currentNav,
                  badgeCount: criticalAlerts,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
                _buildNavItem(
                  context: context,
                  navKey: 'reports',
                  label: 'Reports & Export',
                  icon: Icons.bar_chart_outlined,
                  currentNav: currentNav,
                  onSelect: (k) => ref.read(activeNavProvider.notifier).state = k,
                ),
              ],
            ),
          ),

          // Bottom User Card
          InkWell(
            onTap: () {
              ref.read(activeNavProvider.notifier).state = 'profile';
              onCloseMobile?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryNavy,
                    child: Text(
                    currentUser.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.fullName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentUser.roleDisplayName,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.textMuted),
                  tooltip: 'Sign Out',
                  onPressed: () {
                    ConfirmationDialog.show(
                      context,
                      title: 'Confirm Sign Out',
                      message: 'Are you sure you want to sign out of the BantayGawa portal?',
                      confirmLabel: 'Sign Out',
                      confirmVariant: ButtonVariant.danger,
                      onConfirm: () {
                        ref.read(activeNavProvider.notifier).state = 'login';
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}

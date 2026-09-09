import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class AppHeader extends ConsumerWidget {
  final VoidCallback? onOpenMobileMenu;

  const AppHeader({
    super.key,
    this.onOpenMobileMenu,
  });

  String _getPageTitle(String nav) {
    switch (nav) {
      case 'dashboard':
        return 'System Overview';
      case 'employees':
        return 'Personnel Directory';
      case 'work-areas':
        return 'Work Areas & Geofences';
      case 'attendance':
        return 'Attendance Records';
      case 'accomplishments':
        return 'Field Accomplishment Proofs';
      case 'leaves':
        return 'Leave Requests';
      case 'incidents':
        return 'Worker Incident Reports';
      case 'reports':
        return 'Analytical Reports';
      case 'notifications':
        return 'Alerts & Broadcasts';
      case 'profile':
        return 'System Profile & Settings';
      default:
        return 'BantayGawa';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNav = ref.watch(activeNavProvider);
    final currentUser = ref.watch(currentUserProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final alertsCount = alertsAsync.value?.where((a) => a.severity == 'critical' && !a.isResolved).length ?? 0;

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: onOpenMobileMenu,
            ),
            const SizedBox(width: 8),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPageTitle(activeNav),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (currentUser.role == UserRole.supervisor)
                Text(
                  'Scoped Area: ${currentUser.assignedAreaName ?? "Assigned Sector"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const Spacer(),

          // Search Field
          if (!isMobile)
            Container(
              width: 260,
              height: 40,
              margin: const EdgeInsets.only(right: 16),
              child: TextField(
                onChanged: (val) {
                  ref.read(globalSearchProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: 'Search records...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Role Switcher Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: currentUser.role == UserRole.admin ? AppColors.statusOptimalBg : AppColors.warningBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<UserRole>(
              tooltip: 'Switch testing role',
              initialValue: currentUser.role,
              onSelected: (UserRole selectedRole) {
                if (selectedRole == UserRole.admin) {
                  ref.read(currentUserProvider.notifier).state = UserModel(
                    userId: 'user-admin-1',
                    username: 'admin_enro',
                    firstName: 'Roberto',
                    lastName: 'Del Rosario',
                    contactNumber: '+63 917 111 0001',
                    role: UserRole.admin,
                    status: 'active',
                  );
                } else {
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
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: UserRole.admin,
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 18, color: AppColors.primaryNavy),
                      SizedBox(width: 8),
                      Text('Admin Mode (Full Access)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: UserRole.supervisor,
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: AppColors.accentBlue),
                      SizedBox(width: 8),
                      Text('Field Supervisor (Scoped)'),
                    ],
                  ),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentUser.role == UserRole.admin ? Icons.admin_panel_settings : Icons.shield_outlined,
                    size: 14,
                    color: currentUser.role == UserRole.admin ? AppColors.statusOptimalText : AppColors.warningText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentUser.role == UserRole.admin ? 'Role: ADMIN' : 'Role: SUPERVISOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: currentUser.role == UserRole.admin ? AppColors.statusOptimalText : AppColors.warningText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: currentUser.role == UserRole.admin ? AppColors.statusOptimalText : AppColors.warningText,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Notification Bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, color: AppColors.textSecondary),
                onPressed: () {
                  ref.read(activeNavProvider.notifier).state = 'notifications';
                },
              ),
              if (alertsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.brightRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$alertsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // User Avatar Pill
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryNavy,
            child: Text(
              currentUser.initials,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'toast_notification.dart';
import 'app_button.dart';
import 'confirmation_dialog.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class AppHeader extends ConsumerStatefulWidget {
  final VoidCallback? onOpenMobileMenu;

  const AppHeader({
    super.key,
    this.onOpenMobileMenu,
  });

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  (String, String) _getSectionBreadcrumbs(String nav) {
    switch (nav) {
      case 'dashboard':
        return ('Operations', 'Dashboard Overview');
      case 'work-areas':
        return ('Operations', 'Work Areas & GIS Boundaries');
      case 'attendance':
        return ('Operations', 'Attendance Verification');
      case 'accomplishments':
        return ('Operations', 'Field Accomplishment Proofs');
      case 'employees':
        return ('Workforce & Safety', 'Personnel Directory');
      case 'leaves':
        return ('Workforce & Safety', 'Leave Requests & Approvals');
      case 'incidents':
        return ('Workforce & Safety', 'Field Incident Reports');
      case 'notifications':
        return ('Communications', 'Alerts & Dispatch Hub');
      case 'reports':
        return ('Communications & Audit', 'Analytics & Export Reports');
      case 'profile':
        return ('Account', 'Administrator Profile');
      default:
        return ('Operations', 'Dashboard Overview');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentNav = ref.watch(activeNavProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    final criticalAlerts = alertsAsync.value?.where((a) => a.severity == 'critical' && !a.isResolved).toList() ?? [];
    final (sectionCategory, sectionTitle) = _getSectionBreadcrumbs(currentNav);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Mobile Hamburger Drawer Toggle
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
              onPressed: widget.onOpenMobileMenu,
              tooltip: 'Open navigation',
            ),
            const SizedBox(width: 8),
          ],

          // Dynamic Breadcrumbs
          if (!isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sectionCategory.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
          ],

          const Spacer(),

          // Notification Hub Bell Dropdown
          PopupMenuButton<String>(
            tooltip: 'Field Alerts & Dispatches',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (val) {
              if (val == 'view_all') {
                ref.read(activeNavProvider.notifier).state = 'notifications';
              }
            },
            itemBuilder: (context) {
              if (criticalAlerts.isEmpty) {
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.accentEmerald),
                        SizedBox(width: 10),
                        Text('No active critical alerts', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'view_all',
                    child: Text('Open Alerts & Broadcasts Hub', style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                  ),
                ];
              }

              return [
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Critical Incidents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${criticalAlerts.length} Active',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.dangerText),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...criticalAlerts.take(3).map((a) {
                  return PopupMenuItem(
                    value: 'view_all',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.brightRed),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                a.workerName ?? a.title,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 21, top: 2),
                          child: Text(
                            a.description,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'view_all',
                  child: Center(
                    child: Text('View All Alerts & Broadcasts →', style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w700)),
                  ),
                ),
              ];
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.textSecondary),
                  if (criticalAlerts.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.brightRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Profile Icon & Menu with Full Account Functionality
          PopupMenuButton<String>(
            tooltip: 'Account & Profile',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (val) {
              if (val == 'profile') {
                ref.read(activeNavProvider.notifier).state = 'profile';
              } else if (val == 'switch_role') {
                if (currentUser.role == UserRole.admin) {
                  final employees = ref.read(employeesProvider).value ?? [];
                  final supervisors = employees.where((u) => u.role == UserRole.supervisor).toList();
                  if (supervisors.isNotEmpty) {
                    ref.read(currentUserProvider.notifier).state = supervisors.first;
                    ToastNotification.show(context, message: 'Switched to Supervisor: ${supervisors.first.fullName}', type: ToastType.info);
                  } else {
                    ToastNotification.show(context, message: 'No registered supervisor found. Register a supervisor in Employees first.', type: ToastType.warning);
                  }
                } else {
                  final employees = ref.read(employeesProvider).value ?? [];
                  final admins = employees.where((u) => u.role == UserRole.admin).toList();
                  if (admins.isNotEmpty) {
                    ref.read(currentUserProvider.notifier).state = admins.first;
                    ToastNotification.show(context, message: 'Switched to Administrator view (${admins.first.fullName})', type: ToastType.info);
                  } else {
                    final supaUser = Supabase.instance.client.auth.currentUser;
                    ref.read(currentUserProvider.notifier).state = UserModel(
                      userId: supaUser?.id ?? '',
                      username: supaUser?.email ?? 'admin',
                      firstName: supaUser?.userMetadata?['first_name']?.toString() ?? 'Administrator',
                      lastName: supaUser?.userMetadata?['last_name']?.toString() ?? '',
                      contactNumber: supaUser?.phone ?? '',
                      role: UserRole.admin,
                      status: 'active',
                      schedule: 'Unassigned',
                    );
                    ToastNotification.show(context, message: 'Switched to Administrator view', type: ToastType.info);
                  }
                }
              } else if (val == 'logout') {
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
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${currentUser.roleDisplayName} • ENRO Ormoc City',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('My Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'switch_role',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.accentBlue),
                    const SizedBox(width: 10),
                    Text(
                      currentUser.role == UserRole.admin ? 'Switch to Supervisor View' : 'Switch to Admin View',
                      style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.brightRed),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(color: AppColors.brightRed)),
                  ],
                ),
              ),
            ],
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryNavy,
                      child: Text(
                        currentUser.initials,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentUser.fullName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navActiveBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentUser.role == UserRole.admin ? 'ADMIN' : 'SUPERVISOR',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


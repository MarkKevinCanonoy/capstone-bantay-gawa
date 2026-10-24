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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBackground,
      ),
      child: Row(
        children: [
          // Mobile Hamburger Drawer Toggle (only shown on small screens)
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: onOpenMobileMenu,
            ),
          ],

          const Spacer(),

          // Profile Icon & Menu with Full Account Functionality
          PopupMenuButton<String>(
            tooltip: 'Account & Profile',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (val) {
              if (val == 'profile') {
                ref.read(activeNavProvider.notifier).state = 'profile';
              } else if (val == 'switch_role') {
                if (currentUser.role == UserRole.admin) {
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
              } else if (val == 'logout') {
                ref.read(activeNavProvider.notifier).state = 'login';
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
                      '${currentUser.roleDisplayName} • ENRO',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryNavy,
                      child: Text(
                        currentUser.initials,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentUser.fullName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 2),
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

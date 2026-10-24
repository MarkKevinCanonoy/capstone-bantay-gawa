import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../../data/repositories/offline_sync_service.dart';
import '../dashboard/worker_dashboard_view.dart';
import '../attendance/attendance_view.dart';
import '../map/work_area_map_view.dart';
import '../accomplishments/accomplishments_view.dart';
import '../profile/profile_view.dart';

class WorkerShellView extends ConsumerStatefulWidget {
  const WorkerShellView({super.key});

  @override
  ConsumerState<WorkerShellView> createState() => _WorkerShellViewState();
}

class _WorkerShellViewState extends ConsumerState<WorkerShellView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider).value;
    final workerName = user?.fullName ?? 'Worker';

    final pages = [
      WorkerDashboardView(onNavigate: (idx) => setState(() => _selectedIndex = idx)),
      const AttendanceView(),
      const WorkAreaMapView(),
      const AccomplishmentsView(),
      const ProfileView(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'LGU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BantayGawa',
              style: TextStyle(
                color: AppColors.primaryNavy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Live Sync/Offline indicator
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncService.instance.pendingSyncCountNotifier,
            builder: (context, pendingCount, child) {
              if (pendingCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, size: 14, color: AppColors.warningOrange),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingCount queue',
                        style: const TextStyle(fontSize: 10, color: AppColors.warningText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }
              return const Icon(Icons.cloud_done_outlined, size: 20, color: AppColors.accentGreen);
            },
          ),
          const SizedBox(width: 14),
          // User avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryNavy,
            child: Text(
              workerName.isNotEmpty ? workerName[0].toUpperCase() : 'W',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCE8F6),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppTranslations.get('nav_home', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fingerprint),
            selectedIcon: const Icon(Icons.fingerprint),
            label: AppTranslations.get('nav_attendance', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: AppTranslations.get('nav_map', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: AppTranslations.get('nav_reports', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: AppTranslations.get('nav_profile', lang),
          ),
        ],
      ),
    );
  }
}

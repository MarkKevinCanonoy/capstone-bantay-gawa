import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/language_switch_button.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../../data/repositories/offline_sync_service.dart';
import '../dashboard/worker_dashboard_view.dart';
import '../attendance/attendance_view.dart';
import '../map/work_area_map_view.dart';
import '../accomplishments/accomplishments_view.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_view.dart';

class WorkerShellView extends ConsumerStatefulWidget {
  const WorkerShellView({super.key});

  @override
  ConsumerState<WorkerShellView> createState() => _WorkerShellViewState();
}

class _WorkerShellViewState extends ConsumerState<WorkerShellView> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final area = ref.read(assignedWorkAreaProvider).value;
      final user = ref.read(currentUserProvider).value;
      if (area != null) {
        LocationTrackingService.instance.evaluateCurrentLocation(
          assignedArea: area,
          userId: user?.userId,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(assignedWorkAreaProvider);
    ref.invalidate(allWorkAreasProvider);
    ref.invalidate(attendanceListProvider);
    ref.invalidate(accomplishmentListProvider);
    ref.invalidate(notificationListProvider);
    OfflineSyncService.instance.syncPendingData();
    OfflineSyncService.instance.syncInboundPersonnel();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider).value;
    final workerName = user?.fullName ?? 'Worker';

    ref.listen(assignedWorkAreaProvider, (prev, next) {
      final area = next.value;
      if (area != null) {
        LocationTrackingService.instance.evaluateCurrentLocation(
          assignedArea: area,
          userId: user?.userId,
        );
      }
    });

    final pages = [
      WorkerDashboardView(onNavigate: (idx) => setState(() => _selectedIndex = idx)),
      AttendanceView(isActive: _selectedIndex == 1),
      const WorkAreaMapView(),
      AccomplishmentsView(isActive: _selectedIndex == 3),
      const ProfileView(),
    ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactScreen = screenWidth < 390;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: isCompactScreen ? 12 : 16,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const AppLogo(compact: true),
        actions: [
          // Live Sync/Offline indicator
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncService.instance.pendingSyncCountNotifier,
            builder: (context, pendingCount, child) {
              if (pendingCount > 0) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompactScreen ? 6 : 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, size: 14, color: AppColors.warningOrange),
                      if (!isCompactScreen) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$pendingCount queue',
                          style: const TextStyle(fontSize: 10, color: AppColors.warningText, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return const Icon(Icons.cloud_done_outlined, size: 20, color: AppColors.accentGreen);
            },
          ),
          SizedBox(width: isCompactScreen ? 2 : 4),

          // Notifications Inbox Bell
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Badge(
              isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
              label: Text(
                '${ref.watch(unreadNotificationCountProvider)}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.dangerRed,
              child: const Icon(Icons.notifications_outlined, size: 21, color: AppColors.primaryNavy),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          SizedBox(width: isCompactScreen ? 2 : 4),

          // Prominent Language Toggle
          LanguageSwitchButton(compact: isCompactScreen),
          SizedBox(width: isCompactScreen ? 6 : 10),

          // Worker Profile Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: CircleAvatar(
              radius: isCompactScreen ? 15 : 17,
              backgroundColor: AppColors.primaryNavy,
              child: Text(
                workerName.isNotEmpty ? workerName[0].toUpperCase() : 'W',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isCompactScreen ? 11 : 13,
                ),
              ),
            ),
          ),
          SizedBox(width: isCompactScreen ? 10 : 14),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDCE8F6),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            _refreshAllData();
            final area = ref.read(assignedWorkAreaProvider).value;
            final user = ref.read(currentUserProvider).value;
            if (area != null) {
              LocationTrackingService.instance.evaluateCurrentLocation(
                assignedArea: area,
                userId: user?.userId,
              );
            }
          },
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
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/app_sidebar.dart';
import 'core/widgets/app_header.dart';
import 'data/repositories/repository_provider.dart';
import 'features/auth/login_view.dart';
import 'features/dashboard/dashboard_view.dart';
import 'features/employees/employees_view.dart';
import 'features/work_areas/work_areas_view.dart';
import 'features/attendance/attendance_view.dart';
import 'features/accomplishments/accomplishments_view.dart';
import 'features/leaves/leaves_view.dart';
import 'features/incidents/incidents_view.dart';
import 'features/reports/reports_view.dart';
import 'features/notifications/notifications_view.dart';
import 'features/profile/profile_view.dart';

class BantayGawaAppShell extends ConsumerStatefulWidget {
  const BantayGawaAppShell({super.key});

  @override
  ConsumerState<BantayGawaAppShell> createState() => _BantayGawaAppShellState();
}

class _BantayGawaAppShellState extends ConsumerState<BantayGawaAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildCurrentView(String nav) {
    switch (nav) {
      case 'dashboard':
        return const DashboardView();
      case 'employees':
        return const EmployeesView();
      case 'work-areas':
        return const WorkAreasView();
      case 'attendance':
        return const AttendanceView();
      case 'accomplishments':
        return const AccomplishmentsView();
      case 'leaves':
        return const LeavesView();
      case 'incidents':
        return const IncidentsView();
      case 'reports':
        return const ReportsView();
      case 'notifications':
        return const NotificationsView();
      case 'profile':
        return const ProfileView();
      default:
        return const DashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeNav = ref.watch(activeNavProvider);

    if (activeNav == 'login') {
      return const LoginView();
    }

    final isNarrow = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBackground,
      drawer: isNarrow
          ? Drawer(
              child: AppSidebar(
                onCloseMobile: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: Row(
        children: [
          // Persistent Sidebar on Desktop
          if (!isNarrow) const AppSidebar(),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  onOpenMobileMenu: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: _buildCurrentView(activeNav),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

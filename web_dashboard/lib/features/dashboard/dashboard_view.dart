import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final attendanceAsync = ref.watch(attendanceProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider);
    final alertsAsync = ref.watch(alertsProvider);

    final workAreas = workAreasAsync.value ?? [];
    final employees = employeesAsync.value ?? [];
    final attendance = attendanceAsync.value ?? [];
    final leaves = leaveRequestsAsync.value ?? [];
    final alerts = alertsAsync.value ?? [];

    final activeWorkersCount = employees.where((e) => e.status == 'active').length;
    final verifiedAttendanceCount = attendance.where((a) => a.isVerified).length;
    final complianceRate = attendance.isNotEmpty
        ? ((verifiedAttendanceCount / attendance.length) * 100).toStringAsFixed(1)
        : '100.0';
    final pendingLeaves = leaves.where((l) => l.status == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Welcome
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user.firstName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.role == UserRole.admin
                        ? 'Central City Administrative Overview • Ormoc City ENRO'
                        : 'Field Supervisor Command Center • ${user.assignedAreaName ?? "Assigned Area"}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (user.role == UserRole.admin)
                    AppButton(
                      label: '+ Add Work Area',
                      icon: Icons.add_location_alt_outlined,
                      variant: ButtonVariant.secondary,
                      onPressed: () {
                        ref.read(activeNavProvider.notifier).state = 'work-areas';
                      },
                    ),
                  AppButton(
                    label: 'Broadcast Alert',
                    icon: Icons.campaign_outlined,
                    variant: ButtonVariant.primary,
                    onPressed: () {
                      ref.read(activeNavProvider.notifier).state = 'notifications';
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                    child: StatCard(
                      title: 'Active Workers',
                      value: '$activeWorkersCount',
                      subtitle: 'On-site today',
                      icon: Icons.people_outline,
                      badgeLabel: 'OPTIMAL',
                      badgeType: BadgeType.optimal,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'employees',
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                    child: StatCard(
                      title: 'Geofence Compliance',
                      value: '$complianceRate%',
                      subtitle: 'Inside polygon zones',
                      icon: Icons.verified_user_outlined,
                      badgeLabel: 'VERIFIED',
                      badgeType: BadgeType.success,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'attendance',
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                    child: StatCard(
                      title: 'Active Work Zones',
                      value: '${workAreas.where((a) => a.status == "Active").length}/${workAreas.length}',
                      subtitle: 'Ormoc City sectors',
                      icon: Icons.map_outlined,
                      badgeLabel: 'STABLE',
                      badgeType: BadgeType.neutral,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'work-areas',
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                    child: StatCard(
                      title: 'Pending Leaves',
                      value: '$pendingLeaves',
                      subtitle: 'Awaiting review',
                      icon: Icons.pending_actions_outlined,
                      badgeLabel: pendingLeaves > 0 ? 'ACTION' : 'ALL CLEAR',
                      badgeType: pendingLeaves > 0 ? BadgeType.warning : BadgeType.optimal,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'leaves',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Main 2-Column Section (Map & Critical Alerts)
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 1000;
              return Flex(
                direction: isStacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left / Primary: GIS Workforce Geofence Map
                  Expanded(
                    flex: isStacked ? 0 : 3,
                    child: AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 8,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GIS WORKFORCE GEOFENCES (ORMOC CITY)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Real-time polygon boundaries rendered via OpenStreetMap',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              AppButton(
                                label: 'Full GIS Map',
                                icon: Icons.open_in_new,
                                variant: ButtonVariant.outline,
                                onPressed: () {
                                  ref.read(activeNavProvider.notifier).state = 'work-areas';
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 380,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: FlutterMap(
                              options: const MapOptions(
                                initialCenter: AppConstants.ormocCityCenter,
                                initialZoom: 14.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.bantaygawa.web',
                                ),
                                PolygonLayer(
                                  polygons: workAreas.map((area) {
                                    final isScoped = user.role == UserRole.admin || area.supervisorId == user.userId;
                                    return Polygon(
                                      points: area.polygon,
                                      color: isScoped ? AppColors.accentBlue.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.15),
                                      borderColor: isScoped ? AppColors.accentBlue : Colors.grey,
                                      borderStrokeWidth: 2.5,
                                    );
                                  }).toList(),
                                ),
                                MarkerLayer(
                                  markers: workAreas.map((area) {
                                    return Marker(
                                      point: area.center,
                                      width: 140,
                                      height: 36,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryNavy.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 4),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            area.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!isStacked) const SizedBox(width: 24),
                  if (isStacked) const SizedBox(height: 24),

                  // Right / Secondary: Critical Alerts & Activity
                  Expanded(
                    flex: isStacked ? 0 : 2,
                    child: Column(
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'CRITICAL SYSTEM ALERTS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${alerts.where((a) => !a.isResolved).length} ACTIVE',
                                      style: const TextStyle(
                                        color: AppColors.dangerText,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (alerts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text('No active alerts.', style: TextStyle(color: AppColors.textMuted)),
                                  ),
                                )
                              else
                                ...alerts.take(3).map((alert) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: alert.severity == 'critical'
                                          ? AppColors.dangerBg.withValues(alpha: 0.5)
                                          : AppColors.warningBg.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: alert.severity == 'critical'
                                            ? AppColors.dangerBorder
                                            : AppColors.warningBg,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              alert.severity == 'critical'
                                                  ? Icons.error_outline
                                                  : Icons.warning_amber_rounded,
                                              size: 16,
                                              color: alert.severity == 'critical'
                                                  ? AppColors.dangerText
                                                  : AppColors.warningText,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                alert.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: alert.severity == 'critical'
                                                      ? AppColors.dangerText
                                                      : AppColors.warningText,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              alert.timeAgo,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alert.description,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    ref.read(activeNavProvider.notifier).state = 'notifications';
                                  },
                                  child: const Text('View All Notifications →'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Activity Feed
                        AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RECENT FIELD ACTIVITY',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildActivityItem('Elena Reyes', 'verified Time-In at Ormoc City Hall', '12m ago'),
                              _buildActivityItem('Carlos Mendoza', 'submitted Accomplishment Proof #01', '35m ago'),
                              _buildActivityItem('Juan Santos (Supervisor)', 'approved Waste Disposal Log', '1h ago'),
                              _buildActivityItem('Sofia Bautista', 'logged Time-In at Ormoc Bus Terminal', '2h ago'),
                            ],
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

  Widget _buildActivityItem(String actor, String action, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accentBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                children: [
                  TextSpan(text: actor, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const TextSpan(text: ' '),
                  TextSpan(text: action),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

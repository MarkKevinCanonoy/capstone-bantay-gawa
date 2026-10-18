import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/repositories/repository_provider.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final MapController _mapController = MapController();
  bool _showHistoricalMovement = false;
  String _selectedMapAreaId = 'all';

  // ==========================================
  // UC-08 & UC-10: Worker Profile & Attendance Dialog
  // ==========================================
  void _showWorkerProfileDialog({
    required AttendanceModel attendance,
    required List<UserModel> employees,
    required List<WorkAreaModel> workAreas,
    required List<AttendanceModel> allAttendance,
  }) {
    final worker = employees.firstWhere(
      (e) => e.userId == attendance.userId,
      orElse: () => UserModel(
        userId: attendance.userId,
        username: 'worker',
        firstName: attendance.workerName.split(' ').first,
        lastName: attendance.workerName.split(' ').length > 1 ? attendance.workerName.split(' ').last : '',
        contactNumber: '+63 917 555 0100',
        role: UserRole.worker,
        status: 'active',
        assignedAreaId: attendance.workareaId,
        assignedAreaName: attendance.areaName,
        schedule: 'Mon-Fri 07:00 - 16:00',
        creditScore: 88,
      ),
    );

    final area = workAreas.firstWhere(
      (a) => a.workareaId == attendance.workareaId,
      orElse: () => WorkAreaModel(
        workareaId: attendance.workareaId,
        name: attendance.areaName,
        polygon: const [],
        supervisorName: 'Juan Santos',
      ),
    );

    // Get historical logs for this worker (SRS UC-10 Main Flow Step 6)
    final workerLogs = allAttendance.where((a) => a.userId == attendance.userId).toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: attendance.isVerified ? AppColors.accentEmerald : AppColors.brightRed,
                        child: Text(
                          worker.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  worker.fullName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: attendance.isVerified ? 'ON-SITE' : 'OFF-SITE BREACH',
                                  type: attendance.isVerified ? BadgeType.optimal : BadgeType.danger,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${attendance.workerEmpId} • Contact: ${worker.contactNumber}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  // Real-Time Location & Geofence Status Card (UC-08 Step 4)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Designated Sector', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(attendance.areaName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Area Supervisor', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(area.supervisorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Performance Credit', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text('${worker.creditScore}% Star Rating', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentEmerald)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Today Check-In Time', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text('${attendance.timeIn} (Biometric Match)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('GPS Pin Coordinates', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text('${attendance.gpsLat.toStringAsFixed(4)}, ${attendance.gpsLng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Recent Attendance History (UC-10 Step 6)
                  const Text('ATTENDANCE VERIFICATION HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: workerLogs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No attendance records logged today.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: workerLogs.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderSubtle),
                            itemBuilder: (context, i) {
                              final log = workerLogs[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      log.isVerified ? Icons.check_circle_outline : Icons.error_outline,
                                      size: 16,
                                      color: log.isVerified ? AppColors.accentEmerald : AppColors.brightRed,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Time-In: ${log.timeIn} • Sector: ${log.areaName}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    StatusBadge(
                                      label: log.isVerified ? 'VERIFIED' : 'FLAGGED',
                                      type: log.isVerified ? BadgeType.optimal : BadgeType.danger,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Close Profile',
                      variant: ButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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
    final workAreasAsync = ref.watch(workAreasProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final attendanceAsync = ref.watch(attendanceProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final accomplishmentsAsync = ref.watch(accomplishmentsProvider);
    final locationBreadcrumbsAsync = ref.watch(locationBreadcrumbsProvider(null));

    final workAreas = workAreasAsync.value ?? [];
    final employees = employeesAsync.value ?? [];
    final attendance = attendanceAsync.value ?? [];
    final leaves = leaveRequestsAsync.value ?? [];
    final alerts = alertsAsync.value ?? [];
    final accomplishments = accomplishmentsAsync.value ?? [];
    final locationBreadcrumbs = locationBreadcrumbsAsync.value ?? [];

    final activeWorkersCount = employees.where((e) => e.status == 'active').length;
    final verifiedAttendanceCount = attendance.where((a) => a.isVerified).length;
    final complianceRate = attendance.isNotEmpty
        ? ((verifiedAttendanceCount / attendance.length) * 100).toStringAsFixed(1)
        : '100.0';
    final pendingLeaves = leaves.where((l) => l.status == 'pending').length;
    final pendingAccomplishments = accomplishments.where((a) => a.status == 'pending').length;

    // Filter work areas based on selection (UC-08 Alt Flow 1 & UC-10 Alt Flow 1)
    final filteredAreas = _selectedMapAreaId == 'all'
        ? workAreas
        : workAreas.where((a) => a.workareaId == _selectedMapAreaId).toList();

    // Filter attendance markers based on selected area
    final filteredAttendance = _selectedMapAreaId == 'all'
        ? attendance
        : attendance.where((a) => a.workareaId == _selectedMapAreaId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Welcome & Top-Right Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 680;
              final welcomeTitle = Column(
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
                        ? 'Central City Administrative Command • Ormoc City ENRO'
                        : 'Field Supervisor Command Center • ${user.assignedAreaName ?? "Ormoc City"}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.role == UserRole.admin) ...[
                    AppButton(
                      label: 'Add Work Area',
                      icon: Icons.add_location_alt_outlined,
                      variant: ButtonVariant.outline,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onPressed: () {
                        ref.read(activeNavProvider.notifier).state = 'work-areas';
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  AppButton(
                    label: 'Broadcast Notice',
                    icon: Icons.campaign_outlined,
                    variant: ButtonVariant.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onPressed: () {
                      ref.read(activeNavProvider.notifier).state = 'notifications';
                    },
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    welcomeTitle,
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: welcomeTitle),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // KPI Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 640) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 1100) {
                cardWidth = (constraints.maxWidth - 16) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 48) / 4;
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: user.role == UserRole.supervisor ? 'Team On-Site' : 'Active Workers',
                      value: '$activeWorkersCount',
                      subtitle: user.role == UserRole.supervisor ? 'Assigned to your sector' : 'On-site today',
                      icon: Icons.people_alt_rounded,
                      badgeLabel: 'OPTIMAL',
                      badgeType: BadgeType.optimal,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'employees',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: 'Geofence Compliance',
                      value: '$complianceRate%',
                      subtitle: 'Inside polygon zones',
                      icon: Icons.verified_user_rounded,
                      badgeLabel: 'VERIFIED',
                      badgeType: BadgeType.success,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'attendance',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: user.role == UserRole.supervisor ? 'Assigned Sectors' : 'Active Work Zones',
                      value: '${workAreas.where((a) => a.status == "Active").length}/${workAreas.length}',
                      subtitle: user.role == UserRole.supervisor ? 'Monitored boundaries' : 'Ormoc City sectors',
                      icon: Icons.map_rounded,
                      badgeLabel: 'STABLE',
                      badgeType: BadgeType.neutral,
                      onTap: () => ref.read(activeNavProvider.notifier).state = 'work-areas',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: user.role == UserRole.supervisor ? 'Pending Proofs' : 'Pending Leaves',
                      value: user.role == UserRole.supervisor ? '$pendingAccomplishments' : '$pendingLeaves',
                      subtitle: user.role == UserRole.supervisor ? 'Awaiting validation' : 'Awaiting admin decision',
                      icon: user.role == UserRole.supervisor ? Icons.photo_library_rounded : Icons.pending_actions_rounded,
                      badgeLabel: (user.role == UserRole.supervisor ? pendingAccomplishments : pendingLeaves) > 0 ? 'ACTION' : 'ALL CLEAR',
                      badgeType: (user.role == UserRole.supervisor ? pendingAccomplishments : pendingLeaves) > 0 ? BadgeType.warning : BadgeType.optimal,
                      onTap: () => ref.read(activeNavProvider.notifier).state = user.role == UserRole.supervisor ? 'accomplishments' : 'leaves',
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

              // GIS Interactive Workforce Map Card
              final gisMapCard = AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.role == UserRole.supervisor
                                  ? 'Supervisor Sector Monitoring'
                                  : 'Live Workforce & Geofences',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.role == UserRole.supervisor
                                  ? 'Real-time locations of workers assigned to your sector'
                                  : 'Real-time worker locations and geofence overlays via OpenStreetMap',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        // Map Controls: Area Filter & Historical Movement Toggle
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            // Area Filter Dropdown
                            Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMapAreaId,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('All Monitored Areas')),
                                    ...workAreas.map((a) => DropdownMenuItem(value: a.workareaId, child: Text(a.name))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedMapAreaId = val);
                                  },
                                ),
                              ),
                            ),

                            // Historical Movement Toggle
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _showHistoricalMovement,
                                  activeThumbColor: AppColors.accentBlue,
                                  onChanged: (val) {
                                    setState(() => _showHistoricalMovement = val);
                                  },
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Historical Path (1m)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Privacy Badge Notice (User Specified Rule)
                    if (_showHistoricalMovement)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.navActiveBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 15, color: AppColors.accentBlue),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '1-minute path sampled inside assigned area only (privacy-protected).',
                                style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Interactive FlutterMap
                    Container(
                      height: 420,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: AppConstants.ormocCityCenter,
                          initialZoom: 14.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.bantaygawa.web',
                          ),

                          // 1. Geofence Polygons (UC-08 Step 2)
                          PolygonLayer(
                            polygons: filteredAreas.map((area) {
                              final isCurrentSupervised = user.role == UserRole.admin || area.supervisorId == user.userId;
                              return Polygon(
                                points: area.polygon,
                                color: isCurrentSupervised ? AppColors.accentBlue.withValues(alpha: 0.22) : Colors.grey.withValues(alpha: 0.12),
                                borderColor: isCurrentSupervised ? AppColors.accentBlue : Colors.grey,
                                borderStrokeWidth: 2.5,
                              );
                            }).toList(),
                          ),

                          // 2. Historical Movement Polylines (UC-08 Alt Flow 2: 1-min privacy-enforced path)
                          if (_showHistoricalMovement) ...[
                            PolylineLayer(
                              polylines: [
                                // Elena Reyes Path
                                Polyline(
                                  points: locationBreadcrumbs
                                      .where((b) => b.userId == 'user-w-2' && b.isInsideGeofence)
                                      .map((b) => b.point)
                                      .toList(),
                                  color: AppColors.accentBlue,
                                  strokeWidth: 3.5,
                                ),
                                // Mark Villanueva Path
                                Polyline(
                                  points: locationBreadcrumbs
                                      .where((b) => b.userId == 'user-w-3' && b.isInsideGeofence)
                                      .map((b) => b.point)
                                      .toList(),
                                  color: AppColors.accentEmerald,
                                  strokeWidth: 3.5,
                                ),
                                // Sofia Bautista Path
                                Polyline(
                                  points: locationBreadcrumbs
                                      .where((b) => b.userId == 'user-w-5' && b.isInsideGeofence)
                                      .map((b) => b.point)
                                      .toList(),
                                  color: Colors.purple,
                                  strokeWidth: 3.5,
                                ),
                              ],
                            ),
                          ],

                          // 3. Area Center Name Badges
                          MarkerLayer(
                            markers: filteredAreas.map((area) {
                              return Marker(
                                point: area.center,
                                width: 140,
                                height: 32,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                  child: Center(
                                    child: Text(
                                      area.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // 4. Real-time Worker Location Markers (UC-08 Step 2 & 3; UC-10 Step 4 & 5)
                          MarkerLayer(
                            markers: filteredAttendance.map((att) {
                              final isOnSite = att.isVerified;
                              return Marker(
                                point: LatLng(att.gpsLat, att.gpsLng),
                                width: 42,
                                height: 42,
                                child: GestureDetector(
                                  onTap: () => _showWorkerProfileDialog(
                                    attendance: att,
                                    employees: employees,
                                    workAreas: workAreas,
                                    allAttendance: attendance,
                                  ),
                                  child: Tooltip(
                                    message: '${att.workerName} (${isOnSite ? "On-site" : "Off-site Breach"}) - Tap to view',
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: isOnSite ? AppColors.accentEmerald : AppColors.brightRed,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: const [
                                              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              isOnSite ? Icons.person : Icons.warning_amber_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: isOnSite ? Colors.greenAccent : Colors.redAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Map Legend
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.accentEmerald, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('On-site (Within Geofence)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.brightRed, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('Off-site / Breach Alert', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 13, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text('Click any pin to inspect worker profile & logs', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final alertsAndActivity = Column(
                children: [
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
                                Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.brightRed),
                                SizedBox(width: 8),
                                Text(
                                  'Critical System Alerts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          child: TextButton.icon(
                            onPressed: () {
                              ref.read(activeNavProvider.notifier).state = 'notifications';
                            },
                            icon: const Text(
                              'View All Alerts',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                            ),
                            label: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.accentBlue),
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
                        const Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: AppColors.accentBlue),
                            SizedBox(width: 8),
                            Text(
                              'Recent Field Activity',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildActivityItem('Elena Reyes', 'verified Time-In at Ormoc City Hall (On-site)', '12m ago', icon: Icons.login_rounded),
                        _buildActivityItem('Carlos Mendoza', 'submitted Accomplishment Proof #01', '35m ago', icon: Icons.photo_camera_outlined),
                        _buildActivityItem('Juan Santos (Supervisor)', 'approved Waste Disposal Log', '1h ago', icon: Icons.check_circle_outline),
                        _buildActivityItem('Sofia Bautista', 'logged Time-In at Ormoc Bus Terminal', '2h ago', icon: Icons.login_rounded),
                      ],
                    ),
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gisMapCard,
                    const SizedBox(height: 24),
                    alertsAndActivity,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: gisMapCard),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: alertsAndActivity),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String actor, String action, String time, {IconData icon = Icons.access_time_rounded}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
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

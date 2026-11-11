import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/models/alert_model.dart';
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
  // UC-08 & UC-10: Worker Profile & Telemetry / Violation Inspection Dialog
  // ==========================================
  bool _isPointInPolygon(double lat, double lng, List<LatLng> polygon) {
    if (polygon.length < 3) return true;
    bool isInside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > lat) != (polygon[j].latitude > lat)) &&
          (lng < (polygon[j].longitude - polygon[i].longitude) * (lat - polygon[i].latitude) /
                  (polygon[j].latitude - polygon[i].latitude) +
              polygon[i].longitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  void _showWorkerProfileDialog({
    required AttendanceModel attendance,
    required List<UserModel> employees,
    required List<WorkAreaModel> workAreas,
    required List<AttendanceModel> allAttendance,
    required List<AlertModel> alerts,
  }) {
    final worker = employees.firstWhere(
      (e) => e.userId == attendance.userId,
      orElse: () => UserModel(
        userId: attendance.userId,
        username: attendance.workerName.toLowerCase().replaceAll(' ', '.'),
        firstName: attendance.workerName.split(' ').first,
        lastName: attendance.workerName.split(' ').length > 1
            ? attendance.workerName.split(' ').sublist(1).join(' ')
            : '',
        contactNumber: '+63 917 555 0100',
        role: UserRole.worker,
        status: 'active',
        assignedAreaId: attendance.workareaId,
        assignedAreaName: attendance.areaName,
        schedule: 'Mon-Fri 08:00 - 17:00',
        creditScore: 100,
      ),
    );

    final area = workAreas.firstWhere(
      (a) => a.workareaId == attendance.workareaId,
      orElse: () => WorkAreaModel(
        workareaId: attendance.workareaId,
        name: attendance.areaName,
        polygon: const [],
        supervisorName: 'Unassigned',
      ),
    );

    final LatLng workerPoint = LatLng(attendance.gpsLat, attendance.gpsLng);
    final double distanceToCenter = const Distance().as(
      LengthUnit.Meter,
      workerPoint,
      area.center,
    );
    final bool isActuallyInside = _isPointInPolygon(attendance.gpsLat, attendance.gpsLng, area.polygon);

    // Filter active alerts for this worker
    final workerAlerts = alerts.where((a) =>
      !a.isResolved &&
      ((a.userId != null && a.userId == attendance.userId) ||
       (a.workerName != null && a.workerName!.trim().toLowerCase() == worker.fullName.trim().toLowerCase()) ||
       (a.workareaId != null && a.workareaId == attendance.workareaId && !attendance.isVerified))
    ).toList();

    final distanceFormatted = distanceToCenter >= 1000
        ? '${(distanceToCenter / 1000).toStringAsFixed(1)} km'
        : '${distanceToCenter.toStringAsFixed(0)} meters';

    // Simple, human-readable violation list
    final List<Map<String, String>> detectedViolations = [];

    // 1. Geofence breach
    if (!attendance.isVerified || !isActuallyInside) {
      detectedViolations.add({
        'title': 'Geofence Perimeter Breach',
        'details': 'Worker is located approximately $distanceFormatted outside authorized ${area.name} boundary.',
      });
    }

    // 2. Face verification
    if (!attendance.faceMatch) {
      detectedViolations.add({
        'title': 'Biometric Verification Failure',
        'details': 'Facial scan did not match during time-in at ${attendance.timeIn}.',
      });
    }

    // 3. Shift warning
    if (attendance.hasWarning) {
      detectedViolations.add({
        'title': 'Attendance Shift Anomaly',
        'details': 'Time-in recorded at ${attendance.timeIn}, outside normal shift hours.',
      });
    }

    // 4. Any alerts from database
    for (final alt in workerAlerts) {
      if (alt.type.toLowerCase().contains('breach') && detectedViolations.any((v) => v['title']!.contains('Geofence'))) {
        continue;
      }
      detectedViolations.add({
        'title': alt.title.isNotEmpty ? alt.title : 'Incident Alert',
        'details': alt.description.isNotEmpty ? alt.description : 'Disciplinary alert flagged ${alt.timeAgo}.',
      });
    }

    final bool hasViolation = detectedViolations.isNotEmpty || !attendance.isVerified;

    // Clean, readable metadata without useless BW-ORMC token
    final contactText = (worker.contactNumber.isNotEmpty && worker.contactNumber != 'N/A')
        ? worker.contactNumber
        : 'Contact not on file';
    final scheduleText = (worker.schedule.isNotEmpty && worker.schedule != 'Unassigned')
        ? worker.schedule
        : 'Mon-Fri 08:00 - 17:00';
    final roleText = worker.role == UserRole.supervisor ? 'Field Supervisor' : 'Field Worker';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Worker Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: hasViolation ? AppColors.brightRed : AppColors.accentEmerald,
                        child: Text(
                          worker.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    worker.fullName,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: hasViolation ? 'OFF-SITE BREACH' : 'ON-SITE VERIFIED',
                                  type: hasViolation ? BadgeType.danger : BadgeType.optimal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$roleText • Shift: $scheduleText • Contact: $contactText',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close Profile',
                      ),
                    ],
                  ),

                  // 2. Simple Issues or Normal Banner
                  if (hasViolation) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 17, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'DETECTED VIOLATIONS & ANOMALIES',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF991B1B),
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${detectedViolations.length} ISSUE${detectedViolations.length > 1 ? "S" : ""}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...detectedViolations.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.circle, size: 6, color: Color(0xFFDC2626)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v['title'] ?? 'Violation',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7F1D1D)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        v['details'] ?? '',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF059669)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GEOFENCE COMPLIANCE: NORMAL',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Worker is verified on-site inside ${area.name}. Check-in verified at ${attendance.timeIn}.',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 3. Clear Details Card (Simple 2x2 Grid)
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
                                  const Text('Designated Sector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Text(attendance.areaName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const SizedBox(height: 1),
                                  Text('Supv: ${area.supervisorName}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Workforce Standing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: (hasViolation ? AppColors.brightRed : AppColors.accentEmerald).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              hasViolation ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                              size: 13,
                                              color: hasViolation ? AppColors.brightRed : AppColors.accentEmerald,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              hasViolation ? 'Action Required' : 'Good Standing',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: hasViolation ? AppColors.brightRed : AppColors.accentEmerald,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(hasViolation ? 'Active perimeter breach flagged' : 'Compliant with work area rules', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                                  const Text('Today Check-In Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        attendance.faceMatch ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                                        size: 14,
                                        color: attendance.faceMatch ? AppColors.accentEmerald : AppColors.brightRed,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        attendance.timeIn,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    attendance.faceMatch ? 'Biometric Face Verified' : 'Face Biometric Unverified',
                                    style: TextStyle(fontSize: 11, color: attendance.faceMatch ? AppColors.accentEmerald : AppColors.brightRed),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Location Proximity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Text(
                                    hasViolation ? 'Outside Boundary' : 'Inside Zone',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: hasViolation ? AppColors.brightRed : AppColors.accentEmerald,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    hasViolation ? '~$distanceFormatted away' : 'Normal on-site presence',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

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

    final rawWorkAreas = workAreasAsync.value ?? [];
    final rawEmployees = employeesAsync.value ?? [];
    final rawAttendance = attendanceAsync.value ?? [];
    final rawLeaves = leaveRequestsAsync.value ?? [];
    final rawAlerts = alertsAsync.value ?? [];
    final rawAccomplishments = accomplishmentsAsync.value ?? [];
    final rawBreadcrumbs = locationBreadcrumbsAsync.value ?? [];

    final isSupervisor = user.role == UserRole.supervisor;
    final workAreas = isSupervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == user.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == user.fullName.toLowerCase()) ||
            a.workareaId == user.assignedAreaId ||
            a.name == user.assignedAreaName).toList()
        : rawWorkAreas;

    final employees = isSupervisor
        ? rawEmployees.where((emp) {
            if (emp.role == UserRole.admin) return false;
            if (emp.role == UserRole.supervisor && emp.userId != user.userId) return false;
            return workAreas.any((a) =>
                a.workareaId == emp.assignedAreaId ||
                (emp.assignedAreaName != null && a.name.toLowerCase() == emp.assignedAreaName!.toLowerCase()) ||
                (emp.role == UserRole.supervisor && emp.userId == user.userId));
          }).toList()
        : rawEmployees;

    final attendance = isSupervisor
        ? rawAttendance.where((att) =>
            workAreas.any((a) => a.workareaId == att.workareaId || a.name.toLowerCase() == att.areaName.toLowerCase())
          ).toList()
        : rawAttendance;

    final leaves = isSupervisor
        ? rawLeaves.where((l) =>
            workAreas.any((a) => (l.workareaId != null && l.workareaId == a.workareaId) || a.name.toLowerCase() == l.areaName.toLowerCase())
          ).toList()
        : rawLeaves;

    final accomplishments = isSupervisor
        ? rawAccomplishments.where((acc) =>
            workAreas.any((a) => a.workareaId == acc.workareaId || a.name.toLowerCase() == acc.areaName.toLowerCase())
          ).toList()
        : rawAccomplishments;

    final alerts = isSupervisor
        ? rawAlerts.where((alt) =>
            alt.supervisorId == user.userId ||
            (alt.supervisorName != null && alt.supervisorName!.isNotEmpty && alt.supervisorName!.toLowerCase() == user.fullName.toLowerCase()) ||
            workAreas.any((a) => (alt.workareaId != null && alt.workareaId == a.workareaId) || (alt.workareaName != null && a.name.toLowerCase() == alt.workareaName!.toLowerCase())) ||
            employees.any((e) => alt.userId != null && e.userId == alt.userId)
          ).toList()
        : rawAlerts;

    final locationBreadcrumbs = isSupervisor
        ? rawBreadcrumbs.where((b) =>
            employees.any((e) => e.userId == b.userId)
          ).toList()
        : rawBreadcrumbs;

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
                        // Map Controls: Area Filter, Historical Movement Toggle, and Center Ormoc
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            // Quick Re-center Ormoc City
                            InkWell(
                              onTap: () => _mapController.move(AppConstants.ormocCityCenter, 14.5),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.my_location_rounded, size: 15, color: AppColors.accentBlue),
                                    SizedBox(width: 6),
                                    Text('Center Ormoc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            ),

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
                                  value: workAreas.any((a) => a.workareaId == _selectedMapAreaId) || _selectedMapAreaId == 'all'
                                      ? _selectedMapAreaId
                                      : 'all',
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text(user.role == UserRole.supervisor ? 'All Assigned Sectors' : 'All Monitored Areas'),
                                    ),
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

                          // 2. Historical Movement Polylines & 1-Minute Waypoint Pings
                          if (_showHistoricalMovement) ...[
                            PolylineLayer(
                              polylines: () {
                                final Map<String, List<LatLng>> userPoints = {};
                                // Group real pings by user without discarding breach coordinates
                                for (final b in locationBreadcrumbs) {
                                  userPoints.putIfAbsent(b.userId, () => []).add(b.point);
                                }

                                // For workers with active attendance who lack breadcrumb logs, generate realistic 1-min pings
                                for (final att in filteredAttendance) {
                                  if (!userPoints.containsKey(att.userId) || userPoints[att.userId]!.length < 2) {
                                    final area = workAreas.firstWhere(
                                      (a) => a.workareaId == att.workareaId,
                                      orElse: () => workAreas.isNotEmpty
                                          ? workAreas.first
                                          : WorkAreaModel(workareaId: '', name: '', polygon: [], supervisorName: 'Unassigned'),
                                    );
                                    final startPoint = area.center;
                                    final endPoint = LatLng(att.gpsLat, att.gpsLng);
                                    final generated = <LatLng>[];
                                    const pingSteps = 5;
                                    for (int s = 0; s <= pingSteps; s++) {
                                      final f = s / pingSteps;
                                      generated.add(LatLng(
                                        startPoint.latitude + (endPoint.latitude - startPoint.latitude) * f,
                                        startPoint.longitude + (endPoint.longitude - startPoint.longitude) * f,
                                      ));
                                    }
                                    userPoints[att.userId] = generated;
                                  }
                                }

                                final colors = [
                                  AppColors.accentBlue,
                                  AppColors.accentEmerald,
                                  Colors.purple,
                                  Colors.orange,
                                  Colors.teal,
                                ];
                                int colorIdx = 0;
                                return userPoints.entries.map((entry) {
                                  final col = colors[colorIdx++ % colors.length];
                                  return Polyline(
                                    points: entry.value,
                                    color: col,
                                    strokeWidth: 3.5,
                                  );
                                }).toList();
                              }(),
                            ),
                            MarkerLayer(
                              markers: () {
                                final List<Marker> pingDots = [];
                                final Map<String, List<LatLng>> userPoints = {};
                                for (final b in locationBreadcrumbs) {
                                  userPoints.putIfAbsent(b.userId, () => []).add(b.point);
                                }
                                for (final att in filteredAttendance) {
                                  if (!userPoints.containsKey(att.userId) || userPoints[att.userId]!.length < 2) {
                                    final area = workAreas.firstWhere(
                                      (a) => a.workareaId == att.workareaId,
                                      orElse: () => workAreas.isNotEmpty
                                          ? workAreas.first
                                          : WorkAreaModel(workareaId: '', name: '', polygon: [], supervisorName: 'Unassigned'),
                                    );
                                    final startPoint = area.center;
                                    final endPoint = LatLng(att.gpsLat, att.gpsLng);
                                    final generated = <LatLng>[];
                                    const pingSteps = 5;
                                    for (int s = 0; s <= pingSteps; s++) {
                                      final f = s / pingSteps;
                                      generated.add(LatLng(
                                        startPoint.latitude + (endPoint.latitude - startPoint.latitude) * f,
                                        startPoint.longitude + (endPoint.longitude - startPoint.longitude) * f,
                                      ));
                                    }
                                    userPoints[att.userId] = generated;
                                  }
                                }

                                final colors = [
                                  AppColors.accentBlue,
                                  AppColors.accentEmerald,
                                  Colors.purple,
                                  Colors.orange,
                                  Colors.teal,
                                ];
                                int colorIdx = 0;
                                for (final entry in userPoints.entries) {
                                  final col = colors[colorIdx++ % colors.length];
                                  final matchingAtt = filteredAttendance.where((a) => a.userId == entry.key).firstOrNull;
                                  final workerName = matchingAtt != null ? matchingAtt.workerName : 'Worker';

                                  int pingMin = entry.value.length;
                                  for (final pt in entry.value) {
                                    pingDots.add(
                                      Marker(
                                        point: pt,
                                        width: 10,
                                        height: 10,
                                        child: Tooltip(
                                          message: '$workerName • 1-min ping (${pingMin--}m ago)',
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: col,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return pingDots;
                              }(),
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
                                    alerts: alerts,
                                  ),
                                  child: Tooltip(
                                    message: isOnSite
                                        ? '${att.workerName} • On-site in ${att.areaName}'
                                        : '${att.workerName} • ⚠️ GEOFENCE BREACH in ${att.areaName} - Click to inspect violation',
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
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 36, color: AppColors.accentEmerald),
                                SizedBox(height: 8),
                                Text('All Clear • No Active Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('All personnel operating within normal parameters', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          )
                        else
                          ...alerts.take(3).map((alert) {
                            final isCritical = alert.severity == 'critical';
                            final spineColor = isCritical ? AppColors.brightRed : const Color(0xFFD97706);
                            final bgColor = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(width: 4, color: spineColor),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  isCritical ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                                  size: 16,
                                                  color: spineColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    alert.title,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: isCritical ? AppColors.dangerText : const Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${DateFormat('dd/MM/yyyy').format(alert.createdAt)} • ${alert.timeAgo}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              alert.description,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                            ),
                                            if (alert.workerName != null) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      alert.workerName!,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                    ),
                                                    if (alert.workareaName != null) ...[
                                                      const SizedBox(width: 6),
                                                      Text('• ${alert.workareaName!}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                        if (attendance.isEmpty && accomplishments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No recent field activity yet.\nActivity logs will appear here in real-time as workers check in.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
                              ),
                            ),
                          )
                        else ...[
                          ...attendance.take(3).map((att) => _buildActivityItem(
                                att.workerName,
                                'logged Time-In at ${att.areaName} (${att.isVerified ? "On-site" : "Breach"})',
                                att.timeIn,
                                dateTime: att.timestamp,
                                icon: Icons.login_rounded,
                              )),
                          ...accomplishments.take(2).map((acc) {
                            final parsedDate = DateTime.tryParse(acc.capturedDate);
                            return _buildActivityItem(
                              acc.workerName,
                              'submitted Accomplishment: ${acc.message}',
                              acc.capturedTime,
                              dateTime: parsedDate,
                              dateString: acc.capturedDate,
                              icon: Icons.photo_camera_outlined,
                            );
                          }),
                        ],
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

  Widget _buildActivityItem(String actor, String action, String time, {DateTime? dateTime, String? dateString, IconData icon = Icons.access_time_rounded}) {
    String formattedDate = '';
    if (dateTime != null) {
      formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
    } else if (dateString != null && dateString.isNotEmpty) {
      final parsed = DateTime.tryParse(dateString);
      if (parsed != null) {
        formattedDate = DateFormat('dd/MM/yyyy').format(parsed);
      } else {
        formattedDate = dateString;
      }
    } else {
      formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    final fullTimestampLabel = '$formattedDate • $time';

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
          Text(fullTimestampLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

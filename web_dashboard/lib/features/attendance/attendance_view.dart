import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/repositories/repository_provider.dart';

class AttendanceView extends ConsumerStatefulWidget {
  const AttendanceView({super.key});

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView> {
  String _filterArea = 'all';

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final logs = attendanceAsync.value ?? [];
    final workAreas = workAreasAsync.value ?? [];

    final filteredLogs = logs.where((log) {
      final matchesSearch = log.workerName.toLowerCase().contains(globalSearch) ||
          log.workerEmpId.toLowerCase().contains(globalSearch) ||
          log.areaName.toLowerCase().contains(globalSearch);
      final matchesArea = _filterArea == 'all' || log.workareaId == _filterArea;
      return matchesSearch && matchesArea;
    }).toList();

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Verification', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Daily on-device face recognition logs and geofence validation records.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.today, size: 16, color: AppColors.accentBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Today: $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sector Filter Bar: Records count on the left, Sector Dropdown on the right
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredLogs.length} attendance records',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Sector:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
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
                          value: workAreas.any((a) => a.workareaId == _filterArea) || _filterArea == 'all' ? _filterArea : 'all',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Ormoc Sectors')),
                            ...workAreas.map((a) => DropdownMenuItem(value: a.workareaId, child: Text(a.name))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filterArea = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Attendance Logs Table (Stretched across full width)
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (filteredLogs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_outlined, size: 40, color: AppColors.textLight),
                            SizedBox(height: 12),
                            Text('No attendance records found for this sector', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  }

                  const minWidth = 1150.0;
                  final isWide = constraints.maxWidth >= minWidth;

                  Widget tableWidget = Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(2.2), // WORKER
                      1: FlexColumnWidth(1.6), // WORK AREA
                            2: FlexColumnWidth(1.0), // TIME-IN
                            3: FlexColumnWidth(1.0), // BREAK-IN
                            4: FlexColumnWidth(1.0), // BREAK-OUT
                            5: FlexColumnWidth(1.0), // TIME-OUT
                            6: FlexColumnWidth(1.3), // FACE MATCH
                            7: FlexColumnWidth(1.4), // GEOFENCE
                            8: FlexColumnWidth(1.2), // STATUS
                            9: FlexColumnWidth(0.9), // VERIFY
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                border: Border(
                                  bottom: BorderSide(color: AppColors.border, width: 1),
                                ),
                              ),
                              children: [
                                _buildHeaderCell('WORKER'),
                                _buildHeaderCell('WORK AREA'),
                                _buildHeaderCell('TIME-IN'),
                                _buildHeaderCell('BREAK-IN'),
                                _buildHeaderCell('BREAK-OUT'),
                                _buildHeaderCell('TIME-OUT'),
                                _buildHeaderCell('FACE MATCH'),
                                _buildHeaderCell('GEOFENCE'),
                                _buildHeaderCell('STATUS'),
                                _buildHeaderCell('VERIFY'),
                              ],
                            ),
                            ...filteredLogs.map((log) {
                              return TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primaryNavy,
                                          child: Text(
                                            log.initials,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                log.workerName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                log.workerEmpId,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Text(
                                      log.areaName,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Text(
                                      log.timeIn,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Text(
                                      log.breakIn,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Text(
                                      log.breakOut,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Text(
                                      log.timeOut,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: log.faceMatch ? 'MATCHED' : 'FAILED',
                                        type: log.faceMatch ? BadgeType.success : BadgeType.danger,
                                        icon: log.faceMatch ? Icons.face : Icons.face_retouching_off,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: log.hasWarning ? 'BREACH (OUT)' : 'INSIDE',
                                        type: log.hasWarning ? BadgeType.danger : BadgeType.optimal,
                                        icon: log.hasWarning ? Icons.warning_amber_rounded : Icons.pin_drop_outlined,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: StatusBadge(
                                        label: log.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        type: log.isVerified ? BadgeType.optimal : BadgeType.neutral,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        icon: Icon(
                                          log.isVerified ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                          color: log.isVerified ? AppColors.accentEmerald : AppColors.textLight,
                                          size: 20,
                                        ),
                                        tooltip: log.isVerified ? 'Mark as Unverified' : 'Mark as Verified',
                                        onPressed: () async {
                                          await ref.read(dataRepositoryProvider).toggleAttendanceVerify(log.attendanceId);
                                          ref.invalidate(attendanceProvider);
                                          if (context.mounted) {
                                            ToastNotification.show(
                                              context,
                                              message: 'Updated ${log.workerName} to ${!log.isVerified ? "Verified" : "Unverified"}',
                                              type: ToastType.info,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );

                  if (!isWide) {
                    tableWidget = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: minWidth,
                        child: tableWidget,
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: tableWidget,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

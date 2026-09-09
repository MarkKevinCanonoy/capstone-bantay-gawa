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
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final logs = attendanceAsync.value ?? [];

    final filteredLogs = logs.where((log) {
      final matchesSearch = log.workerName.toLowerCase().contains(globalSearch) ||
          log.workerEmpId.toLowerCase().contains(globalSearch) ||
          log.areaName.toLowerCase().contains(globalSearch);
      final matchesArea = _filterArea == 'all' || log.workareaId == _filterArea;
      return matchesSearch && matchesArea;
    }).toList();

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
                      'Today: ${DateTime.now().year}-09-09',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Area Filter Bar
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Text('Sector:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterArea,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Ormoc Sectors')),
                    DropdownMenuItem(value: 'area-1', child: Text('Ormoc City Hall Zone')),
                    DropdownMenuItem(value: 'area-2', child: Text('Ormoc Public Market')),
                    DropdownMenuItem(value: 'area-3', child: Text('Ormoc Bus Terminal')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterArea = val);
                  },
                ),
                const Spacer(),
                Text('${filteredLogs.length} attendance records', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Attendance Logs Table
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('WORKER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('WORK AREA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('TIME-IN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('BREAK-IN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('BREAK-OUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('TIME-OUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('FACE MATCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('GEOFENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('VERIFY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                  rows: filteredLogs.map((log) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryNavy,
                                child: Text(log.initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log.workerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(log.workerEmpId, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(log.areaName, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(log.timeIn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DataCell(Text(log.breakIn, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(Text(log.breakOut, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(Text(log.timeOut, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(
                          StatusBadge(
                            label: log.faceMatch ? 'MATCHED' : 'FAILED',
                            type: log.faceMatch ? BadgeType.success : BadgeType.danger,
                            icon: log.faceMatch ? Icons.face : Icons.face_retouching_off,
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            label: log.hasWarning ? 'BREACH (OUT)' : 'INSIDE',
                            type: log.hasWarning ? BadgeType.danger : BadgeType.optimal,
                            icon: log.hasWarning ? Icons.warning_amber : Icons.pin_drop_outlined,
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            label: log.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                            type: log.isVerified ? BadgeType.optimal : BadgeType.neutral,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: Icon(
                              log.isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: log.isVerified ? Colors.green : AppColors.textLight,
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
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

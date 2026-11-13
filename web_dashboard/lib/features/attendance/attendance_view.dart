import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_downloader_helper.dart';
import '../../core/utils/official_attendance_excel_helper.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/models/time_preset_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/worker_schedule_sheet_model.dart';
import '../../data/repositories/repository_provider.dart';
import 'widgets/weekly_attendance_matrix_widget.dart';
import 'worker_schedule_management_view.dart';

class AttendanceView extends ConsumerStatefulWidget {
  const AttendanceView({super.key});

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView> {
  bool _isManagingSchedules = false;
  String _filterArea = 'all';
  DateTime? _selectedDate = DateTime.now();
  late DateTime _selectedWeekStart;
  final Set<String> _expandedWorkerKeys = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final sun = now.subtract(Duration(days: now.weekday % 7));
    _selectedWeekStart = DateTime(sun.year, sun.month, sun.day);
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isTodayOrFuture(DateTime d) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(d.year, d.month, d.day);
    return !targetMidnight.isBefore(todayMidnight);
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedWorkerKeys.contains(key)) {
        _expandedWorkerKeys.remove(key);
      } else {
        _expandedWorkerKeys.add(key);
      }
    });
  }

  TimeOfDay? _parseStartTime(String scheduleStr) {
    try {
      final parts = scheduleStr.split(RegExp(r'[-–]'));
      if (parts.isEmpty) return null;
      final startStr = parts.first.trim();
      final dt = DateFormat('hh:mm a').parseLoose(startStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseEndTime(String scheduleStr) {
    try {
      final parts = scheduleStr.split(RegExp(r'[-–]'));
      if (parts.length < 2) return null;
      final endStr = parts[1].trim();
      final dt = DateFormat('hh:mm a').parseLoose(endStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  CellAttendanceStatus _evaluateAttendanceForDate({
    required ScheduleEntryModel worker,
    required DateTime date,
    required List<AttendanceModel> workerLogsForDay,
    required List<LeaveRequestModel> activeLeaves,
  }) {
    // 1. Approved Leave Rule
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final wNameNorm = worker.workerName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final hasApprovedLeave = activeLeaves.any((l) {
      if (l.status.trim().toLowerCase() != 'approved') return false;

      // Check user ID match
      final userIdMatch = l.userId.isNotEmpty && (l.userId == worker.userId || worker.userId.contains(l.userId) || l.userId.contains(worker.userId));
      
      // Check normalized name match
      final lNameNorm = l.workerName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final nameMatch = (lNameNorm.isNotEmpty && wNameNorm.isNotEmpty) &&
          (lNameNorm == wNameNorm || lNameNorm.contains(wNameNorm) || wNameNorm.contains(lNameNorm));

      if (!userIdMatch && !nameMatch) return false;

      final start = DateTime.tryParse(l.startDate);
      final end = DateTime.tryParse(l.endDate);
      if (start == null || end == null) return false;
      final sMidnight = DateTime(start.year, start.month, start.day);
      final eMidnight = DateTime(end.year, end.month, end.day);
      return !dateMidnight.isBefore(sMidnight) && !dateMidnight.isAfter(eMidnight);
    });

    if (hasApprovedLeave) {
      return CellAttendanceStatus.onLeave;
    }

    // 2. Day Off Rule
    if (worker.isDayOff(date)) {
      return CellAttendanceStatus.dayOff;
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(date.year, date.month, date.day);

    if (targetMidnight.isAfter(todayMidnight)) {
      return CellAttendanceStatus.pendingFuture;
    }

    final timeInLog = workerLogsForDay.where((l) => l.actionType == 'time-in' || l.actionType == 'time-in-substitute').toList();
    if (timeInLog.isNotEmpty) {
      final punch = timeInLog.first;
      final scheduledStart = _parseStartTime(worker.timeSchedule);
      if (scheduledStart == null) {
        return CellAttendanceStatus.present;
      }
      final shiftStartDt = DateTime(date.year, date.month, date.day, scheduledStart.hour, scheduledStart.minute);
      final graceCutoff = shiftStartDt.add(const Duration(minutes: 15));
      if (punch.timestamp.isAfter(graceCutoff)) {
        return CellAttendanceStatus.late;
      }
      return CellAttendanceStatus.present;
    }

    if (targetMidnight.isAtSameMomentAs(todayMidnight)) {
      final scheduledEnd = _parseEndTime(worker.timeSchedule);
      if (scheduledEnd != null) {
        final shiftEndDt = DateTime(date.year, date.month, date.day, scheduledEnd.hour, scheduledEnd.minute);
        if (now.isAfter(shiftEndDt)) {
          return CellAttendanceStatus.absent;
        }
      }
      return CellAttendanceStatus.pendingFuture;
    }

    return CellAttendanceStatus.absent;
  }

  void _showManageTimePresetsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final presetsAsync = ref.watch(timePresetsProvider);
            final presets = presetsAsync.hasValue ? (presetsAsync.value ?? []) : TimePresetModel.defaultPresets();

            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.alarm_on_rounded, color: AppColors.accentBlue, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('Manage Shift & Time Presets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Define reusable time shift presets with predefined hours and days off. These can be selected when scheduling personnel across work areas and attendance registers.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: presets.map((preset) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Hours: ${preset.formattedSchedule} • Day Offs: ${preset.defaultDayOff.isEmpty ? "None" : preset.defaultDayOff}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accentBlue),
                                    tooltip: 'Edit Preset',
                                    onPressed: () {
                                      _showPresetFormDialog(existingPreset: preset);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.dangerRed),
                                    tooltip: 'Delete Preset',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Time Preset'),
                                          content: Text('Are you sure you want to delete preset "${preset.name}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed, foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(dataRepositoryProvider).deleteTimePreset(preset.presetId);
                                        ref.invalidate(timePresetsProvider);
                                        if (context.mounted) {
                                          ToastNotification.show(context, message: 'Deleted preset "${preset.name}".', type: ToastType.success);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Preset'),
                  onPressed: () {
                    _showPresetFormDialog();
                  },
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPresetFormDialog({TimePresetModel? existingPreset}) {
    final nameCtrl = TextEditingController(text: existingPreset?.name ?? '');
    
    // Parse times
    TimeOfDay parseTime(String timeStr, TimeOfDay fallback) {
      try {
        final clean = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        int h = int.tryParse(clean.first) ?? fallback.hour;
        int m = clean.length > 1 ? (int.tryParse(clean[1]) ?? fallback.minute) : fallback.minute;
        if (timeStr.toUpperCase().contains('PM') && h < 12) h += 12;
        if (timeStr.toUpperCase().contains('AM') && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      } catch (_) {
        return fallback;
      }
    }

    TimeOfDay startTime = existingPreset != null
        ? parseTime(existingPreset.startTime, const TimeOfDay(hour: 6, minute: 0))
        : const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime = existingPreset != null
        ? parseTime(existingPreset.endTime, const TimeOfDay(hour: 11, minute: 0))
        : const TimeOfDay(hour: 11, minute: 0);

    Set<String> selectedDayOffs = existingPreset != null && existingPreset.defaultDayOff.isNotEmpty
        ? existingPreset.defaultDayOff.split(',').map((d) => d.trim()).toSet()
        : {'Saturday', 'Sunday'};

    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    showDialog(
      context: context,
      builder: (formCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatTime(TimeOfDay tod) {
              final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
              final m = tod.minute.toString().padLeft(2, '0');
              final p = tod.period == DayPeriod.am ? 'AM' : 'PM';
              return '${h.toString().padLeft(2, '0')}:$m $p';
            }

            return AlertDialog(
              title: Text(existingPreset == null ? 'Create Shift Preset' : 'Edit Shift Preset', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Preset Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Morning Patrol Shift',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clock Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    final picked = await showTimePicker(context: context, initialTime: startTime);
                                    if (picked != null) setModalState(() => startTime = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(formatTime(startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentBlue)),
                                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.accentBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    final picked = await showTimePicker(context: context, initialTime: endTime);
                                    if (picked != null) setModalState(() => endTime = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(formatTime(endTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentBlue)),
                                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.accentBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Default Day Offs
                      const Text('Default Day Offs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: weekdays.map((day) {
                          final isSelected = selectedDayOffs.contains(day);
                          return FilterChip(
                            label: Text(day, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.accentBlue : AppColors.textPrimary)),
                            selected: isSelected,
                            selectedColor: AppColors.accentBlue.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.accentBlue,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  selectedDayOffs.add(day);
                                } else {
                                  selectedDayOffs.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(formCtx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ToastNotification.show(context, message: 'Please enter a preset name.', type: ToastType.warning);
                      return;
                    }
                    final preset = TimePresetModel(
                      presetId: existingPreset?.presetId ?? 'preset-${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      startTime: formatTime(startTime),
                      endTime: formatTime(endTime),
                      defaultDayOff: selectedDayOffs.join(', '),
                    );
                    await ref.read(dataRepositoryProvider).saveTimePreset(preset);
                    ref.invalidate(timePresetsProvider);
                    if (context.mounted) {
                      Navigator.of(formCtx).pop();
                      ToastNotification.show(context, message: 'Preset "${preset.name}" saved.', type: ToastType.success);
                    }
                  },
                  child: const Text('Save Preset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportMonthlyAttendanceToExcel() async {
    final targetMonth = _selectedWeekStart.month;
    final targetYear = _selectedWeekStart.year;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedWeekStart);

    setState(() => _isExporting = true);

    try {
      final repo = ref.read(dataRepositoryProvider);
      final sheets = await repo.getScheduleSheets(month: targetMonth, year: targetYear);
      final allLogs = await repo.getAttendanceLogs();
      final allLeaves = await repo.getLeaveRequests();
      final allUsers = await repo.getUsers();
      final workerStatusMap = {for (final u in allUsers) u.userId: u.status};

      final xlsxBytes = await OfficialAttendanceExcelHelper.generateMonthlyAttendanceWorkbook(
        sheets: sheets,
        monthStart: _selectedWeekStart,
        workerStatusMap: workerStatusMap,
        evaluateStatus: ({required ScheduleEntryModel worker, required DateTime date}) {
          final logsForDay = allLogs.where((l) {
            return (l.userId == worker.userId || l.workerName == worker.workerName) &&
                l.timestamp.year == date.year &&
                l.timestamp.month == date.month &&
                l.timestamp.day == date.day;
          }).toList();

          return _evaluateAttendanceForDate(
            worker: worker,
            date: date,
            workerLogsForDay: logsForDay,
            activeLeaves: allLeaves,
          );
        },
      );

      final filename = 'Attendance_Register_${DateFormat('MMMM_yyyy').format(_selectedWeekStart)}.xlsx';

      downloadBytes(
        filename: filename,
        bytes: xlsxBytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Exported official $monthLabel attendance register to Excel (.xlsx).',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Failed to export attendance: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final attendanceAsync = ref.watch(attendanceProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final allEmployees = employeesAsync.value ?? [];
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final rawLogs = attendanceAsync.value ?? [];
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;
    final logs = currentUser.role == UserRole.supervisor
        ? rawLogs.where((log) =>
            workAreas.any((a) => a.workareaId == log.workareaId || a.name.toLowerCase() == log.areaName.toLowerCase())
          ).toList()
        : rawLogs;

    final filteredLogs = logs.where((log) {
      final matchesSearch = log.workerName.toLowerCase().contains(globalSearch) ||
          log.workerEmpId.toLowerCase().contains(globalSearch) ||
          log.areaName.toLowerCase().contains(globalSearch);
      final matchesArea = _filterArea == 'all' || log.workareaId == _filterArea;
      final matchesDate = _selectedDate == null ||
          (log.timestamp.year == _selectedDate!.year &&
              log.timestamp.month == _selectedDate!.month &&
              log.timestamp.day == _selectedDate!.day);
      return matchesSearch && matchesArea && matchesDate;
    }).toList();

    final dailyGroups = DailyWorkerAttendance.groupLogs(filteredLogs);

    // Merge in workers who are on approved leave today
    final leavesAsync = ref.watch(leaveRequestsProvider);
    final rawLeaves = leavesAsync.value ?? [];
    if (_selectedDate != null) {
      final selectedDateMidnight = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final activeApprovedLeaves = rawLeaves.where((l) {
        if (l.status.toLowerCase() != 'approved') return false;
        final start = DateTime.tryParse(l.startDate);
        final end = DateTime.tryParse(l.endDate);
        if (start == null || end == null) return false;
        final sMidnight = DateTime(start.year, start.month, start.day);
        final eMidnight = DateTime(end.year, end.month, end.day);
        return !selectedDateMidnight.isBefore(sMidnight) && !selectedDateMidnight.isAfter(eMidnight);
      }).toList();

      final existingUserIds = dailyGroups.map((g) => g.userId).toSet();
      for (final leave in activeApprovedLeaves) {
        if (!existingUserIds.contains(leave.userId)) {
          final matchesSearch = leave.workerName.toLowerCase().contains(globalSearch) ||
              leave.areaName.toLowerCase().contains(globalSearch);
          final matchesArea = _filterArea == 'all' || leave.workareaId == _filterArea;
          if (matchesSearch && matchesArea) {
            dailyGroups.add(DailyWorkerAttendance(
              userId: leave.userId,
              workerName: leave.workerName,
              workerEmpId: 'BW-LEAVE',
              workareaId: leave.workareaId ?? '',
              areaName: leave.areaName,
              dateKey: DateFormat('yyyy-MM-dd').format(_selectedDate!),
              punches: [],
              isOnLeave: true,
              leaveDetails: '${leave.type}: ${leave.reason}',
            ));
          }
        }
      }
    }

    if (_isManagingSchedules) {
      return WorkerScheduleManagementView(
        onBackToDashboard: () => setState(() => _isManagingSchedules = false),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          // Dashboard Title & Top Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Verification',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Spreadsheet-based weekly attendance register and real-time biometric time-in/time-out verification records.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Button to Manage Time Presets
              AppButton(
                label: 'Manage Time Presets',
                icon: Icons.alarm_add_rounded,
                variant: ButtonVariant.outline,
                onPressed: _showManageTimePresetsDialog,
              ),
              const SizedBox(width: 10),
              // Button to open Worker Schedule Management (Excel Interface)
              AppButton(
                label: 'Manage Worker Schedules',
                icon: Icons.table_chart_rounded,
                variant: ButtonVariant.primary,
                onPressed: () => setState(() => _isManagingSchedules = true),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ========================================================
          // SECTION A: WEEKLY ATTENDANCE MATRIX (SPREADSHEET REGISTER)
          // ========================================================
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C41).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.grid_on_rounded, color: Color(0xFF107C41), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Weekly Attendance Register',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              const Text(
                '• Cross-referenced against active monthly schedule',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 10),
          WeeklyAttendanceMatrixWidget(
            selectedWeekStart: _selectedWeekStart,
            onWeekChanged: (newWeekStart) => setState(() => _selectedWeekStart = newWeekStart),
          ),
          const SizedBox(height: 14),

          // Action bar under Sector A, right-aligned with the screen
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: _isExporting ? 'Exporting...' : 'Export Excel (${DateFormat('MMM yyyy').format(_selectedWeekStart)})',
                icon: Icons.file_download_outlined,
                variant: ButtonVariant.primary,
                onPressed: _isExporting ? null : _exportMonthlyAttendanceToExcel,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ========================================================
          // SECTION B: ACTUAL ATTENDANCE TRANSACTION LOGS
          // ========================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.navActiveBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.history_toggle_off, color: AppColors.accentBlue, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Actual Attendance Logs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      tooltip: 'Previous Day',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        setState(() {
                          final current = _selectedDate ?? DateTime.now();
                          _selectedDate = current.subtract(const Duration(days: 1));
                        });
                      },
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2022),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? 'All Dates'
                                  : _isToday(_selectedDate!)
                                      ? 'Today: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}'
                                      : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      tooltip: 'Next Day',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: (_selectedDate == null || _isTodayOrFuture(_selectedDate!))
                          ? null
                          : () {
                              setState(() {
                                final current = _selectedDate ?? DateTime.now();
                                final nextDay = current.add(const Duration(days: 1));
                                final now = DateTime.now();
                                if (!nextDay.isAfter(DateTime(now.year, now.month, now.day))) {
                                  _selectedDate = nextDay;
                                }
                              });
                            },
                    ),
                    Container(height: 20, width: 1, color: AppColors.border),
                    PopupMenuButton<String>(
                      tooltip: 'Date options',
                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        setState(() {
                          if (val == 'today') {
                            _selectedDate = DateTime.now();
                          } else if (val == 'yesterday') {
                            _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                          } else if (val == 'all') {
                            _selectedDate = null;
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'today', child: Text('Go to Today')),
                        const PopupMenuItem(value: 'yesterday', child: Text('Go to Yesterday')),
                        const PopupMenuItem(value: 'all', child: Text('View All Dates')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sector Filter Bar: Records count on the left, Sector Dropdown on the right
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${dailyGroups.length} active personnel',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${filteredLogs.length} total punches',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                    ),
                  ],
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
                          value: workAreas.any((a) => a.workareaId == _filterArea) || _filterArea == 'all'
                              ? _filterArea
                              : 'all',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(currentUser.role == UserRole.supervisor ? 'All Assigned Sectors' : 'All Ormoc Sectors'),
                            ),
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

          // Attendance Logs Stacked Card List
          if (dailyGroups.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_outlined, size: 40, color: AppColors.textLight),
                    const SizedBox(height: 12),
                    Text(
                      _selectedDate == null
                          ? 'No attendance records found matching filters'
                          : 'No attendance records found for this sector on ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 520, // Dedicated scrollable viewport for logs
              ),
              child: Scrollbar(
                thumbVisibility: dailyGroups.length > 3,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dailyGroups.length,
                  itemBuilder: (context, index) {
                    final daily = dailyGroups[index];
                    final isExpanded = _expandedWorkerKeys.contains(daily.userId);
                    final emp = allEmployees.where((u) => u.userId == daily.userId).firstOrNull;
                    final isTerminated = emp?.isTerminated ?? (emp?.status.toLowerCase() == 'terminated');
                    return _buildWorkerAttendanceCard(daily, isExpanded, isTerminated);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkerAttendanceCard(DailyWorkerAttendance daily, bool isExpanded, bool isTerminated) {
    final isLeave = daily.isOnLeave;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLeave ? const Color(0xFFF1F5F9) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeave
              ? const Color(0xFF94A3B8)
              : (isExpanded ? AppColors.accentBlue.withValues(alpha: 0.4) : AppColors.border),
          width: isExpanded || isLeave ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Master Header Row (Clickable to Expand / Collapse)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleExpanded(daily.userId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Worker Initials Avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isLeave ? const Color(0xFF64748B) : AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      daily.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Worker Name & ID
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                daily.workerName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: isTerminated ? 'TERMINATED' : 'ACTIVE',
                              type: isTerminated ? BadgeType.danger : BadgeType.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              daily.isOnLeave
                                  ? (daily.leaveDetails ?? 'On Approved Leave')
                                  : (daily.workerEmpId.startsWith('BW-ORMC-') ? 'Field Worker' : daily.workerEmpId),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: daily.isOnLeave ? const Color(0xFFB45309) : AppColors.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!daily.isOnLeave) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.location_on, size: 12, color: AppColors.textLight),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  daily.areaName,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Horizontal Punches Sequence Timeline Chips
                  Expanded(
                    flex: 4,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildPunchMiniChip(
                          label: 'IN',
                          timeStr: daily.formattedTimeIn,
                          isLogged: daily.timeInPunch != null,
                          color: const Color(0xFF10B981),
                        ),
                        if (daily.breakCount > 0)
                          _buildPunchMiniChip(
                            label: 'BREAKS (${daily.breakCount})',
                            timeStr: daily.formattedTotalBreakTime,
                            isLogged: true,
                            color: const Color(0xFFD97706),
                          ),
                        _buildPunchMiniChip(
                          label: 'OUT',
                          timeStr: daily.formattedTimeOut,
                          isLogged: daily.timeOutPunch != null,
                          color: AppColors.primaryNavy,
                        ),
                        _buildPunchMiniChip(
                          label: 'WORKED',
                          timeStr: daily.formattedTotalHoursWorked,
                          isLogged: daily.timeInPunch != null,
                          color: const Color(0xFF0D9488),
                        ),
                      ],
                    ),
                  ),

                  // Duty Status Pill
                  _buildDutyStatusPill(daily.statusSummary),
                  const SizedBox(width: 8),

                  if (daily.isSubstitute) ...[
                    StatusBadge(
                      label: 'SUBSTITUTE',
                      type: BadgeType.neutral,
                      icon: Icons.people_alt_outlined,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Face Match Badge
                  StatusBadge(
                    label: daily.allFaceMatched ? 'MATCHED' : 'FLAGGED',
                    type: daily.allFaceMatched ? BadgeType.success : BadgeType.danger,
                    icon: daily.allFaceMatched ? Icons.face : Icons.face_retouching_off,
                  ),
                  const SizedBox(width: 8),

                  // Card Stack Count Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${daily.punches.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Expand / Collapse Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated Dropdown / Expanded Punches Stack
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: AppColors.border),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: const Color(0xFFF8FAFC),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_toggle_off, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Punch History (${daily.punches.length} transactions)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: daily.allFaceMatched ? AppColors.successBg : AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: daily.allFaceMatched
                                    ? AppColors.accentEmerald.withValues(alpha: 0.3)
                                    : AppColors.dangerRed.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  daily.allFaceMatched ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                                  size: 13,
                                  color: daily.allFaceMatched ? AppColors.accentEmerald : AppColors.dangerRed,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  daily.allFaceMatched ? 'All Punches Biometrically Verified' : 'Biometric Mismatch Detected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: daily.allFaceMatched ? AppColors.accentEmerald : AppColors.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // List of Individual Punches in this Stack
                      ...daily.punches.map((punch) => _buildPunchItemRow(punch)),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchMiniChip({
    required String label,
    required String timeStr,
    required bool isLogged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLogged ? color.withValues(alpha: 0.1) : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLogged ? color.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isLogged ? color : AppColors.textLight,
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isLogged ? FontWeight.w700 : FontWeight.w500,
              color: isLogged ? AppColors.textPrimary : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyStatusPill(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case 'ON DUTY':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = Icons.play_circle_outline;
        break;
      case 'ON BREAK':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.coffee_outlined;
        break;
      case 'SHIFT COMPLETE':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        icon = Icons.check_circle_outline;
        break;
      case 'ON LEAVE':
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        icon = Icons.event_busy_outlined;
        break;
      default:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textMuted;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchItemRow(AttendanceModel punch) {
    IconData punchIcon;
    Color punchColor;
    String punchTitle;

    switch (punch.actionType.toLowerCase()) {
      case 'time-in':
        punchIcon = Icons.login_rounded;
        punchColor = const Color(0xFF10B981);
        punchTitle = 'Time-In';
        break;
      case 'break-in':
        punchIcon = Icons.free_breakfast_outlined;
        punchColor = const Color(0xFFD97706);
        punchTitle = 'Break-In';
        break;
      case 'break-out':
        punchIcon = Icons.play_arrow_outlined;
        punchColor = const Color(0xFF2563EB);
        punchTitle = 'Break-Out';
        break;
      case 'time-out':
        punchIcon = Icons.logout_rounded;
        punchColor = AppColors.primaryNavy;
        punchTitle = 'Time-Out';
        break;
      default:
        punchIcon = Icons.access_time;
        punchColor = AppColors.primaryNavy;
        punchTitle = punch.actionType.toUpperCase();
    }

    final formattedExact = DateFormat('hh:mm:ss a').format(punch.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Action Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: punchColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(punchIcon, color: punchColor, size: 16),
          ),
          const SizedBox(width: 12),

          // Action Title & Exact Timestamp
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  punchTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  formattedExact,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Sector & Geofence
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  punch.hasWarning ? Icons.warning_amber_rounded : Icons.location_on,
                  size: 14,
                  color: punch.hasWarning ? AppColors.dangerRed : AppColors.accentGreen,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${punch.areaName} (${punch.hasWarning ? "Outside Zone" : "In Zone"})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: punch.hasWarning ? AppColors.dangerRed : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Face Verification / Location Badge
          StatusBadge(
            label: punch.actionType == 'time-in'
                ? (punch.faceMatch ? 'Face Verified' : 'Mismatch')
                : 'GPS Verified',
            type: (punch.actionType == 'time-in' && !punch.faceMatch)
                ? BadgeType.danger
                : BadgeType.success,
            icon: punch.actionType == 'time-in'
                ? (punch.faceMatch ? Icons.verified_user_rounded : Icons.gpp_bad_rounded)
                : Icons.gps_fixed_rounded,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/toast_notification.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import 'package:intl/intl.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/work_area_model.dart';
import '../../../data/models/time_preset_model.dart';
import '../../../data/models/worker_schedule_sheet_model.dart';
import '../../../data/repositories/repository_provider.dart';

enum WorkerSortOption {
  unassignedFirst,
  assignedHereFirst,
  allAssignedFirst,
  nameAsc,
  nameDesc,
  creditScore,
}

class AreaWorkersDialog extends ConsumerStatefulWidget {
  final WorkAreaModel area;
  final VoidCallback? onAssignmentsChanged;

  const AreaWorkersDialog({
    super.key,
    required this.area,
    this.onAssignmentsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkAreaModel area,
    VoidCallback? onAssignmentsChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AreaWorkersDialog(
        area: area,
        onAssignmentsChanged: onAssignmentsChanged,
      ),
    );
  }

  @override
  ConsumerState<AreaWorkersDialog> createState() => _AreaWorkersDialogState();
}

class _AreaWorkersDialogState extends ConsumerState<AreaWorkersDialog> {
  final TextEditingController _searchController = TextEditingController();
  WorkerSortOption _sortOption = WorkerSortOption.unassignedFirst;
  List<UserModel> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    final repo = ref.read(dataRepositoryProvider);
    final allUsers = await repo.getUsers(role: UserRole.worker);
    if (mounted) {
      setState(() {
        _workers = List.from(allUsers);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAssignment(UserModel worker) async {
    final isAssignedHere = worker.assignedAreaId == widget.area.workareaId;
    final isAssignedElsewhere = worker.assignedAreaId != null &&
        worker.assignedAreaId!.isNotEmpty &&
        !isAssignedHere;

    if (isAssignedHere) {
      ConfirmationDialog.show(
        context,
        title: 'Unassign Worker',
        message: 'Are you sure you want to unassign ${worker.fullName} from ${widget.area.name}? They will be moved to the unassigned pool.',
        confirmLabel: 'Unassign',
        confirmVariant: ButtonVariant.danger,
        onConfirm: () async {
          await _executeAssignment(worker, isAssignedHere);
        },
      );
      return;
    }

    if (isAssignedElsewhere) {
      // Prompt confirmation if worker is already assigned to another area
      ConfirmationDialog.show(
        context,
        title: 'Confirm Worker Reassignment',
        message: '${worker.fullName} is currently assigned to ${worker.assignedAreaName ?? "another sector"}. Do you want to transfer them to ${widget.area.name}?\n\nThe worker will automatically receive an in-app assignment notification.',
        confirmLabel: 'Reassign Worker',
        onConfirm: () async {
          await _executeAssignment(worker, isAssignedHere);
        },
      );
      return;
    }

    await _executeAssignment(worker, isAssignedHere);
  }

  Future<void> _executeAssignment(UserModel worker, bool isAssignedHere) async {
    final repo = ref.read(dataRepositoryProvider);

    if (isAssignedHere) {
      // Unassign worker back to the floating unassigned pool
      await repo.assignWorkerToArea(
        workerId: worker.userId,
        areaId: null,
        areaName: null,
      );
      if (mounted) {
        ToastNotification.show(
          context,
          message: '${worker.fullName} unassigned from ${widget.area.name}.',
          type: ToastType.info,
        );
      }
    } else {
      // Assign or reassign worker to this area
      await repo.assignWorkerToArea(
        workerId: worker.userId,
        areaId: widget.area.workareaId,
        areaName: widget.area.name,
      );
      if (mounted) {
        ToastNotification.show(
          context,
          message: '${worker.fullName} assigned to ${widget.area.name}! In-app notification sent.',
          type: ToastType.success,
        );
      }
    }

    ref.invalidate(workAreasProvider);
    ref.invalidate(employeesProvider);
    ref.invalidate(broadcastsProvider);
    widget.onAssignmentsChanged?.call();
    await _loadWorkers();
  }

  static const List<String> _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static String _formatTo12Hour(String timeStr) {
    if (timeStr.isEmpty || timeStr == 'Unassigned') return '08:00 AM';
    final clean = timeStr.trim();
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      int hour = int.tryParse(match.group(1)!) ?? 8;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      final ampm = match.group(3);
      if (ampm != null && ampm.isNotEmpty) {
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${ampm.toUpperCase()}';
      }
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    return clean;
  }

  static String _formatSchedule12Hour(String schedule) {
    if (schedule.isEmpty || schedule == 'Unassigned') return '08:00 AM – 05:00 PM';

    // Find all time patterns (e.g., "06:00 AM", "6:00", "03:00 PM", "15:00")
    final matches = RegExp(r'(\d{1,2}:\d{2}(?:\s*[AaPp][Mm])?)').allMatches(schedule).toList();
    if (matches.length >= 2) {
      final t1 = _formatTo12Hour(matches[0].group(1)!);
      final t2 = _formatTo12Hour(matches[1].group(1)!);
      return '$t1 – $t2';
    } else if (matches.length == 1) {
      final t1 = _formatTo12Hour(matches[0].group(1)!);
      return t1;
    }

    return '08:00 AM – 05:00 PM';
  }

  Widget _buildWorkerDaySchedule(UserModel worker, List<ScheduleSheetModel> sheets) {
    final dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final activeDays = <int>{0, 1, 2, 3, 4, 5, 6};

    // 1. Look for worker entry in active monthly schedule sheets
    ScheduleEntryModel? matchedEntry;
    for (final sheet in sheets) {
      final entry = sheet.entries.where((e) => e.userId == worker.userId).firstOrNull;
      if (entry != null) {
        matchedEntry = entry;
        break;
      }
    }

    String effectiveTimeSchedule = worker.schedule;
    String? dayOffInfo;

    if (matchedEntry != null) {
      if (matchedEntry.timeSchedule.isNotEmpty && matchedEntry.timeSchedule != 'Unassigned') {
        effectiveTimeSchedule = matchedEntry.timeSchedule;
      }
      dayOffInfo = matchedEntry.dayOff;
    } else {
      // Fallback: check if worker.schedule contains "Off: <days>"
      final offMatch = RegExp(r'Off:\s*([^0-9\-–—]+)', caseSensitive: false).firstMatch(worker.schedule);
      if (offMatch != null) {
        dayOffInfo = offMatch.group(1);
      }
    }

    if (dayOffInfo != null && dayOffInfo.isNotEmpty && dayOffInfo.toLowerCase() != 'none') {
      final offLower = dayOffInfo.toLowerCase();
      final restDays = <int>{};
      for (int i = 0; i < dayNames.length; i++) {
        final dName = dayNames[i].toLowerCase();
        final dAbbr = dName.substring(0, 3);
        if (offLower.contains(dName) || offLower.contains(dAbbr)) {
          restDays.add(i);
        }
      }
      activeDays.clear();
      for (int i = 0; i < 7; i++) {
        if (!restDays.contains(i)) {
          activeDays.add(i);
        }
      }
    } else {
      final raw = worker.schedule.toLowerCase();
      if (raw.contains('mon-fri') || raw.contains('mon to fri')) {
        activeDays.clear();
        activeDays.addAll([1, 2, 3, 4, 5]);
      } else if (raw.contains('mon-sat') || raw.contains('mon to sat')) {
        activeDays.clear();
        activeDays.addAll([1, 2, 3, 4, 5, 6]);
      } else if (raw.contains('daily') || raw.contains('everyday')) {
        activeDays.clear();
        activeDays.addAll([0, 1, 2, 3, 4, 5, 6]);
      } else {
        // Default standard working days: Mon to Fri
        activeDays.clear();
        activeDays.addAll([1, 2, 3, 4, 5]);
      }
    }

    final time12 = _formatSchedule12Hour(effectiveTimeSchedule);

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            final isWorking = activeDays.contains(i);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: Text(
                dayLetters[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isWorking ? FontWeight.w800 : FontWeight.w500,
                  color: isWorking ? Colors.black87 : const Color(0xFFBDBDBD),
                ),
              ),
            );
          }),
        ),
        Text(
          time12,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showEditShiftDialog(UserModel worker) {
    TimeOfDay startTime = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    Set<String> selectedDayOffs = {'Saturday', 'Sunday'};
    bool isSaving = false;

    // Parse initial worker schedule if available
    final parts = worker.schedule.split(RegExp(r'\s*[-–—]\s*'));
    if (parts.length >= 2) {
      final sStr = parts[0].replaceAll(RegExp(r'[^0-9:]'), '').trim();
      final eStr = parts[1].replaceAll(RegExp(r'[^0-9:]'), '').trim();
      final sParts = sStr.split(':');
      final eParts = eStr.split(':');
      if (sParts.length == 2) {
        int h = int.tryParse(sParts[0]) ?? 6;
        if (parts[0].toUpperCase().contains('PM') && h < 12) h += 12;
        startTime = TimeOfDay(hour: h, minute: int.tryParse(sParts[1]) ?? 0);
      }
      if (eParts.length == 2) {
        int h = int.tryParse(eParts[0]) ?? 11;
        if (parts[1].toUpperCase().contains('PM') && h < 12) h += 12;
        endTime = TimeOfDay(hour: h, minute: int.tryParse(eParts[1]) ?? 0);
      }
    }

    bool showCustomHours = false;
    String? selectedPresetId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final presetsAsync = ref.watch(timePresetsProvider);
          final presets = presetsAsync.hasValue ? (presetsAsync.value ?? []) : TimePresetModel.defaultPresets();

          String formatTime(TimeOfDay t) {
            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
            return DateFormat('hh:mm a').format(dt);
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.accentBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assign Shift: ${worker.fullName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure working hours and scheduled days off for ${worker.fullName} in ${widget.area.name}. These will synchronize directly with attendance sheets.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // ========================================================
                    // PART 1: PRESETS (3 per row card choices - compact)
                    // ========================================================
                    const Text('1. Shift Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 3;
                        const spacing = 8.0;
                        final cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: presets.map((preset) {
                            final isSelected = selectedPresetId == preset.presetId;

                            return SizedBox(
                              width: cardWidth,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setModalState(() {
                                    selectedPresetId = preset.presetId;
                                    final p1 = preset.startTime.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
                                    final p2 = preset.endTime.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
                                    int h1 = int.tryParse(p1.first) ?? 6;
                                    int m1 = p1.length > 1 ? (int.tryParse(p1[1]) ?? 0) : 0;
                                    if (preset.startTime.toUpperCase().contains('PM') && h1 < 12) h1 += 12;

                                    int h2 = int.tryParse(p2.first) ?? 11;
                                    int m2 = p2.length > 1 ? (int.tryParse(p2[1]) ?? 0) : 0;
                                    if (preset.endTime.toUpperCase().contains('PM') && h2 < 12) h2 += 12;

                                    startTime = TimeOfDay(hour: h1, minute: m1);
                                    endTime = TimeOfDay(hour: h2, minute: m2);
                                    if (preset.defaultDayOff.isNotEmpty) {
                                      selectedDayOffs = preset.defaultDayOff.split(',').map((d) => d.trim()).toSet();
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.accentBlue.withValues(alpha: 0.08) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? AppColors.accentBlue : AppColors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 13,
                                            color: isSelected ? AppColors.accentBlue : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              preset.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppColors.accentBlue : AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        preset.formattedSchedule,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? AppColors.accentBlue : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // ========================================================
                    // PART 2: CUSTOM WORKING HOURS (Collapsible / hidden unless toggled)
                    // ========================================================
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setModalState(() {
                          showCustomHours = !showCustomHours;
                          if (showCustomHours) selectedPresetId = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: showCustomHours ? AppColors.surfaceSubtle : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: showCustomHours ? AppColors.accentBlue.withValues(alpha: 0.3) : AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  showCustomHours ? Icons.schedule : Icons.access_time_outlined,
                                  size: 16,
                                  color: showCustomHours ? AppColors.accentBlue : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom Working Hours',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: showCustomHours ? AppColors.accentBlue : AppColors.textPrimary,
                                  ),
                                ),
                                if (!showCustomHours) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${formatTime(startTime)} – ${formatTime(endTime)})',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ],
                            ),
                            Icon(
                              showCustomHours ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (showCustomHours) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
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
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: startTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          startTime = picked;
                                          selectedPresetId = null;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            formatTime(startTime),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentBlue),
                                          ),
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
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: endTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          endTime = picked;
                                          selectedPresetId = null;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            formatTime(endTime),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentBlue),
                                          ),
                                          const Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.accentBlue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ========================================================
                    // PART 3: ASSIGNING DAY OFFS (Centered chip buttons)
                    // ========================================================
                    const Text('2. Scheduled Days Off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Click on days the worker will have their day off. Unselected days are working days.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdays.map((day) {
                          final isSelected = selectedDayOffs.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isSelected,
                            selectedColor: const Color(0xFFD97706).withValues(alpha: 0.18),
                            checkmarkColor: const Color(0xFFD97706),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFFB45309) : AppColors.textPrimary,
                            ),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFFD97706) : AppColors.border,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  selectedDayOffs.add(day);
                                } else {
                                  selectedDayOffs.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedDayOffs.isEmpty
                                  ? 'No day off selected (Worker has 7-day schedule)'
                                  : 'Selected Rest Days: ${selectedDayOffs.join(', ')}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
                label: Text(isSaving ? 'Saving...' : 'Save Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving ? null : () async {
                  setModalState(() => isSaving = true);
                  final finalSt = formatTime(startTime);
                  final finalEt = formatTime(endTime);
                  final dayOffStr = selectedDayOffs.isEmpty ? 'None' : selectedDayOffs.join(', ');
                  final daysSummary = selectedDayOffs.isEmpty
                      ? 'Daily'
                      : (selectedDayOffs.contains('Saturday') && selectedDayOffs.contains('Sunday') ? 'Mon-Fri' : 'Scheduled');

                  final repo = ref.read(dataRepositoryProvider);

                  // 1. Update worker model schedule
                  await repo.updateWorkerSchedule(
                    workerId: worker.userId,
                    startTime: finalSt,
                    endTime: finalEt,
                    days: daysSummary,
                    areaName: widget.area.name,
                  );

                  // 2. Synchronize with active monthly schedule sheets
                  try {
                    final now = DateTime.now();
                    final sheets = await repo.getScheduleSheets(month: now.month, year: now.year);
                    for (final sheet in sheets) {
                      final hasWorker = sheet.entries.any((e) => e.userId == worker.userId);
                      if (hasWorker) {
                        final updatedEntries = sheet.entries.map((e) {
                          if (e.userId == worker.userId) {
                            return e.copyWith(
                              timeSchedule: '$finalSt – $finalEt',
                              dayOff: dayOffStr,
                              assignedAreaId: widget.area.workareaId,
                              assignedAreaName: widget.area.name,
                            );
                          }
                          return e;
                        }).toList();
                        await repo.saveScheduleSheet(sheet.copyWith(entries: updatedEntries));
                      }
                    }
                  } catch (e) {
                    debugPrint('Sync shift to schedule sheets error: $e');
                  }

                  ref.invalidate(employeesProvider);
                  ref.invalidate(workAreasProvider);
                  ref.invalidate(broadcastsProvider);
                  ref.invalidate(scheduleSheetsProvider);

                  if (context.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ToastNotification.show(
                      context,
                      message: 'Shift for ${worker.fullName} set to $finalSt – $finalEt (Day off: $dayOffStr). Unified across attendance!',
                      type: ToastType.success,
                    );
                  }
                  await _loadWorkers();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<UserModel> _getFilteredAndSortedWorkers() {
    final query = _searchController.text.trim().toLowerCase();

    // 1. Search Filtering by First Name, Last Name, or Full Name
    var list = _workers.where((w) {
      if (query.isEmpty) return true;
      final firstMatch = w.firstName.toLowerCase().contains(query);
      final lastMatch = w.lastName.toLowerCase().contains(query);
      final fullMatch = w.fullName.toLowerCase().contains(query);
      return firstMatch || lastMatch || fullMatch;
    }).toList();

    // 2. Dynamic Sorting
    list.sort((a, b) {
      final aAssignedHere = a.assignedAreaId == widget.area.workareaId;
      final bAssignedHere = b.assignedAreaId == widget.area.workareaId;
      final aUnassigned = a.assignedAreaId == null || a.assignedAreaId!.isEmpty;
      final bUnassigned = b.assignedAreaId == null || b.assignedAreaId!.isEmpty;

      switch (_sortOption) {
        case WorkerSortOption.unassignedFirst:
          // Unassigned workers prioritized at top, assigned workers at bottom
          if (aUnassigned && !bUnassigned) return -1;
          if (!aUnassigned && bUnassigned) return 1;
          if (aAssignedHere && !bAssignedHere) return -1;
          if (!aAssignedHere && bAssignedHere) return 1;
          return a.fullName.compareTo(b.fullName);

        case WorkerSortOption.assignedHereFirst:
          if (aAssignedHere && !bAssignedHere) return -1;
          if (!aAssignedHere && bAssignedHere) return 1;
          if (aUnassigned && !bUnassigned) return -1;
          if (!aUnassigned && bUnassigned) return 1;
          return a.fullName.compareTo(b.fullName);

        case WorkerSortOption.allAssignedFirst:
          if (!aUnassigned && bUnassigned) return -1;
          if (aUnassigned && !bUnassigned) return 1;
          return a.fullName.compareTo(b.fullName);

        case WorkerSortOption.nameAsc:
          return a.fullName.compareTo(b.fullName);

        case WorkerSortOption.nameDesc:
          return b.fullName.compareTo(a.fullName);

        case WorkerSortOption.creditScore:
          return b.creditScore.compareTo(a.creditScore);
      }
    });

    return list;
  }

  String _getSortLabel(WorkerSortOption option) {
    switch (option) {
      case WorkerSortOption.unassignedFirst:
        return 'Unassigned First (Priority)';
      case WorkerSortOption.assignedHereFirst:
        return 'Assigned Here First';
      case WorkerSortOption.allAssignedFirst:
        return 'All Assigned First';
      case WorkerSortOption.nameAsc:
        return 'Name (A to Z)';
      case WorkerSortOption.nameDesc:
        return 'Name (Z to A)';
      case WorkerSortOption.creditScore:
        return 'Star Rating / Credit';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.role == UserRole.admin;
    final filteredWorkers = _getFilteredAndSortedWorkers();

    final now = DateTime.now();
    final sheetsAsync = ref.watch(scheduleSheetsProvider(ScheduleSheetsQuery(month: now.month, year: now.year)));
    final sheets = sheetsAsync.value ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 16,
      backgroundColor: AppColors.surface,
      child: Container(
        width: 680,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Roster Summary, Share Button & Close
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navActiveBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_outlined, color: AppColors.accentBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.area.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: widget.area.status,
                            type: widget.area.status == 'Active' ? BadgeType.optimal : BadgeType.neutral,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Close Dialog
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Controls: Search Field & Sort Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by first, last, or full name...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Menu Button
                PopupMenuButton<WorkerSortOption>(
                  tooltip: 'Sort Workers',
                  initialValue: _sortOption,
                  onSelected: (val) {
                    setState(() => _sortOption = val);
                  },
                  itemBuilder: (context) => WorkerSortOption.values.map((option) {
                    final isSelected = option == _sortOption;
                    return PopupMenuItem<WorkerSortOption>(
                      value: option,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: isSelected ? AppColors.accentBlue : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getSortLabel(option),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              color: isSelected ? AppColors.accentBlue : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _getSortLabel(_sortOption),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Worker List Header Info
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'WORKFORCE ROSTER (${filteredWorkers.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _sortOption == WorkerSortOption.unassignedFirst
                      ? 'Priority: Unassigned workers listed first'
                      : 'Sorted by: ${_getSortLabel(_sortOption)}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Worker Cards List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredWorkers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_search_outlined, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No workers match "${_searchController.text}"'
                                    : 'No field workers available in the workforce pool.',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredWorkers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final worker = filteredWorkers[index];
                            final isAssignedHere = worker.assignedAreaId == widget.area.workareaId;
                            final isUnassigned = worker.assignedAreaId == null || worker.assignedAreaId!.isEmpty;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAssignedHere
                                    ? AppColors.successBg.withValues(alpha: 0.3)
                                    : isUnassigned
                                        ? AppColors.surface
                                        : AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isAssignedHere
                                      ? AppColors.accentEmerald.withValues(alpha: 0.4)
                                      : AppColors.border,
                                  width: isAssignedHere ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar Initials
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isAssignedHere
                                        ? AppColors.accentEmerald
                                        : isUnassigned
                                            ? AppColors.accentBlue
                                            : AppColors.neutralText,
                                    child: Text(
                                      worker.initials,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Worker Name & Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                worker.fullName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Assignment Status Badge
                                            if (isAssignedHere)
                                              const StatusBadge(label: 'Assigned Here', type: BadgeType.optimal)
                                            else if (isUnassigned)
                                              const StatusBadge(label: 'Unassigned', type: BadgeType.neutral)
                                            else
                                              StatusBadge(
                                                label: 'Assigned: ${worker.assignedAreaName ?? "Other Zone"}',
                                                type: BadgeType.neutral,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (worker.contactNumber.isNotEmpty)
                                              Text(
                                                worker.contactNumber,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            _buildWorkerDaySchedule(worker, sheets),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Assignment Toggle Action (Admin authority)
                                  if (isAdmin)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.schedule_rounded, size: 14, color: AppColors.accentBlue),
                                          label: const Text('Shift', style: TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            side: const BorderSide(color: AppColors.border),
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showEditShiftDialog(worker),
                                        ),
                                        const SizedBox(width: 8),
                                        AppButton(
                                          label: isAssignedHere
                                              ? 'Unassign'
                                              : isUnassigned
                                                  ? '+ Assign'
                                                  : 'Reassign Here',
                                          icon: isAssignedHere
                                              ? Icons.person_remove_outlined
                                              : Icons.person_add_alt_1_outlined,
                                          variant: isAssignedHere
                                              ? ButtonVariant.danger
                                              : isUnassigned
                                                  ? ButtonVariant.primary
                                                  : ButtonVariant.outline,
                                          onPressed: () => _toggleAssignment(worker),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

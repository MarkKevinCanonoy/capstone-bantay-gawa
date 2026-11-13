import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../data/models/user_model.dart';
import '../../data/models/worker_schedule_sheet_model.dart';
import '../../data/repositories/repository_provider.dart';

class WorkerScheduleManagementView extends ConsumerStatefulWidget {
  final VoidCallback onBackToDashboard;

  const WorkerScheduleManagementView({
    super.key,
    required this.onBackToDashboard,
  });

  @override
  ConsumerState<WorkerScheduleManagementView> createState() => _WorkerScheduleManagementViewState();
}

class _WorkerScheduleManagementViewState extends ConsumerState<WorkerScheduleManagementView> {
  late int _selectedMonth;
  late int _selectedYear;
  String? _activeSheetId;
  final TextEditingController _searchController = TextEditingController();

  // Local working copy of sheets for unsaved edits before commit
  Map<String, ScheduleSheetModel> _localSheets = {};
  // Cache removed entries so transferring a worker between sheets preserves their area, day off, and schedule
  final Map<String, ScheduleEntryModel> _removedEntriesCache = {};
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  final ScrollController _tabsScrollController = ScrollController();

  static const List<String> _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static List<String> _parseDayOffList(String raw) {
    if (raw.trim().isEmpty) return [];
    final lower = raw.toLowerCase();
    final result = <String>[];
    for (final day in _weekdays) {
      final prefix = day.substring(0, 3).toLowerCase();
      if (lower.contains(prefix)) {
        result.add(day);
      }
    }
    return result;
  }

  static String _formatDayOffList(List<String> days) {
    if (days.isEmpty) return 'None';
    // Maintain chronological Sunday -> Saturday order
    final sorted = _weekdays.where((d) => days.contains(d)).toList();
    return sorted.join(', ');
  }

  static TimeOfDay _parseTimeOfDay(String str, {required TimeOfDay fallback}) {
    try {
      final cleaned = str.trim();
      final dt = DateFormat('h:mm a').parseLoose(cleaned);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      try {
        final dt = DateFormat('hh:mm a').parseLoose(str.trim());
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {
        return fallback;
      }
    }
  }

  static String _formatTimeSchedule(TimeOfDay start, TimeOfDay end) {
    String formatTime(TimeOfDay t) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      return DateFormat('hh:mm a').format(dt);
    }
    return '${formatTime(start)} – ${formatTime(end)}';
  }

  static (TimeOfDay, TimeOfDay) _extractStartAndEnd(String scheduleStr) {
    final parts = scheduleStr.split(RegExp(r'[-–]'));
    final start = parts.isNotEmpty
        ? _parseTimeOfDay(parts.first, fallback: const TimeOfDay(hour: 6, minute: 0))
        : const TimeOfDay(hour: 6, minute: 0);
    final end = parts.length > 1
        ? _parseTimeOfDay(parts[1], fallback: const TimeOfDay(hour: 15, minute: 0))
        : const TimeOfDay(hour: 15, minute: 0);
    return (start, end);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  void dispose() {
    _tabsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncWithRemote(List<ScheduleSheetModel> remoteSheets) {
    if (_localSheets.isEmpty || !_hasUnsavedChanges) {
      _localSheets = {for (final s in remoteSheets) s.sheetId: s};
      if (_activeSheetId == null || !_localSheets.containsKey(_activeSheetId)) {
        _activeSheetId = _localSheets.isNotEmpty ? _localSheets.keys.first : null;
      }
    }
  }

  Future<void> _saveAllChanges() async {
    setState(() => _isSaving = true);
    final repo = ref.read(dataRepositoryProvider);

    try {
      for (final sheet in _localSheets.values) {
        await repo.saveScheduleSheet(sheet);
        // Automatically sync worker area assignments and working schedules so admin doesn't need to move back and forth
        for (final entry in sheet.entries) {
          if (entry.assignedAreaId.isNotEmpty && entry.assignedAreaId != 'unassigned') {
            await repo.assignWorkerToArea(
              workerId: entry.userId,
              areaId: entry.assignedAreaId,
              areaName: entry.assignedAreaName,
            );
            // Also sync the worker's shift time schedule if provided
            if (entry.timeSchedule.isNotEmpty && entry.timeSchedule != 'Unassigned') {
              await repo.updateWorkerSchedule(
                workerId: entry.userId,
                startTime: entry.timeSchedule.split('–').first.split('-').first.trim(),
                endTime: entry.timeSchedule.split('–').last.split('-').last.trim(),
                days: entry.dayOff.isEmpty || entry.dayOff == 'None'
                    ? 'Daily'
                    : 'Off: ${entry.dayOff}',
                areaName: entry.assignedAreaName,
              );
            }
          }
        }
      }
      ref.invalidate(scheduleSheetsProvider);
      ref.invalidate(workAreasProvider);
      ref.invalidate(employeesProvider);
      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      if (mounted) {
        ToastNotification.show(context, message: 'Worker schedules and sector assignments successfully synced to work areas.', type: ToastType.success);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ToastNotification.show(context, message: 'Failed to save schedules: $e', type: ToastType.error);
      }
    }
  }

  void _addNewSheetDialog() {
    final nameController = TextEditingController(text: 'New Sector Schedule');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.post_add_rounded, color: AppColors.accentBlue, size: 22),
            SizedBox(width: 8),
            Text('Add New Schedule Sheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the title for this schedule tab (e.g. Street Cleaners, Parks and Plaza):',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Sheet Title',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () {
              final title = nameController.text.trim();
              if (title.isNotEmpty) {
                final newId = 'sheet-${DateTime.now().millisecondsSinceEpoch}';
                setState(() {
                  _localSheets[newId] = ScheduleSheetModel(
                    sheetId: newId,
                    sheetName: title,
                    month: _selectedMonth,
                    year: _selectedYear,
                    entries: [],
                  );
                  _activeSheetId = newId;
                  _hasUnsavedChanges = true;
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create Sheet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _renameSheetDialog(ScheduleSheetModel sheet) {
    final nameController = TextEditingController(text: sheet.sheetName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Schedule Sheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sheet Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () {
              final newTitle = nameController.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _localSheets[sheet.sheetId] = sheet.copyWith(sheetName: newTitle);
                  _hasUnsavedChanges = true;
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSheet(ScheduleSheetModel sheet) {
    ConfirmationDialog.show(
      context,
      title: 'Delete "${sheet.sheetName}" Sheet?',
      message: 'Are you sure you want to remove this schedule sheet? This will delete all worker assignment rows in this tab for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}.',
      confirmLabel: 'Delete Sheet',
      confirmVariant: ButtonVariant.danger,
      onConfirm: () async {
        final repo = ref.read(dataRepositoryProvider);
        await repo.deleteScheduleSheet(sheet.sheetId);
        setState(() {
          _localSheets.remove(sheet.sheetId);
          _activeSheetId = _localSheets.isNotEmpty ? _localSheets.keys.first : null;
        });
        ref.invalidate(scheduleSheetsProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Sheet "${sheet.sheetName}" deleted.', type: ToastType.success);
        }
      },
    );
  }
  void _showDayOffPicker({
    required BuildContext context,
    required String currentDayOff,
    required ValueChanged<String> onSelected,
  }) {
    final selectedDays = _parseDayOffList(currentDayOff).toSet();

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setPickerState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: Color(0xFFD97706), size: 22),
                SizedBox(width: 8),
                Text('Select Days Off', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select any combination of rest days for this worker. You can choose one, two, three or more days, or leave none.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekdays.map((day) {
                      final isSelected = selectedDays.contains(day);
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
                          setPickerState(() {
                            if (val) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
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
                            selectedDays.isEmpty
                              ? 'No day off selected (Worker has 7-day schedule)'
                              : 'Selected (${selectedDays.length}): ${_formatDayOffList(selectedDays.toList())}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41)),
                onPressed: () {
                  final formatted = _formatDayOffList(selectedDays.toList());
                  onSelected(formatted);
                  Navigator.of(dCtx).pop();
                },
                child: const Text('Apply', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTimeSchedulePicker({
    required BuildContext context,
    required String currentTimeSchedule,
    required ValueChanged<String> onSelected,
  }) {
    final (initialStart, initialEnd) = _extractStartAndEnd(currentTimeSchedule);
    TimeOfDay startTime = initialStart;
    TimeOfDay endTime = initialEnd;

    showDialog(
      context: context,
      builder: (tCtx) => StatefulBuilder(
        builder: (context, setPickerState) {
          String formatTime(TimeOfDay t) {
            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
            return DateFormat('hh:mm a').format(dt);
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text('Set Working Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify the custom shift start and end times for this worker. Attendance calculations will strictly use these working hours.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Start Time Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setPickerState(() => startTime = picked);
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                    ),
                                    const Icon(Icons.access_time, size: 16, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // End Time Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setPickerState(() => endTime = picked);
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                    ),
                                    const Icon(Icons.access_time_filled, size: 16, color: Color(0xFF2563EB)),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Daily Schedule: ${_formatTimeSchedule(startTime, endTime)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(tCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41)),
                onPressed: () {
                  final formatted = _formatTimeSchedule(startTime, endTime);
                  onSelected(formatted);
                  Navigator.of(tCtx).pop();
                },
                child: const Text('Apply', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addWorkerToSheetDialog(ScheduleSheetModel sheet) async {
    final repo = ref.read(dataRepositoryProvider);
    List<UserModel> allWorkers;
    final cached = ref.read(employeesProvider).value;
    if (cached != null && cached.isNotEmpty) {
      allWorkers = cached.where((u) => u.role == UserRole.worker).toList();
    } else {
      try {
        allWorkers = await repo.getUsers(role: UserRole.worker);
      } catch (_) {
        allWorkers = [];
      }
    }

    final workAreasAsync = ref.read(workAreasProvider);
    final allAreas = workAreasAsync.value ?? [];

    // Use current local sheet entries to ensure freshly removed workers are available
    final currentLocalSheet = _localSheets[sheet.sheetId] ?? sheet;
    final existingIds = currentLocalSheet.entries.map((e) => e.userId).toSet();
    final availableWorkers = allWorkers.where((w) => !existingIds.contains(w.userId)).toList();

    UserModel? selectedWorker = availableWorkers.isNotEmpty ? availableWorkers.first : null;
    String selectedAreaName = allAreas.isNotEmpty ? allAreas.first.name : 'Ormoc Plaza';
    String selectedAreaId = allAreas.isNotEmpty ? allAreas.first.workareaId : 'area-1';
    String selectedDayOff = 'Saturday, Sunday';
    String selectedSchedule = '06:00 AM – 03:00 PM';
    final remarksController = TextEditingController(text: '');

    // Helper to auto-populate existing attributes from previous sheet/removal cache or user model
    void populateWorkerAttributes(UserModel? worker) {
      if (worker == null) return;

      // 1. Check if the worker was previously removed in this session
      final cached = _removedEntriesCache[worker.userId];
      // 2. Check if the worker exists in any other local sheet
      ScheduleEntryModel? otherSheetEntry;
      if (cached == null) {
        for (final s in _localSheets.values) {
          final found = s.entries.where((e) => e.userId == worker.userId).firstOrNull;
          if (found != null) {
            otherSheetEntry = found;
            break;
          }
        }
      }

      final refEntry = cached ?? otherSheetEntry;
      if (refEntry != null) {
        if (refEntry.assignedAreaId.isNotEmpty && refEntry.assignedAreaId != 'unassigned') {
          selectedAreaId = refEntry.assignedAreaId;
          selectedAreaName = refEntry.assignedAreaName;
        }
        if (refEntry.dayOff.isNotEmpty) {
          selectedDayOff = refEntry.dayOff;
        }
        if (refEntry.timeSchedule.isNotEmpty && refEntry.timeSchedule != 'Unassigned') {
          selectedSchedule = refEntry.timeSchedule;
        }
        if (refEntry.statusRemarks.isNotEmpty) {
          remarksController.text = refEntry.statusRemarks;
        }
      } else {
        // Fallback: check worker's UserModel properties
        if (worker.assignedAreaId != null && worker.assignedAreaId!.isNotEmpty && worker.assignedAreaId != 'unassigned') {
          selectedAreaId = worker.assignedAreaId!;
          selectedAreaName = worker.assignedAreaName ?? selectedAreaName;
        }
        if (worker.schedule.isNotEmpty && worker.schedule != 'Unassigned') {
          // Check for "Off: <days>"
          final offMatch = RegExp(r'Off:\s*([^0-9\-–—]+)', caseSensitive: false).firstMatch(worker.schedule);
          if (offMatch != null && offMatch.group(1) != null) {
            selectedDayOff = offMatch.group(1)!.trim();
          } else {
            final lower = worker.schedule.toLowerCase();
            if (lower.contains('mon-fri') || lower.contains('mon to fri')) {
              selectedDayOff = 'Saturday, Sunday';
            } else if (lower.contains('mon-sat') || lower.contains('mon to sat')) {
              selectedDayOff = 'Sunday';
            } else if (lower.contains('daily') || lower.contains('everyday')) {
              selectedDayOff = 'None';
            }
          }
          final (st, et) = _extractStartAndEnd(worker.schedule);
          selectedSchedule = _formatTimeSchedule(st, et);
        }
      }

      // Ensure selectedAreaId is valid within allAreas
      if (allAreas.isNotEmpty && !allAreas.any((a) => a.workareaId == selectedAreaId)) {
        selectedAreaId = allAreas.first.workareaId;
        selectedAreaName = allAreas.first.name;
      }
    }

    if (selectedWorker != null) {
      populateWorkerAttributes(selectedWorker);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          final selectedDayList = _parseDayOffList(selectedDayOff);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accentBlue, size: 22),
                const SizedBox(width: 8),
                Text('Add Worker to ${sheet.sheetName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: availableWorkers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('All registered field workers are already assigned in this schedule sheet.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Field Worker:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<UserModel>(
                                isExpanded: true,
                                value: selectedWorker,
                                items: availableWorkers.map((w) {
                                  return DropdownMenuItem(
                                    value: w,
                                    child: Text(w.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModal(() {
                                      selectedWorker = val;
                                      populateWorkerAttributes(val);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Assigned Work Area (Raffle Outcome):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedAreaId,
                                items: allAreas.map((a) {
                                  return DropdownMenuItem(
                                    value: a.workareaId,
                                    child: Text(a.name, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final found = allAreas.firstWhere((a) => a.workareaId == val);
                                    setModal(() {
                                      selectedAreaId = val;
                                      selectedAreaName = found.name;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Scheduled Day Off:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _showDayOffPicker(
                                context: context,
                                currentDayOff: selectedDayOff,
                                onSelected: (newDays) => setModal(() => selectedDayOff = newDays),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_busy_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: selectedDayList.isEmpty
                                        ? const Text('None (7-day shift)', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                                        : Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: selectedDayList.map((d) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  d,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const Icon(Icons.edit_calendar_outlined, size: 16, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Working Time Schedule:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _showTimeSchedulePicker(
                                context: context,
                                currentTimeSchedule: selectedSchedule,
                                onSelected: (newTime) => setModal(() => selectedSchedule = newTime),
                              );
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
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedSchedule,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Status / Remarks:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: remarksController,
                            decoration: const InputDecoration(
                              hintText: 'Enter notes or leave empty...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              if (availableWorkers.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                  onPressed: () {
                    if (selectedWorker != null) {
                      final newEntry = ScheduleEntryModel(
                        entryId: 'entry-${DateTime.now().millisecondsSinceEpoch}',
                        userId: selectedWorker!.userId,
                        workerName: selectedWorker!.fullName,
                        assignedAreaId: selectedAreaId,
                        assignedAreaName: selectedAreaName,
                        dayOff: selectedDayOff,
                        timeSchedule: selectedSchedule,
                        statusRemarks: remarksController.text.trim(),
                      );
                      setState(() {
                        final currentEntries = _localSheets[sheet.sheetId]?.entries ?? sheet.entries;
                        final updatedEntries = List<ScheduleEntryModel>.from(currentEntries)..add(newEntry);
                        _localSheets[sheet.sheetId] = sheet.copyWith(entries: updatedEntries);
                        _hasUnsavedChanges = true;
                      });
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Add Worker', style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        },
      ),
    );
  }

  void _removeEntry(ScheduleSheetModel sheet, ScheduleEntryModel entry) {
    ConfirmationDialog.show(
      context,
      title: 'Remove ${entry.workerName}?',
      message: 'Are you sure you want to remove ${entry.workerName} from "${sheet.sheetName}" for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}? You will need to click "Save Schedule" to apply this change to the roster.',
      confirmLabel: 'Remove Worker',
      confirmVariant: ButtonVariant.danger,
      onConfirm: () {
        setState(() {
          _removedEntriesCache[entry.userId] = entry;
          final currentEntries = _localSheets[sheet.sheetId]?.entries ?? sheet.entries;
          final updated = List<ScheduleEntryModel>.from(currentEntries)
            ..removeWhere((e) => e.entryId == entry.entryId);
          _localSheets[sheet.sheetId] = sheet.copyWith(entries: updated);
          _hasUnsavedChanges = true;
        });
      },
    );
  }

  void _updateEntry(ScheduleSheetModel sheet, ScheduleEntryModel entry, {
    String? assignedAreaId,
    String? assignedAreaName,
    String? dayOff,
    String? timeSchedule,
    String? statusRemarks,
  }) {
    setState(() {
      final idx = sheet.entries.indexWhere((e) => e.entryId == entry.entryId);
      if (idx != -1) {
        final updatedList = List<ScheduleEntryModel>.from(sheet.entries);
        updatedList[idx] = entry.copyWith(
          assignedAreaId: assignedAreaId,
          assignedAreaName: assignedAreaName,
          dayOff: dayOff,
          timeSchedule: timeSchedule,
          statusRemarks: statusRemarks,
        );
        _localSheets[sheet.sheetId] = sheet.copyWith(entries: updatedList);
        _hasUnsavedChanges = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isSupervisor = currentUser.role == UserRole.supervisor;
    final query = ScheduleSheetsQuery(month: _selectedMonth, year: _selectedYear);
    final remoteSheetsAsync = ref.watch(scheduleSheetsProvider(query));
    final workAreasAsync = ref.watch(workAreasProvider);
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = isSupervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty &&
                a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            (currentUser.assignedAreaId != null &&
                currentUser.assignedAreaId!.isNotEmpty &&
                a.workareaId == currentUser.assignedAreaId) ||
            (currentUser.assignedAreaName != null &&
                currentUser.assignedAreaName!.isNotEmpty &&
                currentUser.assignedAreaName != 'Unassigned' &&
                a.name.toLowerCase() == currentUser.assignedAreaName!.toLowerCase())
          ).toList()
        : rawWorkAreas;
    ref.watch(employeesProvider);

    remoteSheetsAsync.whenData((remoteList) {
      final scopedList = isSupervisor
          ? (workAreas.isEmpty
              ? <ScheduleSheetModel>[]
              : remoteList.map((s) {
                  final scopedEntries = s.entries.where((e) =>
                      workAreas.any((a) =>
                          a.workareaId == e.assignedAreaId ||
                          (e.assignedAreaName.isNotEmpty &&
                              a.name.toLowerCase() == e.assignedAreaName.toLowerCase()))
                  ).toList();
                  return s.copyWith(entries: scopedEntries);
                }).where((s) => s.entries.isNotEmpty).toList())
          : remoteList;
      _syncWithRemote(scopedList);
    });

    final currentSheet = _activeSheetId != null ? _localSheets[_activeSheetId] : null;

    final filteredEntries = (currentSheet?.entries ?? []).where((e) {
      final q = _searchController.text.toLowerCase().trim();
      if (q.isEmpty) return true;
      return e.workerName.toLowerCase().contains(q) ||
          e.assignedAreaName.toLowerCase().contains(q) ||
          e.dayOff.toLowerCase().contains(q) ||
          e.timeSchedule.toLowerCase().contains(q) ||
          e.statusRemarks.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation / Action Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 950;
              final navAndTitle = Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to Attendance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: widget.onBackToDashboard,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 24),
                            Text(
                              isSupervisor ? 'Team Schedule Roster' : 'Worker Schedule Management',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF107C41).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.3)),
                              ),
                              child: Text(isSupervisor ? 'SECTOR ROSTER' : 'EXCEL WORKBOOK FORMAT',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSupervisor
                              ? 'View official schedule assignments and designated off-days for your assigned sectors.'
                              : 'Manage monthly rotation sheets and employee schedules determined by the monthly raffle draw.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final pickerAndAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month Picker Dropdown
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        items: List.generate(12, (i) {
                          final m = i + 1;
                          final label = DateFormat('MMMM').format(DateTime(2026, m));
                          return DropdownMenuItem(value: m, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMonth = val;
                              _localSheets.clear();
                              _activeSheetId = null;
                              _hasUnsavedChanges = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Year Picker Dropdown
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        items: [2025, 2026, 2027].map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedYear = val;
                              _localSheets.clear();
                              _activeSheetId = null;
                              _hasUnsavedChanges = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Save Changes Button or Read-Only Pill
                  if (isSupervisor)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                          SizedBox(width: 6),
                          Text(
                            'Read-Only Team Roster',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    AppButton(
                      label: _isSaving ? 'Saving...' : 'Save Schedule',
                      icon: Icons.save_rounded,
                      variant: _hasUnsavedChanges ? ButtonVariant.primary : ButtonVariant.outline,
                      onPressed: _isSaving ? null : _saveAllChanges,
                    ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    navAndTitle,
                    const SizedBox(height: 12),
                    pickerAndAction,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: navAndTitle),
                  const SizedBox(width: 16),
                  pickerAndAction,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Excel Style Sheet Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _tabsScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _tabsScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          ..._localSheets.values.map((sheet) {
                          final isActive = sheet.sheetId == _activeSheetId;
                          return InkWell(
                            onTap: () => setState(() => _activeSheetId = sheet.sheetId),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isActive ? Border.all(color: const Color(0xFF107C41), width: 1.5) : null,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.table_chart,
                                    size: 14,
                                    color: isActive ? const Color(0xFF107C41) : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sheet.sheetName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                      color: isActive ? const Color(0xFF107C41) : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFFE8F5E9) : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${sheet.entries.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? const Color(0xFF107C41) : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  if (isActive && !isSupervisor) ...[
                                    const SizedBox(width: 6),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 14, color: AppColors.textSecondary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onSelected: (action) {
                                        if (action == 'rename') {
                                          _renameSheetDialog(sheet);
                                        } else if (action == 'delete') {
                                          _confirmDeleteSheet(sheet);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'rename', child: Text('Rename Sheet')),
                                        const PopupMenuItem(value: 'delete', child: Text('Delete Sheet', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        // + Add Sheet Tab (Admin Only)
                        if (!isSupervisor)
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF107C41)),
                            label: const Text('Add Sheet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
                            onPressed: _addNewSheetDialog,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
                // Search input inside sheet
                SizedBox(
                  width: 220,
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search sheet...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (currentSheet != null && !isSupervisor)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_rounded, size: 15),
                    label: const Text('Add Worker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _addWorkerToSheetDialog(currentSheet),
                  ),
              ],
            ),
          ),

          // Main Spreadsheet Table Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: currentSheet == null || currentSheet.entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.textLight),
                          const SizedBox(height: 12),
                          Text(
                            currentSheet == null
                                ? (isSupervisor && workAreas.isEmpty
                                    ? 'No work areas currently assigned to your supervisory oversight.'
                                    : 'No schedule sheets found for this month.')
                                : 'No workers assigned to "${currentSheet.sheetName}" yet.',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentSheet == null
                                ? (isSupervisor
                                    ? (workAreas.isEmpty
                                        ? 'Team schedule sheets will appear here once an administrator assigns a work sector to you.'
                                        : 'No schedule records have been authorized for your assigned sectors in ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}.')
                                    : 'Click "Add Sheet" to create a new sector schedule sheet for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}.')
                                : (isSupervisor
                                    ? 'Workers assigned to your sector will appear here once schedules are confirmed by the administrator.'
                                    : 'Click "Add Worker" to populate this monthly schedule following the raffle draw.'),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (!isSupervisor) ...[
                            const SizedBox(height: 16),
                            if (currentSheet != null)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Add Worker Now'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41), foregroundColor: Colors.white),
                                onPressed: () => _addWorkerToSheetDialog(currentSheet),
                              )
                            else
                              ElevatedButton.icon(
                                icon: const Icon(Icons.post_add_rounded, size: 16),
                                label: const Text('Add Schedule Sheet'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41), foregroundColor: Colors.white),
                                onPressed: _addNewSheetDialog,
                              ),
                          ],
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 280),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              headingRowHeight: 40,
                              dataRowMinHeight: 46,
                              dataRowMaxHeight: 52,
                              columnSpacing: 20,
                              border: const TableBorder(
                                horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                verticalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              ),
                              columns: [
                                const DataColumn(
                                  label: Text(
                                    'No.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    "Worker's Name",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'Assigned Area',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'Day Off',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'Time Schedule',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'Status / Remarks',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                                if (!isSupervisor)
                                  const DataColumn(
                                    label: Text(
                                      'Actions',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                    ),
                                  ),
                              ],
                              rows: List.generate(filteredEntries.length, (index) {
                                final entry = filteredEntries[index];
                                final rowNumber = index + 1;
                                return DataRow(
                                  cells: [
                                    // 1. No.
                                    DataCell(
                                      Text('$rowNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted)),
                                    ),
                                    // 2. Worker's Name
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryNavy,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              entry.workerName.isNotEmpty ? entry.workerName[0].toUpperCase() : 'W',
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(entry.workerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                    // 3. Assigned Area
                                    DataCell(
                                      isSupervisor
                                          ? Text(
                                              entry.assignedAreaName.isNotEmpty ? entry.assignedAreaName : 'Assigned Sector',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                            )
                                          : DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: workAreas.any((a) => a.workareaId == entry.assignedAreaId)
                                                    ? entry.assignedAreaId
                                                    : (workAreas.isNotEmpty ? workAreas.first.workareaId : null),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                items: workAreas.map((a) {
                                                  return DropdownMenuItem(value: a.workareaId, child: Text(a.name));
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    final found = workAreas.firstWhere((a) => a.workareaId == val);
                                                    _updateEntry(
                                                      currentSheet,
                                                      entry,
                                                      assignedAreaId: val,
                                                      assignedAreaName: found.name,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                    ),
                                    // 4. Day Off
                                    DataCell(
                                      Builder(
                                        builder: (c) {
                                          final daysList = _parseDayOffList(entry.dayOff);
                                          final content = Container(
                                            constraints: const BoxConstraints(minWidth: 140),
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (daysList.isEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceSubtle,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppColors.border),
                                                    ),
                                                    child: const Text('None (7-day)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                                  )
                                                else
                                                  Flexible(
                                                    child: Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: daysList.map((d) {
                                                        final short = d.length > 3 ? d.substring(0, 3) : d;
                                                        return Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                                          ),
                                                          child: Text(
                                                            short,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFFB45309),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                if (!isSupervisor) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.edit_calendar_outlined, size: 14, color: AppColors.textLight),
                                                ],
                                              ],
                                            ),
                                          );

                                          if (isSupervisor) return content;

                                          return InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              _showDayOffPicker(
                                                context: context,
                                                currentDayOff: entry.dayOff,
                                                onSelected: (newDays) => _updateEntry(currentSheet, entry, dayOff: newDays),
                                              );
                                            },
                                            child: content,
                                          );
                                        },
                                      ),
                                    ),
                                    // 5. Time Schedule
                                    DataCell(
                                      Builder(
                                        builder: (c) {
                                          final content = Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF2563EB)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        entry.timeSchedule,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF1E40AF),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (!isSupervisor) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.edit, size: 12, color: AppColors.textLight),
                                                ],
                                              ],
                                            ),
                                          );

                                          if (isSupervisor) return content;

                                          return InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              _showTimeSchedulePicker(
                                                context: context,
                                                currentTimeSchedule: entry.timeSchedule,
                                                onSelected: (newTime) => _updateEntry(currentSheet, entry, timeSchedule: newTime),
                                              );
                                            },
                                            child: content,
                                          );
                                        },
                                      ),
                                    ),
                                    // 6. Status / Remarks
                                    DataCell(
                                      isSupervisor
                                          ? Text(
                                              entry.statusRemarks.isNotEmpty ? entry.statusRemarks : 'Active',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                            )
                                          : SizedBox(
                                              width: 170,
                                              height: 32,
                                              child: TextFormField(
                                                key: ValueKey('remarks-${entry.entryId}-${entry.statusRemarks}'),
                                                initialValue: entry.statusRemarks,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter notes...',
                                                  hintStyle: TextStyle(fontSize: 11, color: AppColors.textLight),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                onChanged: (val) {
                                                  _updateEntry(currentSheet, entry, statusRemarks: val.trim());
                                                },
                                              ),
                                            ),
                                    ),
                                    // 7. Actions (Delete from sheet - Admin Only)
                                    if (!isSupervisor)
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Remove worker from this schedule sheet',
                                          onPressed: () => _removeEntry(currentSheet, entry),
                                        ),
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/toast_notification.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/work_area_model.dart';
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

  Widget _buildShiftBadge(String schedule) {
    String label = schedule;
    IconData icon = Icons.schedule_rounded;
    Color color = AppColors.textSecondary;
    Color bg = AppColors.surfaceSubtle;

    if (schedule.contains('06:00') || schedule.contains('11:00') || schedule.toLowerCase().contains('am')) {
      label = 'AM (06:00 - 11:00)';
      icon = Icons.wb_sunny_outlined;
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFEF3C7);
    } else if (schedule.contains('13:00') || (schedule.contains('17:00') && schedule.contains('13'))) {
      label = 'PM (13:00 - 17:00)';
      icon = Icons.wb_twilight_outlined;
      color = const Color(0xFF7C3AED);
      bg = const Color(0xFFEDE9FE);
    } else if (schedule.contains('08:00') && schedule.contains('17:00')) {
      label = 'Full (08:00 - 17:00)';
      icon = Icons.apartment_outlined;
      color = AppColors.accentBlue;
      bg = AppColors.accentBlue.withValues(alpha: 0.1);
    } else if (schedule == 'Unassigned') {
      label = 'No Shift';
      icon = Icons.schedule_outlined;
      color = AppColors.textMuted;
      bg = AppColors.surfaceSubtle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showEditShiftDialog(UserModel worker) {
    String selectedPreset = 'AM';
    String startTime = '06:00';
    String endTime = '11:00';
    String selectedDays = 'Mon-Fri';
    bool isCustom = false;
    bool isSaving = false;

    if (worker.schedule.contains('13:00') || (worker.schedule.contains('17:00') && worker.schedule.contains('13'))) {
      selectedPreset = 'PM';
      startTime = '13:00';
      endTime = '17:00';
    } else if (worker.schedule.contains('08:00') && worker.schedule.contains('17:00')) {
      selectedPreset = 'Full';
      startTime = '08:00';
      endTime = '17:00';
    } else if (worker.schedule.contains('06:00') || worker.schedule.contains('11:00')) {
      selectedPreset = 'AM';
      startTime = '06:00';
      endTime = '11:00';
    } else if (worker.schedule != 'Unassigned') {
      isCustom = true;
      selectedPreset = 'Custom';
    }

    final startController = TextEditingController(text: startTime);
    final endController = TextEditingController(text: endTime);
    final daysController = TextEditingController(text: selectedDays);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
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
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a working shift for ${widget.area.name}. The worker will immediately receive an in-app notification on their phone.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Text('Shift Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedPreset = 'AM';
                                isCustom = false;
                                startTime = '06:00';
                                endTime = '11:00';
                                selectedDays = 'Mon-Fri';
                                startController.text = startTime;
                                endController.text = endTime;
                                daysController.text = selectedDays;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedPreset == 'AM' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                border: Border.all(
                                  color: selectedPreset == 'AM' ? AppColors.accentBlue : AppColors.border,
                                  width: selectedPreset == 'AM' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.wb_sunny_outlined, size: 20, color: selectedPreset == 'AM' ? AppColors.accentBlue : AppColors.textMuted),
                                  const SizedBox(height: 4),
                                  const Text('Morning (AM)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('06:00 - 11:00', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const Text('Mon - Fri', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedPreset = 'PM';
                                isCustom = false;
                                startTime = '13:00';
                                endTime = '17:00';
                                selectedDays = 'Mon-Fri';
                                startController.text = startTime;
                                endController.text = endTime;
                                daysController.text = selectedDays;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedPreset == 'PM' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                border: Border.all(
                                  color: selectedPreset == 'PM' ? AppColors.accentBlue : AppColors.border,
                                  width: selectedPreset == 'PM' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.wb_twilight_outlined, size: 20, color: selectedPreset == 'PM' ? AppColors.accentBlue : AppColors.textMuted),
                                  const SizedBox(height: 4),
                                  const Text('Afternoon (PM)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('13:00 - 17:00', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const Text('Mon - Fri', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedPreset = 'Full';
                                isCustom = false;
                                startTime = '08:00';
                                endTime = '17:00';
                                selectedDays = 'Mon-Fri';
                                startController.text = startTime;
                                endController.text = endTime;
                                daysController.text = selectedDays;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedPreset == 'Full' ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.surface,
                                border: Border.all(
                                  color: selectedPreset == 'Full' ? AppColors.accentBlue : AppColors.border,
                                  width: selectedPreset == 'Full' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.apartment_outlined, size: 20, color: selectedPreset == 'Full' ? AppColors.accentBlue : AppColors.textMuted),
                                  const SizedBox(height: 4),
                                  const Text('Whole Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('08:00 - 17:00', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const Text('Mon - Fri', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          isCustom = !isCustom;
                          if (isCustom) selectedPreset = 'Custom';
                        });
                      },
                      child: Row(
                        children: [
                          Icon(isCustom ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 18, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          const Text('Custom Shift Hours & Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(controller: startController, decoration: const InputDecoration(hintText: '06:00', isDense: true)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(controller: endController, decoration: const InputDecoration(hintText: '11:00', isDense: true)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Working Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(controller: daysController, decoration: const InputDecoration(hintText: 'Mon-Fri or Mon,Wed,Fri', isDense: true)),
                    ],
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
                  final finalSt = startController.text.trim().isNotEmpty ? startController.text.trim() : '08:00';
                  final finalEt = endController.text.trim().isNotEmpty ? endController.text.trim() : '17:00';
                  final finalDays = daysController.text.trim().isNotEmpty ? daysController.text.trim() : 'Mon-Fri';

                  final repo = ref.read(dataRepositoryProvider);
                  await repo.updateWorkerSchedule(
                    workerId: worker.userId,
                    startTime: finalSt,
                    endTime: finalEt,
                    days: finalDays,
                    areaName: widget.area.name,
                  );

                  ref.invalidate(employeesProvider);
                  ref.invalidate(workAreasProvider);
                  ref.invalidate(broadcastsProvider);
                  if (context.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ToastNotification.show(
                      context,
                      message: 'Shift for ${worker.fullName} set to $finalDays $finalSt - $finalEt. Worker notified!',
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
                                            Text(
                                              [
                                                if (worker.contactNumber.isNotEmpty) worker.contactNumber,
                                                'Credit: ${worker.creditScore}%',
                                              ].join(' • '),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            _buildShiftBadge(worker.schedule),
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

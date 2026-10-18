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
    final assignedCount = _workers.where((w) => w.assignedAreaId == widget.area.workareaId).length;
    final unassignedCount = _workers.where((w) => w.assignedAreaId == null || w.assignedAreaId!.isEmpty).length;

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
                      const SizedBox(height: 4),
                      Text(
                        'Supervisor: ${widget.area.supervisorName} • $assignedCount assigned to this sector • $unassignedCount unassigned in pool',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
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
                                        const SizedBox(height: 2),
                                        Text(
                                          '${worker.contactNumber} • Shift: ${worker.schedule} • Credit: ${worker.creditScore}%',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Assignment Toggle Action (Admin authority)
                                  if (isAdmin)
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
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isAdmin
                        ? 'Tip: Assigning or removing workers updates attendance tracking instantly.'
                        : 'Viewing personnel roster assigned to this geofence.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
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

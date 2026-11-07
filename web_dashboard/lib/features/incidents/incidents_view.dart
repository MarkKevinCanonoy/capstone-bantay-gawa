import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/incident_report_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class IncidentsView extends ConsumerStatefulWidget {
  const IncidentsView({super.key});

  @override
  ConsumerState<IncidentsView> createState() => _IncidentsViewState();
}

class _IncidentsViewState extends ConsumerState<IncidentsView> {
  String _statusFilter = 'all';
  DateTime? _selectedDate;
  String _dateRangePreset = 'all';
  String _selectedWorkAreaId = 'all';
  String _sortBy = 'newest';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isTodayOrFuture(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.isAtSameMomentAs(today) || target.isAfter(today);
  }

  String _getDateLabel() {
    if (_dateRangePreset == 'week') return 'This Week (Past 7 Days)';
    if (_dateRangePreset == 'month') return 'This Month';
    if (_dateRangePreset == 'all' || _selectedDate == null) return 'All Dates';
    if (_isToday(_selectedDate!)) return 'Today: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}';
    return DateFormat('EEE, MMM d, yyyy').format(_selectedDate!);
  }

  void _showSettleLocallyDialog(IncidentReportModel inc) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusOptimalBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.handshake_rounded, color: AppColors.accentBlue, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settle Worker Issue Locally',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Resolve this issue at the supervisor level without administrative penalty.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary Box
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
                            child: _buildModalDetailTile(
                              icon: Icons.person_rounded,
                              label: 'REPORTED WORKER',
                              value: inc.reportedName,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalDetailTile(
                              icon: Icons.warning_amber_rounded,
                              label: 'ISSUE CATEGORY',
                              value: inc.issueType,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Worker Statement: "${inc.description}"',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic, height: 1.3),
                        ),
                      ),
                      _buildIncidentProofThumbnail(inc.imageUrl, height: 120),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Supervisor Settlement Action & Notes *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Conducted verbal counseling, re-balanced cleaning sector rotation, and issued verbal reminder.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: ButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                AppButton(
                  label: 'Confirm Local Settlement',
                  variant: ButtonVariant.primary,
                  icon: Icons.check_circle_outline,
                  onPressed: () async {
                    final notes = notesController.text.trim();
                    if (notes.isEmpty) {
                      ToastNotification.show(context, message: 'Settlement notes are mandatory.', type: ToastType.error);
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      final currentUser = ref.read(currentUserProvider);
                      await ref.read(dataRepositoryProvider).settleIncidentLocally(
                            inc.reportId,
                            supervisorId: currentUser.userId,
                            supervisorName: currentUser.fullName,
                            notes: notes,
                          );
                      ref.invalidate(incidentsProvider);
                      if (mounted) {
                        ToastNotification.show(
                          this.context,
                          message: 'Worker issue settled locally by Supervisor ${currentUser.fullName}.',
                          type: ToastType.success,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastNotification.show(this.context, message: 'Failed to settle issue locally: $e', type: ToastType.error);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEscalateToAdminDialog(IncidentReportModel inc) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: AppColors.brightRed, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escalate Worker Issue to Central Admin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Forward severe misconduct report to City Administration for formal review.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brightRed.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.brightRed),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Escalating will notify Central Admin and generate an official transmittal memo.',
                          style: TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalDetailTile(
                              icon: Icons.person_rounded,
                              label: 'REPORTED WORKER',
                              value: inc.reportedName,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalDetailTile(
                              icon: Icons.report_problem_outlined,
                              label: 'ALLEGATION',
                              value: inc.issueType,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reported Behavior: "${inc.description}"',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                      _buildIncidentProofThumbnail(inc.imageUrl, height: 120),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Supervisor Escalation Justification *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe why local intervention is insufficient (e.g. repeated post abandonment, gross insubordination)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: ButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                AppButton(
                  label: 'Escalate to Admin',
                  variant: ButtonVariant.danger,
                  icon: Icons.arrow_upward_rounded,
                  onPressed: () async {
                    final remarks = remarksController.text.trim();
                    if (remarks.isEmpty) {
                      ToastNotification.show(context, message: 'Escalation justification is mandatory.', type: ToastType.error);
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      final currentUser = ref.read(currentUserProvider);
                      await ref.read(dataRepositoryProvider).escalateIncidentToAdmin(
                            inc.reportId,
                            supervisorId: currentUser.userId,
                            supervisorName: currentUser.fullName,
                            notes: remarks,
                          );
                      ref.invalidate(incidentsProvider);
                      if (mounted) {
                        ToastNotification.show(
                          this.context,
                          message: 'Incident escalated to Central Admin with transmittal memo dispatched.',
                          type: ToastType.info,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastNotification.show(this.context, message: 'Failed to escalate incident: $e', type: ToastType.error);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminResolveDialog(IncidentReportModel inc) {
    final resolutionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusOptimalBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: AppColors.primaryNavy, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrative Incident Resolution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Log final administrative decision or disciplinary action taken for this incident.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalDetailTile(
                              icon: Icons.person_rounded,
                              label: 'REPORTED WORKER',
                              value: inc.reportedName,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalDetailTile(
                              icon: Icons.warning_amber_rounded,
                              label: 'ISSUE TYPE',
                              value: inc.issueType,
                            ),
                          ),
                        ],
                      ),
                      if (inc.supervisorNotes != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.comment_outlined, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Supervisor Remarks: ${inc.supervisorNotes}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildIncidentProofThumbnail(inc.imageUrl, height: 140),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Final Administrative Sanction / Action Log *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: resolutionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1st Written Warning issued and employee scheduled for administrative review.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: ButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                AppButton(
                  label: 'Log Resolution',
                  variant: ButtonVariant.primary,
                  icon: Icons.check_circle_outline,
                  onPressed: () async {
                    final res = resolutionController.text.trim();
                    if (res.isEmpty) {
                      ToastNotification.show(context, message: 'Resolution notes are mandatory.', type: ToastType.error);
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      final currentUser = ref.read(currentUserProvider);
                      await ref.read(dataRepositoryProvider).resolveIncidentByAdmin(
                            inc.reportId,
                            adminId: currentUser.userId,
                            resolutionNotes: res,
                          );
                      ref.invalidate(incidentsProvider);
                      if (mounted) {
                        ToastNotification.show(this.context, message: 'Incident officially resolved and logged.', type: ToastType.success);
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastNotification.show(this.context, message: 'Failed to resolve incident: $e', type: ToastType.error);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final incidentsAsync = ref.watch(incidentsProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final rawIncidents = incidentsAsync.value ?? [];
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;
    final incidents = currentUser.role == UserRole.supervisor
        ? rawIncidents.where((inc) {
            return workAreas.any((a) =>
                (inc.workareaId != null && inc.workareaId == a.workareaId) ||
                (inc.areaName != null && a.name.toLowerCase() == inc.areaName!.toLowerCase()));
          }).toList()
        : rawIncidents;

    final totalCount = incidents.length;
    final pendingCount = incidents.where((i) => i.status == 'pending').length;
    final settledCount = incidents.where((i) => i.status == 'settled_locally').length;
    final escalatedCount = incidents.where((i) => i.status == 'escalated_to_admin').length;
    final resolvedCount = incidents.where((i) => i.status == 'resolved').length;

    final filteredIncidents = incidents.where((inc) {
      // 1. Status Filter
      if (_statusFilter == 'pending' && inc.status != 'pending') return false;
      if (_statusFilter == 'settled_locally' && inc.status != 'settled_locally') return false;
      if (_statusFilter == 'escalated_to_admin' && inc.status != 'escalated_to_admin') return false;
      if (_statusFilter == 'resolved' && inc.status != 'resolved') return false;

      // 2. Global Search
      final matchesSearch = inc.reportedName.toLowerCase().contains(globalSearch) ||
          inc.reporterName.toLowerCase().contains(globalSearch) ||
          inc.issueType.toLowerCase().contains(globalSearch) ||
          inc.description.toLowerCase().contains(globalSearch) ||
          (inc.areaName?.toLowerCase().contains(globalSearch) ?? false);
      if (!matchesSearch) return false;

      // 3. Work Area Sector Filter (for Admin)
      if (_selectedWorkAreaId != 'all') {
        final matchesArea = (inc.workareaId != null && inc.workareaId == _selectedWorkAreaId) ||
            workAreas.any((w) => w.workareaId == _selectedWorkAreaId && w.name.toLowerCase() == (inc.areaName?.toLowerCase() ?? ''));
        if (!matchesArea) return false;
      }

      // 4. Date / Period Filter
      if (_dateRangePreset == 'week') {
        final now = DateTime.now();
        final weekAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        if (inc.createdAt.isBefore(weekAgo) || inc.createdAt.isAfter(todayEnd)) {
          return false;
        }
      } else if (_dateRangePreset == 'month') {
        final now = DateTime.now();
        if (inc.createdAt.year != now.year || inc.createdAt.month != now.month) {
          return false;
        }
      } else if (_selectedDate != null) {
        final matches = inc.createdAt.year == _selectedDate!.year &&
            inc.createdAt.month == _selectedDate!.month &&
            inc.createdAt.day == _selectedDate!.day;
        if (!matches) return false;
      }

      return true;
    }).toList();

    // 5. Dynamic Sorting
    switch (_sortBy) {
      case 'newest':
        filteredIncidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filteredIncidents.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'pending_first':
        filteredIncidents.sort((a, b) {
          if (a.status == 'pending' && b.status != 'pending') return -1;
          if (a.status != 'pending' && b.status == 'pending') return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'worker':
        filteredIncidents.sort((a, b) => a.reportedName.toLowerCase().compareTo(b.reportedName.toLowerCase()));
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Date Navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Worker Incident & Issue Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.role == UserRole.admin
                          ? 'Administrative oversight of worker reports and supervisor escalations across Ormoc sectors.'
                          : 'Review worker issue reports in your sector. Settle locally or escalate to Central Admin.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUser.role == UserRole.supervisor && currentUser.assignedAreaName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.statusOptimalBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          Text(
                            'Assigned Sector: ${currentUser.assignedAreaName}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.statusOptimalText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Date Navigation Controller
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
                              _dateRangePreset = 'custom';
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
                              setState(() {
                                _selectedDate = picked;
                                _dateRangePreset = 'custom';
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.accentBlue),
                                const SizedBox(width: 8),
                                Text(
                                  _getDateLabel(),
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
                                      _dateRangePreset = 'custom';
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
                              _dateRangePreset = val;
                              if (val == 'today') {
                                _selectedDate = DateTime.now();
                              } else if (val == 'yesterday') {
                                _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                              } else {
                                _selectedDate = null;
                              }
                            });
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'today', child: Text('Go to Today')),
                            const PopupMenuItem(value: 'yesterday', child: Text('Go to Yesterday')),
                            const PopupMenuItem(value: 'week', child: Text('This Week (Past 7 Days)')),
                            const PopupMenuItem(value: 'month', child: Text('This Month')),
                            const PopupMenuItem(value: 'all', child: Text('View All Dates')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Controls & Filter Bar: Records count, Sector, Sort, and Status tabs
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${filteredIncidents.length} incident reports',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Work Area Sector Selector
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
                          value: workAreas.any((a) => a.workareaId == _selectedWorkAreaId) || _selectedWorkAreaId == 'all'
                              ? _selectedWorkAreaId
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
                            if (val != null) setState(() => _selectedWorkAreaId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Sort Dropdown
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
                          value: _sortBy,
                          icon: const Icon(Icons.sort_rounded, size: 18, color: AppColors.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'newest', child: Text('Sort: Newest First')),
                            DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest First')),
                            DropdownMenuItem(value: 'pending_first', child: Text('Sort: Pending Review First')),
                            DropdownMenuItem(value: 'worker', child: Text('Sort: Worker Name (A–Z)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _sortBy = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusTab('All', 'all', count: totalCount),
                      const SizedBox(width: 6),
                      _buildStatusTab('Pending Review', 'pending', count: pendingCount),
                      const SizedBox(width: 6),
                      _buildStatusTab('Settled Locally', 'settled_locally', count: settledCount),
                      const SizedBox(width: 6),
                      _buildStatusTab('Escalated to Admin', 'escalated_to_admin', count: escalatedCount),
                      const SizedBox(width: 6),
                      _buildStatusTab('Resolved', 'resolved', count: resolvedCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Incidents List
          Expanded(
            child: filteredIncidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text(
                        _statusFilter == 'all'
                            ? 'No worker incident reports in this scope.'
                            : 'No incident reports matching "$_statusFilter".',
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filteredIncidents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final inc = filteredIncidents[index];
                    final isPending = inc.status == 'pending';
                    final isSettledLocally = inc.status == 'settled_locally';
                    final isEscalated = inc.status == 'escalated_to_admin';
                    final isResolved = inc.status == 'resolved';

                    final statusBadgeType = isResolved || isSettledLocally
                        ? BadgeType.success
                        : isEscalated
                            ? BadgeType.danger
                            : BadgeType.warning;

                    final statusLabel = isPending
                        ? 'PENDING REVIEW'
                        : isSettledLocally
                            ? 'SETTLED BY SUPERVISOR'
                            : isEscalated
                                ? 'ESCALATED TO ADMIN'
                                : 'ADMIN RESOLVED';

                    final categoryIcon = inc.issueType.toLowerCase().contains('breach') || inc.issueType.toLowerCase().contains('boundary')
                        ? Icons.wrong_location_outlined
                        : inc.issueType.toLowerCase().contains('misconduct')
                            ? Icons.report_problem_outlined
                            : Icons.warning_amber_rounded;

                    return AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header: Category Icon + Title + Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isResolved || isSettledLocally
                                      ? AppColors.successBg
                                      : isEscalated
                                          ? AppColors.dangerBg
                                          : AppColors.warningBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  categoryIcon,
                                  color: isResolved || isSettledLocally
                                      ? AppColors.successText
                                      : isEscalated
                                          ? AppColors.dangerText
                                          : AppColors.warningText,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          inc.issueType,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                                        ),
                                        StatusBadge(
                                          label: statusLabel,
                                          type: statusBadgeType,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          inc.areaName ?? 'Ormoc City Station',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text('•', style: TextStyle(color: AppColors.textMuted)),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Report ID: ${inc.reportId}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3-Card Information Summary Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoTile(
                                  icon: Icons.person_rounded,
                                  label: 'SUBJECT WORKER',
                                  value: inc.reportedName,
                                  badge: 'Subject',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoTile(
                                  icon: Icons.record_voice_over_outlined,
                                  label: 'REPORTED BY',
                                  value: inc.reporterName,
                                  badge: 'Witness / Filer',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoTile(
                                  icon: Icons.place_outlined,
                                  label: 'WORK AREA',
                                  value: inc.areaName ?? 'Sector',
                                  badge: 'Location',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Incident Statement Box
                          const Text('Statement of Incident', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.format_quote_rounded, size: 20, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    inc.description,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildIncidentProofThumbnail(inc.imageUrl),

                          // Supervisor Action Box
                          if (inc.supervisorNotes != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isEscalated ? AppColors.dangerBg.withValues(alpha: 0.6) : AppColors.statusOptimalBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isEscalated
                                      ? AppColors.brightRed.withValues(alpha: 0.25)
                                      : AppColors.accentBlue.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isEscalated ? Icons.campaign_rounded : Icons.handshake_rounded,
                                    size: 20,
                                    color: isEscalated ? AppColors.brightRed : AppColors.accentBlue,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isEscalated
                                              ? 'Supervisor Escalation Remarks (Forwarded to Admin):'
                                              : 'Supervisor Local Settlement Log (${inc.settledBy ?? "Field Supervisor"}):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isEscalated ? AppColors.dangerText : AppColors.statusOptimalText,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          inc.supervisorNotes!,
                                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Admin Official Resolution Box
                          if (inc.adminResolutionNotes != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.verified_rounded, size: 20, color: AppColors.accentEmerald),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Central Admin Official Action & Resolution:',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.successText),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          inc.adminResolutionNotes!,
                                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Action Footer
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (currentUser.role == UserRole.supervisor && isPending) ...[
                                AppButton(
                                  label: 'Settle Locally',
                                  icon: Icons.handshake_outlined,
                                  variant: ButtonVariant.secondary,
                                  onPressed: () => _showSettleLocallyDialog(inc),
                                ),
                                const SizedBox(width: 12),
                                AppButton(
                                  label: 'Escalate to Admin',
                                  icon: Icons.arrow_upward_rounded,
                                  variant: ButtonVariant.danger,
                                  onPressed: () => _showEscalateToAdminDialog(inc),
                                ),
                              ],
                              if (currentUser.role == UserRole.admin && (isEscalated || isPending)) ...[
                                AppButton(
                                  label: 'Review & Resolve',
                                  icon: Icons.gavel_rounded,
                                  variant: ButtonVariant.primary,
                                  onPressed: () => _showAdminResolveDialog(inc),
                                ),
                              ],
                              if (isResolved || isSettledLocally) ...[
                                const Icon(Icons.done_all_rounded, size: 16, color: AppColors.accentEmerald),
                                const SizedBox(width: 6),
                                Text(
                                  isSettledLocally ? 'Handled at Field Level' : 'Administratively Closed',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                Text(badge, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String val, {int? count}) {
    final isSelected = _statusFilter == val;
    return InkWell(
      onTap: () => setState(() => _statusFilter = val),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryNavy : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentProofThumbnail(String? imageUrl, {double height = 140}) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return const SizedBox.shrink();

    final cleanUrl = imageUrl.trim();
    final isNetwork = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');
    final isBase64 = cleanUrl.startsWith('data:image') ||
        (!isNetwork && cleanUrl.length > 100 && !cleanUrl.startsWith('/') && !cleanUrl.startsWith('file://'));
    final isLocalPath = cleanUrl.startsWith('/data/') ||
        cleanUrl.startsWith('/storage/') ||
        cleanUrl.startsWith('/cache/') ||
        cleanUrl.startsWith('file://') ||
        (cleanUrl.startsWith('/') && !isNetwork && !isBase64);

    Widget? imageContent;
    if (isNetwork) {
      imageContent = Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildBrokenProofIcon(),
      );
    } else if (isBase64) {
      try {
        String cleanBase64 = cleanUrl.contains(',') ? cleanUrl.split(',').last : cleanUrl;
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildBrokenProofIcon(),
        );
      } catch (e) {
        debugPrint('Base64 incident image decoding failed: $e');
        imageContent = null;
      }
    } else if (isLocalPath) {
      final fileName = cleanUrl.contains('/') ? cleanUrl.split('/').last : cleanUrl;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_android_rounded, size: 24, color: AppColors.accentBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Photo proof saved locally on mobile: $fileName\nUpdate to latest mobile app to view cloud image.',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (imageContent == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 10, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('ATTACHED PROOF PHOTO', style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokenProofIcon() {
    return Container(
      color: AppColors.surfaceSubtle,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, size: 32, color: AppColors.textMuted),
      ),
    );
  }
}

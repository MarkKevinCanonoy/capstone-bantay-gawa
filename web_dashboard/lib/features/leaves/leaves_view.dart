import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/repository_provider.dart';

class LeavesView extends ConsumerStatefulWidget {
  const LeavesView({super.key});

  @override
  ConsumerState<LeavesView> createState() => _LeavesViewState();
}

class _LeavesViewState extends ConsumerState<LeavesView> {
  String _statusFilter = 'all';
  String _sortBy = 'newest';

  void _promptDenialDialog(LeaveRequestModel req) {
    final reasonController = TextEditingController();

    ConfirmationDialog.show(
      context,
      title: 'Deny Leave Request',
      message: 'Please provide an official administrative reason for denying ${req.workerName}\'s leave request.',
      confirmLabel: 'Confirm Denial',
      confirmVariant: ButtonVariant.danger,
      contentWidget: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Critical operational understaffing in sector...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      onConfirm: () async {
        final reason = reasonController.text.trim();
        if (reason.isEmpty) {
          ToastNotification.show(context, message: 'Denial reason is mandatory.', type: ToastType.error);
          return;
        }
        final currentUser = ref.read(currentUserProvider);
        await ref.read(dataRepositoryProvider).updateLeaveStatus(
              req.leaveId,
              'denied',
              adminId: currentUser.userId,
              rejectionReason: reason,
            );
        ref.invalidate(leaveRequestsProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Leave request denied with reason logged.', type: ToastType.info);
        }
      },
    );
  }

  void _showLeaveReviewModal(LeaveRequestModel req) {
    final currentUser = ref.read(currentUserProvider);
    final endorsementController = TextEditingController(text: req.supervisorEndorsement ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryNavy,
                    child: Text(
                      req.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Review: ${req.workerName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${req.type} • ${req.areaName} • Filed on ${req.startDate}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusBadge(
              label: req.status.toUpperCase(),
              type: req.status == 'approved'
                  ? BadgeType.success
                  : req.status == 'denied'
                      ? BadgeType.danger
                      : BadgeType.warning,
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentUser.role == UserRole.supervisor) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusOptimalBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: 20, color: AppColors.statusOptimalText),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'City Admin Approval Authority: As a Field Supervisor, leave approval or denial is reserved for Central Admin. You can submit an official endorsement/recommendation below.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusOptimalText, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4-Tile Information Grid
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
                            child: _buildDetailCard(
                              icon: Icons.person_outline_rounded,
                              label: 'FIELD WORKER',
                              value: req.workerName,
                              subtitle: 'Worker ID: ${req.userId}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.event_note_rounded,
                              label: 'LEAVE CATEGORY',
                              value: req.type,
                              subtitle: 'Official Filing Type',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.location_on_outlined,
                              label: 'WORK SECTOR',
                              value: req.areaName,
                              subtitle: 'Assigned Work Post',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'FILING DURATION',
                              value: '${req.startDate} to ${req.endDate}',
                              subtitle: 'Scheduled Absence Period',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Filing Reason & Statement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          req.reason.isNotEmpty ? req.reason : 'No statement provided.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Medical & Supporting Document Proof', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.statusOptimalBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment_rounded, size: 22, color: AppColors.accentBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.type.contains('Sick')
                                  ? 'Official Medical Certificate (Ormoc Doctors Hospital)'
                                  : 'Filing Justification Document (Attached)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusOptimalText),
                            ),
                            const SizedBox(height: 2),
                            const Text('Verified digital document attachment (PDF/JPEG)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ToastNotification.show(context, message: 'Opening attached leave proof document...', type: ToastType.info);
                        },
                        child: const Text('View Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                // Supervisor Endorsement Display (Visible to both Supervisor and Admin)
                if (req.supervisorEndorsement != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusOptimalBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.recommend_rounded, size: 20, color: AppColors.accentBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Supervisor Endorsement (${req.endorsedBy ?? "Field Supervisor"}):',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.statusOptimalText),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                req.supervisorEndorsement!,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Supervisor Endorsement Input (when pending and logged in as supervisor)
                if (currentUser.role == UserRole.supervisor && req.status == 'pending') ...[
                  const SizedBox(height: 16),
                  const Text('Supervisor Recommendation & Endorsement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: endorsementController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Recommend approval: relief worker assigned to sector for morning sweep.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Submit Endorsement to Admin',
                      icon: Icons.send_rounded,
                      variant: ButtonVariant.primary,
                      onPressed: () async {
                        final comment = endorsementController.text.trim();
                        if (comment.isEmpty) {
                          ToastNotification.show(context, message: 'Please enter endorsement comments.', type: ToastType.error);
                          return;
                        }
                        await ref.read(dataRepositoryProvider).endorseLeaveRequest(
                              req.leaveId,
                              supervisorId: currentUser.userId,
                              supervisorName: currentUser.fullName,
                              comments: comment,
                            );
                        ref.invalidate(leaveRequestsProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ToastNotification.show(context, message: 'Supervisor recommendation submitted for Admin review.', type: ToastType.success);
                        }
                      },
                    ),
                  ),
                ],

                if (req.rejectionReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brightRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.dangerText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Administrative Denial Reason',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dangerText),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                req.rejectionReason!,
                                style: const TextStyle(fontSize: 13, color: AppColors.dangerText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  label: 'Close',
                  variant: ButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (currentUser.role == UserRole.admin && req.status == 'pending') ...[
                  AppButton(
                    label: 'Deny Leave',
                    variant: ButtonVariant.danger,
                    icon: Icons.cancel_outlined,
                    onPressed: () {
                      Navigator.pop(context);
                      _promptDenialDialog(req);
                    },
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Approve Leave',
                    variant: ButtonVariant.accent,
                    icon: Icons.check_circle_outline,
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(dataRepositoryProvider).updateLeaveStatus(
                            req.leaveId,
                            'approved',
                            adminId: currentUser.userId,
                          );
                      ref.invalidate(leaveRequestsProvider);
                      if (mounted) {
                        ToastNotification.show(this.context, message: 'Approved leave for ${req.workerName}!', type: ToastType.success);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            child: Icon(icon, size: 18, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final leaves = leaveRequestsAsync.value ?? [];

    final filteredLeaves = leaves.where((l) {
      final matchesSearch = l.workerName.toLowerCase().contains(globalSearch) ||
          l.type.toLowerCase().contains(globalSearch) ||
          l.reason.toLowerCase().contains(globalSearch) ||
          l.areaName.toLowerCase().contains(globalSearch);
      final matchesStatus = _statusFilter == 'all' || l.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    // Dynamic sorting
    switch (_sortBy) {
      case 'newest':
        filteredLeaves.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case 'oldest':
        filteredLeaves.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case 'pending_first':
        filteredLeaves.sort((a, b) {
          if (a.status == 'pending' && b.status != 'pending') return -1;
          if (a.status != 'pending' && b.status == 'pending') return 1;
          return b.startDate.compareTo(a.startDate);
        });
        break;
      case 'worker_name':
        filteredLeaves.sort((a, b) => a.workerName.compareTo(b.workerName));
        break;
      case 'start_date':
        filteredLeaves.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Request Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.role == UserRole.admin
                          ? 'Review and approve/deny workforce absence filings.'
                          : 'Oversight of leave applications in your assigned sectors (Read-only; Admin approval required).',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Role Notice Banner for Supervisor
          if (currentUser.role == UserRole.supervisor)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusOptimalBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.statusOptimalText),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Supervisor Notice: As defined in the Role Matrix (US-18), supervisors can monitor worker leave requests in assigned areas, but final approval authority is reserved for Admin.',
                      style: TextStyle(fontSize: 12, color: AppColors.statusOptimalText, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Controls & Filter Bar (Record count on left, status tabs & sort dropdown on right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredLeaves.length} leave applications',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status filter tabs
                  _buildTab('All', 'all'),
                  const SizedBox(width: 6),
                  _buildTab('Pending', 'pending'),
                  const SizedBox(width: 6),
                  _buildTab('Approved', 'approved'),
                  const SizedBox(width: 6),
                  _buildTab('Denied', 'denied'),
                  const SizedBox(width: 14),

                  // Sort Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      const Text('Sort by:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                            value: _sortBy,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'newest', child: Text('Newest Filing')),
                              DropdownMenuItem(value: 'oldest', child: Text('Oldest Filing')),
                              DropdownMenuItem(value: 'pending_first', child: Text('Pending First')),
                              DropdownMenuItem(value: 'worker_name', child: Text('Worker Name (A-Z)')),
                              DropdownMenuItem(value: 'start_date', child: Text('Start Date')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sortBy = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stretched Leaves Table
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (filteredLeaves.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_outlined, size: 40, color: AppColors.textLight),
                            SizedBox(height: 12),
                            Text('No leave applications found for this filter', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  }

                  const minWidth = 1100.0;
                  final isWide = constraints.maxWidth >= minWidth;

                  Widget tableWidget = Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(2.2), // WORKER
                      1: FlexColumnWidth(1.4), // LEAVE TYPE
                      2: FlexColumnWidth(1.7), // WORK AREA
                      3: FlexColumnWidth(1.1), // START DATE
                      4: FlexColumnWidth(1.1), // END DATE
                      5: FlexColumnWidth(2.4), // REASON / NOTES
                      6: FlexColumnWidth(1.2), // STATUS
                      7: FlexColumnWidth(1.5), // ACTION
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
                          _buildHeaderCell('LEAVE TYPE'),
                          _buildHeaderCell('WORK AREA'),
                          _buildHeaderCell('START DATE'),
                          _buildHeaderCell('END DATE'),
                          _buildHeaderCell('REASON / STATEMENT'),
                          _buildHeaderCell('STATUS'),
                          _buildHeaderCell('ACTION'),
                        ],
                      ),
                      ...filteredLeaves.map((req) {
                        return TableRow(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                            ),
                          ),
                          children: [
                            // Worker Cell
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primaryNavy,
                                    child: Text(
                                      req.initials,
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
                                          req.workerName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          req.userId,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Type Cell
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(req.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                            // Area Cell
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(req.areaName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                            // Start Date
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(req.startDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            // End Date
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(req.endDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            // Reason Cell
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(
                                req.reason,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            // Status Cell
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(
                                  label: req.status.toUpperCase(),
                                  type: req.status == 'approved'
                                      ? BadgeType.success
                                      : req.status == 'denied'
                                          ? BadgeType.danger
                                          : BadgeType.warning,
                                ),
                              ),
                            ),
                            // Action Cell: Only the Review button (no check or X icons)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: Icon(
                                    currentUser.role == UserRole.supervisor ? Icons.recommend_outlined : Icons.description_outlined,
                                    size: 14,
                                  ),
                                  label: Text(
                                    currentUser.role == UserRole.supervisor ? 'Review / Endorse' : 'Review',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accentBlue,
                                    backgroundColor: AppColors.navActiveBackground,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => _showLeaveReviewModal(req),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  );

                  if (isWide) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: tableWidget,
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minWidth,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: tableWidget,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTab(String label, String val) {
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

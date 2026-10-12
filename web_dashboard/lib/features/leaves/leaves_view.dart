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

  void _promptDenialDialog(LeaveRequestModel req) {
    final reasonController = TextEditingController();

    ConfirmationDialog.show(
      context,
      title: 'Deny Leave Request',
      message: 'Provide an official administrative reason for denying ${req.workerName}\'s leave request.',
      confirmLabel: 'Confirm Denial',
      confirmVariant: ButtonVariant.danger,
      contentWidget: TextField(
        controller: reasonController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'e.g. Critical operational understaffing in sector...',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryNavy,
                  child: Text(req.initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave Review: ${req.workerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${req.type} • ${req.areaName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
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
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildReviewRow('Filing Period', '${req.startDate} to ${req.endDate}'),
                _buildReviewRow('Leave Category', req.type),
                _buildReviewRow('Work Sector', req.areaName),
                _buildReviewRow('Worker Account ID', req.userId),
                const SizedBox(height: 12),
                const Text('Filing Reason & Statement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    req.reason,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Medical / Supporting Document Proof (UC-03)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOptimalBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment_outlined, size: 20, color: AppColors.accentBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.type.contains('Sick')
                                  ? 'Official Medical Certificate (Ormoc Doctors Hospital)'
                                  : 'Filing Justification Document (Attached)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusOptimalText),
                            ),
                            const Text('Verified digital document attachment (PDF/JPEG)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ToastNotification.show(context, message: 'Opening attached leave proof document...', type: ToastType.info);
                        },
                        child: const Text('View Document', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                if (req.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.dangerText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Administrative Denial Reason: ${req.rejectionReason}',
                            style: const TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w500),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (currentUser.role == UserRole.admin && req.status == 'pending') ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brightRed,
                side: const BorderSide(color: AppColors.brightRed),
              ),
              onPressed: () {
                Navigator.pop(context);
                _promptDenialDialog(req);
              },
              child: const Text('Deny Leave'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentEmerald,
                foregroundColor: Colors.white,
              ),
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
              child: const Text('Approve Leave'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
          l.reason.toLowerCase().contains(globalSearch);
      final matchesStatus = _statusFilter == 'all' || l.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const SizedBox(width: 16),
              Row(
                children: [
                  _buildTab('All', 'all'),
                  const SizedBox(width: 8),
                  _buildTab('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildTab('Approved', 'approved'),
                  const SizedBox(width: 8),
                  _buildTab('Denied', 'denied'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

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

          // Leaves Table
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('WORKER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('WORK AREA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('START DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('END DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('REASON / NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                  rows: filteredLeaves.map((req) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryNavy,
                                child: Text(req.initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Text(req.workerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        DataCell(Text(req.type, style: const TextStyle(fontSize: 13))),
                        DataCell(Text(req.areaName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(Text(req.startDate, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(req.endDate, style: const TextStyle(fontSize: 12))),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              req.reason,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            label: req.status.toUpperCase(),
                            type: req.status == 'approved'
                                ? BadgeType.success
                                : req.status == 'denied'
                                    ? BadgeType.danger
                                    : BadgeType.warning,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.description_outlined, size: 14),
                                label: const Text('Review', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accentBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showLeaveReviewModal(req),
                              ),
                              if (currentUser.role == UserRole.admin && req.status == 'pending') ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                  tooltip: 'Quick Approve',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    await ref.read(dataRepositoryProvider).updateLeaveStatus(
                                          req.leaveId,
                                          'approved',
                                          adminId: currentUser.userId,
                                        );
                                    ref.invalidate(leaveRequestsProvider);
                                    if (context.mounted) {
                                      ToastNotification.show(context, message: 'Approved leave for ${req.workerName}', type: ToastType.success);
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.highlight_off, color: AppColors.brightRed, size: 18),
                                  tooltip: 'Deny Leave',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _promptDenialDialog(req),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String val) {
    final isSelected = _statusFilter == val;
    return InkWell(
      onTap: () => setState(() => _statusFilter = val),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

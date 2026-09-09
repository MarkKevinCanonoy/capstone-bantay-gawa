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
              Column(
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
                          currentUser.role == UserRole.admin && req.status == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                      tooltip: 'Approve Leave',
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
                                    IconButton(
                                      icon: const Icon(Icons.highlight_off, color: AppColors.brightRed, size: 20),
                                      tooltip: 'Deny Leave',
                                      onPressed: () => _promptDenialDialog(req),
                                    ),
                                  ],
                                )
                              : Text(
                                  req.status == 'pending' ? 'Pending Admin' : req.status.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
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

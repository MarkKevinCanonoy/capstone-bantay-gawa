import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/broadcast_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // UC-06: Send Notification Dialog & Flow
  // ==========================================
  void _showComposeBroadcastDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String recipientType = 'All Personnel'; // 'All Personnel', 'Field Supervisors', 'Field Workers', 'Specific User'
    String? selectedUserId;
    String? selectedUserName;
    bool isConfidential = false;

    final allUsers = ref.read(employeesProvider).value ?? [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.navActiveBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.campaign_outlined, color: AppColors.accentBlue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compose Notification',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Send announcements, alerts, or confidential memos via FCM.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),

                      // Recipient Target Selector (SRS Main Flow Step 3)
                      const Text('Target Audience (Recipients) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: recipientType,
                        items: const [
                          DropdownMenuItem(value: 'All Personnel', child: Text('All Users (City-wide Personnel)')),
                          DropdownMenuItem(value: 'Field Supervisors', child: Text('All Supervisors (Area In-charge)')),
                          DropdownMenuItem(value: 'Field Workers', child: Text('All Field Workers')),
                          DropdownMenuItem(value: 'Specific User', child: Text('Specific User (Individual Dispatch)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              recipientType = val;
                              if (val != 'Specific User') {
                                selectedUserId = null;
                                selectedUserName = null;
                              } else if (allUsers.isNotEmpty) {
                                selectedUserId = allUsers.first.userId;
                                selectedUserName = allUsers.first.fullName;
                              }
                            });
                          }
                        },
                      ),

                      // Conditional Specific User Picker
                      if (recipientType == 'Specific User') ...[
                        const SizedBox(height: 12),
                        const Text('Select Recipient *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedUserId,
                          items: allUsers.map((u) {
                            final roleBadge = u.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
                            return DropdownMenuItem(
                              value: u.userId,
                              child: Text('${u.fullName} ($roleBadge - ${u.assignedAreaName ?? "Unassigned"})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final found = allUsers.firstWhere((u) => u.userId == val);
                              setDialogState(() {
                                selectedUserId = val;
                                selectedUserName = found.fullName;
                              });
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Text('Subject Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(hintText: 'e.g. Weather Advisory / Sector Shift Notice'),
                      ),

                      const SizedBox(height: 14),
                      const Text('Message Content *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Type official memo or operational guidelines...',
                        ),
                      ),

                      const SizedBox(height: 14),
                      // Confidential Memo Checkbox (SRS UC-06 Main Flow Step 4 & Alt Flow 1)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isConfidential ? AppColors.dangerBg.withValues(alpha: 0.3) : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isConfidential ? AppColors.dangerBorder : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isConfidential,
                              activeColor: AppColors.brightRed,
                              onChanged: (val) => setDialogState(() => isConfidential = val ?? false),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mark as Confidential Memo',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'Ensures only the intended recipient has viewing access. Concealed on public bulletin boards.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions: Side-by-Side
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: ButtonVariant.outline,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          AppButton(
                            label: 'Send Notification',
                            icon: Icons.send_rounded,
                            variant: ButtonVariant.primary,
                            onPressed: () async {
                              // SRS Alt Flow 2: Validation check for empty message
                              if (subjectController.text.trim().isEmpty) {
                                ToastNotification.show(context, message: 'Please enter a subject title before sending.', type: ToastType.warning);
                                return;
                              }
                              if (messageController.text.trim().isEmpty) {
                                ToastNotification.show(context, message: 'Message body cannot be empty. Please enter your notice.', type: ToastType.warning);
                                return;
                              }

                              final currentUser = ref.read(currentUserProvider);
                              final recipientLabel = recipientType == 'Specific User'
                                  ? (selectedUserName ?? 'Specific Worker')
                                  : recipientType;

                              final deliveredCount = recipientType == 'Specific User'
                                  ? 1
                                  : recipientType == 'Field Supervisors'
                                      ? 4
                                      : recipientType == 'Field Workers'
                                          ? 44
                                          : 48;

                              final broadcast = BroadcastModel(
                                notificationId: 'bc-${DateTime.now().millisecondsSinceEpoch}',
                                senderId: currentUser.userId,
                                recipients: recipientLabel,
                                subject: subjectController.text.trim(),
                                message: messageController.text.trim(),
                                isConfidential: isConfidential,
                                deliveredCount: deliveredCount,
                                sentAt: DateTime.now(),
                              );

                              final dialogNavigator = Navigator.of(dialogCtx);
                              await ref.read(dataRepositoryProvider).addBroadcast(broadcast);
                              ref.invalidate(broadcastsProvider);

                              if (dialogCtx.mounted) {
                                dialogNavigator.pop();
                              }
                              if (mounted) {
                                ToastNotification.show(
                                  this.context,
                                  message: 'In-app notification delivered to $recipientLabel via Firebase Cloud Messaging.',
                                  type: ToastType.success,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // UC-09: Alert Details & Response Dialog
  // ==========================================
  void _showAlertDetailDialog(AlertModel alert) {
    final currentUser = ref.read(currentUserProvider);
    final isCritical = alert.severity == 'critical';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 660,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: alert.isResolved
                              ? AppColors.successBg
                              : isCritical
                                  ? AppColors.dangerBg
                                  : AppColors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          alert.isResolved
                              ? Icons.check_circle_outline
                              : isCritical
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                          color: alert.isResolved
                              ? AppColors.successText
                              : isCritical
                                  ? AppColors.dangerText
                                  : AppColors.warningText,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ),
                                StatusBadge(
                                  label: alert.isResolved ? 'RESOLVED' : alert.severity.toUpperCase(),
                                  type: alert.isResolved
                                      ? BadgeType.success
                                      : isCritical
                                          ? BadgeType.danger
                                          : BadgeType.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category: ${alert.type} • Triggered ${alert.timeAgo}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  // Affected Worker Profile Card (UC-09 Main Flow Step 4)
                  const Text('AFFECTED FIELD WORKER DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.accentBlue,
                              child: Text(
                                (alert.workerName != null && alert.workerName!.isNotEmpty)
                                    ? alert.workerName!.substring(0, 1)
                                    : 'W',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.workerName ?? 'Unassigned Worker',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${alert.workerEmpId ?? "EMP-ID"} • ${alert.workerContact ?? "+63 900 000 0000"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            // Credit Score Badge
                            if (alert.creditScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: alert.creditScore! < 50 ? AppColors.dangerBg : AppColors.warningBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Score: ${alert.creditScore}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: alert.creditScore! < 50 ? AppColors.dangerText : AppColors.warningText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Work Area Sector', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(alert.workareaName ?? 'Unassigned Area', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Area Supervisor', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(alert.supervisorName ?? 'Unassigned', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (alert.absenceCount != null)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Unexcused Absences', style: TextStyle(fontSize: 11, color: AppColors.brightRed, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('${alert.absenceCount} Days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brightRed)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('ALERT INCIDENT DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(alert.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                  ),

                  // If previously resolved, show audit trail
                  if (alert.isResolved) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successBg.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, size: 20, color: AppColors.successText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Resolution Audit Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successText)),
                                Text(
                                  'Action: ${alert.responseAction ?? "Acknowledged"} • Note: ${alert.responseNote ?? "Resolved"}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.successText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Response Actions (Side-by-Side)
                  if (!alert.isResolved)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Dismiss Action (Alt Flow 1)
                          AppButton(
                            label: 'Dismiss Alert (Audit Log)',
                            variant: ButtonVariant.outline,
                            icon: Icons.cancel_outlined,
                            onPressed: () async {
                              await ref.read(dataRepositoryProvider).dismissAlert(
                                alertId: alert.alertId,
                                adminId: currentUser.userId,
                                reason: 'Dismissed without penalty following admin assessment.',
                              );
                              ref.invalidate(alertsProvider);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                ToastNotification.show(context, message: 'Alert dismissed and logged in system audit trail.', type: ToastType.info);
                              }
                            },
                          ),

                          // Send Warning Notice (Main Flow Step 5)
                          AppButton(
                            label: 'Send Warning Notice',
                            icon: Icons.notifications_active_outlined,
                            variant: ButtonVariant.danger,
                            onPressed: () async {
                              final workerName = alert.workerName ?? 'Worker';
                              final supName = alert.supervisorName ?? 'Field Supervisor';
                              final defaultMsg = 'OFFICIAL ENRO WARNING: Attendance irregularity detected for $workerName (${alert.title}). Please coordinate immediately with $supName to rectify your status. Unresolved breaches will result in performance credit deductions and formal administrative review.';

                              await ref.read(dataRepositoryProvider).sendWarningForAlert(
                                alertId: alert.alertId,
                                workerId: alert.userId ?? 'user-w-4',
                                message: defaultMsg,
                              );

                              ref.invalidate(alertsProvider);
                              ref.invalidate(broadcastsProvider);

                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                ToastNotification.show(
                                  context,
                                  message: 'Warning notice dispatched to $workerName and Supervisor $supName via FCM.',
                                  type: ToastType.success,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        label: 'Close',
                        variant: ButtonVariant.outline,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final broadcastsAsync = ref.watch(broadcastsProvider);
    final activeCategoryFilter = ref.watch(alertCategoryFilterProvider);

    final alerts = alertsAsync.value ?? [];
    final broadcasts = broadcastsAsync.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerts & Broadcast Center',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dispatch official notices, monitor real-time worker warnings, and track geofence perimeter breaches.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AppButton(
                label: 'Compose Notification',
                icon: Icons.campaign_outlined,
                variant: ButtonVariant.primary,
                onPressed: _showComposeBroadcastDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.accentBlue,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentBlue,
              tabs: [
                Tab(text: 'System Alerts (${alerts.length})'),
                Tab(text: 'Broadcasts & Notices (${broadcasts.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: System Alerts List
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All Alerts',
                            value: 'all',
                            isSelected: activeCategoryFilter == 'all',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Consecutive Absences (3+)',
                            value: 'consecutive_absences',
                            isSelected: activeCategoryFilter == 'consecutive_absences',
                            icon: Icons.person_off_outlined,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Credit Score Warnings',
                            value: 'credit_warning',
                            isSelected: activeCategoryFilter == 'credit_warning',
                            icon: Icons.star_outline_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Geofence Breaches',
                            value: 'breach',
                            isSelected: activeCategoryFilter == 'breach',
                            icon: Icons.fmd_bad_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Alerts List
                    Expanded(
                      child: alerts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    activeCategoryFilter == 'all'
                                        ? 'No active alerts.'
                                        : 'No alerts in this category.',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: alerts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final alert = alerts[index];
                                final isCritical = alert.severity == 'critical';

                                return AppCard(
                                  padding: const EdgeInsets.all(18),
                                  backgroundColor: Colors.white,
                                  border: Border.all(
                                    color: alert.isResolved
                                        ? AppColors.border
                                        : isCritical
                                            ? AppColors.brightRed.withValues(alpha: 0.3)
                                            : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Category Icon, Title, StatusBadge, Time Ago
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: alert.isResolved
                                                  ? AppColors.successBg
                                                  : isCritical
                                                      ? AppColors.dangerBg
                                                      : AppColors.warningBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              alert.isResolved
                                                  ? Icons.check_circle_outline
                                                  : isCritical
                                                      ? Icons.error_outline
                                                      : Icons.warning_amber_rounded,
                                              color: alert.isResolved
                                                  ? AppColors.successText
                                                  : isCritical
                                                      ? AppColors.dangerText
                                                      : AppColors.warningText,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        alert.title,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    StatusBadge(
                                                      label: alert.isResolved
                                                          ? 'RESOLVED'
                                                          : alert.severity.toUpperCase(),
                                                      type: alert.isResolved
                                                          ? BadgeType.success
                                                          : isCritical
                                                              ? BadgeType.danger
                                                              : BadgeType.warning,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.surfaceSubtle,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: AppColors.border),
                                                      ),
                                                      child: Text(
                                                        alert.type,
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Text('•', style: TextStyle(color: AppColors.textMuted)),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      alert.timeAgo,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // 3 Structured Tiles: Affected Worker, Sector, Supervisor
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderSubtle),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppColors.primaryNavy,
                                                    child: Text(
                                                      (alert.workerName != null && alert.workerName!.isNotEmpty)
                                                          ? alert.workerName![0]
                                                          : 'W',
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('AFFECTED WORKER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          alert.workerName ?? 'Unassigned Worker',
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 30, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.accentBlue),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('WORK SECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          alert.workareaName ?? 'Ormoc Sector',
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 30, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.supervisor_account_outlined, size: 18, color: AppColors.accentEmerald),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('SUPERVISOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          alert.supervisorName ?? 'Unassigned',
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Incident Description
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          alert.description,
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                                        ),
                                      ),

                                      if (alert.isResolved) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.successBg.withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle, size: 14, color: AppColors.successText),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Resolved: ${alert.responseAction ?? "Acknowledged"} — ${alert.responseNote ?? "Closed"}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 14),

                                      // Footer Row with Action Button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                alert.isResolved ? Icons.history_rounded : Icons.info_outline_rounded,
                                                size: 14,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                alert.isResolved ? 'Logged in system audit history' : 'Action recommended: Review details and coordinate',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                          AppButton(
                                            label: alert.isResolved ? 'View' : 'Respond',
                                            variant: alert.isResolved ? ButtonVariant.outline : ButtonVariant.primary,
                                            icon: alert.isResolved ? Icons.visibility_outlined : Icons.assignment_turned_in_outlined,
                                            onPressed: () => _showAlertDetailDialog(alert),
                                          ),
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

                // Tab 2: Broadcasts & Notices
                broadcasts.isEmpty
                    ? const Center(child: Text('No announcements found.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: broadcasts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final bc = broadcasts[index];

                          return AppCard(
                            padding: const EdgeInsets.all(20),
                            backgroundColor: Colors.white,
                            border: Border.all(color: AppColors.border),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: bc.isConfidential
                                            ? AppColors.dangerBg
                                            : AppColors.accentBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        bc.isConfidential ? Icons.lock_outline_rounded : Icons.campaign_outlined,
                                        color: bc.isConfidential ? AppColors.brightRed : AppColors.accentBlue,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  bc.subject,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              if (bc.isConfidential)
                                                const StatusBadge(label: 'CONFIDENTIAL', type: BadgeType.danger)
                                              else
                                                const StatusBadge(label: 'BROADCAST NOTICE', type: BadgeType.optimal),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceSubtle,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.borderSubtle),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.accentBlue),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Target Audience: ${bc.recipients}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Message Content
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Text(
                                    bc.message,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Footer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.send_rounded, size: 14, color: AppColors.accentEmerald),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Delivered to ${bc.deliveredCount} active devices via Firebase Cloud Messaging',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${bc.sentAt.year}-${bc.sentAt.month.toString().padLeft(2, '0')}-${bc.sentAt.day.toString().padLeft(2, '0')} ${bc.sentAt.hour.toString().padLeft(2, '0')}:${bc.sentAt.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            )
          : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: isSelected ? AppColors.primaryNavy : AppColors.border),
      onSelected: (_) {
        ref.read(alertCategoryFilterProvider.notifier).state = value;
      },
    );
  }
}

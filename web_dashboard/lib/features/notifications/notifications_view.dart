import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/broadcast_model.dart';
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

  void _showComposeBroadcastDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String recipients = 'All Personnel';
    bool isConfidential = false;

    ConfirmationDialog.show(
      context,
      title: 'Compose Broadcast / Notice',
      message: 'Transmit an official announcement or confidential memo.',
      confirmLabel: 'Send Broadcast',
      contentWidget: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Audience', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: recipients,
                items: const [
                  DropdownMenuItem(value: 'All Personnel', child: Text('All Personnel (City-wide)')),
                  DropdownMenuItem(value: 'Field Supervisors', child: Text('Field Supervisors Only')),
                  DropdownMenuItem(value: 'Ormoc City Hall Zone', child: Text('Ormoc City Hall Crew')),
                  DropdownMenuItem(value: 'Ormoc Public Market', child: Text('Public Market Sanitation Crew')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => recipients = val);
                },
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 12),
              const Text('Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: subjectController, decoration: const InputDecoration(hintText: 'e.g. Weather Advisory / Task Shift')),
              const SizedBox(height: 12),
              const Text('Message Body', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: messageController, maxLines: 3, decoration: const InputDecoration(hintText: 'Enter announcement details...')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isConfidential,
                    activeColor: AppColors.accentBlue,
                    onChanged: (val) => setDialogState(() => isConfidential = val ?? false),
                  ),
                  const Text('Mark as Confidential Memo (US-13 Private Notification)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          );
        },
      ),
      onConfirm: () async {
        if (subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;
        final currentUser = ref.read(currentUserProvider);
        final broadcast = BroadcastModel(
          notificationId: 'bc-${DateTime.now().millisecondsSinceEpoch}',
          senderId: currentUser.userId,
          recipients: recipients,
          subject: subjectController.text.trim(),
          message: messageController.text.trim(),
          isConfidential: isConfidential,
          deliveredCount: recipients == 'All Personnel' ? 48 : 12,
          sentAt: DateTime.now(),
        );
        await ref.read(dataRepositoryProvider).addBroadcast(broadcast);
        ref.invalidate(broadcastsProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Broadcast dispatched to $recipients.', type: ToastType.success);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final broadcastsAsync = ref.watch(broadcastsProvider);
    final alerts = alertsAsync.value ?? [];
    final broadcasts = broadcastsAsync.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alerts & Broadcast Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Manage automated breach alerts, absence thresholds, and push announcements.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
              AppButton(
                label: 'Compose Announcement',
                icon: Icons.campaign_outlined,
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
                // Tab 1: Alerts List
                alerts.isEmpty
                    ? const Center(child: Text('No system alerts.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: alerts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          final isCritical = alert.severity == 'critical';

                          return AppCard(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: alert.isResolved
                                ? AppColors.surface
                                : isCritical
                                    ? AppColors.dangerBg.withValues(alpha: 0.3)
                                    : AppColors.warningBg.withValues(alpha: 0.3),
                            border: Border.all(
                              color: alert.isResolved
                                  ? AppColors.border
                                  : isCritical
                                      ? AppColors.dangerBorder
                                      : AppColors.warningBg,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  alert.isResolved
                                      ? Icons.check_circle_outline
                                      : isCritical
                                          ? Icons.error_outline
                                          : Icons.warning_amber_rounded,
                                  color: alert.isResolved
                                      ? Colors.green
                                      : isCritical
                                          ? AppColors.dangerText
                                          : AppColors.warningText,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            label: alert.isResolved ? 'RESOLVED' : alert.severity.toUpperCase(),
                                            type: alert.isResolved
                                                ? BadgeType.success
                                                : isCritical
                                                    ? BadgeType.danger
                                                    : BadgeType.warning,
                                          ),
                                          const Spacer(),
                                          Text(alert.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(alert.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                if (!alert.isResolved) ...[
                                  const SizedBox(width: 12),
                                  AppButton(
                                    label: 'Acknowledge',
                                    variant: ButtonVariant.outline,
                                    onPressed: () async {
                                      await ref.read(dataRepositoryProvider).resolveAlert(alert.alertId);
                                      ref.invalidate(alertsProvider);
                                      if (context.mounted) {
                                        ToastNotification.show(context, message: 'Alert marked as resolved.', type: ToastType.success);
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                // Tab 2: Broadcasts
                broadcasts.isEmpty
                    ? const Center(child: Text('No announcements found.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: broadcasts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bc = broadcasts[index];

                          return AppCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(bc.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                                        if (bc.isConfidential) ...[
                                          const SizedBox(width: 8),
                                          const StatusBadge(label: 'CONFIDENTIAL', type: BadgeType.danger),
                                        ],
                                      ],
                                    ),
                                    Text('Recipients: ${bc.recipients}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(bc.message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.send_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text('Delivered to ${bc.deliveredCount} active devices via FCM', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
}

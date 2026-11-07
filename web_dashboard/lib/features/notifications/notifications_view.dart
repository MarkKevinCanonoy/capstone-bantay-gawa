import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/broadcast_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';
import '../../core/utils/uuid_helper.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inPageSubjectController = TextEditingController();
  final TextEditingController _inPageMessageController = TextEditingController();
  final TextEditingController _broadcastSearchController = TextEditingController();
  String _inPageRecipientType = 'All Users (City-wide Personnel)';
  String? _inPageSelectedUserId;
  String? _inPageSelectedUserName;
  bool _inPageIsConfidential = false;

  // Filtering & Sorting State (Matching Attendance & Field Proof standards)
  String _alertStatusFilter = 'all'; // 'all', 'unresolved', 'resolved'
  DateTime? _selectedDate;
  String _dateRangePreset = 'all'; // 'all', 'today', 'yesterday', 'week', 'month', 'custom'
  String _selectedWorkAreaId = 'all';
  String _sortOrder = 'newest'; // 'newest', 'oldest', 'severity', 'worker'
  String _broadcastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inPageSubjectController.dispose();
    _inPageMessageController.dispose();
    _broadcastSearchController.dispose();
    super.dispose();
  }

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

  // ==========================================
  // UC-06: Send Notification Dialog & Flow
  // ==========================================
  void _showComposeBroadcastDialog() {
    final currentUser = ref.read(currentUserProvider);
    final isSupervisor = currentUser.role == UserRole.supervisor;
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String recipientType = isSupervisor
        ? 'My Assigned Team (Sector Workers)'
        : 'All Users (City-wide Personnel)';
    String? selectedUserId;
    String? selectedUserName;
    bool isConfidential = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Consumer(
          builder: (dialogContext, ref, _) {
            final employeesAsync = ref.watch(employeesProvider);
            final workAreasAsync = ref.watch(workAreasProvider);
            final rawUsers = (employeesAsync.value ?? []).where((u) => u.role != UserRole.admin).toList();
            final rawAreas = workAreasAsync.value ?? [];
            final supervisorAreas = isSupervisor
                ? rawAreas.where((a) =>
                    a.supervisorId == currentUser.userId ||
                    (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
                    a.workareaId == currentUser.assignedAreaId ||
                    a.name == currentUser.assignedAreaName).toList()
                : rawAreas;
            final allUsers = isSupervisor
                ? rawUsers.where((u) =>
                    u.role == UserRole.worker &&
                    supervisorAreas.any((a) =>
                        a.workareaId == u.assignedAreaId ||
                        (u.assignedAreaName != null && a.name.toLowerCase() == u.assignedAreaName!.toLowerCase())
                    )).toList()
                : rawUsers;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final isIndividual = recipientType == 'Specific User (Individual Dispatch)' || recipientType == 'Specific Worker in My Team';
                if (isIndividual && allUsers.isNotEmpty) {
                  if (selectedUserId == null || !allUsers.any((u) => u.userId == selectedUserId)) {
                    selectedUserId = allUsers.first.userId;
                    selectedUserName = allUsers.first.fullName;
                  }
                }

                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppColors.surface,
                  child: Container(
                    width: 580,
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
                                      'Send official announcements, alerts, or confidential memos.',
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

                          // Recipient Target Selector
                          const Text('Target Audience (Recipients) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: recipientType,
                            items: isSupervisor
                                ? const [
                                    DropdownMenuItem(value: 'My Assigned Team (Sector Workers)', child: Text('My Assigned Team (Sector Workers)')),
                                    DropdownMenuItem(value: 'Specific Worker in My Team', child: Text('Specific Worker in My Team')),
                                  ]
                                : const [
                                    DropdownMenuItem(value: 'All Users (City-wide Personnel)', child: Text('All Users (City-wide Personnel)')),
                                    DropdownMenuItem(value: 'All Supervisors (Area In-charge)', child: Text('All Supervisors (Area In-charge)')),
                                    DropdownMenuItem(value: 'All Field Workers', child: Text('All Field Workers')),
                                    DropdownMenuItem(value: 'Specific User (Individual Dispatch)', child: Text('Specific User (Individual Dispatch)')),
                                  ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  recipientType = val;
                                  final isIndiv = val == 'Specific User (Individual Dispatch)' || val == 'Specific Worker in My Team';
                                  if (!isIndiv) {
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
                          if (recipientType == 'Specific User (Individual Dispatch)' || recipientType == 'Specific Worker in My Team') ...[
                            const SizedBox(height: 12),
                            const Text('Select Recipient *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            if (employeesAsync.isLoading && allUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('Loading personnel list...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  ],
                                ),
                              )
                            else if (allUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No personnel records found in system.', style: TextStyle(fontSize: 12, color: AppColors.dangerText)),
                              )
                            else
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Subject Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildDialogTemplateChip('Weather Alert', 'Heavy Rain Advisory & Safety Protocol', subjectController, setDialogState),
                                      const SizedBox(width: 4),
                                      _buildDialogTemplateChip('Sector Muster', 'Mandatory Morning Assembly Notice', subjectController, setDialogState),
                                      const SizedBox(width: 4),
                                      _buildDialogTemplateChip('Assembly Notice', 'Urgent General Field Briefing Notice', subjectController, setDialogState),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                          // Confidential Memo Checkbox
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

                          // Actions
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
                                  if (subjectController.text.trim().isEmpty) {
                                    ToastNotification.show(context, message: 'Please enter a subject title before sending.', type: ToastType.warning);
                                    return;
                                  }
                                  if (messageController.text.trim().isEmpty) {
                                    ToastNotification.show(context, message: 'Message body cannot be empty. Please enter your notice.', type: ToastType.warning);
                                    return;
                                  }

                                  final currentUser = ref.read(currentUserProvider);
                                  final isSpecific = recipientType == 'Specific User (Individual Dispatch)' || recipientType == 'Specific Worker in My Team';
                                  String recipientLabel;
                                  if (isSpecific) {
                                    final targetUser = allUsers.where((u) => u.userId == selectedUserId).firstOrNull;
                                    final roleBadge = targetUser?.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
                                    final name = targetUser?.fullName ?? selectedUserName ?? 'Worker';
                                    recipientLabel = '$name ($roleBadge)';
                                  } else if (recipientType == 'My Assigned Team (Sector Workers)') {
                                    recipientLabel = 'Assigned Team (${currentUser.assignedAreaName ?? "Sector"})';
                                  } else if (recipientType == 'All Supervisors (Area In-charge)') {
                                    recipientLabel = 'All Supervisors (Area In-charge)';
                                  } else if (recipientType == 'All Field Workers') {
                                    recipientLabel = 'All Field Workers';
                                  } else {
                                    recipientLabel = 'All Users (except Admins)';
                                  }

                                  final deliveredCount = isSpecific
                                      ? 1
                                      : recipientType == 'My Assigned Team (Sector Workers)'
                                          ? allUsers.length
                                          : recipientType == 'All Supervisors (Area In-charge)'
                                              ? allUsers.where((u) => u.role == UserRole.supervisor).length
                                              : recipientType == 'All Field Workers'
                                                  ? allUsers.where((u) => u.role == UserRole.worker).length
                                                  : allUsers.length;

                                  final broadcast = BroadcastModel(
                                    notificationId: UuidHelper.generate(),
                                    senderId: currentUser.userId,
                                    receiverId: isSpecific ? selectedUserId : null,
                                    recipients: recipientLabel,
                                    subject: subjectController.text.trim(),
                                    message: messageController.text.trim(),
                                    type: isConfidential ? 'confidential' : 'announcement',
                                    isConfidential: isConfidential,
                                    deliveredCount: deliveredCount,
                                    sentAt: DateTime.now(),
                                  );

                                  try {
                                    await ref.read(dataRepositoryProvider).addBroadcast(broadcast);
                                    ref.invalidate(broadcastsProvider);

                                    if (dialogCtx.mounted) {
                                      Navigator.of(dialogCtx).pop();
                                    }
                                    if (mounted) {
                                      ToastNotification.show(
                                        this.context,
                                        message: 'In-app notification delivered to $recipientLabel.',
                                        type: ToastType.success,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ToastNotification.show(
                                        this.context,
                                        message: 'Failed to send notification: $e',
                                        type: ToastType.error,
                                      );
                                    }
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
      },
    );
  }

  // ==========================================
  // In-Page Quick Send Broadcast Action
  // ==========================================
  Future<void> _handleInPageSend() async {
    if (_inPageSubjectController.text.trim().isEmpty) {
      ToastNotification.show(context, message: 'Please enter a subject title before sending.', type: ToastType.warning);
      return;
    }
    if (_inPageMessageController.text.trim().isEmpty) {
      ToastNotification.show(context, message: 'Message body cannot be empty. Please enter your notice.', type: ToastType.warning);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final isSupervisor = currentUser.role == UserRole.supervisor;
    final employeesAsync = ref.read(employeesProvider);
    final workAreasAsync = ref.read(workAreasProvider);
    final rawUsers = (employeesAsync.value ?? []).where((u) => u.role != UserRole.admin).toList();
    final rawAreas = workAreasAsync.value ?? [];
    final supervisorAreas = isSupervisor
        ? rawAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawAreas;
    final allUsers = isSupervisor
        ? rawUsers.where((u) =>
            u.role == UserRole.worker &&
            supervisorAreas.any((a) =>
                a.workareaId == u.assignedAreaId ||
                (u.assignedAreaName != null && a.name.toLowerCase() == u.assignedAreaName!.toLowerCase())
            )).toList()
        : rawUsers;

    final isSpecific = _inPageRecipientType == 'Specific User (Individual Dispatch)' || _inPageRecipientType == 'Specific Worker in My Team';
    String recipientLabel;
    if (isSpecific) {
      final targetUser = allUsers.where((u) => u.userId == _inPageSelectedUserId).firstOrNull;
      final roleBadge = targetUser?.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
      final name = targetUser?.fullName ?? _inPageSelectedUserName ?? 'Worker';
      recipientLabel = '$name ($roleBadge)';
    } else if (_inPageRecipientType == 'My Assigned Team (Sector Workers)') {
      recipientLabel = 'Assigned Team (${currentUser.assignedAreaName ?? "Sector"})';
    } else if (_inPageRecipientType == 'All Supervisors (Area In-charge)') {
      recipientLabel = 'All Supervisors (Area In-charge)';
    } else if (_inPageRecipientType == 'All Field Workers') {
      recipientLabel = 'All Field Workers';
    } else {
      recipientLabel = 'All Users (except Admins)';
    }

    final deliveredCount = isSpecific
        ? 1
        : _inPageRecipientType == 'My Assigned Team (Sector Workers)'
            ? allUsers.length
            : _inPageRecipientType == 'All Supervisors (Area In-charge)'
                ? allUsers.where((u) => u.role == UserRole.supervisor).length
                : _inPageRecipientType == 'All Field Workers'
                    ? allUsers.where((u) => u.role == UserRole.worker).length
                    : allUsers.length;

    final broadcast = BroadcastModel(
      notificationId: UuidHelper.generate(),
      senderId: currentUser.userId,
      receiverId: isSpecific ? _inPageSelectedUserId : null,
      recipients: recipientLabel,
      subject: _inPageSubjectController.text.trim(),
      message: _inPageMessageController.text.trim(),
      type: _inPageIsConfidential ? 'confidential' : 'announcement',
      isConfidential: _inPageIsConfidential,
      deliveredCount: deliveredCount,
      sentAt: DateTime.now(),
    );

    try {
      await ref.read(dataRepositoryProvider).addBroadcast(broadcast);
      ref.invalidate(broadcastsProvider);

      _inPageSubjectController.clear();
      _inPageMessageController.clear();
      setState(() {
        _inPageIsConfidential = false;
      });

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'In-app notification delivered to $recipientLabel.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Failed to dispatch notice: $e',
          type: ToastType.error,
        );
      }
    }
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

                  // Affected Worker Profile Card
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
                                  Text(alert.workareaName ?? 'Ormoc Sector', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

                  // Response Actions
                  if (!alert.isResolved && currentUser.role == UserRole.admin)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Dismiss Action
                          AppButton(
                            label: 'Dismiss Alert (Audit Log)',
                            variant: ButtonVariant.outline,
                            icon: Icons.cancel_outlined,
                            onPressed: () async {
                              try {
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
                              } catch (e) {
                                if (mounted) {
                                  ToastNotification.show(context, message: 'Failed to dismiss alert: $e', type: ToastType.error);
                                }
                              }
                            },
                          ),

                          // Send Warning Notice
                          AppButton(
                            label: 'Send Warning Notice',
                            icon: Icons.notifications_active_outlined,
                            variant: ButtonVariant.danger,
                            onPressed: () async {
                              final workerName = alert.workerName ?? 'Worker';
                              final supName = alert.supervisorName ?? 'Field Supervisor';
                              final defaultMsg = 'OFFICIAL ENRO WARNING: Attendance irregularity detected for $workerName (${alert.title}). Please coordinate immediately with $supName to rectify your status. Unresolved breaches will result in formal administrative disciplinary review and corrective action.';

                              String targetWorkerId = alert.userId ?? '';
                              if (targetWorkerId.isEmpty) {
                                final emps = ref.read(employeesProvider).value ?? [];
                                final match = emps.where((e) => e.fullName.toLowerCase() == workerName.toLowerCase()).toList();
                                if (match.isNotEmpty) {
                                  targetWorkerId = match.first.userId;
                                }
                              }

                              if (targetWorkerId.isEmpty) {
                                if (mounted) {
                                  ToastNotification.show(context, message: 'Cannot dispatch warning: Worker record for $workerName not found.', type: ToastType.error);
                                }
                                return;
                              }

                              try {
                                await ref.read(dataRepositoryProvider).sendWarningForAlert(
                                  alertId: alert.alertId,
                                  workerId: targetWorkerId,
                                  message: defaultMsg,
                                );

                                ref.invalidate(alertsProvider);
                                ref.invalidate(employeesProvider);
                                ref.invalidate(broadcastsProvider);

                                if (dialogCtx.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                }
                                if (mounted) {
                                  ToastNotification.show(
                                    context,
                                    message: 'Warning notice dispatched to $workerName and Supervisor $supName.',
                                    type: ToastType.success,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ToastNotification.show(context, message: 'Failed to dispatch warning notice: $e', type: ToastType.error);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!alert.isResolved && currentUser.role == UserRole.supervisor)
                          const Expanded(
                            child: Text(
                              'Advisory overview only. Formal warning notices and disciplinary reviews are managed by Central Admin.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 12),
                        AppButton(
                          label: 'Close',
                          variant: ButtonVariant.outline,
                          onPressed: () => Navigator.of(dialogCtx).pop(),
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isSupervisor = currentUser.role == UserRole.supervisor;
    final alertsAsync = ref.watch(alertsProvider);
    final broadcastsAsync = ref.watch(broadcastsProvider);
    final activeCategoryFilter = ref.watch(alertCategoryFilterProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final rawAllUsers = employeesAsync.value ?? [];
    final rawWorkAreas = workAreasAsync.value ?? [];

    final rawAlerts = alertsAsync.value ?? [];
    final rawBroadcasts = broadcastsAsync.value ?? [];

    final workAreas = isSupervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;

    final allUsers = isSupervisor
        ? rawAllUsers.where((emp) {
            if (emp.role == UserRole.admin) return false;
            if (emp.role == UserRole.supervisor && emp.userId != currentUser.userId) return false;
            return workAreas.any((a) =>
                a.workareaId == emp.assignedAreaId ||
                (emp.assignedAreaName != null && a.name.toLowerCase() == emp.assignedAreaName!.toLowerCase()) ||
                (emp.role == UserRole.supervisor && emp.userId == currentUser.userId));
          }).toList()
        : rawAllUsers;

    final alerts = isSupervisor
        ? rawAlerts.where((alt) =>
            alt.supervisorId == currentUser.userId ||
            (alt.supervisorName != null && alt.supervisorName!.isNotEmpty && alt.supervisorName!.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            workAreas.any((a) => (alt.workareaId != null && alt.workareaId == a.workareaId) || (alt.workareaName != null && a.name.toLowerCase() == alt.workareaName!.toLowerCase())) ||
            allUsers.any((e) => alt.userId != null && e.userId == alt.userId)
          ).toList()
        : rawAlerts;

    final broadcasts = isSupervisor
        ? rawBroadcasts.where((b) {
            return b.senderId == currentUser.userId ||
                b.receiverId == currentUser.userId ||
                b.recipients.contains('All') ||
                b.recipients.contains('Supervisor');
          }).toList()
        : rawBroadcasts;

    if (isSupervisor && _inPageRecipientType == 'All Users (City-wide Personnel)') {
      _inPageRecipientType = 'My Assigned Team (Sector Workers)';
    }

    // ==========================================
    // Multi-Dimension Filter Engine: Status, Sector, Date & Sort
    // ==========================================
    var filteredAlerts = alerts.where((alert) {
      // 0. SRS Category Filter
      if (activeCategoryFilter != 'all') {
        if (alert.srsCategory != activeCategoryFilter) return false;
      }

      // 1. Status Filter
      if (_alertStatusFilter == 'unresolved' && alert.isResolved) return false;
      if (_alertStatusFilter == 'resolved' && !alert.isResolved) return false;

      // 2. Work Area Sector Filter
      if (_selectedWorkAreaId != 'all') {
        if (alert.workareaId != _selectedWorkAreaId) return false;
      }

      // 3. Date / Period Filter
      if (_dateRangePreset == 'week') {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        if (alert.createdAt.isBefore(weekAgo) && alert.isResolved) return false;
      } else if (_dateRangePreset == 'month') {
        final now = DateTime.now();
        if ((alert.createdAt.year != now.year || alert.createdAt.month != now.month) && alert.isResolved) {
          return false;
        }
      } else if (_selectedDate != null) {
        final matches = alert.createdAt.year == _selectedDate!.year &&
            alert.createdAt.month == _selectedDate!.month &&
            alert.createdAt.day == _selectedDate!.day;
        if (!matches && alert.isResolved) return false;
      }

      return true;
    }).toList();

    // 4. Sort Order for Alerts
    filteredAlerts.sort((a, b) {
      if (_sortOrder == 'severity') {
        int rank(AlertModel x) {
          if (!x.isResolved && x.severity == 'critical') return 4;
          if (!x.isResolved && x.severity == 'warning') return 3;
          if (!x.isResolved) return 2;
          return 1;
        }
        final diff = rank(b).compareTo(rank(a));
        if (diff != 0) return diff;
        return b.createdAt.compareTo(a.createdAt);
      } else if (_sortOrder == 'oldest') {
        return a.createdAt.compareTo(b.createdAt);
      } else if (_sortOrder == 'worker') {
        final nameA = a.workerName ?? '';
        final nameB = b.workerName ?? '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      } else {
        // 'newest' default
        return b.createdAt.compareTo(a.createdAt);
      }
    });

    // Key Operational Metrics
    final unresolvedCount = alerts.where((a) => !a.isResolved).length;
    final breachCount = alerts.where((a) => a.type.toLowerCase().contains('geofence') || a.type.toLowerCase().contains('breach')).length;
    final flagCount = alerts.where((a) => a.type.toLowerCase().contains('absence') || a.type.toLowerCase().contains('credit') || (a.creditScore != null && a.creditScore! < 50)).length;
    final totalDelivered = broadcasts.fold<int>(0, (sum, b) => sum + b.deliveredCount);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // Modern Header Bar with Unified Switcher
            // ==========================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Alerts & Broadcast Center',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monitor geofence perimeter violations, review worker attendance flags, and broadcast official field orders.',
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

            // ==========================================
            // Executive KPI Ribbon: 4 Operational Stats
            // ==========================================
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final crossAxisCount = isNarrow ? (constraints.maxWidth < 560 ? 1 : 2) : 4;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: isNarrow ? 2.8 : 2.3,
                  children: [
                    _buildKpiCard(
                      title: 'Active Incidents',
                      value: '$unresolvedCount',
                      subtitle: unresolvedCount > 0 ? 'Requires attention' : 'All clear',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.brightRed,
                      bgColor: AppColors.dangerBg,
                    ),
                    _buildKpiCard(
                      title: 'Perimeter Breaches',
                      value: '$breachCount',
                      subtitle: 'Perimeter anomalies',
                      icon: Icons.fmd_bad_outlined,
                      color: const Color(0xFFD97706),
                      bgColor: AppColors.warningBg,
                    ),
                    _buildKpiCard(
                      title: 'Personnel Warnings',
                      value: '$flagCount',
                      subtitle: 'Absence & attendance drops',
                      icon: Icons.person_off_outlined,
                      color: AppColors.accentBlue,
                      bgColor: AppColors.navActiveBackground,
                    ),
                    _buildKpiCard(
                      title: 'Field Broadcasts',
                      value: '${broadcasts.length}',
                      subtitle: '$totalDelivered total deliveries',
                      icon: Icons.send_rounded,
                      color: AppColors.accentEmerald,
                      bgColor: AppColors.successBg,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // ==========================================
            // Time & Area Control Bar: Date Navigator, Sector & Sort (Identical to Attendance)
            // ==========================================
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Left: Date Navigation Controller
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          tooltip: 'Date Range & Presets',
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

                  // Right: Sector Dropdown & Sort Order Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Work Area Sector Selector
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: workAreas.any((wa) => wa.workareaId == _selectedWorkAreaId) || _selectedWorkAreaId == 'all'
                                ? _selectedWorkAreaId
                                : 'all',
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(isSupervisor ? 'All Assigned Sectors' : 'All Ormoc Sectors'),
                              ),
                              ...workAreas.map((wa) => DropdownMenuItem(value: wa.workareaId, child: Text(wa.name))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedWorkAreaId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Order Selector
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortOrder,
                            icon: const Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'newest', child: Text('Sort: Newest First')),
                              DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest First')),
                              DropdownMenuItem(value: 'severity', child: Text('Sort: Severity (High First)')),
                              DropdownMenuItem(value: 'worker', child: Text('Sort: Worker Name (A–Z)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sortOrder = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // Custom Sleek Segmented Switcher
            // ==========================================
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primaryNavy,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                onTap: (_) => setState(() {}),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text('System Alerts (${rawAlerts.length})'),
                        if (unresolvedCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brightRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unresolvedCount',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.campaign_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Broadcasts & Notices (${broadcasts.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // Tab View Body: Alerts Center or Broadcast Hub
            // ==========================================
            IndexedStack(
              index: _tabController.index,
              children: [
                _buildSystemAlertsTab(filteredAlerts, activeCategoryFilter),
                _buildBroadcastHubTab(broadcasts, allUsers),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: Modern System Alerts Center
  // ==========================================
  Widget _buildSystemAlertsTab(List<AlertModel> filteredAlerts, String activeCategoryFilter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Toolbar & Status Segments
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All Alerts',
                      value: 'all',
                      isSelected: activeCategoryFilter == 'all',
                      icon: Icons.apps_rounded,
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
                      label: 'Compliance Warnings',
                      value: 'credit_warning',
                      isSelected: activeCategoryFilter == 'credit_warning',
                      icon: Icons.verified_user_outlined,
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
            ),
            const SizedBox(width: 14),
            // Status Toggle: All / Unresolved / Resolved
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  _buildStatusFilterPill('all', 'All'),
                  _buildStatusFilterPill('unresolved', 'Active'),
                  _buildStatusFilterPill('resolved', 'Resolved'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Alert Items Content
        if (filteredAlerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_outlined, size: 36, color: AppColors.accentEmerald),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No Alerts Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  activeCategoryFilter == 'all'
                      ? 'All operations in Ormoc City sectors are running normally for the selected date.'
                      : 'No active incident reports under this filter category for the selected date.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 280,
                ),
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = filteredAlerts[index];
                  return _buildModernAlertCard(alert);
                },
              );
            },
          ),
      ],
    );
  }

  // Modern Card for Each System Alert
  Widget _buildModernAlertCard(AlertModel alert) {
    final isCritical = alert.severity == 'critical';
    final accentColor = alert.isResolved
        ? AppColors.accentEmerald
        : isCritical
            ? AppColors.brightRed
            : const Color(0xFFF59E0B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isResolved ? AppColors.border : accentColor.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Severity Accent Spine
              Container(width: 4, color: accentColor),

              // Main Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Type pill + Time ago + Status Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  alert.isResolved
                                      ? Icons.check_circle_outline
                                      : isCritical
                                          ? Icons.error_outline
                                          : Icons.warning_amber_rounded,
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  alert.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(alert.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 10),

                      // Title
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Description Snippet
                      Text(
                        alert.description,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Worker Profile & Context Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
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
                                  Text(
                                    alert.workerName ?? 'Unassigned Worker',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${alert.workareaName ?? "Ormoc Sector"} • Sup: ${alert.supervisorName ?? "Unassigned"}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (alert.absenceCount != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${alert.absenceCount} Absences',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dangerText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Card Footer Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            alert.isResolved ? 'Logged in audit history' : 'Action required',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: alert.isResolved ? AppColors.textMuted : AppColors.brightRed,
                            ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: Modern Broadcast Hub (Split-View Studio)
  // ==========================================
  Widget _buildBroadcastHubTab(List<BroadcastModel> broadcasts, List<UserModel> allUsers) {
    final personnelUsers = allUsers.where((u) => u.role != UserRole.admin).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Fast In-Page Broadcast Composer Studio
              Expanded(
                flex: 5,
                child: _buildInPageBroadcastComposer(personnelUsers),
              ),
              const SizedBox(width: 20),
              // Right: Recent Dispatched Notices Feed
              Expanded(
                flex: 6,
                child: _buildRecentBroadcastsFeed(broadcasts, personnelUsers),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInPageBroadcastComposer(personnelUsers),
              const SizedBox(height: 24),
              _buildRecentBroadcastsFeed(broadcasts, personnelUsers),
            ],
          );
        }
      },
    );
  }

  // Fast In-Page Composer Card
  Widget _buildInPageBroadcastComposer(List<UserModel> allUsers) {
    final currentUser = ref.watch(currentUserProvider);
    final isSupervisor = currentUser.role == UserRole.supervisor;
    return AppCard(
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.white,
      border: Border.all(color: AppColors.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.navActiveBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispatch Field Notice',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Instant push notification to personnel devices',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Target Audience Selector
          const Text('Target Audience (Recipients) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _inPageRecipientType,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            items: isSupervisor
                ? const [
                    DropdownMenuItem(value: 'My Assigned Team (Sector Workers)', child: Text('My Assigned Team (Sector Workers)')),
                    DropdownMenuItem(value: 'Specific Worker in My Team', child: Text('Specific Worker in My Team')),
                  ]
                : const [
                    DropdownMenuItem(value: 'All Users (City-wide Personnel)', child: Text('All Users (City-wide Personnel)')),
                    DropdownMenuItem(value: 'All Supervisors (Area In-charge)', child: Text('All Supervisors (Area In-charge)')),
                    DropdownMenuItem(value: 'All Field Workers', child: Text('All Field Workers')),
                    DropdownMenuItem(value: 'Specific User (Individual Dispatch)', child: Text('Specific User (Individual Dispatch)')),
                  ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _inPageRecipientType = val;
                  final isIndiv = val == 'Specific User (Individual Dispatch)' || val == 'Specific Worker in My Team';
                  if (!isIndiv) {
                    _inPageSelectedUserId = null;
                    _inPageSelectedUserName = null;
                  } else if (allUsers.isNotEmpty) {
                    _inPageSelectedUserId = allUsers.first.userId;
                    _inPageSelectedUserName = allUsers.first.fullName;
                  }
                });
              }
            },
          ),

          if (_inPageRecipientType == 'Specific User (Individual Dispatch)' || _inPageRecipientType == 'Specific Worker in My Team') ...[
            const SizedBox(height: 12),
            const Text('Select Recipient *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _inPageSelectedUserId ?? (allUsers.isNotEmpty ? allUsers.first.userId : null),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                filled: true,
                fillColor: AppColors.surfaceSubtle,
              ),
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
                  setState(() {
                    _inPageSelectedUserId = val;
                    _inPageSelectedUserName = found.fullName;
                  });
                }
              },
            ),
          ],

          const SizedBox(height: 14),

          // Quick Subject Templates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subject Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Row(
                children: [
                  _buildTemplateChip('Weather Alert', 'Heavy Rain Advisory & Safety Protocol'),
                  const SizedBox(width: 4),
                  _buildTemplateChip('Sector Muster', 'Mandatory Morning Assembly Notice'),
                  const SizedBox(width: 4),
                  _buildTemplateChip('Assembly Notice', 'Urgent General Field Briefing Notice'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _inPageSubjectController,
            decoration: InputDecoration(
              hintText: 'e.g. Typhoon Advisory / Afternoon Sector Relocation',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
          ),

          const SizedBox(height: 14),
          const Text('Message Body *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _inPageMessageController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Enter official directives, muster guidelines, or administrative updates...',
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
          ),

          // Confidential Memo Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _inPageIsConfidential ? AppColors.dangerBg.withValues(alpha: 0.3) : AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _inPageIsConfidential ? AppColors.dangerBorder : AppColors.border),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _inPageIsConfidential,
                  activeColor: AppColors.brightRed,
                  onChanged: (val) => setState(() => _inPageIsConfidential = val ?? false),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark as Confidential Memo',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Restricts visibility on shared bulletin boards.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Send Notification',
              icon: Icons.send_rounded,
              variant: ButtonVariant.primary,
              onPressed: _handleInPageSend,
            ),
          ),
        ],
      ),
    );
  }

  // Template Clickable Chip
  Widget _buildTemplateChip(String label, String templateText) {
    return InkWell(
      onTap: () {
        setState(() {
          _inPageSubjectController.text = templateText;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navActiveBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        child: Text(
          '+ $label',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentBlue),
        ),
      ),
    );
  }

  Widget _buildDialogTemplateChip(
    String label,
    String templateText,
    TextEditingController controller,
    StateSetter setDialogState,
  ) {
    return InkWell(
      onTap: () {
        setDialogState(() {
          controller.text = templateText;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navActiveBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        child: Text(
          '+ $label',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentBlue),
        ),
      ),
    );
  }

  String _resolveSmartTarget(BroadcastModel bc, List<UserModel> allUsers) {
    if (bc.receiverId != null && bc.receiverId!.isNotEmpty) {
      final match = allUsers.where((u) => u.userId == bc.receiverId).firstOrNull;
      if (match != null) {
        final roleLabel = match.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
        return '${match.fullName} ($roleLabel)';
      }
      if (bc.recipients.isNotEmpty &&
          bc.recipients != 'Field Worker' &&
          bc.recipients != 'All Personnel' &&
          bc.recipients != 'All Users (City-wide Personnel)') {
        return bc.recipients;
      }
      return 'Specific Field Worker';
    }

    final rLower = bc.recipients.toLowerCase();
    if (rLower.contains('supervisor')) {
      return 'All Supervisors (Area In-charge)';
    } else if (rLower.contains('field worker') || (rLower.contains('worker') && !rLower.contains('all users') && !rLower.contains('personnel'))) {
      return 'All Field Workers';
    } else if (rLower.contains('except admin') || rLower.contains('city-wide') || rLower.contains('all personnel') || rLower.contains('all users')) {
      return 'All Users (except Admins)';
    } else if (bc.recipients.isNotEmpty && bc.recipients != 'All Personnel') {
      return bc.recipients;
    }
    return 'All Users (except Admins)';
  }

  Widget _buildSmartTargetBadge(String target, BroadcastModel bc) {
    final tLower = target.toLowerCase();
    final isSupervisor = tLower.contains('supervisor') && !tLower.contains('worker');
    final isWorkerGroup = tLower.contains('all field workers') || (tLower.contains('workers') && !tLower.contains('all users'));
    final isAllUsers = tLower.contains('all users') || tLower.contains('personnel') || tLower.contains('except admin');
    final isIndividual = bc.receiverId != null || (!isSupervisor && !isWorkerGroup && !isAllUsers);

    Color bg;
    Color text;
    IconData icon;

    if (isIndividual) {
      bg = const Color(0xFFE0F2FE); // Soft light sky
      text = const Color(0xFF0369A1); // Sky 700
      icon = Icons.person_outline_rounded;
    } else if (isSupervisor) {
      bg = const Color(0xFFF3E8FF); // Soft purple
      text = const Color(0xFF7E22CE); // Purple 700
      icon = Icons.security_outlined;
    } else if (isWorkerGroup) {
      bg = const Color(0xFFFEF3C7); // Soft amber
      text = const Color(0xFFB45309); // Amber 700
      icon = Icons.engineering_outlined;
    } else {
      bg = const Color(0xFFECFDF5); // Soft emerald
      text = const Color(0xFF047857); // Emerald 700
      icon = Icons.groups_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 5),
          Text(
            'Target: $target',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // Right Side: Sent Notices Feed
  Widget _buildRecentBroadcastsFeed(List<BroadcastModel> broadcasts, [List<UserModel> allUsers = const []]) {
    var filteredBroadcasts = broadcasts.where((bc) {
      // 1. Date Filter
      if (_selectedDate != null) {
        final matches = bc.sentAt.year == _selectedDate!.year &&
            bc.sentAt.month == _selectedDate!.month &&
            bc.sentAt.day == _selectedDate!.day;
        if (!matches) return false;
      } else if (_dateRangePreset == 'week') {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        if (bc.sentAt.isBefore(weekAgo)) return false;
      } else if (_dateRangePreset == 'month') {
        final now = DateTime.now();
        if (bc.sentAt.year != now.year || bc.sentAt.month != now.month) return false;
      }

      // 2. Search query
      if (_broadcastSearchQuery.trim().isNotEmpty) {
        final q = _broadcastSearchQuery.toLowerCase();
        final smartTarget = _resolveSmartTarget(bc, allUsers).toLowerCase();
        return bc.subject.toLowerCase().contains(q) ||
            bc.message.toLowerCase().contains(q) ||
            bc.recipients.toLowerCase().contains(q) ||
            smartTarget.contains(q);
      }
      return true;
    }).toList();

    // 3. Sort Order
    filteredBroadcasts.sort((a, b) {
      if (_sortOrder == 'oldest') {
        return a.sentAt.compareTo(b.sentAt);
      }
      return b.sentAt.compareTo(a.sentAt);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dispatched Broadcasts History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              '${filteredBroadcasts.length} of ${broadcasts.length} messages',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Search bar for past broadcasts
        TextField(
          controller: _broadcastSearchController,
          onChanged: (val) => setState(() => _broadcastSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search broadcasts by subject or recipient...',
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
            suffixIcon: _broadcastSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _broadcastSearchController.clear();
                      setState(() => _broadcastSearchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),

        if (filteredBroadcasts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No announcements found for this filter.', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredBroadcasts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bc = filteredBroadcasts[index];
              final smartTarget = _resolveSmartTarget(bc, allUsers);

              return AppCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.white,
                border: Border.all(
                  color: bc.isConfidential ? AppColors.dangerBorder : AppColors.border,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bc.isConfidential
                                ? AppColors.dangerBg
                                : AppColors.accentBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            bc.isConfidential ? Icons.lock_outline_rounded : Icons.campaign_outlined,
                            color: bc.isConfidential ? AppColors.brightRed : AppColors.accentBlue,
                            size: 18,
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
                                      bc.subject,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (bc.isConfidential)
                                    const StatusBadge(label: 'CONFIDENTIAL', type: BadgeType.danger)
                                  else
                                    const StatusBadge(label: 'BROADCAST', type: BadgeType.optimal),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildSmartTargetBadge(smartTarget, bc),
                                  const Spacer(),
                                  Text(
                                    '${bc.sentAt.year}-${bc.sentAt.month.toString().padLeft(2, '0')}-${bc.sentAt.day.toString().padLeft(2, '0')} ${bc.sentAt.hour.toString().padLeft(2, '0')}:${bc.sentAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bc.message,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentEmerald),
                        const SizedBox(width: 5),
                        Text(
                          bc.deliveredCount > 0
                              ? 'Delivered to ${bc.deliveredCount} ${bc.deliveredCount == 1 ? "active device" : "active devices"}'
                              : (bc.receiverId != null ? 'Delivered to 1 recipient device' : 'Broadcast to all active field devices'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // Helper Widgets: KPI Card & Filter Chips
  // ==========================================
  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
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
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            )
          : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
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

  Widget _buildStatusFilterPill(String id, String label) {
    final isSelected = _alertStatusFilter == id;
    return InkWell(
      onTap: () => setState(() => _alertStatusFilter = id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

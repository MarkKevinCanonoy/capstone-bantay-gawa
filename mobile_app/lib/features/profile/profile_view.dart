import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../../data/repositories/offline_sync_service.dart';
import '../leaves/leave_request_dialog.dart';
import '../onboarding/tutorial_screen.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _isManualSyncing = false;
  bool _showLeaveHistory = false;

  String _getAttachmentDisplayName(String? url) {
    if (url == null || url.trim().isEmpty) return 'Document';
    final trimmed = url.trim();
    if (trimmed.startsWith('data:')) {
      final mime = trimmed.substring(5).split(';').first.toLowerCase();
      if (mime.contains('pdf')) return 'Medical_Certificate.pdf';
      if (mime.contains('word') || mime.contains('officedocument') || mime.contains('doc')) {
        return 'Supporting_Document.docx';
      }
      if (mime.contains('image')) return 'Proof_Photo.jpg';
      if (mime.contains('text')) return 'Document.txt';
      return 'Supporting_Document';
    }
    final clean = trimmed.split('?').first;
    final name = clean.split('/').last;
    if (name.length > 28) {
      final extIndex = name.lastIndexOf('.');
      if (extIndex != -1 && extIndex > name.length - 6) {
        final ext = name.substring(extIndex);
        return '${name.substring(0, 20)}...$ext';
      }
      return '${name.substring(0, 25)}...';
    }
    return name.isNotEmpty ? name : 'Document';
  }

  void _showAttachmentPreview(BuildContext context, String url) {
    final clean = url.trim();
    final isImage = clean.startsWith('data:image') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getAttachmentDisplayName(url),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: clean.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(clean.split(',').last),
                          height: 260,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        )
                      : clean.startsWith('http')
                          ? Image.network(
                              clean,
                              height: 260,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(child: Text('Could not load image')),
                            )
                          : File(clean).existsSync()
                              ? Image.file(
                                  File(clean),
                                  height: 260,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                )
                              : const Center(child: Text('Image file not found on device')),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        clean.toLowerCase().contains('pdf') ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                        size: 48,
                        color: clean.toLowerCase().contains('pdf') ? Colors.red.shade700 : Colors.blue.shade700,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getAttachmentDisplayName(url),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Document attached and ready for Supervisor review.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleManualSync() async {
    setState(() => _isManualSyncing = true);
    final count = await OfflineSyncService.instance.syncPendingData();
    final remaining = OfflineSyncService.instance.pendingSyncCountNotifier.value;
    if (mounted) {
      setState(() => _isManualSyncing = false);
      if (count > 0) {
        if (remaining == 0) {
          ToastNotification.showSuccess(context, 'Successfully synced $count offline record(s) to server.');
        } else {
          ToastNotification.showWarning(context, 'Synced $count record(s). $remaining remain queued due to a sync issue.');
        }
      } else {
        if (remaining > 0) {
          ToastNotification.showWarning(context, '$remaining record(s) could not be synced yet. Please check connection or payload.');
        } else {
          ToastNotification.showInfo(context, 'All records are already up to date with the server.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider).value;
    final area = ref.watch(assignedWorkAreaProvider).value;
    final leaveRequests = ref.watch(leaveRequestListProvider).value ?? [];
    final attendanceLogs = ref.watch(attendanceListProvider).value ?? [];

    final now = DateTime.now();
    final currentMonthLogs = attendanceLogs.where((l) => l.timestamp.year == now.year && l.timestamp.month == now.month).toList();
    final presentDays = currentMonthLogs.where((l) => l.actionType == 'time-in').map((l) => l.timestamp.day).toSet().length;
    final tardyCount = currentMonthLogs.where((l) => l.actionType == 'time-in' && (l.timestamp.hour > 8 || (l.timestamp.hour == 8 && l.timestamp.minute > 15))).length;

    int elapsedWorkDays = 0;
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        elapsedWorkDays++;
      }
    }
    final approvedLeavesThisMonth = leaveRequests.where((l) =>
      l.status == 'approved' &&
      l.startDate.year == now.year &&
      l.startDate.month == now.month
    ).length;
    final absentDays = math.max(0, elapsedWorkDays - presentDays - approvedLeavesThisMonth);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppTranslations.get('nav_profile', lang),
          style: const TextStyle(fontSize: 20, color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
        ),
        Text(
          lang == AppLanguage.cebuano
              ? 'Estadistika sa attendance ug pagdumala sa datos'
              : 'Attendance records & local data management',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 14),

        // Identity Card
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.paleGreen,
                child: Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'W',
                  style: const TextStyle(fontSize: 28, color: AppColors.accentGreen, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                user?.fullName.isNotEmpty == true ? user!.fullName : '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              Text(
                [
                  if (user != null && (user.username.isNotEmpty || user.userId.isNotEmpty))
                    'ID: ${(user.username.isNotEmpty ? user.username : user.userId).toUpperCase()}',
                  if (user != null && user.contactNumber.isNotEmpty)
                    'Contact: ${user.contactNumber}',
                ].join(' • '),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  StatusBadge(
                    label: (user?.roleDisplayName ?? 'Field Worker').toUpperCase(),
                    backgroundColor: AppColors.paleGreen,
                    textColor: AppColors.accentGreen,
                  ),
                  StatusBadge(
                    label: area?.name.isNotEmpty == true
                        ? area!.name
                        : (lang == AppLanguage.cebuano ? 'Walay Lugar' : 'Unassigned Area'),
                    backgroundColor: const Color(0xFFDBEAFE),
                    textColor: const Color(0xFF1E40AF),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Monthly Attendance Summary Card (UC-18 Step 4)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang == AppLanguage.cebuano ? 'Buwanang Talaan sa Pagtambong' : 'Monthly Attendance Summary',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(now),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$presentDays',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              lang == AppLanguage.cebuano ? 'Mitambong' : 'Days Present',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$tardyCount',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.warningOrange),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              lang == AppLanguage.cebuano ? 'Naulahi (Late)' : 'Late',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neutralBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$absentDays',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              lang == AppLanguage.cebuano ? 'Wala (Absent)' : 'Absent',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Leave Requests (Decluttered: Active Card + Collapsible Past History)
        Builder(
          builder: (context) {
            final pendingLeaves = leaveRequests.where((l) => l.status.toLowerCase() == 'pending').toList();
            final pastLeaves = leaveRequests.where((l) => l.status.toLowerCase() != 'pending').toList();
            final hasPending = pendingLeaves.isNotEmpty;
            final activeLeave = hasPending ? pendingLeaves.first : null;

            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, color: AppColors.primaryNavy, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lang == AppLanguage.cebuano ? 'Akong mga Hangyo sa Bakasyon' : 'My Leave Requests',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                        ),
                      ),
                      if (!hasPending)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.accentBlue),
                          tooltip: 'Apply for Leave',
                          onPressed: () => showLeaveRequestDialog(context, ref),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 1. Active Leave Card
                  if (activeLeave != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                activeLeave.type,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                              ),
                              StatusBadge(
                                label: 'PENDING REVIEW',
                                backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                textColor: Colors.orange.shade800,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${DateFormat('MMM d, yyyy').format(activeLeave.startDate)} — ${DateFormat('MMM d, yyyy').format(activeLeave.endDate)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeLeave.reason,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (activeLeave.imageUrl != null && activeLeave.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showAttachmentPreview(context, activeLeave.imageUrl!),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attachment_rounded, size: 13, color: AppColors.accentBlue),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Proof Attached: ${_getAttachmentDisplayName(activeLeave.imageUrl)}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.accentBlue, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.visibility_outlined, size: 13, color: AppColors.accentBlue),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.beach_access_rounded, size: 18, color: AppColors.accentBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == AppLanguage.cebuano ? 'Walay pending nga bakasyon' : 'No active leave pending',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang == AppLanguage.cebuano ? 'Pindota ang Apply aron mag-file ug bakasyon' : 'File a request if you need sick or emergency leave',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.add, size: 14, color: AppColors.primaryNavy),
                            label: Text(
                              lang == AppLanguage.cebuano ? 'I-aplay' : 'Apply',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                            onPressed: () => showLeaveRequestDialog(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. Collapsible Past Leave History (prevents clutter)
                  if (pastLeaves.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _showLeaveHistory = !_showLeaveHistory),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              '${lang == AppLanguage.cebuano ? "Kaagi sa Bakasyon" : "Past Leave History"} (${pastLeaves.length})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            Icon(
                              _showLeaveHistory ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showLeaveHistory) ...[
                      const Divider(height: 12),
                      ...pastLeaves.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${l.type} (${DateFormat('MMM d').format(l.startDate)})',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        l.reason,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: l.status.toUpperCase(),
                                  backgroundColor: l.status == 'approved'
                                      ? AppColors.successBg
                                      : (l.status == 'denied' || l.status == 'rejected')
                                          ? AppColors.dangerBg.withValues(alpha: 0.6)
                                          : AppColors.warningBg,
                                  textColor: l.status == 'approved'
                                      ? AppColors.successText
                                      : (l.status == 'denied' || l.status == 'rejected')
                                          ? AppColors.dangerText
                                          : AppColors.warningText,
                                ),
                              ],
                            ),
                            if ((l.status == 'denied' || l.status == 'rejected') && l.rejectionReason != null && l.rejectionReason!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${lang == AppLanguage.cebuano ? "Rason" : "Reason"}: ${l.rejectionReason}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (l.imageUrl != null && l.imageUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: InkWell(
                                  onTap: () => _showAttachmentPreview(context, l.imageUrl!),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attachment_rounded, size: 11, color: AppColors.accentBlue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Proof: ${_getAttachmentDisplayName(l.imageUrl)}',
                                          style: const TextStyle(fontSize: 9, color: AppColors.accentBlue, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        const SizedBox(height: 14),

        // Settings, Language Toggle & App Tutorial
        AppCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // Language Switch
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.language, color: AppColors.primaryNavy, size: 22),
                  ),
                  title: Text(
                    AppTranslations.get('language_setting', lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  subtitle: Text(
                    lang == AppLanguage.cebuano ? 'Karon: Cebuano (Bisaya)' : 'Current: English Language',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang == AppLanguage.cebuano ? 'CEBUANO' : 'ENGLISH',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_horiz, size: 16, color: AppColors.primaryNavy),
                      ],
                    ),
                  ),
                  onTap: () {
                    ref.read(localeProvider.notifier).toggleLanguage();
                  },
                ),
                const Divider(height: 1),

                // Tutorial Walkthrough Button
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline, color: AppColors.primaryNavy, size: 22),
                  ),
                  title: Text(
                    AppTranslations.get('tutorial_button', lang),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  subtitle: const Text(
                    'Geofencing, Watermark, & Compliance Guide',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 22, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorialScreen(isModalView: true),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),

                // Face Biometrics Status Tile
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                          ? AppColors.successBg
                          : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                          ? Icons.verified_user_rounded
                          : Icons.face_retouching_natural_rounded,
                      color: (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                          ? AppColors.accentGreen
                          : AppColors.warningOrange,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                        ? 'Face Biometrics Enrolled'
                        : 'Face Profile Not Enrolled',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  subtitle: Text(
                    (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                        ? 'Biometric template active for attendance authentication'
                        : 'Register face on Attendance tab to clock in',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                          ? AppColors.successBg
                          : AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty) ? 'ACTIVE' : 'PENDING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (user?.faceEmbedding != null && user!.faceEmbedding!.isNotEmpty)
                            ? AppColors.accentGreen
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Offline Sync Manager
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.get('sync_manager', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Logs and proof images taken offline are stored locally in SQLite and synchronized automatically when an internet connection is established.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: OfflineSyncService.instance.pendingSyncCountNotifier,
                builder: (context, count, child) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                        label: count == 0 ? 'ALL DATA SYNCED' : '$count QUEUED FOR SYNC',
                        backgroundColor: count == 0 ? AppColors.successBg : AppColors.warningBg,
                        textColor: count == 0 ? AppColors.successText : AppColors.warningText,
                      ),
                      AppButton(
                        label: AppTranslations.get('sync_now', lang),
                        isLoading: _isManualSyncing,
                        variant: AppButtonVariant.secondary,
                        minHeight: 36,
                        isFullWidth: false,
                        onPressed: _isManualSyncing ? null : _handleManualSync,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Logout
        AppButton(
          label: AppTranslations.get('logout', lang),
          icon: Icons.logout,
          variant: AppButtonVariant.danger,
          onPressed: () async {
            await ref.read(currentUserProvider.notifier).logout();
            if (context.mounted) {
              ToastNotification.showInfo(context, 'Logged out. Biometric verification required for next login.');
            }
          },
        ),
      ],
    );
  }
}

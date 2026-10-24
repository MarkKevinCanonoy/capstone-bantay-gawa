import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                    hintText: 'e.g. 1st Written Warning issued, docked 15 performance credit points, and rescheduled for ethics seminar.',
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
    final incidents = incidentsAsync.value ?? [];

    final filteredIncidents = incidents.where((inc) {
      if (_statusFilter == 'pending') return inc.status == 'pending';
      if (_statusFilter == 'settled_locally') return inc.status == 'settled_locally';
      if (_statusFilter == 'escalated_to_admin') return inc.status == 'escalated_to_admin';
      if (_statusFilter == 'resolved') return inc.status == 'resolved';
      return true;
    }).toList();

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
              if (currentUser.role == UserRole.supervisor && currentUser.assignedAreaName != null) ...[
                const SizedBox(width: 16),
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
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Controls & Filter Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredIncidents.length} incident reports',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusTab('All', 'all'),
                  const SizedBox(width: 6),
                  _buildStatusTab('Pending Review', 'pending'),
                  const SizedBox(width: 6),
                  _buildStatusTab('Settled Locally', 'settled_locally'),
                  const SizedBox(width: 6),
                  _buildStatusTab('Escalated to Admin', 'escalated_to_admin'),
                  const SizedBox(width: 6),
                  _buildStatusTab('Resolved', 'resolved'),
                ],
              ),
            ],
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
                                          (inc.areaName != null && inc.areaName!.isNotEmpty) ? inc.areaName! : 'Field Assignment',
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

  Widget _buildStatusTab(String label, String val) {
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

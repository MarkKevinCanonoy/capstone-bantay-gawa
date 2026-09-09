import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
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
  void _showCreateIncidentDialog() {
    final issueTypeController = TextEditingController();
    final descController = TextEditingController();
    String reportedId = 'user-w-4';
    String reportedName = 'Ramon Aquino';

    ConfirmationDialog.show(
      context,
      title: 'File Worker Incident Report',
      message: 'Submit an official worker non-compliance or field misconduct report to Central Admin.',
      confirmLabel: 'Submit Incident',
      confirmVariant: ButtonVariant.danger,
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reported Field Worker', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: reportedId,
            items: const [
              DropdownMenuItem(value: 'user-w-4', child: Text('Ramon Aquino (Ormoc Public Market)')),
              DropdownMenuItem(value: 'user-w-1', child: Text('Carlos Mendoza (City Hall Zone)')),
              DropdownMenuItem(value: 'user-w-5', child: Text('Sofia Bautista (Bus Terminal)')),
            ],
            onChanged: (val) {
              if (val != null) {
                reportedId = val;
                reportedName = val == 'user-w-4' ? 'Ramon Aquino' : val == 'user-w-1' ? 'Carlos Mendoza' : 'Sofia Bautista';
              }
            },
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 12),
          const Text('Violation / Issue Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: issueTypeController, decoration: const InputDecoration(hintText: 'e.g. Unauthorized Absence / Boundary Breach')),
          const SizedBox(height: 12),
          const Text('Detailed Observation & Evidence Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe location, time, and photo evidence details...')),
        ],
      ),
      onConfirm: () async {
        if (issueTypeController.text.trim().isEmpty || descController.text.trim().isEmpty) return;
        final currentUser = ref.read(currentUserProvider);
        final incident = IncidentReportModel(
          reportId: 'inc-${DateTime.now().millisecondsSinceEpoch}',
          reporterId: currentUser.userId,
          reporterName: currentUser.fullName,
          reportedId: reportedId,
          reportedName: reportedName,
          issueType: issueTypeController.text.trim(),
          description: descController.text.trim(),
          status: 'pending',
          createdAt: DateTime.now(),
        );
        await ref.read(dataRepositoryProvider).addIncident(incident);
        ref.invalidate(incidentsProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Incident report filed and transmitted to Admin.', type: ToastType.success);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final incidentsAsync = ref.watch(incidentsProvider);
    final incidents = incidentsAsync.value ?? [];

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
                  const Text('Incident & Worker Misconduct Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    currentUser.role == UserRole.admin
                        ? 'Administrative review of field violations submitted by supervisors.'
                        : 'Submit documented disciplinary or breach issues directly to Admin with photo logs.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              AppButton(
                label: 'Report Worker Issue',
                icon: Icons.report_outlined,
                variant: ButtonVariant.danger,
                onPressed: _showCreateIncidentDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Incidents List
          Expanded(
            child: incidents.isEmpty
                ? const Center(
                    child: Text('No active worker incident reports.', style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.separated(
                    itemCount: incidents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final inc = incidents[index];
                      final isResolved = inc.status == 'resolved';

                      return AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isResolved ? AppColors.successBg : AppColors.dangerBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isResolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                color: isResolved ? AppColors.successText : AppColors.dangerText,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        inc.issueType,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 10),
                                      StatusBadge(
                                        label: inc.status.toUpperCase(),
                                        type: isResolved ? BadgeType.success : BadgeType.danger,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reported Worker: ${inc.reportedName} • Submitted by ${inc.reporterName}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    inc.description,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            if (currentUser.role == UserRole.admin && !isResolved)
                              AppButton(
                                label: 'Mark Resolved',
                                variant: ButtonVariant.outline,
                                onPressed: () async {
                                  await ref.read(dataRepositoryProvider).resolveIncident(inc.reportId);
                                  ref.invalidate(incidentsProvider);
                                  if (context.mounted) {
                                    ToastNotification.show(context, message: 'Incident resolved.', type: ToastType.success);
                                  }
                                },
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
}

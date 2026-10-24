import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../leaves/leave_request_dialog.dart';
import 'announcements_dialog.dart';

class WorkerDashboardView extends ConsumerWidget {
  final ValueChanged<int> onNavigate;

  const WorkerDashboardView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider).value;
    final assignedArea = ref.watch(assignedWorkAreaProvider).value;
    final attendanceLogs = ref.watch(attendanceListProvider).value ?? [];

    final workerFirstName = user?.firstName ?? 'Worker';
    final areaName = assignedArea?.name ?? 'Sector 4 - Downtown Zone';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // GEOFENCE BREACH ACTIVE WARNING BANNER
        ValueListenableBuilder<bool>(
          valueListenable: LocationTrackingService.instance.hasGeofenceBreachNotifier,
          builder: (context, hasBreach, child) {
            if (!hasBreach) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.dangerRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == AppLanguage.filipino ? 'BABALA: NASA LABAS NG SONA' : 'WARNING: OUTSIDE GEOFENCE',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dangerText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lang == AppLanguage.filipino
                              ? 'Natukoy ng system na ikaw ay lumabas sa $areaName. Hindi itinatala ang eksaktong lokasyon para sa iyong privacy, ngunit naka-lock ang attendance logging hanggang sa makabalik ka.'
                              : 'System detected you have left $areaName. Exact coordinates are not recorded for your privacy, but attendance logging is locked until you return.',
                          style: const TextStyle(fontSize: 10, color: AppColors.dangerText, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        Text(
          '${AppTranslations.get('greeting', lang)}, $workerFirstName!',
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${AppTranslations.get('field_worker_badge', lang)}  •  ID: ${user?.userId ?? "ENRO-2024-001"}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5),
        ),
        const SizedBox(height: 14),

        // Current Status Panel
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('current_status', lang),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryNavy,
                    radius: 17,
                    child: Icon(Icons.location_on, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      areaName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: LocationTrackingService.instance.isInsideGeofenceNotifier,
                    builder: (context, isInside, child) {
                      return StatusBadge(
                        label: isInside
                            ? AppTranslations.get('in_zone', lang)
                            : AppTranslations.get('outside_zone', lang),
                        backgroundColor: isInside ? AppColors.successBg : AppColors.dangerBg,
                        textColor: isInside ? AppColors.successText : AppColors.dangerText,
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.border),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 15, color: AppColors.primaryNavy),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppTranslations.get('morning_shift', lang),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Actions Section
        Text(
          AppTranslations.get('main_actions', lang),
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        _ActionItem(
          icon: Icons.fingerprint,
          title: AppTranslations.get('log_attendance', lang),
          subtitle: AppTranslations.get('log_attendance_sub', lang),
          onTap: () => onNavigate(1),
        ),
        _ActionItem(
          icon: Icons.cloud_upload_outlined,
          title: AppTranslations.get('upload_report', lang),
          subtitle: AppTranslations.get('upload_report_sub', lang),
          onTap: () => onNavigate(3),
        ),
        _ActionItem(
          icon: Icons.event_note,
          title: AppTranslations.get('request_leave', lang),
          subtitle: AppTranslations.get('request_leave_sub', lang),
          onTap: () => showLeaveRequestDialog(context, ref),
        ),
        _ActionItem(
          icon: Icons.campaign_outlined,
          title: AppTranslations.get('announcements', lang),
          subtitle: AppTranslations.get('announcements_sub', lang),
          onTap: () => AnnouncementsDialog.show(context),
        ),
        const SizedBox(height: 16),

        // Recent Attendance List
        const Text(
          'ATTENDANCE LOGS',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        if (attendanceLogs.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(16),
            child: Text(
              'Wala pang attendance record ngayong araw.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          ...attendanceLogs.take(4).map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: log.isSynced ? AppColors.paleGreen : AppColors.warningBg,
                          radius: 16,
                          child: Icon(
                            log.isSynced ? Icons.check : Icons.sync,
                            color: log.isSynced ? AppColors.accentGreen : AppColors.warningOrange,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.actionType.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy • hh:mm a').format(log.timestamp),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: log.isSynced ? 'SYNCED' : 'LOCAL',
                          backgroundColor: log.isSynced ? AppColors.successBg : AppColors.warningBg,
                          textColor: log.isSynced ? AppColors.successText : AppColors.warningText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryNavy,
              radius: 18,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/schedule_helper.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/repositories/location_tracking_service.dart';
import '../../data/repositories/mobile_repository_provider.dart';
import '../../data/repositories/offline_sync_service.dart';
import '../leaves/leave_request_dialog.dart';
import '../reports/report_worker_dialog.dart';
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
    final shiftEval = ScheduleHelper.evaluateShift(schedule: user?.schedule);

    final workerFirstName = user?.firstName ?? 'Worker';
    final areaName = (assignedArea?.name != null && assignedArea!.name.trim().isNotEmpty)
        ? assignedArea.name
        : AppTranslations.get('unassigned_area', lang);

    ref.listen(assignedWorkAreaProvider, (prev, next) {
      final area = next.value;
      if (area != null) {
        LocationTrackingService.instance.evaluateCurrentLocation(
          assignedArea: area,
          userId: user?.userId,
        );
      }
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(assignedWorkAreaProvider);
        ref.invalidate(attendanceListProvider);
        ref.invalidate(notificationListProvider);
        ref.invalidate(creditHistoryProvider);
        await OfflineSyncService.instance.syncPendingData();
        await OfflineSyncService.instance.syncInboundPersonnel();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
        // GEOFENCE BREACH ACTIVE WARNING BANNER
        ValueListenableBuilder<bool>(
          valueListenable: LocationTrackingService.instance.hasGeofenceBreachNotifier,
          builder: (context, hasBreach, child) {
            if (!hasBreach) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.dangerRed, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('geofence_warning_title', lang),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dangerText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang == AppLanguage.cebuano
                              ? 'Namatikdan sa system nga nilakaw ka gawas sa $areaName. Alang sa imong privacy, wala gitala ang eksaktong lokasyon, apan naka-lock ang attendance logging hangtod makabalik ka.'
                              : 'System detected you have left $areaName. Exact coordinates are not recorded for your privacy, but attendance logging is locked until you return.',
                          style: const TextStyle(fontSize: 12, color: AppColors.dangerText, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Worker Welcome & Persona Banner
        Text(
          '${AppTranslations.get('greeting', lang)}, $workerFirstName!',
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppTranslations.get('field_worker_badge', lang),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),

        // Current Status Panel (High Readability for Elderly Users)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('current_status', lang),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          areaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ormoc City ENRO Sector',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: LocationTrackingService.instance.isInsideGeofenceNotifier,
                    builder: (context, isInside, child) {
                      return StatusBadge(
                        label: isInside
                            ? (lang == AppLanguage.cebuano ? 'SULOD' : 'IN ZONE')
                            : (lang == AppLanguage.cebuano ? 'GAWAS' : 'OUTSIDE'),
                        backgroundColor: isInside ? AppColors.successBg : AppColors.dangerBg,
                        textColor: isInside ? AppColors.successText : AppColors.dangerText,
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    shiftEval.status == ShiftStatus.activeShift
                        ? Icons.play_circle_fill_rounded
                        : shiftEval.status == ShiftStatus.beforeShift
                            ? Icons.alarm_on_rounded
                            : shiftEval.status == ShiftStatus.restDay
                                ? Icons.bedtime_outlined
                                : Icons.access_time_filled,
                    size: 18,
                    color: shiftEval.status == ShiftStatus.activeShift
                        ? AppColors.accentEmerald
                        : shiftEval.status == ShiftStatus.beforeShift
                            ? const Color(0xFFD97706)
                            : AppColors.primaryNavy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (user?.schedule != null && user!.schedule.isNotEmpty && user.schedule != 'Unassigned')
                                    ? '${AppTranslations.get('schedule_prefix', lang)}: ${user.schedule}'
                                    : AppTranslations.get('unassigned_schedule', lang),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (shiftEval.status == ShiftStatus.activeShift)
                              StatusBadge(
                                label: lang == AppLanguage.cebuano ? 'AKTIBO' : 'ACTIVE',
                                backgroundColor: AppColors.successBg,
                                textColor: AppColors.successText,
                              )
                            else if (shiftEval.status == ShiftStatus.beforeShift)
                              StatusBadge(
                                label: shiftEval.isStartingSoon
                                    ? (lang == AppLanguage.cebuano ? 'MAGSUGOD NA' : 'SOON')
                                    : (lang == AppLanguage.cebuano ? 'UPCOMING' : 'UPCOMING'),
                                backgroundColor: const Color(0xFFFEF3C7),
                                textColor: const Color(0xFFD97706),
                              )
                            else if (shiftEval.status == ShiftStatus.afterShift)
                              StatusBadge(
                                label: lang == AppLanguage.cebuano ? 'NAHUMAN' : 'COMPLETED',
                                backgroundColor: AppColors.surfaceSubtle,
                                textColor: AppColors.textMuted,
                              )
                            else if (shiftEval.status == ShiftStatus.restDay)
                              const StatusBadge(
                                label: 'REST DAY',
                                backgroundColor: Color(0xFFE0E7FF),
                                textColor: Color(0xFF4338CA),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lang == AppLanguage.cebuano
                              ? ScheduleHelper.getCebuanoShiftNotice(shiftEval, areaName: assignedArea?.name)
                              : ScheduleHelper.getEnglishShiftNotice(shiftEval, areaName: assignedArea?.name),
                          style: TextStyle(
                            fontSize: 11,
                            color: shiftEval.status == ShiftStatus.beforeShift && shiftEval.isStartingSoon
                                ? const Color(0xFFB45309)
                                : AppColors.textSecondary,
                            fontStyle: shiftEval.status == ShiftStatus.restDay ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (shiftEval.status == ShiftStatus.beforeShift && shiftEval.isStartingSoon) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang == AppLanguage.cebuano
                              ? 'Pahinumdom: Magsugod ang imong trabaho sa ${ScheduleHelper.formatDuration(shiftEval.timeUntilStart!)}. Palihug siguroha nga anaa ka na sa $areaName sa dili pa mag-Time In.'
                              : 'Upcoming Shift: Starts in ${ScheduleHelper.formatDuration(shiftEval.timeUntilStart!)}. Please ensure you arrive at $areaName before timing in.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Actions Section (Large Touch Targets & High Contrast)
        Text(
          AppTranslations.get('main_actions', lang),
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        _ActionItem(
          icon: Icons.fingerprint,
          iconBg: AppColors.primaryNavy,
          title: AppTranslations.get('log_attendance', lang),
          subtitle: AppTranslations.get('log_attendance_sub', lang),
          onTap: () => onNavigate(1),
        ),
        _ActionItem(
          icon: Icons.camera_alt_outlined,
          iconBg: AppColors.accentGreen,
          title: AppTranslations.get('upload_report', lang),
          subtitle: AppTranslations.get('upload_report_sub', lang),
          onTap: () => onNavigate(3),
        ),
        _ActionItem(
          icon: Icons.event_note,
          iconBg: AppColors.accentBlue,
          title: AppTranslations.get('request_leave', lang),
          subtitle: AppTranslations.get('request_leave_sub', lang),
          onTap: () => showLeaveRequestDialog(context, ref),
        ),
        _ActionItem(
          icon: Icons.campaign_outlined,
          iconBg: AppColors.warningOrange,
          title: AppTranslations.get('announcements', lang),
          subtitle: AppTranslations.get('announcements_sub', lang),
          onTap: () => AnnouncementsDialog.show(context),
        ),
        _ActionItem(
          icon: Icons.report_problem_outlined,
          iconBg: AppColors.dangerRed,
          title: lang == AppLanguage.cebuano ? 'I-report ang Trabahante' : 'Report Worker Issue',
          subtitle: lang == AppLanguage.cebuano
              ? 'Taho bahin sa misconduct o pagliban'
              : 'Report conduct, absence, or area violation',
          onTap: () => showReportWorkerDialog(context, ref),
        ),
        const SizedBox(height: 20),

        // Recent Attendance List
        Text(
          AppTranslations.get('recent_attendance', lang),
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (attendanceLogs.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: Text(
                AppTranslations.get('no_attendance_today', lang),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...attendanceLogs.take(4).map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: log.isSynced ? AppColors.paleGreen : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            log.isSynced ? Icons.check_circle_outline : Icons.sync,
                            color: log.isSynced ? AppColors.accentGreen : AppColors.warningOrange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.actionType.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM d, yyyy • hh:mm a').format(log.timestamp),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

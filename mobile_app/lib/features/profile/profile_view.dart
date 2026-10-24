import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
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

  Color _getCreditScoreColor(int score) {
    if (score >= AppConstants.creditScoreGoodThreshold) return AppColors.accentGreen;
    if (score >= AppConstants.creditScoreWarningThreshold) return AppColors.warningOrange;
    return AppColors.dangerRed;
  }

  String _getCreditScoreTier(int score, AppLanguage lang) {
    if (score >= AppConstants.creditScoreGoodThreshold) return AppTranslations.get('good_standing', lang);
    if (score >= AppConstants.creditScoreWarningThreshold) return AppTranslations.get('needs_improvement', lang);
    return AppTranslations.get('critical_risk', lang);
  }

  Future<void> _handleManualSync() async {
    setState(() => _isManualSyncing = true);
    final count = await OfflineSyncService.instance.syncPendingData();
    if (mounted) {
      setState(() => _isManualSyncing = false);
      if (count > 0) {
        ToastNotification.showSuccess(context, 'Successfully synced $count offline record(s) to server.');
      } else {
        ToastNotification.showInfo(context, 'All records are already up to date with the server.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider).value;
    final area = ref.watch(assignedWorkAreaProvider).value;
    final leaveRequests = ref.watch(leaveRequestListProvider).value ?? [];
    final score = user?.performanceScore ?? 88;
    final scoreColor = _getCreditScoreColor(score);
    final scoreTier = _getCreditScoreTier(score, lang);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppTranslations.get('nav_profile', lang),
          style: const TextStyle(fontSize: 20, color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Performance credits & local data management',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                user?.fullName ?? 'Juan Dela Cruz',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              Text(
                'ID: ${user?.userId ?? "ENRO-2024-001"} • Contact: ${user?.contactNumber ?? "+63 917 123 4567"}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  const StatusBadge(
                    label: 'FIELD WORKER',
                    backgroundColor: AppColors.paleGreen,
                    textColor: AppColors.accentGreen,
                  ),
                  StatusBadge(
                    label: area?.name ?? 'Sector 4',
                    backgroundColor: const Color(0xFFDBEAFE),
                    textColor: const Color(0xFF1E40AF),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Performance Credit Score Card (SRS UC-18)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: scoreColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTranslations.get('credit_score_title', lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                    ),
                  ),
                  Text(
                    scoreTier,
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scoreColor),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100.0,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              const SizedBox(height: 10),
              if (score < AppConstants.creditScoreGoodThreshold)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scoreColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          score < AppConstants.creditScoreWarningThreshold
                              ? 'Critical alert: Consecutive unverified absences detected. Please consult ENRO supervisor.'
                              : 'Warning: Score has dropped below 80. Ensure timely attendance and approved task reports.',
                          style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Settings, Language Toggle & App Tutorial
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Language Switch
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.primaryNavy, size: 22),
                title: Text(
                  AppTranslations.get('language_setting', lang),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lang == AppLanguage.filipino ? 'Kasalukuyan: Wikang Filipino' : 'Current: English Language',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang == AppLanguage.filipino ? 'FILIPINO' : 'ENGLISH',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.swap_horiz, size: 14, color: AppColors.primaryNavy),
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
                leading: const Icon(Icons.help_outline, color: AppColors.primaryNavy, size: 22),
                title: Text(
                  AppTranslations.get('tutorial_button', lang),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Geofencing, Watermark, & Credits Guide',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TutorialScreen(isModalView: true),
                    ),
                  );
                },
              ),
            ],
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
                  return Row(
                    children: [
                      StatusBadge(
                        label: count == 0 ? 'ALL DATA SYNCED' : '$count QUEUED FOR SYNC',
                        backgroundColor: count == 0 ? AppColors.successBg : AppColors.warningBg,
                        textColor: count == 0 ? AppColors.successText : AppColors.warningText,
                      ),
                      const Spacer(),
                      AppButton(
                        label: AppTranslations.get('sync_now', lang),
                        isLoading: _isManualSyncing,
                        variant: AppButtonVariant.secondary,
                        minHeight: 36,
                        onPressed: _isManualSyncing ? null : _handleManualSync,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Leave Requests
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'My Leave Requests',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20, color: AppColors.primaryNavy),
                    onPressed: () => showLeaveRequestDialog(context, ref),
                  ),
                ],
              ),
              if (leaveRequests.isEmpty)
                const Text('No leave applications filed yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
              else
                ...leaveRequests.take(3).map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${l.type} (${DateFormat('MMM d').format(l.startDate)})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text(l.reason, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), maxLines: 1),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: l.status.toUpperCase(),
                            backgroundColor: l.status == 'approved' ? AppColors.successBg : AppColors.warningBg,
                            textColor: l.status == 'approved' ? AppColors.successText : AppColors.warningText,
                          ),
                        ],
                      ),
                    )),
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

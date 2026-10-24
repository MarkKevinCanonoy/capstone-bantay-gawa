import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';

class AnnouncementsDialog extends StatelessWidget {
  const AnnouncementsDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AnnouncementsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcements = [
      _Announcement(
        title: 'Advisory: Coastal Clearing & Drainage Operations',
        source: 'Office of ENRO Ormoc City',
        date: 'Today • 08:00 AM',
        content:
            'All field workers assigned to Sector 1 and Sector 4 are advised to prioritize shoreline drainage canals ahead of the expected low-pressure weather system this weekend.',
        badge: 'HIGH PRIORITY',
        badgeColor: AppColors.dangerRed,
        badgeBg: AppColors.dangerBg,
      ),
      _Announcement(
        title: 'Safety Gear & PPE Compliance Reminder',
        source: 'LGU Safety Inspection Unit',
        date: 'Yesterday • 02:30 PM',
        content:
            'Wearing of high-visibility vests, hard hats, and safety gloves is mandatory at all times during duty hours. Unverified accomplishments without PPE may be subject to supervisor review.',
        badge: 'NOTICE',
        badgeColor: AppColors.warningOrange,
        badgeBg: AppColors.warningBg,
      ),
      _Announcement(
        title: 'Arbor Day Tree Planting Schedule',
        source: 'ENRO Forestry Division',
        date: 'Oct 22 • 09:00 AM',
        content:
            'Registration is now open for volunteers for the upcoming Ormoc Watershed Rehabilitation activity next Saturday.',
        badge: 'ANNOUNCEMENT',
        badgeColor: AppColors.accentGreen,
        badgeBg: AppColors.paleGreen,
      ),
    ];

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.primaryNavy, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Mga Anunsyo ng ENRO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = announcements[index];
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: item.badge,
                            backgroundColor: item.badgeBg,
                            textColor: item.badgeColor,
                          ),
                          const Spacer(),
                          Text(item.date, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.source,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.content,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
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

class _Announcement {
  final String title;
  final String source;
  final String date;
  final String content;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;

  _Announcement({
    required this.title,
    required this.source,
    required this.date,
    required this.content,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
  });
}

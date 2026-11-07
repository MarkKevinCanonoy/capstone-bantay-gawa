import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/broadcast_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showRead = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNotificationDetail(BuildContext context, BroadcastModel item, AppLanguage lang) {
    // Mark as read immediately on open
    ref.read(readNotificationsProvider.notifier).markAsRead(item.notificationId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  StatusBadge(
                    label: item.type == 'alert'
                        ? 'ALERT / PAHIBALO'
                        : item.isConfidential
                            ? 'CONFIDENTIAL / PERSONAL'
                            : 'ENRO ADVISORY',
                    backgroundColor: item.type == 'alert'
                        ? AppColors.dangerBg
                        : item.isConfidential
                            ? const Color(0xFFDBEAFE)
                            : AppColors.paleGreen,
                    textColor: item.type == 'alert'
                        ? AppColors.dangerText
                        : item.isConfidential
                            ? const Color(0xFF1E40AF)
                            : AppColors.accentGreen,
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, yyyy • hh:mm a').format(item.sentAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.subject,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${lang == AppLanguage.cebuano ? "Gikan sa" : "From"}: ${item.recipients}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const Divider(height: 24),
              Text(
                item.message,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    lang == AppLanguage.cebuano ? 'Isira' : 'Close',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final notifications = ref.watch(notificationListProvider).value ?? [];
    final readIds = ref.watch(readNotificationsProvider).value ?? {};

    final unread = notifications.where((n) => !readIds.contains(n.notificationId)).toList();
    final announcements = notifications.where((n) => n.type == 'announcement').toList();
    final alerts = notifications.where((n) => n.type != 'announcement').toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang == AppLanguage.cebuano ? 'Mga Pahibalo' : 'Notifications',
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Toggle button to show or hide read notifications
          if (readIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _showRead = !_showRead),
              icon: Icon(
                _showRead ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
                color: AppColors.primaryNavy,
              ),
              label: Text(
                _showRead
                    ? (lang == AppLanguage.cebuano ? 'Tago-a ang Natan-aw' : 'Hide Read')
                    : (lang == AppLanguage.cebuano ? 'Ipakita Natan-aw (${readIds.length})' : 'Show Read (${readIds.length})'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
            ),
          // Mark all read button
          if (unread.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: AppColors.accentGreen, size: 22),
              tooltip: lang == AppLanguage.cebuano ? 'Basaha Tanan' : 'Mark All Read',
              onPressed: () {
                final allIds = notifications.map((n) => n.notificationId).toList();
                ref.read(readNotificationsProvider.notifier).markAllAsRead(allIds);
              },
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryNavy,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentGreen,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: lang == AppLanguage.cebuano ? 'Bag-o (${unread.length})' : 'Unread (${unread.length})'),
            Tab(text: lang == AppLanguage.cebuano ? 'Tanan (${notifications.length})' : 'All (${notifications.length})'),
            Tab(text: lang == AppLanguage.cebuano ? 'Anunsyo (${announcements.length})' : 'Notices (${announcements.length})'),
            Tab(text: lang == AppLanguage.cebuano ? 'Alerto (${alerts.length})' : 'Alerts (${alerts.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRefreshableList(unread, readIds, lang, emptyMessage: lang == AppLanguage.cebuano ? 'Wala kay bag-ong unread nga pahibalo!' : 'All caught up! No unread notifications.'),
          _buildRefreshableList(_showRead ? notifications : unread, readIds, lang),
          _buildRefreshableList(_showRead ? announcements : announcements.where((n) => !readIds.contains(n.notificationId)).toList(), readIds, lang),
          _buildRefreshableList(_showRead ? alerts : alerts.where((n) => !readIds.contains(n.notificationId)).toList(), readIds, lang),
        ],
      ),
    );
  }

  Widget _buildRefreshableList(
    List<BroadcastModel> items,
    Set<String> readIds,
    AppLanguage lang, {
    String? emptyMessage,
  }) {
    return RefreshIndicator(
      color: AppColors.accentGreen,
      onRefresh: () async {
        await ref.read(notificationListProvider.notifier).refresh();
      },
      child: _buildList(items, readIds, lang, emptyMessage: emptyMessage),
    );
  }

  Widget _buildList(
    List<BroadcastModel> items,
    Set<String> readIds,
    AppLanguage lang, {
    String? emptyMessage,
  }) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage ?? (lang == AppLanguage.cebuano ? 'Walay pahibalo nga makita' : 'No notifications to display'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (!_showRead && readIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _showRead = true),
                      child: Text(
                        lang == AppLanguage.cebuano
                            ? 'Ipakita ang ${readIds.length} nga natan-aw na'
                            : 'View ${readIds.length} previously read notifications',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentBlue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isRead = readIds.contains(item.notificationId);

        return AppCard(
          onTap: () => _showNotificationDetail(context, item, lang),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.type == 'alert'
                          ? AppColors.dangerBg
                          : item.isConfidential
                              ? const Color(0xFFEFF6FF)
                              : AppColors.paleGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.type == 'alert'
                          ? Icons.warning_amber_rounded
                          : item.isConfidential
                              ? Icons.lock_outline
                              : Icons.campaign_outlined,
                      color: item.type == 'alert'
                          ? AppColors.dangerRed
                          : item.isConfidential
                              ? AppColors.accentBlue
                              : AppColors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isRead ? AppColors.textMuted : AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.recipients} • ${DateFormat('MMM d, hh:mm a').format(item.sentAt)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isRead ? AppColors.textMuted : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusBadge(
                    label: item.type == 'alert'
                        ? 'ALERT / PAHIBALO'
                        : item.isConfidential
                            ? 'CONFIDENTIAL / PERSONAL'
                            : 'ENRO ADVISORY',
                    backgroundColor: item.type == 'alert'
                        ? AppColors.dangerBg
                        : item.isConfidential
                            ? const Color(0xFFDBEAFE)
                            : AppColors.paleGreen,
                    textColor: item.type == 'alert'
                        ? AppColors.dangerText
                        : item.isConfidential
                            ? const Color(0xFF1E40AF)
                            : AppColors.accentGreen,
                  ),
                  const Spacer(),
                  Text(
                    isRead ? 'Natan-aw na' : 'Bag-o (Tap to open)',
                    style: TextStyle(
                      fontSize: 10,
                      color: isRead ? AppColors.textMuted : AppColors.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

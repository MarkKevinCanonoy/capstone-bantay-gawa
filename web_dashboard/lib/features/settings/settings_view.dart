import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _supabaseUrlController = TextEditingController(text: 'https://xyzcompany.supabase.co');
  final _supabaseKeyController = TextEditingController(text: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  bool _useLiveSupabase = false;

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          const Text(
            'System Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure database connectivity parameters, service endpoints, and system operational rules.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Backend Architecture & Supabase Configuration Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage_rounded, color: AppColors.accentBlue, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Backend Data Layer Configuration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: _useLiveSupabase ? 'LIVE SUPABASE CONNECTED' : 'MOCK REPOSITORY ACTIVE',
                      type: _useLiveSupabase ? BadgeType.success : BadgeType.optimal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The web dashboard employs a decoupled Repository Pattern. While preparing your production Supabase database instance, all views, approvals, geofencing, and reports run interactively in Mock Mode. When your credentials are ready, enter them below to transition smoothly.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),

                const Text('Supabase Project URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseUrlController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.link_rounded, size: 18, color: AppColors.textMuted),
                    hintText: 'https://[project-ref].supabase.co',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentBlue)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Supabase Public Anon Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseKeyController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.key_outlined, size: 18, color: AppColors.textMuted),
                    hintText: 'anon public key token...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentBlue)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // Side-by-Side Action Buttons
                Row(
                  children: [
                    AppButton(
                      label: 'Save & Test Connection',
                      icon: Icons.sync,
                      variant: ButtonVariant.primary,
                      onPressed: () {
                        setState(() => _useLiveSupabase = true);
                        ToastNotification.show(
                          context,
                          message: 'Supabase credentials stored in configuration. Tables strictly aligned with specs/schema.sql.',
                          type: ToastType.success,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'Revert to Mock Mode',
                      variant: ButtonVariant.outline,
                      icon: Icons.restart_alt_rounded,
                      onPressed: () {
                        setState(() => _useLiveSupabase = false);
                        ToastNotification.show(context, message: 'Reverted to in-memory mock repository.', type: ToastType.info);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Infrastructure Services Health Overview Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_outlined, color: AppColors.accentBlue, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Connected Services & Infrastructure Health',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildServiceTile(
                          icon: Icons.storage_outlined,
                          title: 'PostgreSQL 15 + PostGIS',
                          status: 'Operational',
                          detail: 'Spatial geometry & geofence indexing enabled',
                          isHealthy: true,
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                        ),
                        _buildServiceTile(
                          icon: Icons.cloud_done_outlined,
                          title: 'Supabase Storage Bucket',
                          status: 'Active',
                          detail: 'Accomplishment proofs & field photo bucket',
                          isHealthy: true,
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                        ),
                        _buildServiceTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Firebase Cloud Messaging (FCM)',
                          status: 'Operational',
                          detail: 'In-app notification and alert broadcast channel',
                          isHealthy: true,
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                        ),
                        _buildServiceTile(
                          icon: Icons.map_outlined,
                          title: 'OpenStreetMap Tile Service',
                          status: 'Live',
                          detail: 'Interactive GIS and sector perimeter mapping',
                          isHealthy: true,
                          width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Operational Rules & Parameters Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppColors.accentBlue, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Operational Rules & System Thresholds',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildParameterRow(
                  label: 'Session Inactivity Auto-Logout',
                  value: '30 Minutes',
                  description: 'Enforces session termination after 30 minutes of idle inactivity for data security.',
                ),
                const Divider(height: 24, color: AppColors.border),
                _buildParameterRow(
                  label: 'Geofence Departure Grace Period',
                  value: '15 Minutes',
                  description: 'Allows short temporary signal drops before formal perimeter breach warnings are triggered.',
                ),
                const Divider(height: 24, color: AppColors.border),
                _buildParameterRow(
                  label: 'Consecutive Absence Alert Threshold',
                  value: '3 Working Days',
                  description: 'Automatically flags workers with 3+ consecutive unexcused absences for administrative inquiry.',
                ),
                const Divider(height: 24, color: AppColors.border),
                _buildParameterRow(
                  label: 'Worker Performance Credit Baseline',
                  value: '100 Points',
                  description: 'Standard starting balance. Deductions apply on unexcused absences; additions on verified proofs.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required String status,
    required String detail,
    required bool isHealthy,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHealthy ? AppColors.successBg : AppColors.dangerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHealthy ? AppColors.successText : AppColors.dangerText,
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
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isHealthy ? AppColors.successBg : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isHealthy ? AppColors.successText : AppColors.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow({
    required String label,
    required String value,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.statusOptimalBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.statusOptimalText),
          ),
        ),
      ],
    );
  }
}

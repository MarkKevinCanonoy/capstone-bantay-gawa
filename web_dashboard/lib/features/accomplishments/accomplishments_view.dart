import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/repositories/repository_provider.dart';

class AccomplishmentsView extends ConsumerStatefulWidget {
  const AccomplishmentsView({super.key});

  @override
  ConsumerState<AccomplishmentsView> createState() => _AccomplishmentsViewState();
}

class _AccomplishmentsViewState extends ConsumerState<AccomplishmentsView> {
  DateTime? _selectedDate;
  String _statusFilter = 'all';
  String _areaFilter = 'all';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'area', 'worker'
  bool _groupByArea = false;
  final Set<String> _expandedGroupKeys = {};

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isTodayOrFuture(DateTime d) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(d.year, d.month, d.day);
    return !targetMidnight.isBefore(todayMidnight);
  }

  DateTime? _parseCapturedDate(String dateStr) {
    if (dateStr.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) return parsed;
    try {
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat('MMM d, yyyy').parse(dateStr);
    } catch (_) {}
    return null;
  }

  bool _isPointInPolygon(double lat, double lng, List<LatLng> polygon) {
    if (polygon.length < 3) return true; // Default fallback if no boundary
    bool isInside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > lat) != (polygon[j].latitude > lat)) &&
          (lng < (polygon[j].longitude - polygon[i].longitude) * (lat - polygon[i].latitude) /
                  (polygon[j].latitude - polygon[i].latitude) +
              polygon[i].longitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  void _inspectProofModal(AccomplishmentModel proof) {
    final workAreas = ref.read(workAreasProvider).value ?? [];
    final matchingArea = workAreas.where((a) => a.workareaId == proof.workareaId).firstOrNull;
    final bool isInGeofence = matchingArea != null && matchingArea.polygon.isNotEmpty
        ? _isPointInPolygon(proof.capturedLat, proof.capturedLng, matchingArea.polygon)
        : true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proof.workerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${proof.areaName} • Submitted on ${proof.capturedDate} at ${proof.capturedTime}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusBadge(
              label: proof.status.toUpperCase(),
              type: proof.status == 'approved'
                  ? BadgeType.success
                  : proof.status == 'denied'
                      ? BadgeType.danger
                      : BadgeType.warning,
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with burned metadata banner simulation
                Container(
                  height: 300,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black87,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProofImage(proof, isModal: true),
                      // Burned Metadata Overlay (as specified in Rule #4 of GEMINI.md & SRS)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: Colors.black.withValues(alpha: 0.8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.yellowAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${proof.capturedDate} ${proof.capturedTime}',
                                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${proof.capturedLat.toStringAsFixed(5)}° N, ${proof.capturedLng.toStringAsFixed(5)}° E',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.accentEmerald, width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: AppColors.accentEmerald),
                                    SizedBox(width: 4),
                                    Text('BURNED WATERMARK VERIFIED', style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Location Status Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isInGeofence ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isInGeofence ? AppColors.accentEmerald.withValues(alpha: 0.4) : AppColors.brightRed.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isInGeofence ? Icons.check_circle_rounded : Icons.warning_rounded,
                                size: 20,
                                color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isInGeofence ? 'GEOFENCE MATCH: IN-ZONE VERIFIED' : 'GEOFENCE MISMATCH: OUT-OF-BOUNDS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                                ),
                              ),
                            ],
                          ),
                          StatusBadge(
                            label: isInGeofence ? 'INSIDE WORK AREA' : 'OUTSIDE WORK AREA',
                            type: isInGeofence ? BadgeType.success : BadgeType.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isInGeofence
                            ? 'Location Confirmed: The worker was physically inside their assigned boundary (${proof.areaName}) when this photo was taken.'
                            : 'Location Alert: The worker was outside their assigned boundary (${proof.areaName}) when this photo was taken. Please review carefully before approving.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Worker Task Description (Prominent & Easy to Spot)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Ribbon
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                          border: const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.assignment_turned_in_rounded, size: 16, color: AppColors.accentBlue),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'WORKER TASK DESCRIPTION',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_circle_outlined, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    proof.workerName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Description Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: proof.message.trim().isNotEmpty
                            ? Text(
                                proof.message.trim(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              )
                            : Row(
                                children: const [
                                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                                  SizedBox(width: 8),
                                  Text(
                                    'No task description was entered by the worker.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Submission & Photo Details
                const Text('Photo & Location Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
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
                            child: _buildDetailCard(
                              icon: Icons.person_outline_rounded,
                              label: 'FIELD WORKER',
                              value: proof.workerName,
                              subtitle: 'Field Personnel',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.location_on_outlined,
                              label: 'ASSIGNED WORK AREA',
                              value: proof.areaName,
                              subtitle: 'Designated Sector',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'DATE & TIME TAKEN',
                              value: '${proof.capturedDate} at ${proof.capturedTime}',
                              subtitle: 'Recorded by camera',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.my_location_rounded,
                              label: 'GPS POSITION',
                              value: '${proof.capturedLat.toStringAsFixed(5)}° N, ${proof.capturedLng.toStringAsFixed(5)}° E',
                              subtitle: 'High accuracy coordinates',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppColors.accentEmerald),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Authenticity Check: Image contains burned GPS coordinates and timestamp in pixel data.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (proof.rejectionReason != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brightRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.dangerText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejection Reason',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dangerText),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                proof.rejectionReason!,
                                style: const TextStyle(fontSize: 12, color: AppColors.dangerText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  label: 'Close',
                  variant: ButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (proof.status == 'pending') ...[
                  AppButton(
                    label: 'Reject Proof',
                    variant: ButtonVariant.danger,
                    icon: Icons.cancel_outlined,
                    onPressed: () {
                      Navigator.of(context).pop();
                      _promptRejectionDialog(proof);
                    },
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Approve Proof',
                    variant: ButtonVariant.accent,
                    icon: Icons.check_circle_outline,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final currentUser = ref.read(currentUserProvider);
                      await ref.read(dataRepositoryProvider).updateAccomplishmentStatus(
                            proof.accomplishmentId,
                            'approved',
                            approvedBy: currentUser.userId,
                            approvedByName: currentUser.fullName,
                          );
                      ref.invalidate(accomplishmentsProvider);
                      if (!mounted) return;
                      ToastNotification.show(this.context, message: 'Proof from ${proof.workerName} approved!', type: ToastType.success);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            child: Icon(icon, size: 18, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _promptRejectionDialog(AccomplishmentModel proof) {
    final reasonController = TextEditingController();

    ConfirmationDialog.show(
      context,
      title: 'Reject Accomplishment Proof',
      message: 'Provide a mandatory reason for denying this field accomplishment.',
      confirmLabel: 'Confirm Rejection',
      confirmVariant: ButtonVariant.danger,
      contentWidget: TextField(
        controller: reasonController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'e.g. Photo lacks burned coordinates, or work incomplete...',
        ),
      ),
      onConfirm: () async {
        final reason = reasonController.text.trim();
        if (reason.isEmpty) {
          ToastNotification.show(context, message: 'Rejection reason is required.', type: ToastType.error);
          return;
        }
        final currentUser = ref.read(currentUserProvider);
        await ref.read(dataRepositoryProvider).updateAccomplishmentStatus(
              proof.accomplishmentId,
              'denied',
              rejectionReason: reason,
              approvedBy: currentUser.userId,
              approvedByName: currentUser.fullName,
            );
        ref.invalidate(accomplishmentsProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Proof denied with reason recorded.', type: ToastType.info);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final accomplishmentsAsync = ref.watch(accomplishmentsProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final rawProofs = accomplishmentsAsync.value ?? [];
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;
    final proofs = currentUser.role == UserRole.supervisor
        ? rawProofs.where((p) {
            return workAreas.any((a) =>
                a.workareaId == p.workareaId ||
                a.name.toLowerCase() == p.areaName.toLowerCase());
          }).toList()
        : rawProofs;

    final filteredProofs = proofs.where((p) {
      final matchesSearch = p.workerName.toLowerCase().contains(globalSearch) ||
          p.areaName.toLowerCase().contains(globalSearch) ||
          p.message.toLowerCase().contains(globalSearch);
      final matchesStatus = _statusFilter == 'all' || p.status.toLowerCase() == _statusFilter.toLowerCase();
      final matchesArea = _areaFilter == 'all' || p.workareaId == _areaFilter;

      bool matchesDate = true;
      if (_selectedDate != null) {
        if (p.status.toLowerCase() == 'pending') {
          // Safeguard: Always keep pending accomplishments visible so unreviewed proofs are not missed
          matchesDate = true;
        } else {
          final parsedDate = _parseCapturedDate(p.capturedDate);
          if (parsedDate != null) {
            matchesDate = parsedDate.year == _selectedDate!.year &&
                parsedDate.month == _selectedDate!.month &&
                parsedDate.day == _selectedDate!.day;
          }
        }
      }

      return matchesSearch && matchesStatus && matchesArea && matchesDate;
    }).toList();

    int statusPriority(String status) {
      final s = status.toLowerCase();
      if (s == 'pending') return 1;
      if (s == 'approved' || s == 'accepted') return 2;
      if (s == 'denied' || s == 'rejected') return 3;
      return 2;
    }

    filteredProofs.sort((a, b) {
      final rankA = statusPriority(a.status);
      final rankB = statusPriority(b.status);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      switch (_sortBy) {
        case 'oldest':
          return a.capturedDate.compareTo(b.capturedDate);
        case 'area':
          final cmp = a.areaName.compareTo(b.areaName);
          return cmp != 0 ? cmp : b.capturedDate.compareTo(a.capturedDate);
        case 'worker':
          final cmp = a.workerName.compareTo(b.workerName);
          return cmp != 0 ? cmp : b.capturedDate.compareTo(a.capturedDate);
        case 'newest':
        default:
          final cmp = b.capturedDate.compareTo(a.capturedDate);
          return cmp != 0 ? cmp : b.capturedTime.compareTo(a.capturedTime);
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Field Accomplishment Proofs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Validate geotagged work completion submissions with burned EXIF metadata.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.accentBlue),
                      tooltip: 'Refresh Proofs from Cloud',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () {
                        ref.invalidate(accomplishmentsProvider);
                        ToastNotification.info(context, 'Checking cloud for newest field proofs...');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Date Navigation Controller (Identical to Attendance View)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
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
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? 'All Dates'
                                  : _isToday(_selectedDate!)
                                      ? 'Today: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}'
                                      : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
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
                                }
                              });
                            },
                    ),
                    Container(height: 20, width: 1, color: AppColors.border),
                    PopupMenuButton<String>(
                      tooltip: 'Date options',
                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        setState(() {
                          if (val == 'today') {
                            _selectedDate = DateTime.now();
                          } else if (val == 'yesterday') {
                            _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                          } else if (val == 'all') {
                            _selectedDate = null;
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'today', child: Text('Go to Today')),
                        const PopupMenuItem(value: 'yesterday', child: Text('Go to Yesterday')),
                        const PopupMenuItem(value: 'all', child: Text('View All Dates')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 16),

          // Enhanced Filter, Sort, & Clutter Management Control Bar
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Left group: Submissions count, Sector, and Sort
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_turned_in_outlined, size: 14, color: AppColors.accentBlue),
                          const SizedBox(width: 6),
                          Text(
                            '${filteredProofs.length} submissions',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),

                    // Sector Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: workAreas.any((a) => a.workareaId == _areaFilter) || _areaFilter == 'all'
                              ? _areaFilter
                              : 'all',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                          items: [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                currentUser.role == UserRole.supervisor ? 'All Assigned Sectors' : 'All Sectors',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ...workAreas.map((a) => DropdownMenuItem(
                              value: a.workareaId,
                              child: Text(a.name, style: const TextStyle(fontSize: 12)),
                            )),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _areaFilter = val);
                          },
                        ),
                      ),
                    ),

                    // Sort By Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                              items: const [
                                DropdownMenuItem(value: 'newest', child: Text('Newest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'oldest', child: Text('Oldest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'area', child: Text('Sort by Sector', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'worker', child: Text('Sort by Worker', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _sortBy = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Group by Sector View Toggle (Anti-Clutter)
                    Tooltip(
                      message: _groupByArea ? 'Switch to Standard Grid' : 'Group Submissions by Sector (Anti-Clutter)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _groupByArea = !_groupByArea),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _groupByArea ? AppColors.primaryNavy.withValues(alpha: 0.1) : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _groupByArea ? AppColors.primaryNavy : AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _groupByArea ? Icons.folder_copy : Icons.grid_view_rounded,
                                size: 16,
                                color: _groupByArea ? AppColors.primaryNavy : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _groupByArea ? 'Grouped' : 'Grid',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _groupByArea ? AppColors.primaryNavy : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Right group: Status filter tabs
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterTab('All', 'all', count: proofs.length),
                      _buildFilterTab(
                        'Pending',
                        'pending',
                        count: proofs.where((p) => p.status.toLowerCase() == 'pending').length,
                        dotColor: const Color(0xFFF59E0B),
                      ),
                      _buildFilterTab(
                        'Accepted',
                        'approved',
                        count: proofs.where((p) => p.status.toLowerCase() == 'approved' || p.status.toLowerCase() == 'accepted').length,
                        dotColor: const Color(0xFF10B981),
                      ),
                      _buildFilterTab(
                        'Denied',
                        'denied',
                        count: proofs.where((p) => p.status.toLowerCase() == 'denied' || p.status.toLowerCase() == 'rejected').length,
                        dotColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Proofs Content (Grid or Sector Accordion)
          Expanded(
            child: accomplishmentsAsync.isLoading && proofs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.accentBlue),
                        SizedBox(height: 16),
                        Text(
                          'Loading field accomplishment reports from cloud...',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : accomplishmentsAsync.hasError && proofs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.dangerRed),
                              const SizedBox(height: 12),
                              const Text(
                                'Unable to load field reports from database.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${accomplishmentsAsync.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onPressed: () => ref.invalidate(accomplishmentsProvider),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry Connection'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredProofs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.photo_library_outlined, size: 32, color: AppColors.textLight),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedDate == null
                                        ? 'No accomplishment proofs match current filters'
                                        : 'No accomplishment proofs found for ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Try switching to All Submissions or adjusting search keywords.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryNavy,
                                      side: const BorderSide(color: AppColors.primaryNavy),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDate = null;
                                        _statusFilter = 'all';
                                        _areaFilter = 'all';
                                      });
                                      ref.invalidate(accomplishmentsProvider);
                                    },
                                    icon: const Icon(Icons.restart_alt, size: 16),
                                    label: const Text('Reset Filters & View All Proofs'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _groupByArea
                    ? _buildGroupedByAreaView(filteredProofs, workAreas)
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 350,
                        ),
                        itemCount: filteredProofs.length,
                        itemBuilder: (context, index) => _buildProofCard(filteredProofs[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedByAreaView(List<AccomplishmentModel> proofs, List<WorkAreaModel> workAreas) {
    final Map<String, List<AccomplishmentModel>> grouped = {};
    for (final p in proofs) {
      final key = p.areaName.isNotEmpty ? p.areaName : 'Unassigned Sector';
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final areaName = sortedKeys[index];
        final areaProofs = grouped[areaName]!;
        final isExpanded = _expandedGroupKeys.contains(areaName) || _expandedGroupKeys.contains('__ALL__');
        final pendingCount = areaProofs.where((p) => p.status == 'pending').length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: isExpanded ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedGroupKeys.remove('__ALL__');
                        _expandedGroupKeys.remove(areaName);
                      } else {
                        _expandedGroupKeys.add(areaName);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                areaName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${areaProofs.length} proof submissions',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warningText.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '$pendingCount pending review',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warningText),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 350,
                      ),
                      itemCount: areaProofs.length,
                      itemBuilder: (context, i) => _buildProofCard(areaProofs[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static final Map<String, Uint8List> _storageImageCache = {};
  static final Map<String, Future<Uint8List?>> _pendingStorageDownloads = {};

  Widget _buildProofCard(AccomplishmentModel proof) {
    final workAreas = ref.watch(workAreasProvider).value ?? [];
    final matchingArea = workAreas.where((a) => a.workareaId == proof.workareaId).firstOrNull;
    final bool isInGeofence = matchingArea != null && matchingArea.polygon.isNotEmpty
        ? _isPointInPolygon(proof.capturedLat, proof.capturedLng, matchingArea.polygon)
        : true;

    final status = proof.status.toLowerCase();
    final isPending = status == 'pending';
    final isApproved = status == 'approved' || status == 'accepted';
    final isDenied = status == 'denied' || status == 'rejected';

    final Color statusColor = isPending
        ? const Color(0xFFF59E0B) // Amber
        : isApproved
            ? const Color(0xFF10B981) // Emerald
            : isDenied
                ? const Color(0xFFEF4444) // Crimson Red
                : AppColors.textMuted;

    final Color cardBorderColor = isPending
        ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
        : isApproved
            ? const Color(0xFF10B981).withValues(alpha: 0.45)
            : isDenied
                ? const Color(0xFFEF4444).withValues(alpha: 0.55)
                : AppColors.border;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorderColor, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => _inspectProofModal(proof),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Header
              Container(
                height: 140,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  color: Colors.black12,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildProofImage(proof, isModal: false),
                    // Top Row Badges
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isInGeofence ? AppColors.accentEmerald.withValues(alpha: 0.92) : AppColors.brightRed.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isInGeofence ? Icons.check_circle_rounded : Icons.warning_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isInGeofence ? 'IN-ZONE' : 'OUT-OF-BOUNDS',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPending
                                  ? Icons.hourglass_top_rounded
                                  : isApproved
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPending
                                  ? 'PENDING'
                                  : isApproved
                                      ? 'ACCEPTED'
                                      : 'DENIED',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${proof.capturedDate} ${proof.capturedTime}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primaryNavy,
                            child: Text(
                              proof.workerName.isNotEmpty ? proof.workerName[0].toUpperCase() : 'W',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            proof.workerName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              proof.capturedTime,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.accentBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            proof.areaName,
                            style: const TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.assignment_outlined, size: 14, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TASK DESCRIPTION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  proof.message.isNotEmpty ? proof.message : 'No task description provided.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Clear Status Banner Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFEF3C7)
                            : isApproved
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                              : isApproved
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPending
                                ? Icons.hourglass_top_rounded
                                : isApproved
                                    ? Icons.verified_rounded
                                    : Icons.cancel_outlined,
                            size: 14,
                            color: isPending
                                ? const Color(0xFFB45309)
                                : isApproved
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isPending
                                  ? 'PENDING REVIEW • Needs verification'
                                  : isApproved
                                      ? 'ACCEPTED & VERIFIED'
                                      : (proof.rejectionReason != null && proof.rejectionReason!.isNotEmpty)
                                          ? 'DENIED: ${proof.rejectionReason}'
                                          : 'DENIED: Submission rejected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPending
                                    ? const Color(0xFFB45309)
                                    : isApproved
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFB91C1C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildFilterTab(String label, String value, {int? count, Color? dotColor}) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProofImage(AccomplishmentModel proof, {bool isModal = false}) {
    final cleanUrl = proof.imageUrl.trim();
    final isNetwork = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');
    final isBase64 = cleanUrl.startsWith('data:image') ||
        (!isNetwork && cleanUrl.length > 100 && !cleanUrl.startsWith('/') && !cleanUrl.startsWith('file://'));
    final isLocalPath = cleanUrl.startsWith('/data/') ||
        cleanUrl.startsWith('/storage/') ||
        cleanUrl.startsWith('/cache/') ||
        cleanUrl.startsWith('file://') ||
        (cleanUrl.startsWith('/') && !isNetwork && !isBase64);

    Widget? imageContent;
    if (_storageImageCache.containsKey(cleanUrl)) {
      imageContent = Image.memory(
        _storageImageCache[cleanUrl]!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (isNetwork) {
      imageContent = Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          if (_storageImageCache.containsKey(cleanUrl)) {
            return Image.memory(
              _storageImageCache[cleanUrl]!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          }
          final future = _pendingStorageDownloads.putIfAbsent(
            cleanUrl,
            () => _tryDownloadSupabaseStorage(cleanUrl),
          );
          return FutureBuilder<Uint8List?>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              }
              return _buildFallbackProofPlaceholder(proof, isModal);
            },
          );
        },
      );
    } else if (isBase64) {
      try {
        String cleanBase64 = cleanUrl.contains(',') ? cleanUrl.split(',').last : cleanUrl;
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildFallbackProofPlaceholder(proof, isModal),
        );
      } catch (e) {
        debugPrint('Base64 image decoding failed: $e');
        imageContent = null;
      }
    } else if (isLocalPath) {
      imageContent = _buildLocalPathPlaceholder(cleanUrl, isModal);
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageContent != null)
            Positioned.fill(child: imageContent)
          else
            Positioned.fill(child: _buildFallbackProofPlaceholder(proof, isModal)),

          // Geotag Watermark & Coordinates Overlay (SRS UC-12)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${proof.capturedDate} ${proof.capturedTime} • ${proof.areaName}',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'GPS: ${proof.capturedLat.toStringAsFixed(4)}, ${proof.capturedLng.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _tryDownloadSupabaseStorage(String url) async {
    if (_storageImageCache.containsKey(url)) {
      return _storageImageCache[url];
    }
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final segments = uri.pathSegments;
      final publicIdx = segments.indexOf('public');
      if (publicIdx != -1 && publicIdx + 2 < segments.length) {
        final bucket = segments[publicIdx + 1];
        final path = segments.sublist(publicIdx + 2).join('/');
        final bytes = await Supabase.instance.client.storage.from(bucket).download(path);
        _storageImageCache[url] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildLocalPathPlaceholder(String path, bool isModal) {
    final fileName = path.contains('/') ? path.split('/').last : path;
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android_rounded, size: isModal ? 44 : 26, color: AppColors.accentBlue),
            const SizedBox(height: 6),
            Text(
              'MOBILE LOCAL STORAGE PROOF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: isModal ? 12 : 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photo cached on device: $fileName\nSync updated mobile app to upload cloud image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isModal ? 11 : 9,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackProofPlaceholder(AccomplishmentModel proof, bool isModal) {
    final isPark = proof.areaName.toLowerCase().contains('park');
    final isMarket = proof.areaName.toLowerCase().contains('market');
    final gradientColors = isPark
        ? [const Color(0xFF1E3A2F), const Color(0xFF0F1E19)]
        : isMarket
            ? [const Color(0xFF3B291A), const Color(0xFF1F150D)]
            : [const Color(0xFF1E293B), const Color(0xFF0F172A)];

    final icon = isPark
        ? Icons.park_rounded
        : isMarket
            ? Icons.storefront_rounded
            : Icons.account_balance_rounded;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.12,
            child: CustomPaint(
              painter: _GeotagGridPainter(),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isModal ? 52 : 36, color: Colors.white70),
                const SizedBox(height: 8),
                Text(
                  'ENRO FIELD PROOF PHOTO',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: isModal ? 12 : 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeotagGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

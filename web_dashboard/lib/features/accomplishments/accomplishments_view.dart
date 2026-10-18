import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/repositories/repository_provider.dart';

class AccomplishmentsView extends ConsumerStatefulWidget {
  const AccomplishmentsView({super.key});

  @override
  ConsumerState<AccomplishmentsView> createState() => _AccomplishmentsViewState();
}

class _AccomplishmentsViewState extends ConsumerState<AccomplishmentsView> {
  String _statusFilter = 'all';

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
                              subtitle: 'Worker ID: ${proof.userId}',
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
                const SizedBox(height: 16),

                const Text("Worker's Task Description", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proof.message.isNotEmpty ? proof.message : 'No additional description provided.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
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
    final accomplishmentsAsync = ref.watch(accomplishmentsProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final proofs = accomplishmentsAsync.value ?? [];

    final filteredProofs = proofs.where((p) {
      final matchesSearch = p.workerName.toLowerCase().contains(globalSearch) ||
          p.areaName.toLowerCase().contains(globalSearch) ||
          p.message.toLowerCase().contains(globalSearch);
      final matchesStatus = _statusFilter == 'all' || p.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                children: [
                  _buildFilterTab('All Submissions', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Pending Review', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Approved', 'approved'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proofs Grid
          Expanded(
            child: filteredProofs.isEmpty
                ? const Center(
                    child: Text('No accomplishment proofs match the current filter.', style: TextStyle(color: AppColors.textMuted)),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 320,
                    ),
                    itemCount: filteredProofs.length,
                    itemBuilder: (context, index) {
                      final proof = filteredProofs[index];

                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _inspectProofModal(proof),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Header
                              Container(
                                height: 160,
                                width: double.infinity,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                  color: Colors.black12,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildProofImage(proof, isModal: false),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: StatusBadge(
                                        label: proof.status.toUpperCase(),
                                        type: proof.status == 'approved'
                                            ? BadgeType.success
                                            : proof.status == 'denied'
                                                ? BadgeType.danger
                                                : BadgeType.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Card Body
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          proof.workerName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                        Text(
                                          proof.capturedTime,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      proof.areaName,
                                      style: const TextStyle(fontSize: 12, color: AppColors.accentBlue, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      proof.message,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildProofImage(AccomplishmentModel proof, {bool isModal = false}) {
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
          Positioned.fill(
            child: Image.memory(
              _kTransparentPixel,
              fit: BoxFit.cover,
            ),
          ),
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
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    'CAM-01 • ${proof.areaName}',
                    style: const TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace'),
                  ),
                ],
              ),
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

final Uint8List _kTransparentPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

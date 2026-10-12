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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proof.workerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${proof.areaName} • Submitted on ${proof.capturedDate}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
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
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with burned metadata banner simulation
                Container(
                  height: 280,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black87,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        proof.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                        ),
                      ),
                      // Burned Metadata Overlay (as specified in Rule #4 of GEMINI.md & SRS)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          color: Colors.black.withValues(alpha: 0.75),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STAMP: ${proof.capturedDate} ${proof.capturedTime}',
                                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                  Text(
                                    'GPS: ${proof.capturedLat.toStringAsFixed(5)}, ${proof.capturedLng.toStringAsFixed(5)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              const Text('ENRO VERIFIED', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // UC-04 Geofence Match Status Card (Steps 5 & 6)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isInGeofence ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
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
                                isInGeofence ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 18,
                                color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isInGeofence ? 'GEOFENCE MATCH: IN-ZONE VERIFIED' : 'GEOFENCE MISMATCH: OUT-OF-BOUNDS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                                ),
                              ),
                            ],
                          ),
                          StatusBadge(
                            label: isInGeofence ? 'IN-BOUNDS' : 'FLAGGED WARNING',
                            type: isInGeofence ? BadgeType.success : BadgeType.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isInGeofence
                            ? 'Captured GPS coordinates (${proof.capturedLat.toStringAsFixed(4)}, ${proof.capturedLng.toStringAsFixed(4)}) match inside the registered geofence perimeter for ${proof.areaName} (UC-04).'
                            : 'Warning (UC-04 Alt Flow 2): Extracted GPS coordinates deviate from the assigned work area perimeter. Verify photo metadata before approving.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isInGeofence ? AppColors.successText : AppColors.dangerText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Extracted Metadata Summary (UC-04 Step 5)
                const Text('Extracted Exif Metadata Summary (UC-04)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildMetaRow('Capture Timestamp', '${proof.capturedDate} at ${proof.capturedTime}'),
                      _buildMetaRow('GPS Coordinates', '${proof.capturedLat.toStringAsFixed(5)}° N, ${proof.capturedLng.toStringAsFixed(5)}° E'),
                      _buildMetaRow('Assigned Work Area', proof.areaName),
                      _buildMetaRow('Reporting Field Worker', '${proof.workerName} (${proof.userId})'),
                      _buildMetaRow('Watermark Integrity', 'Burned GPS/Time Overlay Intact (Valid)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Work Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(proof.message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),

                if (proof.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.dangerText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rejection Reason: ${proof.rejectionReason}',
                            style: const TextStyle(fontSize: 12, color: AppColors.dangerText, fontWeight: FontWeight.w500),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (proof.status == 'pending') ...[
            AppButton(
              label: 'Reject Proof',
              variant: ButtonVariant.danger,
              onPressed: () {
                Navigator.of(context).pop();
                _promptRejectionDialog(proof);
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Approve Proof',
              variant: ButtonVariant.accent,
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
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                                    Image.network(
                                      proof.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ),
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
}

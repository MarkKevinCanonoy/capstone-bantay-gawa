import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/models/worker_schedule_sheet_model.dart';
import '../../data/repositories/repository_provider.dart';
import '../../core/utils/uuid_helper.dart';
import 'widgets/area_workers_dialog.dart';

class WorkAreasView extends ConsumerStatefulWidget {
  const WorkAreasView({super.key});

  @override
  ConsumerState<WorkAreasView> createState() => _WorkAreasViewState();
}

class _WorkAreasViewState extends ConsumerState<WorkAreasView> {
  final MapController _mapController = MapController();
  WorkAreaModel? _selectedArea;
  String? _expandedWorkerAreaId;
  bool _isDrawing = false;
  final List<LatLng> _newPolygonPoints = [];

  void _focusArea(WorkAreaModel area) {
    setState(() {
      _selectedArea = area;
      // Toggle dropdown if clicked again for the same area, or open it
      _expandedWorkerAreaId = (_expandedWorkerAreaId == area.workareaId) ? null : area.workareaId;
    });
    // Move map focus to the area selected and zoom in a wee bit more (17.0)
    _mapController.move(area.center, 17.0);
  }

  static String _formatTo12Hour(String time24) {
    final clean = time24.trim();
    if (clean.isEmpty) return '';
    try {
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final min = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour == 0) {
          hour = 12;
        } else if (hour > 12) {
          hour -= 12;
        }
        return '${hour.toString().padLeft(2, '0')}:$min $period';
      }
    } catch (_) {}
    return clean;
  }

  Widget _buildWorkerScheduleView(String rawSchedule, {ScheduleEntryModel? entry}) {
    // Days mapping: Sunday(0) to Saturday(6) -> S M T W T F S
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    final activeDays = <int>{0, 1, 2, 3, 4, 5, 6}; // start with all days

    if (entry != null && entry.dayOff.isNotEmpty && entry.dayOff.toLowerCase() != 'none') {
      final offLower = entry.dayOff.toLowerCase();
      // Remove days specified as days off
      for (int i = 0; i < dayNames.length; i++) {
        final prefix = dayNames[i].substring(0, 3).toLowerCase();
        if (offLower.contains(prefix)) {
          activeDays.remove(i);
        }
      }
    } else if (rawSchedule.isNotEmpty && rawSchedule != 'Unassigned') {
      final lower = rawSchedule.toLowerCase();
      if (lower.contains('mon-fri') || lower.contains('mon to fri')) {
        activeDays.clear();
        activeDays.addAll([1, 2, 3, 4, 5]);
      } else if (lower.contains('mon-sat') || lower.contains('mon to sat')) {
        activeDays.clear();
        activeDays.addAll([1, 2, 3, 4, 5, 6]);
      } else if (lower.contains('daily') || lower.contains('everyday')) {
        activeDays.clear();
        activeDays.addAll([0, 1, 2, 3, 4, 5, 6]);
      } else {
        final found = <int>{};
        for (int i = 0; i < dayNames.length; i++) {
          final prefix = dayNames[i].substring(0, 3).toLowerCase();
          if (lower.contains(prefix)) {
            found.add(i);
          }
        }
        if (found.isNotEmpty) {
          activeDays.clear();
          activeDays.addAll(found);
        }
      }
    } else {
      // Default standard working days Monday to Friday if unassigned
      activeDays.clear();
      activeDays.addAll([1, 2, 3, 4, 5]);
    }

    // Determine time range string
    String time12 = '';
    final timeSource = (entry != null && entry.timeSchedule.isNotEmpty && entry.timeSchedule != 'Unassigned')
        ? entry.timeSchedule
        : rawSchedule;

    final timeMatch = RegExp(r'(\d{1,2}:\d{2}(?:\s*[AaPp][Mm])?)\s*[-–—]\s*(\d{1,2}:\d{2}(?:\s*[AaPp][Mm])?)').firstMatch(timeSource);
    if (timeMatch != null) {
      final t1 = timeMatch.group(1)!;
      final t2 = timeMatch.group(2)!;
      final t1_12 = t1.toLowerCase().contains('m') ? t1 : _formatTo12Hour(t1);
      final t2_12 = t2.toLowerCase().contains('m') ? t2 : _formatTo12Hour(t2);
      time12 = '$t1_12 - $t2_12';
    } else if (timeSource.contains('AM') || timeSource.contains('PM')) {
      time12 = timeSource;
    } else if (timeSource.isNotEmpty && timeSource != 'Unassigned') {
      time12 = timeSource;
    } else {
      time12 = '08:00 AM - 05:00 PM';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // S M T W T F S day row: black for working days, grey for day offs
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            final isWorking = activeDays.contains(i);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Text(
                dayLetters[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isWorking ? FontWeight.w800 : FontWeight.w500,
                  color: isWorking ? Colors.black87 : const Color(0xFFBDBDBD),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        // 12-hour format time below
        Text(
          time12,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showManageWorkersDialog(WorkAreaModel area) {
    AreaWorkersDialog.show(
      context,
      area: area,
      onAssignmentsChanged: () async {
        final updatedAreas = await ref.read(dataRepositoryProvider).getWorkAreas();
        if (_selectedArea?.workareaId == area.workareaId) {
          final found = updatedAreas.firstWhere(
            (a) => a.workareaId == area.workareaId,
            orElse: () => _selectedArea!,
          );
          if (mounted) {
            setState(() => _selectedArea = found);
          }
        }
        ref.invalidate(workAreasProvider);
      },
    );
  }

  void _startDrawingGeofence() {
    setState(() {
      _isDrawing = true;
      _newPolygonPoints.clear();
    });
    ToastNotification.show(
      context,
      message: 'Draw Mode Enabled: Tap at least 3 points on the map to define the perimeter.',
      type: ToastType.info,
    );
  }

  void _showAddAreaDialog() async {
    if (_newPolygonPoints.length < 3) {
      ToastNotification.show(
        context,
        message: 'Please draw a geofence area on the map (at least 3 points) before saving.',
        type: ToastType.warning,
      );
      setState(() => _isDrawing = true);
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final supervisors = ref.read(supervisorsProvider).value ??
        await ref.read(dataRepositoryProvider).getUsers(role: UserRole.supervisor);
    String? supervisorId;
    String supervisorName = 'No supervisor';

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 580,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.navActiveBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_location_alt_outlined, color: AppColors.accentBlue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Save New Work Area',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Review boundary parameters and assign an active field supervisor.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 18),

                      // Geofence Stats Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 22, color: AppColors.successText),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                  'Drawn Geofence: ${_newPolygonPoints.length} GPS Coordinates',
                                  style: const TextStyle(fontSize: 13, color: AppColors.successText, fontWeight: FontWeight.w700),
                                ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Area Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Ormoc Coastal Pier',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Assigned Field Supervisor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: supervisorId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                    SizedBox(width: 10),
                                    Text('No supervisor (Unassigned)'),
                                  ],
                                ),
                              ),
                              ...supervisors.map((s) => DropdownMenuItem<String?>(
                                    value: s.userId,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            '${s.fullName} (${s.assignedAreaName ?? 'General'})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                supervisorId = val;
                                final matched = supervisors.where((s) => s.userId == val);
                                supervisorName = matched.isNotEmpty ? matched.first.fullName : 'No supervisor';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Description / Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Work sector notes...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dialog Buttons: Cancel on Left, Save on Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: ButtonVariant.outline,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                          AppButton(
                            label: 'Save Work Area',
                            icon: Icons.check_circle_outline,
                            variant: ButtonVariant.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) {
                                ToastNotification.show(context, message: 'Please provide an area name.', type: ToastType.warning);
                                return;
                              }
                              if (_newPolygonPoints.length < 3) {
                                ToastNotification.show(context, message: 'You must draw at least 3 points to save a geofence.', type: ToastType.error);
                                return;
                              }
                              final newArea = WorkAreaModel(
                                workareaId: UuidHelper.generate(),
                                name: nameController.text.trim(),
                                description: descController.text.trim(),
                                supervisorId: supervisorId,
                                supervisorName: supervisorName,
                                assignedCount: 0,
                                status: 'Active',
                                areaSqKm: '',
                                polygon: List.from(_newPolygonPoints),
                              );
                              await ref.read(dataRepositoryProvider).addWorkArea(newArea);
                              ref.invalidate(workAreasProvider);
                              final refreshed = await ref.read(dataRepositoryProvider).getWorkAreas();
                              final created = refreshed.firstWhere(
                                (a) => a.name == newArea.name,
                                orElse: () => newArea,
                              );
                              setState(() {
                                _isDrawing = false;
                                _newPolygonPoints.clear();
                                _selectedArea = created;
                              });
                              _mapController.move(newArea.center, 15.0);
                              ref.invalidate(workAreasProvider);
                              ref.invalidate(supervisorsProvider);
                              ref.invalidate(employeesProvider);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                ToastNotification.show(context, message: 'Work Area "${created.name}" created with custom drawn geofence!', type: ToastType.success);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditAreaDialog(WorkAreaModel area) async {
    final nameController = TextEditingController(text: area.name);
    final descController = TextEditingController(text: area.description ?? '');
    final supervisors = ref.read(supervisorsProvider).value ??
        await ref.read(dataRepositoryProvider).getUsers(role: UserRole.supervisor);
    String? supervisorId = area.supervisorId;
    String supervisorName = (area.supervisorId != null && area.supervisorName.isNotEmpty && area.supervisorName != 'Field Supervisor' && area.supervisorName != 'Unassigned')
        ? area.supervisorName
        : 'No supervisor';
    String status = area.status;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            final hasDrawnPolygon = _newPolygonPoints.length >= 3;
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 580,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.navActiveBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_location_alt_outlined, color: AppColors.accentBlue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Work Area: ${area.name}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Modify work zone parameters, supervisor assignment, and operational status.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 18),

                      const Text('Area Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Ormoc Coastal Pier',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Assigned Supervisor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: supervisors.any((s) => s.userId == supervisorId) ? supervisorId : null,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                    SizedBox(width: 10),
                                    Text('No supervisor (Unassigned)'),
                                  ],
                                ),
                              ),
                              ...supervisors.map((s) => DropdownMenuItem<String?>(
                                    value: s.userId,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            '${s.fullName} (${s.assignedAreaName ?? 'General'})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                supervisorId = val;
                                final matched = supervisors.where((s) => s.userId == val);
                                supervisorName = matched.isNotEmpty ? matched.first.fullName : 'No supervisor';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: status,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(
                                value: 'Active',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.accentEmerald),
                                    SizedBox(width: 10),
                                    Text('Active (Monitored)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Inactive',
                                child: Row(
                                  children: [
                                    Icon(Icons.pause_circle_outline, size: 16, color: AppColors.textMuted),
                                    SizedBox(width: 10),
                                    Text('Inactive (Suspended)'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => status = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Description / Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Work sector notes...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      if (hasDrawnPolygon) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 18, color: AppColors.successText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Will update boundary with ${_newPolygonPoints.length} points drawn on map.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.successText, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Dialog Buttons: Cancel on Left, Save on Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: ButtonVariant.outline,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                          AppButton(
                            label: 'Save Changes',
                            icon: Icons.check_circle_outline,
                            variant: ButtonVariant.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;
                              final isUnassigned = supervisorId == null ||
                                  supervisorId!.isEmpty ||
                                  supervisorName == 'No supervisor';
                              final updatedArea = area.copyWith(
                                name: nameController.text.trim(),
                                description: descController.text.trim(),
                                supervisorId: isUnassigned ? null : supervisorId,
                                supervisorName: isUnassigned ? 'No supervisor' : supervisorName,
                                clearSupervisor: isUnassigned,
                                status: status,
                                polygon: (_newPolygonPoints.length >= 3) ? List.from(_newPolygonPoints) : area.polygon,
                              );
                              await ref.read(dataRepositoryProvider).updateWorkArea(updatedArea);
                              ref.invalidate(workAreasProvider);
                              ref.invalidate(supervisorsProvider);
                              ref.invalidate(employeesProvider);
                              ref.invalidate(attendanceProvider);
                              ref.invalidate(accomplishmentsProvider);
                              ref.invalidate(leaveRequestsProvider);
                              final curUser = ref.read(currentUserProvider);
                              if (curUser.userId == supervisorId || curUser.userId == area.supervisorId) {
                                final allUsers = await ref.read(dataRepositoryProvider).getUsers();
                                final updatedCur = allUsers.where((u) => u.userId == curUser.userId).firstOrNull;
                                if (updatedCur != null) {
                                  ref.read(currentUserProvider.notifier).state = updatedCur;
                                }
                              }
                              final refreshed = await ref.read(dataRepositoryProvider).getWorkAreas();
                              final created = refreshed.firstWhere(
                                (a) => a.workareaId == area.workareaId,
                                orElse: () => updatedArea,
                              );
                              if (_selectedArea?.workareaId == area.workareaId) {
                                setState(() {
                                  _selectedArea = created;
                                  _newPolygonPoints.clear();
                                });
                              }
                              ref.invalidate(workAreasProvider);
                              ref.invalidate(supervisorsProvider);
                              ref.invalidate(employeesProvider);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                ToastNotification.show(context, message: 'Work Area "${created.name}" updated successfully!', type: ToastType.success);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmUnassignSupervisor(WorkAreaModel area) {
    ConfirmationDialog.show(
      context,
      title: 'Unassign Supervisor',
      message: 'Are you sure you want to unassign ${area.supervisorName} from ${area.name}? The sector will remain unassigned until a new supervisor is designated.',
      confirmLabel: 'Unassign',
      confirmVariant: ButtonVariant.danger,
      onConfirm: () async {
        final updatedArea = area.copyWith(
          clearSupervisor: true,
          supervisorId: null,
          supervisorName: 'No supervisor',
        );
        await ref.read(dataRepositoryProvider).updateWorkArea(updatedArea);
        ref.invalidate(workAreasProvider);
        ref.invalidate(supervisorsProvider);
        ref.invalidate(employeesProvider);
        ref.invalidate(attendanceProvider);
        ref.invalidate(accomplishmentsProvider);
        ref.invalidate(leaveRequestsProvider);
        final curUser = ref.read(currentUserProvider);
        if (curUser.userId == area.supervisorId) {
          ref.read(currentUserProvider.notifier).state = curUser.copyWith(
            clearAssignedArea: true,
            assignedAreaId: null,
            assignedAreaName: 'Unassigned',
          );
        }
        if (_selectedArea?.workareaId == area.workareaId) {
          setState(() {
            _selectedArea = updatedArea;
          });
        }
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Supervisor unassigned from "${area.name}".',
            type: ToastType.info,
          );
        }
      },
    );
  }

  Future<void> _toggleAreaStatus(WorkAreaModel area) async {
    final nextStatus = area.status == 'Active' ? 'Inactive' : 'Active';
    final updated = area.copyWith(status: nextStatus);
    try {
      await ref.read(dataRepositoryProvider).updateWorkArea(updated);
      if (_selectedArea?.workareaId == area.workareaId) {
        setState(() => _selectedArea = updated);
      }
      ref.invalidate(workAreasProvider);
      ref.invalidate(supervisorsProvider);
      ref.invalidate(employeesProvider);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Work Area "${area.name}" is now $nextStatus.',
          type: nextStatus == 'Active' ? ToastType.success : ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(context, message: 'Failed to update status: $e', type: ToastType.error);
      }
    }
  }

  void _confirmDeleteArea(WorkAreaModel area) {
    final hasActiveWorkers = area.assignedCount > 0;

    ConfirmationDialog.show(
      context,
      title: 'Delete Work Area: ${area.name}',
      message: hasActiveWorkers
          ? 'WARNING: This work area currently has ${area.assignedCount} active worker(s) assigned. Deleting this area will permanently remove its geofence boundary and clear all worker assignments back to the unassigned workforce pool.\n\nAre you sure you want to proceed with deletion?'
          : 'Are you sure you want to permanently delete "${area.name}"? This will remove its geofence boundary and clear area assignments for workers.',
      confirmLabel: 'Confirm Delete Area',
      confirmVariant: ButtonVariant.danger,
      onConfirm: () async {
        await ref.read(dataRepositoryProvider).deleteWorkArea(area.workareaId);
        if (_selectedArea?.workareaId == area.workareaId) {
          setState(() => _selectedArea = null);
        }
        ref.invalidate(workAreasProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Work Area "${area.name}" deleted successfully.', type: ToastType.success);
        }
      },
    );
  }

  void _showMonthlyShuffleDialog() async {
    final repo = ref.read(dataRepositoryProvider);
    final activeAreas = (await repo.getWorkAreas()).where((a) => a.status == 'Active').toList();
    final allWorkers = await repo.getUsers(role: UserRole.worker);

    if (activeAreas.isEmpty) {
      if (mounted) {
        ToastNotification.show(context, message: 'No active work areas available for workforce rotation.', type: ToastType.warning);
      }
      return;
    }

    if (allWorkers.isEmpty) {
      if (mounted) {
        ToastNotification.show(context, message: 'No field workers available in system.', type: ToastType.warning);
      }
      return;
    }

    // Pre-calculate balanced rotation proposal (SRS UC-07 Alternative Flow 2: Bulk Assign)
    final Map<String, String> plannedAssignments = {};
    for (int i = 0; i < allWorkers.length; i++) {
      final targetArea = activeAreas[i % activeAreas.length];
      plannedAssignments[allWorkers[i].userId] = targetArea.workareaId;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 620,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.navActiveBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shuffle_rounded, color: AppColors.accentBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Workforce Shuffle',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Reassign Field Workers evenly across sectors with automated notifications.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successBg.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: AppColors.successText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Rotation Summary: ${allWorkers.length} workers will be balanced across ${activeAreas.length} active sectors (~${(allWorkers.length / activeAreas.length).ceil()} per zone).',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('PROPOSED SECTOR ASSIGNMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMuted)),
                  const SizedBox(height: 8),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allWorkers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderSubtle),
                      itemBuilder: (context, i) {
                        final w = allWorkers[i];
                        final targetAreaId = plannedAssignments[w.userId]!;
                        final targetArea = activeAreas.firstWhere((a) => a.workareaId == targetAreaId);
                        final isChanging = w.assignedAreaId != targetAreaId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isChanging ? AppColors.accentBlue : AppColors.neutralText,
                                child: Text(w.initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Text(w.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        w.assignedAreaName ?? 'Unassigned',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.accentBlue),
                                    ),
                                    Flexible(
                                      child: Text(
                                        targetArea.name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isChanging)
                                const StatusBadge(label: 'ROTATING', type: BadgeType.optimal)
                              else
                                const StatusBadge(label: 'RETAINED', type: BadgeType.neutral),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'In-app notices will be generated immediately for all affected workers.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        label: 'Cancel',
                        variant: ButtonVariant.outline,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'Confirm & Execute Shuffle',
                        icon: Icons.check_circle_outline,
                        variant: ButtonVariant.primary,
                        onPressed: () async {
                          await repo.bulkAssignWorkers(plannedAssignments);
                          ref.invalidate(workAreasProvider);
                          ref.invalidate(employeesProvider);
                          ref.invalidate(broadcastsProvider);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (mounted) {
                            ToastNotification.show(
                              context,
                              message: 'Monthly workforce shuffle executed! In-app notifications dispatched to all workers.',
                              type: ToastType.success,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final allEmployees = ref.watch(employeesProvider).value ?? [];
    final now = DateTime.now();
    final scheduleSheetsAsync = ref.watch(scheduleSheetsProvider(ScheduleSheetsQuery(month: now.month, year: now.year)));
    final allSheets = scheduleSheetsAsync.value ?? [];
    // Map worker userId to their designated monthly ScheduleEntryModel (which contains exact dayOff and timeSchedule)
    final Map<String, ScheduleEntryModel> workerRosterMap = {};
    for (final sheet in allSheets) {
      for (final entry in sheet.entries) {
        workerRosterMap[entry.userId] = entry;
      }
    }
    ref.watch(supervisorsProvider);
    final rawWorkAreas = workAreasAsync.value ?? [];
    final workAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) =>
            a.supervisorId == currentUser.userId ||
            (a.supervisorName.isNotEmpty && a.supervisorName.toLowerCase() == currentUser.fullName.toLowerCase()) ||
            a.workareaId == currentUser.assignedAreaId ||
            a.name == currentUser.assignedAreaName).toList()
        : rawWorkAreas;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 950;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Controls
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isHeaderStacked = headerConstraints.maxWidth < 750;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Areas & Geofences',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.role == UserRole.admin
                            ? 'Configure Ormoc City geofence boundaries and assigned supervisors.'
                            : 'Monitored sectors assigned to your supervisory oversight.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  );

                  final actionButtons = currentUser.role == UserRole.admin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppButton(
                              label: 'Shuffle Workers',
                              icon: Icons.shuffle,
                              variant: ButtonVariant.outline,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              onPressed: _showMonthlyShuffleDialog,
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: _isDrawing ? 'Cancel Drawing' : '+ Add Work Area',
                              icon: _isDrawing ? Icons.close : Icons.draw_outlined,
                              variant: _isDrawing ? ButtonVariant.outline : ButtonVariant.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              onPressed: () {
                                if (_isDrawing) {
                                  setState(() {
                                    _isDrawing = false;
                                    _newPolygonPoints.clear();
                                  });
                                } else {
                                  _startDrawingGeofence();
                                }
                              },
                            ),
                          ],
                        )
                      : const SizedBox.shrink();

                  if (isHeaderStacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        if (currentUser.role == UserRole.admin) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actionButtons,
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Content Area: Map on Left, Area Cards List on Right
              Expanded(
                child: Flex(
                  direction: isStacked ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive OpenStreetMap (Left Side)
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Stack(
                          children: [
                            MouseRegion(
                              cursor: _isDrawing ? SystemMouseCursors.precise : SystemMouseCursors.basic,
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: AppConstants.ormocCityCenter,
                                  initialZoom: 14.0,
                                  onTap: (tapPosition, point) {
                                    if (_isDrawing) {
                                      setState(() {
                                        _newPolygonPoints.add(point);
                                      });
                                    }
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.bantaygawa.web',
                                  ),
                                  PolygonLayer(
                                    polygons: [
                                      ...workAreas.map((area) {
                                        final isSelected = _selectedArea?.workareaId == area.workareaId;
                                        return Polygon(
                                          points: area.polygon,
                                          color: isSelected ? AppColors.accentBlue.withValues(alpha: 0.35) : AppColors.accentBlue.withValues(alpha: 0.15),
                                          borderColor: isSelected ? AppColors.primaryNavy : AppColors.accentBlue,
                                          borderStrokeWidth: isSelected ? 3.5 : 2.0,
                                        );
                                      }),
                                      if (_newPolygonPoints.length >= 3)
                                        Polygon(
                                          points: _newPolygonPoints,
                                          color: Colors.green.withValues(alpha: 0.28),
                                          borderColor: Colors.green.shade700,
                                          borderStrokeWidth: 2.5,
                                        ),
                                    ],
                                  ),
                                  if (_newPolygonPoints.length >= 2)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [
                                            ..._newPolygonPoints,
                                            if (_newPolygonPoints.length >= 3) _newPolygonPoints.first,
                                          ],
                                          color: Colors.green.shade800,
                                          strokeWidth: 2.5,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      ...workAreas.map((area) {
                                        return Marker(
                                          point: area.center,
                                          width: 130,
                                          height: 32,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryNavy,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Center(
                                              child: Text(
                                                area.name,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (_isDrawing && _newPolygonPoints.isNotEmpty)
                                        ..._newPolygonPoints.asMap().entries.map((entry) {
                                          final idx = entry.key + 1;
                                          final pt = entry.value;
                                          return Marker(
                                            point: pt,
                                            width: 24,
                                            height: 24,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade700,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$idx',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Floating Drawing Instruction / Action Bar (Spanning across top of map)
                            if (_isDrawing)
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _newPolygonPoints.length >= 3 ? AppColors.accentEmerald : AppColors.accentBlue,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: (_newPolygonPoints.length >= 3 ? AppColors.accentEmerald : AppColors.accentBlue).withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _newPolygonPoints.length >= 3 ? Icons.check_circle : Icons.draw_outlined,
                                              size: 20,
                                              color: _newPolygonPoints.length >= 3 ? AppColors.accentEmerald : AppColors.accentBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _newPolygonPoints.length >= 3
                                                    ? 'Geofence Perimeter Ready (${_newPolygonPoints.length} vertices)'
                                                    : 'Drawing Geofence (${_newPolygonPoints.length}/3 min points)',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                              ),
                                              Text(
                                                _newPolygonPoints.isEmpty
                                                    ? 'Click anywhere on the map to place vertex #1.'
                                                    : _newPolygonPoints.length < 3
                                                        ? 'Click on map to place vertex #${_newPolygonPoints.length + 1} (Need at least 3 points).'
                                                        : 'Perimeter closed! Add more points or click "Save Work Area".',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_newPolygonPoints.isNotEmpty) ...[
                                            TextButton.icon(
                                              icon: const Icon(Icons.undo, size: 14),
                                              label: const Text('Undo', style: TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppColors.textSecondary,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _newPolygonPoints.removeLast();
                                                });
                                              },
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                                              label: const Text('Clear', style: TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppColors.brightRed,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _newPolygonPoints.clear();
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.textMuted,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isDrawing = false;
                                                _newPolygonPoints.clear();
                                              });
                                            },
                                            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.save_outlined, size: 15),
                                            label: const Text('Save Work Area', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _newPolygonPoints.length >= 3 ? AppColors.accentEmerald : AppColors.border,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onPressed: _newPolygonPoints.length >= 3
                                                ? () => _showAddAreaDialog()
                                                : () {
                                                    ToastNotification.show(
                                                      context,
                                                      message: 'Please click at least 3 points on the map to define the perimeter before saving.',
                                                      type: ToastType.warning,
                                                    );
                                                  },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (!isStacked) const SizedBox(width: 20),
                    if (isStacked) const SizedBox(height: 20),

                    // Area Cards List (Right Side)
                    SizedBox(
                      width: isStacked ? double.infinity : 360,
                      height: isStacked ? 260 : double.infinity,
                      child: ListView.separated(
                        itemCount: workAreas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final area = workAreas[index];
                          final isSelected = _selectedArea?.workareaId == area.workareaId;
                          final isExpanded = _expandedWorkerAreaId == area.workareaId;
                          final assignedWorkers = allEmployees.where((e) =>
                              e.role == UserRole.worker &&
                              (e.assignedAreaId == area.workareaId ||
                               (e.assignedAreaName != null && e.assignedAreaName == area.name))).toList();

                          return AppCard(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: isSelected ? const Color(0xFFF0F7FF) : AppColors.surface,
                            border: isSelected ? Border.all(color: AppColors.accentBlue, width: 2) : Border.all(color: AppColors.border),
                            onTap: () {
                              setState(() {
                                _selectedArea = area;
                                // If clicking a different card, close any other card's dropdown
                                if (_expandedWorkerAreaId != area.workareaId) {
                                  _expandedWorkerAreaId = null;
                                }
                              });
                              _mapController.move(area.center, 17.0);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            size: 16,
                                            color: isSelected ? AppColors.accentBlue : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              area.name,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: currentUser.role == UserRole.admin
                                          ? 'Click to toggle status'
                                          : '',
                                      child: InkWell(
                                        onTap: currentUser.role == UserRole.admin
                                            ? () => _toggleAreaStatus(area)
                                            : null,
                                        borderRadius: BorderRadius.circular(20),
                                        child: StatusBadge(
                                          label: area.status,
                                          type: area.status == 'Active' ? BadgeType.optimal : BadgeType.neutral,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 14,
                                      color: (area.supervisorId != null && area.supervisorId!.isNotEmpty)
                                          ? AppColors.accentBlue
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        (area.supervisorId != null && area.supervisorName.isNotEmpty && area.supervisorName != 'No supervisor' && area.supervisorName != 'Field Supervisor' && area.supervisorName != 'Unassigned')
                                            ? area.supervisorName
                                            : 'No supervisor assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: (area.supervisorId != null && area.supervisorId!.isNotEmpty)
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: (area.supervisorId != null && area.supervisorId!.isNotEmpty)
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (currentUser.role == UserRole.admin &&
                                        area.supervisorId != null &&
                                        area.supervisorId!.isNotEmpty &&
                                        area.supervisorName != 'No supervisor' &&
                                        area.supervisorName != 'Unassigned') ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: 'Unassign Supervisor from this sector',
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(4),
                                          onTap: () => _confirmUnassignSupervisor(area),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.dangerBg,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.brightRed.withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person_remove_outlined, size: 12, color: AppColors.brightRed),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Unassign',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brightRed),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.groups_outlined, size: 13, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${area.assignedCount} Workers',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (area.description != null && area.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(area.description!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],

                                // Collapsible Assigned Workers Dropdown
                                if (isExpanded) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'ASSIGNED WORKERS (${assignedWorkers.length})',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5),
                                            ),
                                            InkWell(
                                              onTap: () => setState(() => _expandedWorkerAreaId = null),
                                              child: const Icon(Icons.keyboard_arrow_up, size: 16, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (assignedWorkers.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Text('No workers assigned to this area yet.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                                          )
                                        else
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 44, // Minimum height for 1 worker list row
                                              maxHeight: 220, // Max height for ~5 workers before smooth scrolling
                                            ),
                                            child: Scrollbar(
                                              thumbVisibility: assignedWorkers.length > 5,
                                              child: ListView.separated(
                                                shrinkWrap: true,
                                                padding: EdgeInsets.zero,
                                                itemCount: assignedWorkers.length,
                                                separatorBuilder: (_, _) => const Divider(height: 10, color: AppColors.borderSubtle),
                                                itemBuilder: (context, wIdx) {
                                                  final w = assignedWorkers[wIdx];
                                                  return Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor: AppColors.accentBlue,
                                                        child: Text(w.initials, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          w.fullName,
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _buildWorkerScheduleView(w.schedule, entry: workerRosterMap[w.userId]),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 10),
                                const Divider(height: 1, color: AppColors.border),
                                const SizedBox(height: 8),
                                if (currentUser.role == UserRole.admin)
                                  // Sleek, borderless 2x2 action buttons matching card background with light hover dimming
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton.icon(
                                              icon: Icon(
                                                isExpanded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                size: 13,
                                                color: AppColors.accentBlue,
                                              ),
                                              label: Text(
                                                isExpanded ? 'Hide' : 'View',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ButtonStyle(
                                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: WidgetStateProperty.all(Size.zero),
                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.hovered)) {
                                                    return Colors.black.withValues(alpha: 0.05);
                                                  }
                                                  return isExpanded ? const Color(0xFFEBF5FF) : Colors.transparent;
                                                }),
                                                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                              ),
                                              onPressed: () => _focusArea(area),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextButton.icon(
                                              icon: const Icon(Icons.person_add_alt_1_outlined, size: 13, color: AppColors.accentEmerald),
                                              label: const Text(
                                                '+ Add Worker',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentEmerald),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ButtonStyle(
                                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: WidgetStateProperty.all(Size.zero),
                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.hovered)) {
                                                    return Colors.black.withValues(alpha: 0.05);
                                                  }
                                                  return Colors.transparent;
                                                }),
                                                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                              ),
                                              onPressed: () => _showManageWorkersDialog(area),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton.icon(
                                              icon: const Icon(Icons.edit_outlined, size: 13, color: AppColors.accentBlue),
                                              label: const Text(
                                                'Edit',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ButtonStyle(
                                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: WidgetStateProperty.all(Size.zero),
                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.hovered)) {
                                                    return Colors.black.withValues(alpha: 0.05);
                                                  }
                                                  return Colors.transparent;
                                                }),
                                                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                              ),
                                              onPressed: () => _showEditAreaDialog(area),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextButton.icon(
                                              icon: const Icon(Icons.delete_outline, size: 13, color: AppColors.brightRed),
                                              label: const Text(
                                                'Remove',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.brightRed),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ButtonStyle(
                                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: WidgetStateProperty.all(Size.zero),
                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.hovered)) {
                                                    return Colors.black.withValues(alpha: 0.05);
                                                  }
                                                  return Colors.transparent;
                                                }),
                                                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                              ),
                                              onPressed: () => _confirmDeleteArea(area),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else if (currentUser.role == UserRole.supervisor)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          icon: Icon(
                                            isExpanded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 13,
                                            color: AppColors.accentBlue,
                                          ),
                                          label: Text(
                                            isExpanded ? 'Hide' : 'View',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                          ),
                                          style: ButtonStyle(
                                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                            visualDensity: VisualDensity.compact,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            minimumSize: WidgetStateProperty.all(Size.zero),
                                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                                              if (states.contains(WidgetState.hovered)) {
                                                return Colors.black.withValues(alpha: 0.05);
                                              }
                                              return isExpanded ? const Color(0xFFEBF5FF) : Colors.transparent;
                                            }),
                                            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                          ),
                                          onPressed: () => _focusArea(area),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.groups_outlined, size: 13, color: AppColors.accentBlue),
                                          label: const Text(
                                            'Assigned Workers',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                                          ),
                                          style: ButtonStyle(
                                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                                            visualDensity: VisualDensity.compact,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            minimumSize: WidgetStateProperty.all(Size.zero),
                                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                                              if (states.contains(WidgetState.hovered)) {
                                                return Colors.black.withValues(alpha: 0.05);
                                              }
                                              return Colors.transparent;
                                            }),
                                            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                                          ),
                                          onPressed: () => _showManageWorkersDialog(area),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

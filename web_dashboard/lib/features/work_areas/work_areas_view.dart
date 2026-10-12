import 'dart:math' as math;
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
import '../../data/repositories/repository_provider.dart';
import 'widgets/area_workers_dialog.dart';

class WorkAreasView extends ConsumerStatefulWidget {
  const WorkAreasView({super.key});

  @override
  ConsumerState<WorkAreasView> createState() => _WorkAreasViewState();
}

class _WorkAreasViewState extends ConsumerState<WorkAreasView> {
  final MapController _mapController = MapController();
  WorkAreaModel? _selectedArea;
  bool _isDrawing = false;
  final List<LatLng> _newPolygonPoints = [];

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

  double _calculateAreaSqKm(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    const double latKm = 110.574;
    final double lonKm = 111.320 * math.cos(11.005 * math.pi / 180);
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final xi = points[i].longitude * lonKm;
      final yi = points[i].latitude * latKm;
      final xj = points[j].longitude * lonKm;
      final yj = points[j].latitude * latKm;
      area += (xi * yj) - (xj * yi);
    }
    return area.abs() / 2.0;
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

  void _showAddAreaDialog() {
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
    final allEmployees = ref.read(employeesProvider).value ?? [];
    final supervisors = allEmployees.where((u) => u.role == UserRole.supervisor).toList();
    String supervisorId = supervisors.isNotEmpty ? supervisors.first.userId : 'user-sup-1';
    String supervisorName = supervisors.isNotEmpty ? supervisors.first.fullName : 'Juan Santos';
    final areaSqKm = _calculateAreaSqKm(_newPolygonPoints);

    ConfirmationDialog.show(
      context,
      title: 'Save New Work Area (UC-02)',
      message: 'Review boundary parameters and assign an active field supervisor.',
      confirmLabel: 'Save Work Area',
      contentWidget: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 20, color: AppColors.successText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Drawn Geofence: ${_newPolygonPoints.length} GPS Coordinates',
                              style: const TextStyle(fontSize: 12, color: AppColors.successText, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Calculated Boundary Area: ${areaSqKm.toStringAsFixed(2)} km²',
                              style: const TextStyle(fontSize: 11, color: AppColors.successText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Area Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: nameController, decoration: const InputDecoration(hintText: 'e.g. Ormoc Coastal Pier')),
                const SizedBox(height: 12),
                const Text('Assigned Field Supervisor (Dynamic)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: supervisors.any((s) => s.userId == supervisorId) ? supervisorId : (supervisors.isNotEmpty ? supervisors.first.userId : supervisorId),
                  items: [
                    if (supervisors.isEmpty)
                      DropdownMenuItem(value: supervisorId, child: Text(supervisorName))
                    else
                      ...supervisors.map((s) => DropdownMenuItem(
                            value: s.userId,
                            child: Text('${s.fullName} (${s.assignedAreaName ?? 'General'})'),
                          )),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        supervisorId = val;
                        final matched = supervisors.where((s) => s.userId == val);
                        supervisorName = matched.isNotEmpty ? matched.first.fullName : supervisorName;
                      });
                    }
                  },
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                const Text('Description / Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(hintText: 'Work sector notes...')),
              ],
            ),
          );
        },
      ),
      onConfirm: () async {
        if (nameController.text.trim().isEmpty) {
          ToastNotification.show(context, message: 'Please provide an area name.', type: ToastType.warning);
          return;
        }
        if (_newPolygonPoints.length < 3) {
          ToastNotification.show(context, message: 'You must draw at least 3 points to save a geofence.', type: ToastType.error);
          return;
        }
        final newArea = WorkAreaModel(
          workareaId: 'area-${DateTime.now().millisecondsSinceEpoch}',
          name: nameController.text.trim(),
          description: descController.text.trim(),
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          assignedCount: 0,
          status: 'Active',
          areaSqKm: '${areaSqKm.toStringAsFixed(2)} km²',
          polygon: List.from(_newPolygonPoints),
        );
        await ref.read(dataRepositoryProvider).addWorkArea(newArea);
        setState(() {
          _isDrawing = false;
          _newPolygonPoints.clear();
          _selectedArea = newArea;
        });
        _mapController.move(newArea.center, 15.0);
        ref.invalidate(workAreasProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Work Area "${newArea.name}" created with custom drawn geofence!', type: ToastType.success);
        }
      },
    );
  }

  void _showEditAreaDialog(WorkAreaModel area) {
    final nameController = TextEditingController(text: area.name);
    final descController = TextEditingController(text: area.description ?? '');
    final allEmployees = ref.read(employeesProvider).value ?? [];
    final supervisors = allEmployees.where((u) => u.role == UserRole.supervisor).toList();
    String supervisorId = area.supervisorId ?? (supervisors.isNotEmpty ? supervisors.first.userId : 'user-sup-1');
    String supervisorName = area.supervisorName;
    String status = area.status;

    ConfirmationDialog.show(
      context,
      title: 'Edit Work Area: ${area.name}',
      message: 'Modify work zone parameters, supervisor assignment, and operational status.',
      confirmLabel: 'Save Changes',
      contentWidget: StatefulBuilder(
        builder: (context, setDialogState) {
          final hasDrawnPolygon = _newPolygonPoints.length >= 3;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Area Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: nameController, decoration: const InputDecoration(hintText: 'e.g. Ormoc Coastal Pier')),
                const SizedBox(height: 12),
                const Text('Assigned Supervisor (Dynamic)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: supervisors.any((s) => s.userId == supervisorId) ? supervisorId : (supervisors.isNotEmpty ? supervisors.first.userId : supervisorId),
                  items: [
                    if (supervisors.isEmpty)
                      DropdownMenuItem(value: supervisorId, child: Text(supervisorName))
                    else
                      ...supervisors.map((s) => DropdownMenuItem(
                            value: s.userId,
                            child: Text('${s.fullName} (${s.assignedAreaName ?? 'General'})'),
                          )),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        supervisorId = val;
                        final matched = supervisors.where((s) => s.userId == val);
                        supervisorName = matched.isNotEmpty ? matched.first.fullName : supervisorName;
                      });
                    }
                  },
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active (Monitored)')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive (Suspended)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => status = val);
                    }
                  },
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(hintText: 'Work sector notes...')),
                if (hasDrawnPolygon) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.successText),
                        const SizedBox(width: 6),
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
              ],
            ),
          );
        },
      ),
      onConfirm: () async {
        if (nameController.text.trim().isEmpty) return;
        final updatedArea = area.copyWith(
          name: nameController.text.trim(),
          description: descController.text.trim(),
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          status: status,
          polygon: (_newPolygonPoints.length >= 3) ? List.from(_newPolygonPoints) : area.polygon,
        );
        await ref.read(dataRepositoryProvider).updateWorkArea(updatedArea);
        if (_selectedArea?.workareaId == area.workareaId) {
          setState(() {
            _selectedArea = updatedArea;
            _newPolygonPoints.clear();
          });
        }
        ref.invalidate(workAreasProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Work Area "${updatedArea.name}" updated successfully!', type: ToastType.success);
        }
      },
    );
  }

  void _confirmDeleteArea(WorkAreaModel area) {
    final hasActiveWorkers = area.assignedCount > 0;

    ConfirmationDialog.show(
      context,
      title: 'Delete Work Area: ${area.name}',
      message: hasActiveWorkers
          ? 'WARNING (UC-02): This work area currently has ${area.assignedCount} active worker(s) assigned. Deleting this area will permanently remove its geofence boundary and clear all worker assignments back to the unassigned workforce pool.\n\nAre you sure you want to proceed with deletion?'
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final workAreas = workAreasAsync.value ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 950;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Controls
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
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
                  ),
                  if (currentUser.role == UserRole.admin)
                    AppButton(
                      label: _isDrawing ? 'Cancel Drawing' : '+ Add Work Area',
                      icon: _isDrawing ? Icons.close : Icons.draw_outlined,
                      variant: _isDrawing ? ButtonVariant.outline : ButtonVariant.primary,
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
              ),
              const SizedBox(height: 20),

              // Content Area: Map and Area List
              Expanded(
                child: Flex(
                  direction: isStacked ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Area Cards List
                    SizedBox(
                      width: isStacked ? double.infinity : 360,
                      height: isStacked ? 260 : double.infinity,
                      child: ListView.separated(
                        itemCount: workAreas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final area = workAreas[index];
                          final isSelected = _selectedArea?.workareaId == area.workareaId;

                          return AppCard(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: isSelected ? AppColors.navActiveBackground : AppColors.surface,
                            border: isSelected ? Border.all(color: AppColors.accentBlue, width: 2) : null,
                            onTap: () {
                              setState(() => _selectedArea = area);
                              _mapController.move(area.center, 15.0);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        area.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    StatusBadge(
                                      label: area.status,
                                      type: area.status == 'Active' ? BadgeType.optimal : BadgeType.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Sup: ${area.supervisorName}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.groups_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text('${area.assignedCount} Workers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  ],
                                ),
                                if (area.description != null) ...[
                                  const SizedBox(height: 6),
                                  Text(area.description!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                                if (currentUser.role == UserRole.admin) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: AppColors.border),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
                                        label: const Text('+ Add Worker', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.accentEmerald,
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showManageWorkersDialog(area),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit_outlined, size: 14),
                                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.accentBlue,
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showEditAreaDialog(area),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 14),
                                        label: const Text('Remove', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.brightRed,
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _confirmDeleteArea(area),
                                      ),
                                    ],
                                  ),
                                ],
                                if (currentUser.role == UserRole.supervisor) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: AppColors.border),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.groups_outlined, size: 14),
                                        label: const Text('View Workers', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.accentBlue,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showManageWorkersDialog(area),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    if (!isStacked) const SizedBox(width: 20),
                    if (isStacked) const SizedBox(height: 20),

                    // Interactive OpenStreetMap
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

                            // Floating Drawing Instruction / Action Bar
                            if (_isDrawing)
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 80,
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

                            // Map Overlay Controls
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                ),
                                child: Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.my_location, size: 20),
                                      tooltip: 'Center Ormoc City',
                                      onPressed: () => _mapController.move(AppConstants.ormocCityCenter, 14.0),
                                    ),
                                    const Divider(height: 8),
                                    IconButton(
                                      icon: Icon(
                                        _isDrawing ? Icons.check : Icons.polyline_outlined,
                                        color: _isDrawing ? Colors.green : AppColors.textPrimary,
                                        size: 20,
                                      ),
                                      tooltip: _isDrawing ? 'Finish & Save Geofence' : 'Draw geofence polygon',
                                      onPressed: () {
                                        if (_isDrawing) {
                                          if (_newPolygonPoints.length >= 3) {
                                            _showAddAreaDialog();
                                          } else {
                                            ToastNotification.show(
                                              context,
                                              message: 'Please click at least 3 points on the map before saving.',
                                              type: ToastType.warning,
                                            );
                                          }
                                        } else {
                                          _startDrawingGeofence();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

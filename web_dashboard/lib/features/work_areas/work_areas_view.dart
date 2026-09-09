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

  void _showAddAreaDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String supervisorName = 'Juan Santos';
    String supervisorId = 'user-sup-1';

    ConfirmationDialog.show(
      context,
      title: 'Add New Work Area',
      message: 'Define a new work zone and assign a field supervisor.',
      confirmLabel: 'Save Work Area',
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Area Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: nameController, decoration: const InputDecoration(hintText: 'e.g. Ormoc Coastal Pier')),
          const SizedBox(height: 12),
          const Text('Supervisor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: supervisorId,
            items: const [
              DropdownMenuItem(value: 'user-sup-1', child: Text('Juan Santos (District 1)')),
              DropdownMenuItem(value: 'user-sup-2', child: Text('Maria Clara (District 2)')),
            ],
            onChanged: (val) {
              if (val != null) {
                supervisorId = val;
                supervisorName = val == 'user-sup-1' ? 'Juan Santos' : 'Maria Clara';
              }
            },
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 12),
          const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(hintText: 'Work sector notes...')),
        ],
      ),
      onConfirm: () async {
        if (nameController.text.trim().isEmpty) return;
        final newArea = WorkAreaModel(
          workareaId: 'area-${DateTime.now().millisecondsSinceEpoch}',
          name: nameController.text.trim(),
          description: descController.text.trim(),
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          assignedCount: 0,
          status: 'Active',
          areaSqKm: '1.1 km²',
          polygon: [
            LatLng(11.0040 + (_selectedArea?.polygon.length ?? 0) * 0.001, 124.6050),
            LatLng(11.0060, 124.6060),
            LatLng(11.0050, 124.6080),
            LatLng(11.0030, 124.6070),
          ],
        );
        await ref.read(dataRepositoryProvider).addWorkArea(newArea);
        ref.invalidate(workAreasProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Work Area "${newArea.name}" successfully created!', type: ToastType.success);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      label: '+ Add Work Area',
                      icon: Icons.add_location_alt_outlined,
                      onPressed: _showAddAreaDialog,
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
                                    Text('Sup: ${area.supervisorName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const Spacer(),
                                    const Icon(Icons.groups_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text('${area.assignedCount} Workers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  ],
                                ),
                                if (area.description != null) ...[
                                  const SizedBox(height: 6),
                                  Text(area.description!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                            FlutterMap(
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
                                        color: Colors.green.withValues(alpha: 0.3),
                                        borderColor: Colors.green,
                                        borderStrokeWidth: 2.0,
                                      ),
                                  ],
                                ),
                                MarkerLayer(
                                  markers: workAreas.map((area) {
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
                                  }).toList(),
                                ),
                              ],
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
                                      tooltip: _isDrawing ? 'Done drawing boundary' : 'Draw geofence polygon',
                                      onPressed: () {
                                        setState(() {
                                          _isDrawing = !_isDrawing;
                                          if (!_isDrawing && _newPolygonPoints.isNotEmpty) {
                                            ToastNotification.show(context, message: 'Captured ${_newPolygonPoints.length} geofence points.', type: ToastType.info);
                                          }
                                        });
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

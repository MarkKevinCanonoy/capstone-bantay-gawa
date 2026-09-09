import 'package:latlong2/latlong.dart';

class WorkAreaModel {
  final String workareaId;
  final String name;
  final String? description;
  final String? supervisorId;
  final String supervisorName;
  final List<LatLng> polygon;
  final int assignedCount;
  final String status; // 'Active', 'Inactive'
  final String areaSqKm;

  WorkAreaModel({
    required this.workareaId,
    required this.name,
    this.description,
    this.supervisorId,
    required this.supervisorName,
    required this.polygon,
    this.assignedCount = 0,
    this.status = 'Active',
    this.areaSqKm = '1.2 km²',
  });

  LatLng get center {
    if (polygon.isEmpty) return const LatLng(11.0050, 124.6075);
    double latSum = 0;
    double lngSum = 0;
    for (var p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }

  WorkAreaModel copyWith({
    String? workareaId,
    String? name,
    String? description,
    String? supervisorId,
    String? supervisorName,
    List<LatLng>? polygon,
    int? assignedCount,
    String? status,
    String? areaSqKm,
  }) {
    return WorkAreaModel(
      workareaId: workareaId ?? this.workareaId,
      name: name ?? this.name,
      description: description ?? this.description,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      polygon: polygon ?? this.polygon,
      assignedCount: assignedCount ?? this.assignedCount,
      status: status ?? this.status,
      areaSqKm: areaSqKm ?? this.areaSqKm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workarea_id': workareaId,
      'name': name,
      'description': description,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'assigned_count': assignedCount,
      'status': status,
      'area_sq_km': areaSqKm,
    };
  }
}

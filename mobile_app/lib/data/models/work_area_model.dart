import 'package:latlong2/latlong.dart';

class WorkAreaModel {
  final String workareaId;
  final String name;
  final String? description;
  final String? supervisorId;
  final String supervisorName;
  final List<LatLng> polygonCoordinates;
  final int assignedCount;
  final String status;
  final String areaSqKm;

  WorkAreaModel({
    required this.workareaId,
    required this.name,
    this.description,
    this.supervisorId,
    this.supervisorName = 'Field Supervisor',
    required this.polygonCoordinates,
    this.assignedCount = 0,
    this.status = 'Active',
    this.areaSqKm = '1.2 km²',
  });

  List<LatLng> get polygon => polygonCoordinates;

  LatLng get center {
    if (polygonCoordinates.isEmpty) return const LatLng(11.0050, 124.6075);
    double latSum = 0;
    double lngSum = 0;
    for (var p in polygonCoordinates) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygonCoordinates.length, lngSum / polygonCoordinates.length);
  }

  factory WorkAreaModel.fromMap(Map<String, dynamic> map) {
    List<LatLng> coords = [];
    final polyStr = map['polygon_coordinates'] as String?;
    if (polyStr != null && polyStr.isNotEmpty) {
      final pairs = polyStr.split(';');
      for (final pair in pairs) {
        final parts = pair.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            coords.add(LatLng(lat, lng));
          }
        }
      }
    }

    if (coords.isEmpty) {
      // Default Sector 4 polygon in Ormoc City
      coords = const [
        LatLng(11.0080, 124.6040),
        LatLng(11.0080, 124.6110),
        LatLng(11.0020, 124.6110),
        LatLng(11.0020, 124.6040),
      ];
    }

    return WorkAreaModel(
      workareaId: map['workarea_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Sector 4 - Downtown Zone',
      description: map['description'] as String?,
      supervisorId: map['supervisor_id'] as String?,
      supervisorName: map['supervisor_name'] as String? ?? 'Engr. Roberto Gomez',
      polygonCoordinates: coords,
      assignedCount: (map['assigned_count'] as num?)?.toInt() ?? 12,
      status: map['status'] as String? ?? 'Active',
      areaSqKm: map['area_sq_km'] as String? ?? '1.2 km²',
    );
  }
}

import 'dart:math' as math;
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
  final String? _explicitArea;

  WorkAreaModel({
    required this.workareaId,
    required this.name,
    this.description,
    this.supervisorId,
    required this.supervisorName,
    required this.polygon,
    this.assignedCount = 0,
    this.status = 'Active',
    String? areaSqKm,
  }) : _explicitArea = (areaSqKm != null && areaSqKm.trim().isNotEmpty && areaSqKm != '1.2 km²') ? areaSqKm : null;

  String get areaSqKm => _explicitArea ?? '';

  /// Computes geodesic planar area in square meters using projected Shoelace formula.
  static double computeAreaSquareMeters(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    double latSum = 0;
    for (final p in points) {
      latSum += p.latitude;
    }
    final meanLatRad = (latSum / points.length) * (math.pi / 180.0);
    const double metersPerDegreeLat = 110574.0;
    final double metersPerDegreeLng = 111320.0 * math.cos(meanLatRad);

    final originLat = points.first.latitude;
    final originLng = points.first.longitude;

    double area = 0.0;
    final n = points.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = (points[i].longitude - originLng) * metersPerDegreeLng;
      final yi = (points[i].latitude - originLat) * metersPerDegreeLat;
      final xj = (points[j].longitude - originLng) * metersPerDegreeLng;
      final yj = (points[j].latitude - originLat) * metersPerDegreeLat;
      area += (xi * yj) - (xj * yi);
    }
    return area.abs() / 2.0;
  }

  /// Adaptive human-readable area formatting (m², ha, km²)
  static String formatPolygonArea(List<LatLng> points) {
    final sqM = computeAreaSquareMeters(points);
    if (sqM <= 0) return '—';
    if (sqM < 10000) {
      if (sqM < 100) return '${sqM.toStringAsFixed(1)} m²';
      return '${sqM.round()} m²';
    } else if (sqM < 1000000) {
      final ha = sqM / 10000.0;
      return '${ha.toStringAsFixed(2)} ha';
    } else {
      final sqKm = sqM / 1000000.0;
      return '${sqKm.toStringAsFixed(2)} km²';
    }
  }

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
      areaSqKm: areaSqKm ?? _explicitArea,
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

  factory WorkAreaModel.fromJson(Map<String, dynamic> json) {
    List<LatLng> coords = [];
    final geom = json['geometry'];
    if (geom is Map<String, dynamic>) {
      final coordinates = geom['coordinates'];
      if (coordinates is List && coordinates.isNotEmpty) {
        final ring = coordinates[0];
        if (ring is List) {
          for (final pt in ring) {
            if (pt is List && pt.length >= 2) {
              final lng = (pt[0] as num).toDouble();
              final lat = (pt[1] as num).toDouble();
              coords.add(LatLng(lat, lng));
            }
          }
        }
      }
    } else if (json['polygon'] is List) {
      coords = (json['polygon'] as List).map((p) {
        if (p is LatLng) return p;
        if (p is Map) return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
        return const LatLng(11.0050, 124.6075);
      }).toList();
    }

    final supId = json['supervisor_id']?.toString();
    String supName = json['supervisor_name']?.toString() ?? '';
    if (supName.isEmpty && json['users'] != null) {
      final u = json['users'];
      if (u is Map) {
        supName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      }
    }
    if (supId == null || supId.isEmpty || supName.isEmpty || supName == 'Field Supervisor' || supName == 'Unassigned') {
      supName = (supId != null && supId.isNotEmpty && supName.isNotEmpty && supName != 'Field Supervisor' && supName != 'Unassigned')
          ? supName
          : 'No supervisor';
    }

    String status = json['status']?.toString() ?? 'Active';
    String? desc = json['description']?.toString();
    if (desc != null && desc.contains('[STATUS:Inactive]')) {
      status = 'Inactive';
      desc = desc.replaceAll('[STATUS:Inactive]', '').trim();
      if (desc.isEmpty) desc = null;
    } else if (desc != null && desc.contains('[STATUS:Active]')) {
      status = 'Active';
      desc = desc.replaceAll('[STATUS:Active]', '').trim();
      if (desc.isEmpty) desc = null;
    }

    return WorkAreaModel(
      workareaId: json['workarea_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: desc,
      supervisorId: supId,
      supervisorName: supName,
      polygon: coords,
      assignedCount: (json['assigned_count'] as num?)?.toInt() ?? 0,
      status: status,
      areaSqKm: json['area_sq_km']?.toString(),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    final ring = polygon.map((p) => [p.longitude, p.latitude]).toList();
    if (ring.isNotEmpty && (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(ring.first);
    }
    var cleanDesc = description;
    if (cleanDesc != null) {
      cleanDesc = cleanDesc.replaceAll(RegExp(r'\[STATUS:(Active|Inactive)\]'), '').trim();
      if (cleanDesc.isEmpty) cleanDesc = null;
    }
    return {
      'workarea_id': workareaId,
      'name': name,
      if (cleanDesc != null) 'description': cleanDesc,
      'supervisor_id': (supervisorId != null && supervisorId!.isNotEmpty) ? supervisorId : null,
      if (ring.isNotEmpty)
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
    };
  }
}

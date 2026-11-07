import 'dart:math' as math;
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
  final String? _explicitArea;

  WorkAreaModel({
    required this.workareaId,
    required this.name,
    this.description,
    this.supervisorId,
    this.supervisorName = 'Field Supervisor',
    required this.polygonCoordinates,
    this.assignedCount = 0,
    this.status = 'Active',
    String? areaSqKm,
  }) : _explicitArea = (areaSqKm != null && areaSqKm.trim().isNotEmpty && areaSqKm != '1.2 km²') ? areaSqKm : null;

  List<LatLng> get polygon => polygonCoordinates;

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

    // 1. PostGIS GeoJSON geometry
    final geom = map['geometry'];
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
    }

    // 2. Semicolon-delimited coordinates (SQLite local cache format)
    if (coords.isEmpty) {
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
    }

    if (coords.isEmpty) {
      coords = const [
        LatLng(11.0080, 124.6040),
        LatLng(11.0080, 124.6110),
        LatLng(11.0020, 124.6110),
        LatLng(11.0020, 124.6040),
      ];
    }

    String supName = map['supervisor_name'] as String? ?? '';
    if (supName.isEmpty && map['users'] != null) {
      final u = map['users'];
      if (u is Map) {
        supName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      }
    }
    if (supName.isEmpty) supName = 'Field Supervisor';

    return WorkAreaModel(
      workareaId: map['workarea_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Ormoc Work Area',
      description: map['description'] as String?,
      supervisorId: map['supervisor_id'] as String?,
      supervisorName: supName,
      polygonCoordinates: coords,
      assignedCount: (map['assigned_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'Active',
      areaSqKm: map['area_sq_km'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workarea_id': workareaId,
      'name': name,
      'description': description,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'polygon_coordinates': polygonCoordinates.map((p) => '${p.latitude},${p.longitude}').join(';'),
      'assigned_count': assignedCount,
      'status': status,
      'area_sq_km': areaSqKm,
    };
  }
}

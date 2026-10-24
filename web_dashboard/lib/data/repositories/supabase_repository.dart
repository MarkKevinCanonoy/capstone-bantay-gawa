import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';
import 'data_repository.dart';

class SupabaseRepository implements DataRepository {
  SupabaseClient get _client => Supabase.instance.client;

  bool _isValidUuid(String? id) {
    if (id == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  }

  // Helper to parse WKT POLYGON((lng lat, lng lat, ...)) or GeoJSON
  List<LatLng> _parseWktPolygon(dynamic geom) {
    if (geom == null) return const [];
    try {
      if (geom is Map && geom['coordinates'] is List) {
        final coords = (geom['coordinates'] as List).first as List;
        return coords.map((c) {
          final list = c as List;
          return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
        }).toList();
      }
      final str = geom.toString();
      if (!str.contains('POLYGON')) return const [];
      final coordsStr = str.replaceAll(RegExp(r'[A-Za-z()]+'), '').trim();
      final pairs = coordsStr.split(',');
      final List<LatLng> result = [];
      for (var pair in pairs) {
        final parts = pair.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final lng = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            result.add(LatLng(lat, lng));
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error parsing geometry: $e');
      return const [];
    }
  }

  // ==========================================
  // Work Areas
  // ==========================================
  @override
  Future<List<WorkAreaModel>> getWorkAreas({String? supervisorId}) async {
    try {
      dynamic response;
      try {
        var query = _client.from('work_areas').select('*, users!work_areas_supervisor_id_fkey(first_name, last_name), work_area_assignments(assignment_id, is_active)');
        if (supervisorId != null && supervisorId.isNotEmpty && _isValidUuid(supervisorId)) {
          query = query.eq('supervisor_id', supervisorId);
        }
        response = await query.order('name');
      } catch (joinErr) {
        debugPrint('Note: Embedded supervisor join skipped, fetching simple: $joinErr');
        var query = _client.from('work_areas').select('*');
        if (supervisorId != null && supervisorId.isNotEmpty && _isValidUuid(supervisorId)) {
          query = query.eq('supervisor_id', supervisorId);
        }
        response = await query.order('name');
      }

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        final supervisor = json['users'];
        String supName = 'Unassigned';
        if (supervisor != null && supervisor is Map) {
          supName = '${supervisor['first_name'] ?? ''} ${supervisor['last_name'] ?? ''}'.trim();
        }

        final polygon = _parseWktPolygon(json['geometry']);
        final assignments = json['work_area_assignments'];
        int activeCount = 0;
        if (assignments is List) {
          activeCount = assignments.where((a) => a['is_active'] == true).length;
        }

        // Calculate area in km² dynamically from polygon if available
        double areaKm = 0.0;
        if (polygon.length >= 3) {
          const double latKm = 110.574;
          final double lonKm = 111.320 * 0.9816;
          for (int i = 0; i < polygon.length; i++) {
            final j = (i + 1) % polygon.length;
            final xi = polygon[i].longitude * lonKm;
            final yi = polygon[i].latitude * latKm;
            final xj = polygon[j].longitude * lonKm;
            final yj = polygon[j].latitude * latKm;
            areaKm += (xi * yj) - (xj * yi);
          }
          areaKm = areaKm.abs() / 2.0;
        }

        return WorkAreaModel(
          workareaId: json['workarea_id']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          description: json['description']?.toString(),
          supervisorId: json['supervisor_id']?.toString(),
          supervisorName: supName.isEmpty ? 'Unassigned' : supName,
          polygon: polygon.isNotEmpty ? polygon : const [LatLng(11.0050, 124.6075)],
          assignedCount: activeCount,
          status: 'Active',
          areaSqKm: areaKm > 0.0 ? '${areaKm.toStringAsFixed(2)} km²' : '0.00 km²',
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getWorkAreas error: $e');
      return const [];
    }
  }

  @override
  Future<void> addWorkArea(WorkAreaModel area) async {
    try {
      final payload = <String, dynamic>{
        'name': area.name,
        'description': area.description,
      };
      if (_isValidUuid(area.workareaId)) {
        payload['workarea_id'] = area.workareaId;
      }
      if (_isValidUuid(area.supervisorId)) {
        payload['supervisor_id'] = area.supervisorId;
      }
      if (area.polygon.length >= 3) {
        final closedPoints = [
          ...area.polygon.map((p) => [p.longitude, p.latitude]),
          [area.polygon.first.longitude, area.polygon.first.latitude],
        ];
        payload['geometry'] = {
          'type': 'Polygon',
          'coordinates': [closedPoints],
        };
      }
      await _client.from('work_areas').insert(payload);
    } catch (e) {
      debugPrint('Supabase addWorkArea error: $e');
    }
  }

  @override
  Future<void> updateWorkArea(WorkAreaModel area) async {
    try {
      if (!_isValidUuid(area.workareaId)) return;
      final payload = <String, dynamic>{
        'name': area.name,
        'description': area.description,
        'updated_at': DateTime.now().toIso8601String(),
        'supervisor_id': _isValidUuid(area.supervisorId) ? area.supervisorId : null,
      };
      if (area.polygon.length >= 3) {
        final closedPoints = [
          ...area.polygon.map((p) => [p.longitude, p.latitude]),
          [area.polygon.first.longitude, area.polygon.first.latitude],
        ];
        payload['geometry'] = {
          'type': 'Polygon',
          'coordinates': [closedPoints],
        };
      }
      await _client.from('work_areas').update(payload).eq('workarea_id', area.workareaId);
    } catch (e) {
      debugPrint('Supabase updateWorkArea error: $e');
    }
  }

  @override
  Future<void> deleteWorkArea(String areaId) async {
    try {
      if (!_isValidUuid(areaId)) return;
      await _client.from('work_areas').delete().eq('workarea_id', areaId);
    } catch (e) {
      debugPrint('Supabase deleteWorkArea error: $e');
    }
  }

  // ==========================================
  // Users / Employees & Assignments
  // ==========================================
  @override
  Future<List<UserModel>> getUsers({String? areaId, UserRole? role}) async {
    try {
      final query = _client.from('users').select('''
        *,
        roles(name),
        work_area_assignments(workarea_id, is_active, work_areas(name)),
        credit_balance(current_score)
      ''');

      final response = await query.order('first_name');
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      var userList = data.map((json) {
        final rolesData = json['roles'];
        String rName = '';
        if (rolesData is Map) {
          rName = rolesData['name']?.toString() ?? '';
        }
        final roleId = json['role_id']?.toString() ?? '';
        UserRole uRole = UserRole.worker;
        if (rName.toLowerCase().contains('admin') || roleId == '00000000-0000-0000-0000-000000000001') {
          uRole = UserRole.admin;
        } else if (rName.toLowerCase().contains('super') || roleId == '00000000-0000-0000-0000-000000000002') {
          uRole = UserRole.supervisor;
        }

        String? assignedAreaId;
        String? assignedAreaName;
        final assignments = json['work_area_assignments'];
        if (assignments is List && assignments.isNotEmpty) {
          final activeAssign = assignments.firstWhere(
            (a) => a['is_active'] == true,
            orElse: () => assignments.first,
          );
          assignedAreaId = activeAssign['workarea_id']?.toString();
          final area = activeAssign['work_areas'];
          if (area is Map) {
            assignedAreaName = area['name']?.toString();
          }
        }

        int score = 100;
        final creditData = json['credit_balance'];
        if (creditData is Map) {
          score = (creditData['current_score'] as num?)?.toInt() ?? 100;
        } else if (creditData is List && creditData.isNotEmpty) {
          score = (creditData.first['current_score'] as num?)?.toInt() ?? 100;
        }

        return UserModel(
          userId: json['user_id']?.toString() ?? '',
          username: json['username']?.toString() ?? '',
          firstName: json['first_name']?.toString() ?? '',
          lastName: json['last_name']?.toString() ?? '',
          contactNumber: json['contact_number']?.toString() ?? '',
          qrToken: json['qr_token']?.toString(),
          role: uRole,
          status: json['status']?.toString() ?? 'active',
          assignedAreaId: assignedAreaId,
          assignedAreaName: assignedAreaName,
          creditScore: score,
        );
      }).toList();

      if (role != null) {
        userList = userList.where((u) => u.role == role).toList();
      }
      if (areaId != null && areaId.isNotEmpty && _isValidUuid(areaId)) {
        userList = userList.where((u) => u.assignedAreaId == areaId).toList();
      }

      return userList;
    } catch (e) {
      debugPrint('Supabase getUsers error: $e');
      return const [];
    }
  }

  @override
  Future<void> addUser(UserModel user) async {
    try {
      String roleUuid = '00000000-0000-0000-0000-000000000003';
      if (user.role == UserRole.admin) {
        roleUuid = '00000000-0000-0000-0000-000000000001';
      } else if (user.role == UserRole.supervisor) {
        roleUuid = '00000000-0000-0000-0000-000000000002';
      }

      final payload = <String, dynamic>{
        'username': user.username,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'contact_number': user.contactNumber,
        'qr_token': user.qrToken,
        'role_id': roleUuid,
        'status': user.status,
      };
      if (_isValidUuid(user.userId)) {
        payload['user_id'] = user.userId;
      }

      final insertedUser = await _client.from('users').insert(payload).select().single();
      final actualUserId = insertedUser['user_id']?.toString() ?? user.userId;

      await _client.from('credit_balance').insert({
        'user_id': actualUserId,
        'current_score': user.creditScore,
      });

      if (user.assignedAreaId != null && _isValidUuid(user.assignedAreaId)) {
        await _client.from('work_area_assignments').insert({
          'user_id': actualUserId,
          'workarea_id': user.assignedAreaId,
          'is_active': true,
        });
      }
    } catch (e) {
      debugPrint('Supabase addUser error: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      if (!_isValidUuid(userId)) return;
      await _client.from('users').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteUser error: $e');
    }
  }

  @override
  Future<void> assignWorkerToArea({
    required String workerId,
    required String? areaId,
    String? areaName,
  }) async {
    try {
      if (!_isValidUuid(workerId)) return;
      await _client.from('work_area_assignments').update({'is_active': false}).eq('user_id', workerId);
      if (areaId != null && _isValidUuid(areaId)) {
        await _client.from('work_area_assignments').insert({
          'user_id': workerId,
          'workarea_id': areaId,
          'is_active': true,
        });
      }
    } catch (e) {
      debugPrint('Supabase assignWorkerToArea error: $e');
    }
  }

  @override
  Future<void> bulkAssignWorkers(Map<String, String?> assignments) async {
    for (final entry in assignments.entries) {
      await assignWorkerToArea(workerId: entry.key, areaId: entry.value);
    }
  }

  // ==========================================
  // Attendance & Location Tracking
  // ==========================================
  @override
  Future<List<AttendanceModel>> getAttendanceLogs({String? areaId, String? workerId}) async {
    try {
      var query = _client.from('attendance').select('*, users(first_name, last_name, username), work_areas(name)');
      if (areaId != null && areaId.isNotEmpty) {
        query = query.eq('workarea_id', areaId);
      }
      if (workerId != null && workerId.isNotEmpty) {
        query = query.eq('user_id', workerId);
      }
      final response = await query.order('timestamp', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        final user = json['users'];
        final area = json['work_areas'];
        String wName = 'Field Worker';
        if (user is Map) {
          wName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
        }
        String aName = 'General Work Area';
        if (area is Map) {
          aName = area['name']?.toString() ?? aName;
        }

        final ts = DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now();

        return AttendanceModel(
          attendanceId: json['attendance_id']?.toString() ?? '',
          userId: json['user_id']?.toString() ?? '',
          workerName: wName.isEmpty ? 'Field Worker' : wName,
          workerEmpId: 'EMP-${json['user_id']?.toString().substring(0, 4).toUpperCase()}',
          workareaId: json['workarea_id']?.toString() ?? '',
          areaName: aName,
          actionType: json['action_type']?.toString() ?? 'time-in',
          timestamp: ts,
          gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 11.0050,
          gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 124.6075,
          imageUrl: json['image_url']?.toString(),
          faceMatch: json['face_match'] == true,
          isSynced: json['is_synced'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getAttendanceLogs error: $e');
      return const [];
    }
  }

  @override
  Future<void> toggleAttendanceVerify(String attendanceId) async {}

  @override
  Future<List<LocationTrackingModel>> getLocationBreadcrumbs({String? userId, String? areaId}) async {
    try {
      var query = _client.from('location_tracking').select('*, users(first_name, last_name)');
      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }
      final response = await query.order('timestamp', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        return LocationTrackingModel(
          locationId: json['location_id']?.toString() ?? '',
          userId: json['user_id']?.toString() ?? '',
          attendanceId: json['attendance_id']?.toString(),
          gpsLat: (json['gps_lat'] as num?)?.toDouble() ?? 11.0050,
          gpsLng: (json['gps_lng'] as num?)?.toDouble() ?? 124.6075,
          timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isLastSeen: json['is_last_seen'] == true,
          isInsideGeofence: json['is_last_seen'] != true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getLocationBreadcrumbs error: $e');
      return const [];
    }
  }

  // ==========================================
  // Accomplishments
  // ==========================================
  @override
  Future<List<AccomplishmentModel>> getAccomplishments({String? areaId}) async {
    try {
      dynamic response;
      try {
        var query = _client.from('accomplishments').select('*, users!accomplishments_user_id_fkey(first_name, last_name), work_areas(name)');
        if (areaId != null && areaId.isNotEmpty && _isValidUuid(areaId)) {
          query = query.eq('workarea_id', areaId);
        }
        response = await query.order('created_at', ascending: false);
      } catch (embedErr) {
        debugPrint('Accomplishments embed error, falling back to simple select: $embedErr');
        var query = _client.from('accomplishments').select('*');
        if (areaId != null && areaId.isNotEmpty && _isValidUuid(areaId)) {
          query = query.eq('workarea_id', areaId);
        }
        response = await query.order('created_at', ascending: false);
      }
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        final user = json['users'];
        final area = json['work_areas'];
        String wName = 'Field Worker';
        if (user is Map) {
          wName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
        }
        String aName = 'General Work Area';
        if (area is Map) {
          aName = area['name']?.toString() ?? aName;
        }

        return AccomplishmentModel(
          accomplishmentId: json['accomplishment_id']?.toString() ?? '',
          userId: json['user_id']?.toString() ?? '',
          workerName: wName.isEmpty ? 'Field Worker' : wName,
          workareaId: json['workarea_id']?.toString() ?? '',
          areaName: aName,
          imageUrl: json['image_url']?.toString() ?? '',
          capturedDate: json['captured_date']?.toString() ?? '',
          capturedTime: json['captured_time']?.toString() ?? '',
          capturedLat: (json['captured_lat'] as num?)?.toDouble() ?? 11.0050,
          capturedLng: (json['captured_lng'] as num?)?.toDouble() ?? 124.6075,
          message: json['message']?.toString() ?? '',
          status: json['status']?.toString() ?? 'pending',
          approvedBy: json['approved_by']?.toString(),
          rejectionReason: json['rejection_reason']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getAccomplishments error: $e');
      return const [];
    }
  }

  @override
  Future<void> updateAccomplishmentStatus(
    String accomplishmentId,
    String status, {
    String? rejectionReason,
    String? approvedBy,
    String? approvedByName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': status,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': rejectionReason,
      };
      if (_isValidUuid(approvedBy)) {
        payload['approved_by'] = approvedBy;
      }
      await _client.from('accomplishments').update(payload).eq('accomplishment_id', accomplishmentId);
    } catch (e) {
      debugPrint('Supabase updateAccomplishmentStatus error: $e');
    }
  }

  // ==========================================
  // Leaves
  // ==========================================
  @override
  Future<List<LeaveRequestModel>> getLeaveRequests({String? areaId}) async {
    try {
      dynamic response;
      try {
        response = await _client.from('leave_requests').select('*, users!leave_requests_user_id_fkey(first_name, last_name)').order('created_at', ascending: false);
      } catch (embedErr) {
        debugPrint('Leave requests embed error, falling back to simple select: $embedErr');
        response = await _client.from('leave_requests').select('*').order('created_at', ascending: false);
      }
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        final user = json['users'];
        String wName = 'Field Worker';
        if (user is Map) {
          wName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
        }

        return LeaveRequestModel(
          leaveId: json['leave_id']?.toString() ?? '',
          userId: json['user_id']?.toString() ?? '',
          workerName: wName.isEmpty ? 'Field Worker' : wName,
          areaName: 'General / Field',
          type: json['type']?.toString() ?? 'Vacation Leave',
          startDate: json['start_date']?.toString() ?? '',
          endDate: json['end_date']?.toString() ?? '',
          reason: json['reason']?.toString() ?? '',
          imageUrl: json['image_url']?.toString(),
          status: json['status']?.toString() ?? 'pending',
          adminDecision: json['admin_decision']?.toString(),
          decisionAt: DateTime.tryParse(json['decision_at']?.toString() ?? ''),
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getLeaveRequests error: $e');
      return const [];
    }
  }

  @override
  Future<void> updateLeaveStatus(
    String leaveId,
    String status, {
    String? adminId,
    String? rejectionReason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': status,
        'decision_at': DateTime.now().toIso8601String(),
        'reason': rejectionReason,
      };
      if (_isValidUuid(adminId)) {
        payload['admin_decision'] = adminId;
      }
      await _client.from('leave_requests').update(payload).eq('leave_id', leaveId);
    } catch (e) {
      debugPrint('Supabase updateLeaveStatus error: $e');
    }
  }

  @override
  Future<void> endorseLeaveRequest(
    String leaveId, {
    required String supervisorId,
    required String supervisorName,
    required String comments,
  }) async {}

  // ==========================================
  // Alerts
  // ==========================================
  @override
  Future<List<AlertModel>> getAlerts({String? areaId, String? category}) async {
    try {
      dynamic response;
      try {
        response = await _client.from('alerts').select('*, users!alerts_user_id_fkey(first_name, last_name)').order('created_at', ascending: false);
      } catch (embedErr) {
        debugPrint('Alerts embed error, falling back to simple select: $embedErr');
        response = await _client.from('alerts').select('*').order('created_at', ascending: false);
      }
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        final user = json['users'];
        String wName = 'Field Worker';
        if (user is Map) {
          wName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
        }
        final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
        return AlertModel(
          alertId: json['alert_id']?.toString() ?? '',
          title: json['type']?.toString() ?? 'System Alert',
          type: json['type']?.toString() ?? 'Consecutive Absences',
          description: json['message']?.toString() ?? '',
          severity: 'warning',
          timeAgo: 'Just now',
          createdAt: createdAt,
          workerName: wName,
          isResolved: json['resolved_at'] != null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getAlerts error: $e');
      return const [];
    }
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    try {
      await _client.from('alerts').update({
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('alert_id', alertId);
    } catch (e) {
      debugPrint('Supabase resolveAlert error: $e');
    }
  }

  @override
  Future<void> sendWarningForAlert({
    required String alertId,
    required String workerId,
    required String message,
    String? supervisorId,
  }) async {
    await resolveAlert(alertId);
    await addBroadcast(
      BroadcastModel(
        notificationId: '',
        senderId: '11111111-1111-1111-1111-111111111111',
        recipients: 'Worker & Supervisor',
        subject: 'Official Warning Notice',
        message: message,
        isConfidential: true,
        deliveredCount: 2,
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> dismissAlert({
    required String alertId,
    required String adminId,
    String? reason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'resolved_at': DateTime.now().toIso8601String(),
      };
      if (_isValidUuid(adminId)) {
        payload['resolved_by'] = adminId;
      }
      await _client.from('alerts').update(payload).eq('alert_id', alertId);
    } catch (e) {
      debugPrint('Supabase dismissAlert error: $e');
    }
  }

  // ==========================================
  // Broadcasts
  // ==========================================
  @override
  Future<List<BroadcastModel>> getBroadcasts() async {
    try {
      final response = await _client.from('notifications').select().order('sent_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const [];

      return data.map((json) {
        return BroadcastModel(
          notificationId: json['notification_id']?.toString() ?? '',
          senderId: json['sender_id']?.toString() ?? '',
          recipients: 'All Personnel',
          subject: json['type']?.toString() ?? 'Notification',
          message: json['message']?.toString() ?? '',
          isConfidential: json['type'] == 'confidential',
          deliveredCount: 1,
          sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getBroadcasts error: $e');
      return const [];
    }
  }

  @override
  Future<void> addBroadcast(BroadcastModel broadcast) async {
    try {
      final payload = <String, dynamic>{
        'message': broadcast.message,
        'type': broadcast.isConfidential ? 'confidential' : 'announcement',
        'is_read': false,
        'sent_at': broadcast.sentAt.toIso8601String(),
      };
      if (_isValidUuid(broadcast.notificationId)) {
        payload['notification_id'] = broadcast.notificationId;
      }
      if (_isValidUuid(broadcast.senderId)) {
        payload['sender_id'] = broadcast.senderId;
      }
      await _client.from('notifications').insert(payload);
    } catch (e) {
      debugPrint('Supabase addBroadcast error: $e');
    }
  }

  @override
  Future<void> sendReportToAdmin({
    required String reportType,
    required String summary,
    String? note,
    required String supervisorId,
    required String supervisorName,
  }) async {}

  // ==========================================
  // Incidents
  // ==========================================
  @override
  Future<List<IncidentReportModel>> getIncidents({String? reporterId, String? workareaId, String? status}) async {
    try {
      final response = await _client.from('worker_reports').select('*, users!worker_reports_reported_id_fkey(first_name, last_name)').order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final reported = json['users'];
        String rName = 'Field Worker';
        if (reported is Map) {
          rName = '${reported['first_name'] ?? ''} ${reported['last_name'] ?? ''}'.trim();
        }
        return IncidentReportModel(
          reportId: json['report_id']?.toString() ?? '',
          reporterId: json['reporter_id']?.toString() ?? '',
          reporterName: 'Supervisor',
          reportedId: json['reported_id']?.toString() ?? '',
          reportedName: rName,
          issueType: json['issue_type']?.toString() ?? 'General Issue',
          workareaId: workareaId ?? '',
          areaName: 'Field Assignment',
          description: json['description']?.toString() ?? '',
          status: json['status']?.toString() ?? 'pending',
          createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase getIncidents error: $e');
      return const [];
    }
  }

  @override
  Future<void> addIncident(IncidentReportModel incident) async {}

  @override
  Future<void> resolveIncident(String reportId) async {}

  @override
  Future<void> settleIncidentLocally(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {}

  @override
  Future<void> escalateIncidentToAdmin(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {}

  @override
  Future<void> resolveIncidentByAdmin(
    String reportId, {
    required String adminId,
    required String resolutionNotes,
  }) async {}
}

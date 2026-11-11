import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/uuid_helper.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/worker_schedule_sheet_model.dart';
import '../models/alert_model.dart';
import '../models/broadcast_model.dart';
import '../models/incident_report_model.dart';
import '../models/location_tracking_model.dart';
import 'data_repository.dart';

class SupabaseRepository implements DataRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // ==========================================
  // Work Areas
  // ==========================================
  @override
  Future<List<WorkAreaModel>> getWorkAreas({String? supervisorId}) async {
    try {
      var query = _client.from('work_areas').select('*, users!supervisor_id(first_name, last_name)');
      if (supervisorId != null && supervisorId.isNotEmpty) {
        query = query.eq('supervisor_id', supervisorId);
      }
      final res = await query.order('name');
      final areas = (res as List).map((map) => WorkAreaModel.fromJson(map as Map<String, dynamic>)).toList();

      // Count active workers per area
      final assignments = await _client
          .from('work_area_assignments')
          .select('workarea_id')
          .eq('is_active', true);
      final Map<String, int> counts = {};
      for (final a in (assignments as List)) {
        final id = a['workarea_id']?.toString() ?? '';
        if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
      }

      return areas.map((a) => a.copyWith(assignedCount: counts[a.workareaId] ?? 0)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository getWorkAreas error: $e');
      return [];
    }
  }

  @override
  Future<void> addWorkArea(WorkAreaModel area) async {
    try {
      final payload = area.toSupabaseJson();
      if (payload['workarea_id'] == null || (payload['workarea_id'] as String).isEmpty) {
        payload['workarea_id'] = UuidHelper.generate();
      }

      // Try inserting with status column
      try {
        final payloadWithStatus = Map<String, dynamic>.from(payload);
        payloadWithStatus['status'] = area.status;
        await _client.from('work_areas').insert(payloadWithStatus);
        return;
      } catch (statusErr) {
        debugPrint('Supabase work_areas status column not available on insert: $statusErr');
      }

      // Fallback: encode status in description
      if (area.status == 'Inactive') {
        final curDesc = payload['description']?.toString() ?? '';
        payload['description'] = (curDesc.isEmpty ? '' : '$curDesc ') + '[STATUS:Inactive]';
      }
      await _client.from('work_areas').insert(payload);
    } catch (e) {
      debugPrint('SupabaseRepository addWorkArea error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateWorkArea(WorkAreaModel area) async {
    try {
      final payload = area.toSupabaseJson();

      // Try updating with status column
      try {
        final payloadWithStatus = Map<String, dynamic>.from(payload);
        payloadWithStatus['status'] = area.status;
        await _client.from('work_areas').update(payloadWithStatus).eq('workarea_id', area.workareaId);
        return;
      } catch (statusErr) {
        debugPrint('Supabase work_areas status column not available on update: $statusErr');
      }

      // Fallback: encode status in description
      var curDesc = payload['description']?.toString() ?? '';
      curDesc = curDesc.replaceAll(RegExp(r'\[STATUS:(Active|Inactive)\]'), '').trim();
      if (area.status == 'Inactive') {
        curDesc = (curDesc.isEmpty ? '' : '$curDesc ') + '[STATUS:Inactive]';
      }
      payload['description'] = curDesc.isEmpty ? null : curDesc;
      await _client.from('work_areas').update(payload).eq('workarea_id', area.workareaId);
    } catch (e) {
      debugPrint('SupabaseRepository updateWorkArea error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteWorkArea(String areaId) async {
    try {
      await _client.from('work_areas').delete().eq('workarea_id', areaId);
    } catch (e) {
      debugPrint('SupabaseRepository deleteWorkArea error: $e');
      rethrow;
    }
  }

  // ==========================================
  // Users & Worker Assignments
  // ==========================================
  @override
  Future<List<UserModel>> getUsers({String? areaId, UserRole? role}) async {
    try {
      final res = await _client.from('users').select('''
        *,
        roles(role_id, name),
        credit_balance(current_score),
        work_area_assignments(workarea_id, is_active, work_areas(name)),
        schedules(schedule_id, start_time, end_time, days, created_at)
      ''').order('last_name');

      var list = (res as List).map((m) => UserModel.fromJson(m as Map<String, dynamic>)).toList();

      if (role != null) {
        list = list.where((u) => u.role == role).toList();
      }
      if (areaId != null && areaId.isNotEmpty) {
        list = list.where((u) => u.assignedAreaId == areaId).toList();
      }

      return list;
    } catch (e) {
      debugPrint('SupabaseRepository getUsers error: $e');
      return [];
    }
  }

  @override
  Future<void> addUser(UserModel user) async {
    try {
      // Validate or generate RFC4122 v4 UUID
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      final userId = (user.userId.isNotEmpty && uuidRegex.hasMatch(user.userId))
          ? user.userId
          : UuidHelper.generate();

      // Resolve role_id dynamically from database if possible, fallback to AppConstants
      String roleId = user.role == UserRole.admin
          ? AppConstants.roleAdminId
          : user.role == UserRole.supervisor
              ? AppConstants.roleSupervisorId
              : AppConstants.roleWorkerId;

      try {
        final roleKeyword = user.role == UserRole.admin
            ? 'Admin'
            : user.role == UserRole.supervisor
                ? 'Supervisor'
                : 'Worker';
        final roleRes = await _client
            .from('roles')
            .select('role_id')
            .ilike('name', '%$roleKeyword%')
            .limit(1)
            .maybeSingle();
        if (roleRes != null && roleRes['role_id'] != null) {
          roleId = roleRes['role_id'].toString();
        }
      } catch (roleErr) {
        debugPrint('Dynamic role resolution warning: $roleErr');
      }

      final insertData = <String, dynamic>{
        'user_id': userId,
        'username': user.username,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'contact_number': user.contactNumber,
        'qr_token': user.qrToken ?? 'QR-${user.username}',
        'role_id': roleId,
        'status': user.status,
      };

      if (user.faceEmbedding != null && user.faceEmbedding!.isNotEmpty) {
        insertData['face_embedding'] = user.faceEmbedding;
      }

      await _client.from('users').insert(insertData);

      // Insert starting credit balance strictly for Field Workers (SRS UC-18)
      if (user.role == UserRole.worker) {
        try {
          await _client.from('credit_balance').upsert({
            'user_id': userId,
            'current_score': user.creditScore,
          }, onConflict: 'user_id');
        } catch (cbErr) {
          debugPrint('SupabaseRepository credit_balance upsert warning: $cbErr');
        }
      }

      // If initial shift schedule assigned (SRS FR-12)
      if (user.schedule.isNotEmpty && user.schedule != 'Unassigned') {
        try {
          final parts = user.schedule.split(' ');
          final days = parts.isNotEmpty ? parts.first : 'Mon-Fri';
          var st = '08:00';
          var et = '17:00';
          if (user.schedule.contains('-')) {
            final timePart = user.schedule.substring(days.length).trim();
            final times = timePart.split('-').map((t) => t.trim()).toList();
            if (times.length == 2) {
              st = times[0];
              et = times[1];
            }
          }
          await _client.from('schedules').insert({
            'user_id': userId,
            'start_time': st,
            'end_time': et,
            'days': days,
          });
        } catch (schedErr) {
          debugPrint('SupabaseRepository initial schedule insert notice: $schedErr');
        }
      }

      // If work area assigned
      if (user.assignedAreaId != null && user.assignedAreaId!.isNotEmpty) {
        await assignWorkerToArea(
          workerId: userId,
          areaId: user.assignedAreaId,
          areaName: user.assignedAreaName,
        );
      }
    } catch (e) {
      debugPrint('SupabaseRepository addUser error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _client.from('users').update({'status': status}).eq('user_id', userId);
    } catch (e) {
      debugPrint('SupabaseRepository updateUserStatus error: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('SupabaseRepository deleteUser error: $e');
      rethrow;
    }
  }

  @override
  Future<void> assignWorkerToArea({
    required String workerId,
    required String? areaId,
    String? areaName,
  }) async {
    try {
      // Deactivate current active assignments
      await _client
          .from('work_area_assignments')
          .update({'is_active': false})
          .eq('user_id', workerId);

      // If assigning to a new area
      if (areaId != null && areaId.isNotEmpty) {
        await _client.from('work_area_assignments').insert({
          'assignment_id': UuidHelper.generate(),
          'user_id': workerId,
          'workarea_id': areaId,
          'is_active': true,
        });
      }
    } catch (e) {
      debugPrint('SupabaseRepository assignWorkerToArea error: $e');
      rethrow;
    }
  }

  @override
  Future<void> bulkAssignWorkers(Map<String, String?> assignments) async {
    for (final entry in assignments.entries) {
      await assignWorkerToArea(workerId: entry.key, areaId: entry.value);
    }
  }

  @override
  Future<void> updateWorkerSchedule({
    required String workerId,
    required String startTime,
    required String endTime,
    required String days,
    String? areaName,
  }) async {
    try {
      // 1. Insert historical schedule record (specs/schema.sql schedules table)
      await _client.from('schedules').insert({
        'user_id': workerId,
        'start_time': startTime,
        'end_time': endTime,
        'days': days,
      });

      // 2. Dispatch automated in-app assignment notification (specs/schema.sql notifications table)
      final locationNotice = areaName != null && areaName.isNotEmpty ? ' sa $areaName' : '';
      await _client.from('notifications').insert({
        'receiver_id': workerId,
        'type': 'announcement',
        'message': 'Nausab ang imong iskedyul sa trabaho: $days $startTime - $endTime$locationNotice. Palihug tan-awa ang imong iskedyul sa dashboard.',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('SupabaseRepository updateWorkerSchedule error: $e');
      rethrow;
    }
  }

  // Local fallback storage for schedule sheets across Supabase restarts
  static final List<ScheduleSheetModel> _supaMemSheets = [];

  @override
  Future<List<ScheduleSheetModel>> getScheduleSheets({int? month, int? year}) async {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    try {
      final res = await _client
          .from('schedules_sheets')
          .select()
          .eq('month', targetMonth)
          .eq('year', targetYear);
      if (res.isNotEmpty) {
        return (res as List).map((m) => ScheduleSheetModel.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('SupabaseRepository getScheduleSheets remote notice: $e');
    }

    // Fallback to in-memory / synthesized active workforce sheets
    if (!_supaMemSheets.any((s) => s.month == targetMonth && s.year == targetYear)) {
      try {
        final workers = await getUsers(role: UserRole.worker);
        final half = (workers.length / 2).ceil();
        final streetWorkers = workers.take(half).toList();
        final parksWorkers = workers.skip(half).toList();

        final streetEntries = <ScheduleEntryModel>[];
        for (int i = 0; i < streetWorkers.length; i++) {
          final w = streetWorkers[i];
          final areaName = w.assignedAreaName ?? (i % 2 == 0 ? 'San Pedro Street' : 'Real Street');
          final areaId = w.assignedAreaId ?? (i % 2 == 0 ? 'area-1' : 'area-2');
          streetEntries.add(ScheduleEntryModel(
            entryId: 'entry-sc-$i-$targetMonth-$targetYear',
            userId: w.userId,
            workerName: w.fullName,
            assignedAreaId: areaId,
            assignedAreaName: areaName,
            dayOff: i % 2 == 0 ? 'Saturday and Sunday' : 'Sunday and Monday',
            timeSchedule: '04:00 AM – 01:00 PM',
            statusRemarks: 'Raffle Batch 1',
          ));
        }

        final parksEntries = <ScheduleEntryModel>[];
        for (int i = 0; i < parksWorkers.length; i++) {
          final w = parksWorkers[i];
          final areaName = w.assignedAreaName ?? 'Ormoc Plaza';
          final areaId = w.assignedAreaId ?? 'area-1';
          parksEntries.add(ScheduleEntryModel(
            entryId: 'entry-pp-$i-$targetMonth-$targetYear',
            userId: w.userId,
            workerName: w.fullName,
            assignedAreaId: areaId,
            assignedAreaName: areaName,
            dayOff: i % 2 == 0 ? 'Sunday and Monday' : 'Friday and Saturday',
            timeSchedule: '06:00 AM – 03:00 PM',
            statusRemarks: 'Raffle Batch 2',
          ));
        }

        _supaMemSheets.add(ScheduleSheetModel(
          sheetId: 'sheet-sc-$targetMonth-$targetYear',
          sheetName: 'Street Cleaners',
          month: targetMonth,
          year: targetYear,
          entries: streetEntries,
        ));

        _supaMemSheets.add(ScheduleSheetModel(
          sheetId: 'sheet-pp-$targetMonth-$targetYear',
          sheetName: 'Parks and Plaza',
          month: targetMonth,
          year: targetYear,
          entries: parksEntries,
        ));
      } catch (err) {
        debugPrint('SupabaseRepository synthesize default sheets notice: $err');
      }
    }

    return _supaMemSheets.where((s) => s.month == targetMonth && s.year == targetYear).toList();
  }

  @override
  Future<void> saveScheduleSheet(ScheduleSheetModel sheet) async {
    final idx = _supaMemSheets.indexWhere((s) => s.sheetId == sheet.sheetId);
    if (idx != -1) {
      _supaMemSheets[idx] = sheet;
    } else {
      _supaMemSheets.add(sheet);
    }

    try {
      await _client.from('schedules_sheets').upsert({
        'sheet_id': sheet.sheetId,
        'sheet_name': sheet.sheetName,
        'month': sheet.month,
        'year': sheet.year,
        'entries': sheet.entries.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('SupabaseRepository saveScheduleSheet remote notice: $e');
    }
  }

  @override
  Future<void> deleteScheduleSheet(String sheetId) async {
    _supaMemSheets.removeWhere((s) => s.sheetId == sheetId);
    try {
      await _client.from('schedules_sheets').delete().eq('sheet_id', sheetId);
    } catch (e) {
      debugPrint('SupabaseRepository deleteScheduleSheet remote notice: $e');
    }
  }

  // ==========================================
  // Attendance & Location Tracking
  // ==========================================
  @override
  Future<List<AttendanceModel>> getAttendanceLogs({String? areaId, String? workerId}) async {
    try {
      var query = _client.from('attendance').select('''
        *,
        users(first_name, last_name, qr_token),
        work_areas(name)
      ''');

      if (workerId != null && workerId.isNotEmpty) {
        query = query.eq('user_id', workerId);
      }
      if (areaId != null && areaId.isNotEmpty) {
        query = query.eq('workarea_id', areaId);
      }

      final res = await query.order('timestamp', ascending: false);
      return (res as List).map((m) => AttendanceModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository getAttendanceLogs error: $e');
      return [];
    }
  }

  @override
  Future<void> toggleAttendanceVerify(String attendanceId) async {
    // Attendance records are immutable biometric logs authenticated on-device.
    // We intentionally do not mutate `face_match` as it represents the raw biometric scan outcome.
  }

  @override
  Future<List<LocationTrackingModel>> getLocationBreadcrumbs({String? userId, String? areaId}) async {
    try {
      var query = _client.from('location_tracking').select('*');
      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }
      final res = await query.order('timestamp', ascending: true).limit(100);
      return (res as List).map((m) => LocationTrackingModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository getLocationBreadcrumbs error: $e');
      return [];
    }
  }

  // ==========================================
  // Accomplishments
  // ==========================================
  @override
  Future<List<AccomplishmentModel>> getAccomplishments({String? areaId}) async {
    final validAreaId = (areaId != null && areaId.isNotEmpty && areaId != 'all') ? areaId : null;

    // Tier 1: PostgREST column-based foreign key syntax
    try {
      var query = _client.from('accomplishments').select('''
        *,
        users:users!user_id(first_name, last_name),
        work_areas(name),
        approver:users!approved_by(first_name, last_name)
      ''');

      if (validAreaId != null) {
        query = query.eq('workarea_id', validAreaId);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((m) => AccomplishmentModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {}

    // Tier 2: PostgREST constraint-name based foreign key syntax
    try {
      var query = _client.from('accomplishments').select('''
        *,
        users:users!accomplishments_user_id_fkey(first_name, last_name),
        work_areas(name),
        approver:users!accomplishments_approved_by_fkey(first_name, last_name)
      ''');

      if (validAreaId != null) {
        query = query.eq('workarea_id', validAreaId);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((m) => AccomplishmentModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {}

    // Tier 3: Work area join only + user name enrichment
    try {
      var query = _client.from('accomplishments').select('''
        *,
        work_areas(name)
      ''');

      if (validAreaId != null) {
        query = query.eq('workarea_id', validAreaId);
      }

      final res = await query.order('created_at', ascending: false);
      final list = (res as List).map((m) => AccomplishmentModel.fromJson(m as Map<String, dynamic>)).toList();
      return await _enrichAccomplishments(list);
    } catch (_) {}

    // Tier 4: Fallback pure select without any relational embedding with multi-column order fallback
    try {
      var query = _client.from('accomplishments').select('*');
      if (validAreaId != null) {
        query = query.eq('workarea_id', validAreaId);
      }
      List res;
      try {
        res = await query.order('created_at', ascending: false);
      } catch (_) {
        try {
          res = await query.order('captured_date', ascending: false);
        } catch (_) {
          res = await query;
        }
      }
      final list = res.map((m) => AccomplishmentModel.fromJson(m as Map<String, dynamic>)).toList();
      return await _enrichAccomplishments(list);
    } catch (e) {
      debugPrint('SupabaseRepository getAccomplishments fatal error: $e');
      return [];
    }
  }

  Future<List<AccomplishmentModel>> _enrichAccomplishments(List<AccomplishmentModel> list) async {
    if (list.isEmpty) return list;
    try {
      final userIds = list.map((a) => a.userId).where((id) => id.isNotEmpty).toSet().toList();
      final areaIds = list.map((a) => a.workareaId).where((id) => id.isNotEmpty).toSet().toList();

      final userNames = <String, String>{};
      final areaNames = <String, String>{};

      if (userIds.isNotEmpty) {
        try {
          final usersRes = await _client.from('users').select('user_id, first_name, last_name');
          for (final u in (usersRes as List)) {
            final id = u['user_id']?.toString() ?? '';
            final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
            if (id.isNotEmpty && name.isNotEmpty) userNames[id] = name;
          }
        } catch (_) {}
      }

      if (areaIds.isNotEmpty) {
        try {
          final areasRes = await _client.from('work_areas').select('workarea_id, name');
          for (final a in (areasRes as List)) {
            final id = a['workarea_id']?.toString() ?? '';
            final name = a['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) areaNames[id] = name;
          }
        } catch (_) {}
      }

      return list.map((a) {
        final realName = userNames[a.userId];
        final realArea = areaNames[a.workareaId];
        return a.copyWith(
          workerName: (realName != null && realName.isNotEmpty) ? realName : a.workerName,
          areaName: (realArea != null && realArea.isNotEmpty) ? realArea : a.areaName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Enrich accomplishments notice: $e');
      return list;
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
      await _client.from('accomplishments').update({
        'status': status,
        if (approvedBy != null && approvedBy.isNotEmpty) 'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      }).eq('accomplishment_id', accomplishmentId);
    } catch (e) {
      debugPrint('SupabaseRepository updateAccomplishmentStatus error: $e');
      rethrow;
    }
  }

  // ==========================================
  // Leave Requests
  // ==========================================
  @override
  Future<List<LeaveRequestModel>> getLeaveRequests({String? areaId}) async {
    try {
      final res = await _client.from('leave_requests').select('''
        *,
        users:users!leave_requests_user_id_fkey(first_name, last_name, assigned_area_name),
        work_areas(name)
      ''').order('created_at', ascending: false);

      final list = (res as List).map((m) => LeaveRequestModel.fromJson(m as Map<String, dynamic>)).toList();

      // Enrich rejectionReason for denied leaves from notifications
      final deniedLeaves = list.where((l) => l.status == 'denied').toList();
      if (deniedLeaves.isNotEmpty) {
        try {
          final notifs = await _client
              .from('notifications')
              .select('receiver_id, message, sent_at')
              .ilike('message', '%Leave Request Denied%')
              .order('sent_at', ascending: false);

          final notifList = notifs as List;
          return list.map((l) {
            if (l.status != 'denied' || (l.rejectionReason != null && l.rejectionReason!.isNotEmpty)) {
              return l;
            }
            final match = notifList.firstWhere(
              (n) => n['receiver_id'] == l.userId && n['message'] != null && n['message'].toString().contains('Reason: '),
              orElse: () => null,
            );
            if (match != null) {
              final msg = match['message'].toString();
              final idx = msg.indexOf('Reason: ');
              if (idx != -1) {
                final reason = msg.substring(idx + 8).trim();
                return l.copyWith(rejectionReason: reason);
              }
            }
            return l;
          }).toList();
        } catch (enrichErr) {
          debugPrint('Error enriching leave rejection reasons from notifications: $enrichErr');
        }
      }

      return list;
    } catch (e) {
      debugPrint('SupabaseRepository getLeaveRequests error: $e');
      return [];
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
      };
      if (adminId != null && adminId.isNotEmpty && UuidHelper.isValid(adminId)) {
        payload['admin_decision'] = adminId;
      }
      await _client.from('leave_requests').update(payload).eq('leave_id', leaveId);

      // Fulfill SRS UC-03 step 8: Send notification to the worker
      try {
        final leaveRow = await _client.from('leave_requests').select('user_id, type').eq('leave_id', leaveId).maybeSingle();
        if (leaveRow != null && leaveRow['user_id'] != null) {
          final targetUserId = leaveRow['user_id'] as String;
          final leaveType = leaveRow['type']?.toString() ?? 'Leave';
          if (status == 'denied') {
            final reasonText = (rejectionReason != null && rejectionReason.isNotEmpty)
                ? ' Reason: $rejectionReason'
                : '';
            await _client.from('notifications').insert({
              'notification_id': UuidHelper.generate(),
              if (adminId != null && UuidHelper.isValid(adminId)) 'sender_id': adminId,
              'receiver_id': targetUserId,
              'message': 'Leave Request Denied: Your $leaveType application has been denied.$reasonText',
              'type': 'confidential',
              'is_read': false,
            });
          } else if (status == 'approved') {
            await _client.from('notifications').insert({
              'notification_id': UuidHelper.generate(),
              if (adminId != null && UuidHelper.isValid(adminId)) 'sender_id': adminId,
              'receiver_id': targetUserId,
              'message': 'Leave Request Approved: Your $leaveType application has been approved.',
              'type': 'confidential',
              'is_read': false,
            });
          }
        }
      } catch (notifErr) {
        debugPrint('Notification dispatch on leave status change error: $notifErr');
      }
    } catch (e) {
      debugPrint('SupabaseRepository updateLeaveStatus error: $e');
      rethrow;
    }
  }

  @override
  Future<void> endorseLeaveRequest(
    String leaveId, {
    required String supervisorId,
    required String supervisorName,
    required String comments,
  }) async {
    try {
      // Notify admin of supervisor endorsement
      await _client.from('notifications').insert({
        'notification_id': UuidHelper.generate(),
        'sender_id': supervisorId,
        'message': 'Supervisor Endorsement: $supervisorName endorsed leave $leaveId. Notes: $comments',
        'type': 'confidential',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('SupabaseRepository endorseLeaveRequest error: $e');
    }
  }

  // ==========================================
  // Alerts & Warnings
  // ==========================================
  @override
  Future<List<AlertModel>> getAlerts({String? areaId, String? category}) async {
    try {
      final res = await _client.from('alerts').select('''
        *,
        users:users!alerts_user_id_fkey(
          first_name,
          last_name,
          qr_token,
          contact_number,
          credit_balance(current_score),
          work_area_assignments(workarea_id, is_active, work_areas(name))
        )
      ''').order('created_at', ascending: false);

      var list = (res as List).map((m) => AlertModel.fromJson(m as Map<String, dynamic>)).toList();

      if (category != null && category != 'all') {
        list = list.where((a) => a.srsCategory == category).toList();
      }
      return list;
    } catch (e) {
      debugPrint('SupabaseRepository getAlerts error: $e');
      return [];
    }
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    try {
      await _client.from('alerts').update({
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('alert_id', alertId);
    } catch (e) {
      debugPrint('SupabaseRepository resolveAlert error: $e');
    }
  }

  @override
  Future<void> sendWarningForAlert({
    required String alertId,
    required String workerId,
    required String message,
    String? supervisorId,
  }) async {
    try {
      // 1. Deduct performance credit points for the warning notice
      const int penaltyPoints = 5;
      int currentScore = 100;
      try {
        final balRes = await _client
            .from('credit_balance')
            .select('current_score')
            .eq('user_id', workerId)
            .maybeSingle();
        if (balRes != null && balRes['current_score'] != null) {
          currentScore = (balRes['current_score'] as num).toInt();
        }
      } catch (e) {
        debugPrint('Failed to query current credit_balance: $e');
      }

      final newScore = (currentScore - penaltyPoints).clamp(0, 100);

      // 2. Upsert credit_balance with updated score
      try {
        await _client.from('credit_balance').upsert({
          'user_id': workerId,
          'current_score': newScore,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (e) {
        debugPrint('Failed to update credit_balance: $e');
      }

      // 3. Insert audit log into credit_history
      try {
        await _client.from('credit_history').insert({
          'history_id': UuidHelper.generate(),
          'user_id': workerId,
          'change_amount': -penaltyPoints,
          'reason': 'Warning Notice: Official penalty issued for attendance irregularity',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Failed to insert credit_history: $e');
      }

      // 4. Insert notification for worker
      final notifPayload = <String, dynamic>{
        'notification_id': UuidHelper.generate(),
        'message': message,
        'type': 'alert',
        'is_read': false,
        'sent_at': DateTime.now().toIso8601String(),
      };
      if (supervisorId != null && supervisorId.isNotEmpty && UuidHelper.isValid(supervisorId)) {
        notifPayload['sender_id'] = supervisorId;
      }
      if (workerId.isNotEmpty && UuidHelper.isValid(workerId)) {
        notifPayload['receiver_id'] = workerId;
      }
      await _client.from('notifications').insert(notifPayload);

      // 5. Mark alert as resolved
      await resolveAlert(alertId);
    } catch (e) {
      debugPrint('SupabaseRepository sendWarningForAlert error: $e');
    }
  }

  @override
  Future<void> dismissAlert({
    required String alertId,
    required String adminId,
    String? reason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'resolved_at': DateTime.now().toIso8601String(),
      };
      if (adminId.isNotEmpty && UuidHelper.isValid(adminId)) {
        updateData['resolved_by'] = adminId;
      }
      await _client.from('alerts').update(updateData).eq('alert_id', alertId);
    } catch (e) {
      debugPrint('SupabaseRepository dismissAlert error: $e');
    }
  }

  // ==========================================
  // Broadcasts & Notifications
  // ==========================================
  @override
  Future<List<BroadcastModel>> getBroadcasts() async {
    try {
      final res = await _client
          .from('notifications')
          .select('*, receiver:users!receiver_id(first_name, last_name, roles(name))')
          .order('sent_at', ascending: false);
      return (res as List).map((m) => BroadcastModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository getBroadcasts joined notice: $e');
      try {
        final res = await _client.from('notifications').select('*').order('sent_at', ascending: false);
        return (res as List).map((m) => BroadcastModel.fromJson(m as Map<String, dynamic>)).toList();
      } catch (fallbackErr) {
        debugPrint('SupabaseRepository getBroadcasts fallback error: $fallbackErr');
        return [];
      }
    }
  }

  @override
  Future<void> addBroadcast(BroadcastModel broadcast) async {
    try {
      final payload = broadcast.toSupabaseJson();
      if (payload['notification_id'] == null ||
          (payload['notification_id'] as String).isEmpty ||
          !UuidHelper.isValid(payload['notification_id'] as String)) {
        payload['notification_id'] = UuidHelper.generate();
      }
      if (payload['sender_id'] != null && !UuidHelper.isValid(payload['sender_id'] as String)) {
        payload.remove('sender_id');
      }
      if (payload['receiver_id'] != null && !UuidHelper.isValid(payload['receiver_id'] as String)) {
        payload.remove('receiver_id');
      }
      await _client.from('notifications').insert(payload);
    } catch (e) {
      debugPrint('SupabaseRepository addBroadcast error: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendReportToAdmin({
    required String reportType,
    required String summary,
    String? note,
    required String supervisorId,
    required String supervisorName,
  }) async {
    try {
      await _client.from('notifications').insert({
        'notification_id': UuidHelper.generate(),
        'sender_id': supervisorId,
        'message': 'Official Supervisor Transmittal: [$reportType] $summary. Note: ${note ?? "None"}',
        'type': 'confidential',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('SupabaseRepository sendReportToAdmin error: $e');
    }
  }

  // ==========================================
  // Incidents / Worker Reports
  // ==========================================
  @override
  Future<List<IncidentReportModel>> getIncidents({
    String? reporterId,
    String? workareaId,
    String? status,
  }) async {
    try {
      var query = _client.from('worker_reports').select('''
        *,
        reporter:users!worker_reports_reporter_id_fkey(first_name, last_name),
        reported:users!worker_reports_reported_id_fkey(first_name, last_name)
      ''');

      if (reporterId != null && reporterId.isNotEmpty) {
        query = query.eq('reporter_id', reporterId);
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((m) => IncidentReportModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository getIncidents error: $e');
      return [];
    }
  }

  @override
  Future<void> addIncident(IncidentReportModel incident) async {
    try {
      final payload = incident.toSupabaseJson();
      if (payload['report_id'] == null || (payload['report_id'] as String).isEmpty) {
        payload['report_id'] = UuidHelper.generate();
      }
      await _client.from('worker_reports').insert(payload);
    } catch (e) {
      debugPrint('SupabaseRepository addIncident error: $e');
      rethrow;
    }
  }

  @override
  Future<void> resolveIncident(String reportId) async {
    try {
      await _client.from('worker_reports').update({'status': 'resolved'}).eq('report_id', reportId);
    } catch (e) {
      debugPrint('SupabaseRepository resolveIncident error: $e');
    }
  }

  @override
  Future<void> settleIncidentLocally(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {
    try {
      await _client.from('worker_reports').update({
        'status': 'settled_locally',
      }).eq('report_id', reportId);
    } catch (e) {
      debugPrint('SupabaseRepository settleIncidentLocally error: $e');
      rethrow;
    }
  }

  @override
  Future<void> escalateIncidentToAdmin(
    String reportId, {
    required String supervisorId,
    required String supervisorName,
    required String notes,
  }) async {
    try {
      await _client.from('worker_reports').update({
        'status': 'escalated_to_admin',
      }).eq('report_id', reportId);

      // Dispatch escalation notice for central admin
      try {
        await _client.from('notifications').insert({
          'notification_id': UuidHelper.generate(),
          'user_id': null,
          'title': 'Incident Escalated: Field Supervisor $supervisorName',
          'message': 'Supervisor $supervisorName escalated field incident.\nRemarks: $notes',
          'type': 'incident',
          'is_read': false,
        });
      } catch (notifErr) {
        debugPrint('Notification dispatch on incident escalation error: $notifErr');
      }
    } catch (e) {
      debugPrint('SupabaseRepository escalateIncidentToAdmin error: $e');
      rethrow;
    }
  }

  @override
  Future<void> resolveIncidentByAdmin(
    String reportId, {
    required String adminId,
    required String resolutionNotes,
  }) async {
    try {
      await _client.from('worker_reports').update({
        'status': 'resolved',
      }).eq('report_id', reportId);
    } catch (e) {
      debugPrint('SupabaseRepository resolveIncidentByAdmin error: $e');
      rethrow;
    }
  }
}

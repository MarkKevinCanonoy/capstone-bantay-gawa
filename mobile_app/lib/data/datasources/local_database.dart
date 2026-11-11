import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/location_tracking_model.dart';
import '../models/incident_report_model.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  static bool _useInMemory = false;

  // In-memory fallback stores for desktop preview / testing
  UserModel? _memUser;
  final List<UserModel> _memEnrolledWorkers = [];
  List<WorkAreaModel> _memAreas = [];
  final List<AttendanceModel> _memAttendance = [];
  final List<AccomplishmentModel> _memAccomplishments = [];
  final List<LeaveRequestModel> _memLeaves = [];
  final List<LocationTrackingModel> _memTracking = [];
  final List<IncidentReportModel> _memIncidents = [];
  final Set<String> _memReadNotifications = {};

  LocalDatabase._init();

  Future<Database?> get database async {
    if (_useInMemory) return null;
    if (_database != null) return _database!;
    try {
      _database = await _initDB('bantay_gawa_offline.db');
      return _database!;
    } catch (e) {
      debugPrint('LocalDatabase falling back to in-memory store: $e');
      _useInMemory = true;
      return null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    try {
      dbPath = await getDatabasesPath();
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = dir.path;
    }
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS enrolled_workers (
            user_id TEXT PRIMARY KEY,
            username TEXT,
            first_name TEXT,
            last_name TEXT,
            contact_number TEXT,
            role_name TEXT,
            face_embedding TEXT,
            performance_score INTEGER DEFAULT 100,
            schedule TEXT,
            assigned_area_id TEXT,
            assigned_area_name TEXT,
            status TEXT DEFAULT 'active'
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS read_notifications (
            notification_id TEXT PRIMARY KEY,
            read_at TEXT NOT NULL
          )
        ''');

        // Automatic rolling retention purge on database open (30-day retention for synced records)
        try {
          final cutoff = DateTime.now().subtract(const Duration(days: 30));
          final cutoffIso = cutoff.toIso8601String();
          final cutoffDateOnly = cutoffIso.substring(0, 10);
          await db.delete('attendance_queue', where: 'is_synced = 1 AND timestamp < ?', whereArgs: [cutoffIso]);
          await db.delete('accomplishments_queue', where: 'is_synced = 1 AND captured_date < ?', whereArgs: [cutoffDateOnly]);
          await db.delete('leave_requests_queue', where: 'is_synced = 1 AND start_date < ?', whereArgs: [cutoffIso]);
          await db.delete('location_tracking_queue', where: 'is_synced = 1 AND timestamp < ?', whereArgs: [cutoffIso]);
          await db.delete('incident_reports_queue', where: 'is_synced = 1 AND created_at < ?', whereArgs: [cutoffIso]);
        } catch (e) {
          debugPrint('LocalDatabase onOpen purge error: $e');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE enrolled_workers (
        user_id TEXT PRIMARY KEY,
        username TEXT,
        first_name TEXT,
        last_name TEXT,
        contact_number TEXT,
        role_name TEXT,
        face_embedding TEXT,
        performance_score INTEGER DEFAULT 100,
        schedule TEXT,
        assigned_area_id TEXT,
        assigned_area_name TEXT,
        status TEXT DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_user (
        user_id TEXT PRIMARY KEY,
        username TEXT,
        first_name TEXT,
        last_name TEXT,
        contact_number TEXT,
        role_name TEXT,
        face_embedding TEXT,
        performance_score INTEGER,
        schedule TEXT,
        assigned_area_id TEXT,
        assigned_area_name TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_work_areas (
        workarea_id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        polygon_coordinates TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_queue (
        attendance_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workarea_id TEXT,
        action_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        gps_lat REAL NOT NULL,
        gps_lng REAL NOT NULL,
        image_path TEXT,
        face_match INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE accomplishments_queue (
        accomplishment_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workarea_id TEXT,
        image_path TEXT NOT NULL,
        captured_date TEXT NOT NULL,
        captured_time TEXT NOT NULL,
        captured_lat REAL NOT NULL,
        captured_lng REAL NOT NULL,
        message TEXT,
        status TEXT DEFAULT 'pending',
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE leave_requests_queue (
        leave_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        image_path TEXT,
        status TEXT DEFAULT 'pending',
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE location_tracking_queue (
        location_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        gps_lat REAL NOT NULL,
        gps_lng REAL NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE incident_reports_queue (
        report_id TEXT PRIMARY KEY,
        reporter_id TEXT NOT NULL,
        reporter_name TEXT,
        reported_id TEXT NOT NULL,
        reported_name TEXT,
        workarea_id TEXT,
        area_name TEXT,
        issue_type TEXT NOT NULL,
        description TEXT NOT NULL,
        image_url TEXT,
        status TEXT DEFAULT 'pending',
        is_escalated INTEGER DEFAULT 0,
        supervisor_notes TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  // --- Enrolled Workers (Biometric Store for Offline Face Login per SRS Section 2.1 & 6.1) ---
  Future<void> cacheEnrolledWorkers(List<UserModel> workers) async {
    final db = await database;
    if (db == null) {
      _memEnrolledWorkers.clear();
      _memEnrolledWorkers.addAll(workers);
      return;
    }
    final batch = db.batch();
    for (final worker in workers) {
      batch.insert(
        'enrolled_workers',
        {
          'user_id': worker.userId,
          'username': worker.username,
          'first_name': worker.firstName,
          'last_name': worker.lastName,
          'contact_number': worker.contactNumber,
          'role_name': worker.roleDisplayName,
          'face_embedding': worker.faceEmbedding,
          'performance_score': worker.creditScore,
          'schedule': worker.schedule,
          'assigned_area_id': worker.assignedAreaId,
          'assigned_area_name': worker.assignedAreaName,
          'status': worker.status,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<UserModel>> getEnrolledWorkers() async {
    final db = await database;
    if (db == null) {
      return _memEnrolledWorkers
          .where((w) => w.faceEmbedding != null && w.faceEmbedding!.trim().isNotEmpty)
          .toList();
    }
    final results = await db.query(
      'enrolled_workers',
      where: 'face_embedding IS NOT NULL AND face_embedding != ""',
    );
    return results.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<void> syncEnrolledWorkersFromCloud(dynamic client) async {
    try {
      final res = await client.from('users').select('''
        *,
        roles(name),
        credit_balance(current_score),
        work_area_assignments(workarea_id, is_active, work_areas(name))
      ''').not('face_embedding', 'is', null).timeout(const Duration(seconds: 12));

      final users = (res as List).map((m) => UserModel.fromJson(m as Map<String, dynamic>)).toList();
      if (users.isNotEmpty) {
        await cacheEnrolledWorkers(users);
        debugPrint('Successfully synchronized ${users.length} enrolled biometric worker profiles into local SQLite.');
      }
    } catch (e) {
      debugPrint('Cloud biometric sync notice (will operate seamlessly using local SQLite biometrics): $e');
    }
  }

  // --- User Cache ---
  Future<void> cacheUser(UserModel user) async {
    final db = await database;
    if (db == null) {
      _memUser = user;
      return;
    }
    await db.insert(
      'cached_user',
      {
        'user_id': user.userId,
        'username': user.username,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'contact_number': user.contactNumber,
        'role_name': user.roleName,
        'face_embedding': user.faceEmbedding,
        'performance_score': user.performanceScore,
        'schedule': user.schedule,
        'assigned_area_id': user.assignedAreaId,
        'assigned_area_name': user.assignedAreaName,
        'is_active': user.isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getCachedUser() async {
    final db = await database;
    if (db == null) return _memUser;
    final results = await db.query('cached_user', limit: 1);
    if (results.isEmpty) return _memUser;
    final map = results.first;
    return UserModel(
      userId: map['user_id'] as String,
      username: map['username'] as String? ?? '',
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      contactNumber: map['contact_number'] as String? ?? '',
      roleId: AppConstants.roleWorkerId,
      roleName: map['role_name'] as String? ?? 'Field Worker',
      faceEmbedding: map['face_embedding'] as String?,
      schedule: map['schedule'] as String? ?? 'Unassigned',
      assignedAreaId: map['assigned_area_id'] as String?,
      assignedAreaName: map['assigned_area_name'] as String?,
      performanceScore: map['performance_score'] as int? ?? 100,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Future<void> clearUserCache() async {
    final db = await database;
    if (db == null) {
      _memUser = null;
      return;
    }
    await db.delete('cached_user');
  }

  // --- Work Areas Cache ---
  Future<void> cacheWorkAreas(List<WorkAreaModel> areas) async {
    final db = await database;
    if (db == null) {
      _memAreas = List.from(areas);
      return;
    }
    final batch = db.batch();
    batch.delete('cached_work_areas');
    for (final area in areas) {
      batch.insert('cached_work_areas', {
        'workarea_id': area.workareaId,
        'name': area.name,
        'description': area.description,
        'polygon_coordinates': area.polygonCoordinates
            .map((c) => '${c.latitude},${c.longitude}')
            .join(';'),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<WorkAreaModel>> getCachedWorkAreas() async {
    final db = await database;
    if (db == null) return _memAreas;
    final results = await db.query('cached_work_areas');
    return results.map((m) => WorkAreaModel.fromMap(m)).toList();
  }

  // --- Attendance ---
  Future<void> insertAttendance(AttendanceModel attendance) async {
    final db = await database;
    if (db == null) {
      _memAttendance.removeWhere((a) => a.attendanceId == attendance.attendanceId);
      _memAttendance.insert(0, attendance);
      return;
    }
    await db.insert(
      'attendance_queue',
      {
        'attendance_id': attendance.attendanceId,
        'user_id': attendance.userId,
        'workarea_id': attendance.workareaId,
        'action_type': attendance.actionType,
        'timestamp': attendance.timestamp.toIso8601String(),
        'gps_lat': attendance.gpsLat,
        'gps_lng': attendance.gpsLng,
        'image_path': attendance.imageUrl,
        'face_match': attendance.faceMatch ? 1 : 0,
        'is_synced': attendance.isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    final db = await database;
    if (db == null) return _memAttendance;
    final results = await db.query('attendance_queue', orderBy: 'timestamp DESC');
    return results.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  Future<List<AttendanceModel>> getUnsyncedAttendance() async {
    final db = await database;
    if (db == null) return _memAttendance.where((a) => !a.isSynced).toList();
    final results = await db.query('attendance_queue', where: 'is_synced = 0');
    return results.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  Future<void> markAttendanceSynced(String attendanceId) async {
    final db = await database;
    if (db == null) {
      final index = _memAttendance.indexWhere((a) => a.attendanceId == attendanceId);
      if (index != -1) {
        final existing = _memAttendance[index];
        _memAttendance[index] = AttendanceModel(
          attendanceId: existing.attendanceId,
          userId: existing.userId,
          workerName: existing.workerName,
          workerEmpId: existing.workerEmpId,
          workareaId: existing.workareaId,
          areaName: existing.areaName,
          actionType: existing.actionType,
          timestamp: existing.timestamp,
          gpsLat: existing.gpsLat,
          gpsLng: existing.gpsLng,
          imageUrl: existing.imageUrl,
          faceMatch: existing.faceMatch,
          isSynced: true,
          isVerified: existing.isVerified,
          hasWarning: existing.hasWarning,
          timeIn: existing.timeIn,
          isSubstitute: existing.isSubstitute,
          lateReason: existing.lateReason,
        );
      }
      return;
    }
    await db.update(
      'attendance_queue',
      {'is_synced': 1},
      where: 'attendance_id = ?',
      whereArgs: [attendanceId],
    );
  }

  // --- Accomplishments ---
  Future<void> insertAccomplishment(AccomplishmentModel accomplishment) async {
    final db = await database;
    if (db == null) {
      _memAccomplishments.removeWhere((a) => a.accomplishmentId == accomplishment.accomplishmentId);
      _memAccomplishments.insert(0, accomplishment);
      return;
    }
    await db.insert(
      'accomplishments_queue',
      {
        'accomplishment_id': accomplishment.accomplishmentId,
        'user_id': accomplishment.userId,
        'workarea_id': accomplishment.workareaId,
        'image_path': accomplishment.imageUrl,
        'captured_date': accomplishment.capturedDate.toIso8601String().substring(0, 10),
        'captured_time': accomplishment.capturedTime,
        'captured_lat': accomplishment.capturedLat,
        'captured_lng': accomplishment.capturedLng,
        'message': accomplishment.message,
        'status': accomplishment.status,
        'is_synced': accomplishment.isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AccomplishmentModel>> getAllAccomplishments() async {
    final db = await database;
    if (db == null) return _memAccomplishments;
    final results = await db.query('accomplishments_queue', orderBy: 'captured_date DESC');
    return results.map((m) => AccomplishmentModel.fromMap(m)).toList();
  }

  Future<List<AccomplishmentModel>> getUnsyncedAccomplishments() async {
    final db = await database;
    if (db == null) return _memAccomplishments.where((a) => !a.isSynced).toList();
    final results = await db.query('accomplishments_queue', where: 'is_synced = 0');
    return results.map((m) => AccomplishmentModel.fromMap(m)).toList();
  }

  Future<void> markAccomplishmentSynced(String accomplishmentId) async {
    final db = await database;
    if (db == null) {
      final index = _memAccomplishments.indexWhere((a) => a.accomplishmentId == accomplishmentId);
      if (index != -1) {
        final existing = _memAccomplishments[index];
        _memAccomplishments[index] = AccomplishmentModel(
          accomplishmentId: existing.accomplishmentId,
          userId: existing.userId,
          workerName: existing.workerName,
          workareaId: existing.workareaId,
          areaName: existing.areaName,
          imageUrl: existing.imageUrl,
          capturedDate: existing.capturedDate,
          capturedTime: existing.capturedTime,
          capturedLat: existing.capturedLat,
          capturedLng: existing.capturedLng,
          message: existing.message,
          status: existing.status,
          approvedBy: existing.approvedBy,
          approvedByName: existing.approvedByName,
          approvedAt: existing.approvedAt,
          rejectionReason: existing.rejectionReason,
          isSynced: true,
        );
      }
      return;
    }
    await db.update(
      'accomplishments_queue',
      {'is_synced': 1},
      where: 'accomplishment_id = ?',
      whereArgs: [accomplishmentId],
    );
  }

  Future<void> updateAccomplishmentImageUrl(String accomplishmentId, String newUrl) async {
    final db = await database;
    if (db == null) {
      final index = _memAccomplishments.indexWhere((a) => a.accomplishmentId == accomplishmentId);
      if (index != -1) {
        _memAccomplishments[index] = _memAccomplishments[index].copyWith(imageUrl: newUrl);
      }
      return;
    }
    await db.update(
      'accomplishments_queue',
      {'image_path': newUrl},
      where: 'accomplishment_id = ?',
      whereArgs: [accomplishmentId],
    );
  }

  // --- Leave Requests ---
  Future<void> insertLeaveRequest(LeaveRequestModel leave) async {
    final db = await database;
    if (db == null) {
      _memLeaves.insert(0, leave);
      return;
    }
    await db.insert(
      'leave_requests_queue',
      {
        'leave_id': leave.leaveId,
        'user_id': leave.userId,
        'type': leave.type,
        'start_date': leave.startDate.toIso8601String(),
        'end_date': leave.endDate.toIso8601String(),
        'reason': leave.reason,
        'image_path': leave.imageUrl,
        'status': leave.status,
        'is_synced': leave.isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LeaveRequestModel>> getAllLeaveRequests() async {
    final db = await database;
    if (db == null) return _memLeaves;
    final results = await db.query('leave_requests_queue', orderBy: 'start_date DESC');
    return results.map((m) => LeaveRequestModel.fromMap(m)).toList();
  }

  Future<List<LeaveRequestModel>> getUnsyncedLeaves() async {
    final db = await database;
    if (db == null) return _memLeaves.where((l) => !l.isSynced).toList();
    final results = await db.query(
      'leave_requests_queue',
      where: 'is_synced = 0',
      orderBy: 'start_date DESC',
    );
    return results.map((m) => LeaveRequestModel.fromMap(m)).toList();
  }

  Future<void> updateLeaveStatus(String leaveId, String status) async {
    final db = await database;
    if (db == null) {
      final idx = _memLeaves.indexWhere((l) => l.leaveId == leaveId);
      if (idx != -1) {
        _memLeaves[idx] = _memLeaves[idx].copyWith(status: status);
      }
      return;
    }
    await db.update(
      'leave_requests_queue',
      {'status': status},
      where: 'leave_id = ?',
      whereArgs: [leaveId],
    );
  }

  Future<void> markLeaveSynced(String leaveId) async {
    final db = await database;
    if (db == null) {
      final idx = _memLeaves.indexWhere((l) => l.leaveId == leaveId);
      if (idx != -1) {
        final existing = _memLeaves[idx];
        _memLeaves[idx] = LeaveRequestModel(
          leaveId: existing.leaveId,
          userId: existing.userId,
          type: existing.type,
          startDate: existing.startDate,
          endDate: existing.endDate,
          reason: existing.reason,
          imageUrl: existing.imageUrl,
          status: existing.status,
          isSynced: true,
        );
      }
      return;
    }
    await db.update(
      'leave_requests_queue',
      {'is_synced': 1},
      where: 'leave_id = ?',
      whereArgs: [leaveId],
    );
  }

  Future<void> updateLeaveImageUrl(String leaveId, String newUrl) async {
    final db = await database;
    if (db == null) {
      final index = _memLeaves.indexWhere((l) => l.leaveId == leaveId);
      if (index != -1) {
        _memLeaves[index] = _memLeaves[index].copyWith(imageUrl: newUrl);
      }
      return;
    }
    await db.update(
      'leave_requests_queue',
      {'image_path': newUrl},
      where: 'leave_id = ?',
      whereArgs: [leaveId],
    );
  }

  // --- Incident Reports Queue ---
  Future<void> insertIncidentReport(IncidentReportModel report) async {
    final db = await database;
    if (db == null) {
      _memIncidents.insert(0, report);
      return;
    }
    await db.insert(
      'incident_reports_queue',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<IncidentReportModel>> getAllIncidentReports() async {
    final db = await database;
    if (db == null) return _memIncidents;
    final results = await db.query('incident_reports_queue', orderBy: 'created_at DESC');
    return results.map((m) => IncidentReportModel.fromMap(m)).toList();
  }

  Future<List<IncidentReportModel>> getUnsyncedIncidentReports() async {
    final db = await database;
    if (db == null) return _memIncidents.where((i) => !i.isSynced).toList();
    final results = await db.query(
      'incident_reports_queue',
      where: 'is_synced = 0',
      orderBy: 'created_at DESC',
    );
    return results.map((m) => IncidentReportModel.fromMap(m)).toList();
  }

  Future<void> markIncidentReportSynced(String reportId) async {
    final db = await database;
    if (db == null) {
      final idx = _memIncidents.indexWhere((i) => i.reportId == reportId);
      if (idx != -1) {
        _memIncidents[idx] = _memIncidents[idx].copyWith(isSynced: true);
      }
      return;
    }
    await db.update(
      'incident_reports_queue',
      {'is_synced': 1},
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  // --- Location Tracking Queue ---
  Future<void> insertLocationTracking(LocationTrackingModel tracking) async {
    final db = await database;
    if (db == null) {
      _memTracking.add(tracking);
      return;
    }
    await db.insert(
      'location_tracking_queue',
      {
        'location_id': tracking.locationId,
        'user_id': tracking.userId,
        'gps_lat': tracking.gpsLat,
        'gps_lng': tracking.gpsLng,
        'timestamp': tracking.timestamp.toIso8601String(),
        'is_synced': tracking.isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationTrackingModel>> getUnsyncedLocationTracking() async {
    final db = await database;
    if (db == null) {
      return _memTracking.where((t) => !t.isSynced).toList();
    }
    final maps = await db.query(
      'location_tracking_queue',
      where: 'is_synced = 0',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => LocationTrackingModel.fromJson(m)).toList();
  }

  Future<void> markLocationTrackingSynced(String locationId) async {
    final db = await database;
    if (db == null) {
      final idx = _memTracking.indexWhere((t) => t.locationId == locationId);
      if (idx != -1) {
        _memTracking[idx] = _memTracking[idx].copyWith(isSynced: true);
      }
      return;
    }
    await db.update(
      'location_tracking_queue',
      {'is_synced': 1},
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    if (db == null) {
      final att = _memAttendance.where((a) => !a.isSynced).length;
      final acc = _memAccomplishments.where((a) => !a.isSynced).length;
      final lve = _memLeaves.where((l) => !l.isSynced).length;
      final inc = _memIncidents.where((i) => !i.isSynced).length;
      final loc = _memTracking.where((t) => !t.isSynced).length;
      return att + acc + lve + inc + loc;
    }
    final attCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance_queue WHERE is_synced = 0')) ?? 0;
    final accCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accomplishments_queue WHERE is_synced = 0')) ?? 0;
    final lveCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM leave_requests_queue WHERE is_synced = 0')) ?? 0;
    final incCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM incident_reports_queue WHERE is_synced = 0')) ?? 0;
    final locCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM location_tracking_queue WHERE is_synced = 0')) ?? 0;
    return attCount + accCount + lveCount + incCount + locCount;
  }

  // --- Read Notifications Tracking ---
  Future<void> markNotificationAsRead(String notificationId) async {
    final db = await database;
    if (db == null) {
      _memReadNotifications.add(notificationId);
      return;
    }
    await db.insert(
      'read_notifications',
      {
        'notification_id': notificationId,
        'read_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markAllNotificationsAsRead(List<String> notificationIds) async {
    final db = await database;
    if (db == null) {
      _memReadNotifications.addAll(notificationIds);
      return;
    }
    final batch = db.batch();
    for (final id in notificationIds) {
      batch.insert(
        'read_notifications',
        {
          'notification_id': id,
          'read_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> getReadNotificationIds() async {
    final db = await database;
    if (db == null) {
      return Set<String>.from(_memReadNotifications);
    }
    final rows = await db.query('read_notifications', columns: ['notification_id']);
    return rows.map((r) => r['notification_id'] as String).toSet();
  }

  /// Automated rolling retention cleanup: Purges synced records (is_synced = 1)
  /// older than [retentionDays] from offline storage to keep SQLite and device storage lean.
  /// Unsynced records (is_synced = 0) are strictly retained until uploaded.
  Future<void> purgeOldSyncedRecords({int retentionDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffIso = cutoff.toIso8601String();
    final cutoffDateOnly = cutoffIso.substring(0, 10);

    final db = await database;
    if (db == null) {
      _memAttendance.removeWhere((a) => a.isSynced && a.timestamp.isBefore(cutoff));
      _memAccomplishments.removeWhere((a) => a.isSynced && a.capturedDate.isBefore(cutoff));
      _memLeaves.removeWhere((l) => l.isSynced && l.startDate.isBefore(cutoff));
      _memTracking.removeWhere((t) => t.isSynced && t.timestamp.isBefore(cutoff));
      _memIncidents.removeWhere((i) => i.isSynced && i.createdAt.isBefore(cutoff));
      return;
    }

    try {
      final attDeleted = await db.delete('attendance_queue', where: 'is_synced = 1 AND timestamp < ?', whereArgs: [cutoffIso]);
      final accDeleted = await db.delete('accomplishments_queue', where: 'is_synced = 1 AND captured_date < ?', whereArgs: [cutoffDateOnly]);
      final lveDeleted = await db.delete('leave_requests_queue', where: 'is_synced = 1 AND start_date < ?', whereArgs: [cutoffIso]);
      final locDeleted = await db.delete('location_tracking_queue', where: 'is_synced = 1 AND timestamp < ?', whereArgs: [cutoffIso]);
      final incDeleted = await db.delete('incident_reports_queue', where: 'is_synced = 1 AND created_at < ?', whereArgs: [cutoffIso]);
      final total = attDeleted + accDeleted + lveDeleted + locDeleted + incDeleted;
      if (total > 0) {
        debugPrint('LocalDatabase: Purged $total synced records older than $retentionDays days (cutoff: $cutoffIso)');
      }
    } catch (e) {
      debugPrint('LocalDatabase: purgeOldSyncedRecords error: $e');
    }
  }
}

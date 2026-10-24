import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/work_area_model.dart';
import '../models/attendance_model.dart';
import '../models/accomplishment_model.dart';
import '../models/leave_request_model.dart';
import '../models/location_tracking_model.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bantay_gawa_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
        face_match INTEGER DEFAULT 1,
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
  }

  // --- User Cache ---
  Future<void> cacheUser(UserModel user) async {
    final db = await database;
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
        'is_active': user.isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getCachedUser() async {
    final db = await database;
    final results = await db.query('cached_user', limit: 1);
    if (results.isEmpty) return null;
    final map = results.first;
    return UserModel(
      userId: map['user_id'] as String,
      username: map['username'] as String? ?? '',
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      contactNumber: map['contact_number'] as String? ?? '',
      roleId: 'worker_role_id',
      roleName: map['role_name'] as String? ?? 'Field Worker',
      faceEmbedding: map['face_embedding'] as String?,
      performanceScore: map['performance_score'] as int? ?? 85,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Future<void> clearUserCache() async {
    final db = await database;
    await db.delete('cached_user');
  }

  // --- Work Areas Cache ---
  Future<void> cacheWorkAreas(List<WorkAreaModel> areas) async {
    final db = await database;
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
    final results = await db.query('cached_work_areas');
    return results.map((m) => WorkAreaModel.fromMap(m)).toList();
  }

  // --- Attendance ---
  Future<void> insertAttendance(AttendanceModel attendance) async {
    final db = await database;
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
    final results = await db.query('attendance_queue', orderBy: 'timestamp DESC');
    return results.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  Future<List<AttendanceModel>> getUnsyncedAttendance() async {
    final db = await database;
    final results = await db.query('attendance_queue', where: 'is_synced = 0');
    return results.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  Future<void> markAttendanceSynced(String attendanceId) async {
    final db = await database;
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
    final results = await db.query('accomplishments_queue', orderBy: 'captured_date DESC');
    return results.map((m) => AccomplishmentModel.fromMap(m)).toList();
  }

  Future<List<AccomplishmentModel>> getUnsyncedAccomplishments() async {
    final db = await database;
    final results = await db.query('accomplishments_queue', where: 'is_synced = 0');
    return results.map((m) => AccomplishmentModel.fromMap(m)).toList();
  }

  Future<void> markAccomplishmentSynced(String accomplishmentId) async {
    final db = await database;
    await db.update(
      'accomplishments_queue',
      {'is_synced': 1},
      where: 'accomplishment_id = ?',
      whereArgs: [accomplishmentId],
    );
  }

  // --- Leave Requests ---
  Future<void> insertLeaveRequest(LeaveRequestModel leave) async {
    final db = await database;
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
    final results = await db.query('leave_requests_queue', orderBy: 'start_date DESC');
    return results.map((m) => LeaveRequestModel.fromMap(m)).toList();
  }

  // --- Location Tracking Queue ---
  Future<void> insertLocationTracking(LocationTrackingModel tracking) async {
    final db = await database;
    await db.insert(
      'location_tracking_queue',
      {
        'location_id': tracking.locationId,
        'user_id': tracking.userId,
        'gps_lat': tracking.gpsLat,
        'gps_lng': tracking.gpsLng,
        'timestamp': tracking.timestamp.toIso8601String(),
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final attCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance_queue WHERE is_synced = 0')) ?? 0;
    final accCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accomplishments_queue WHERE is_synced = 0')) ?? 0;
    return attCount + accCount;
  }
}

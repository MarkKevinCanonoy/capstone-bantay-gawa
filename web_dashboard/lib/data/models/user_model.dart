enum UserRole { admin, supervisor, worker }

class UserModel {
  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String contactNumber;
  final String? qrToken;
  final UserRole role;
  final String? faceEmbedding;
  final String status; // 'active', 'inactive', 'pending'
  final String? assignedAreaId;
  final String? assignedAreaName;
  final String? photoUrl;
  final String schedule; // e.g. "Mon-Fri 07:00 - 16:00"
  final int creditScore; // 0 - 100

  UserModel({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.contactNumber,
    this.qrToken,
    required this.role,
    this.faceEmbedding,
    this.status = 'active',
    this.assignedAreaId,
    this.assignedAreaName,
    this.photoUrl,
    this.schedule = 'Unassigned',
    this.creditScore = 100,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.supervisor:
        return 'Field Supervisor';
      case UserRole.worker:
        return 'Field Worker';
    }
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? firstName,
    String? lastName,
    String? contactNumber,
    String? qrToken,
    UserRole? role,
    String? faceEmbedding,
    String? status,
    String? assignedAreaId,
    String? assignedAreaName,
    bool clearAssignedArea = false,
    String? photoUrl,
    String? schedule,
    int? creditScore,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      contactNumber: contactNumber ?? this.contactNumber,
      qrToken: qrToken ?? this.qrToken,
      role: role ?? this.role,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      status: status ?? this.status,
      assignedAreaId: clearAssignedArea ? null : (assignedAreaId ?? this.assignedAreaId),
      assignedAreaName: clearAssignedArea ? null : (assignedAreaName ?? this.assignedAreaName),
      photoUrl: photoUrl ?? this.photoUrl,
      schedule: schedule ?? this.schedule,
      creditScore: creditScore ?? this.creditScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'contact_number': contactNumber,
      'qr_token': qrToken,
      'role': roleDisplayName,
      'status': status,
      'assigned_area_id': assignedAreaId,
      'schedule': schedule,
      'credit_score': creditScore,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole role = UserRole.worker;
    String rStr = (json['role'] ?? json['role_name'] ?? json['role_id'] ?? '').toString().toLowerCase();
    if (json['roles'] is Map) {
      final rMap = json['roles'] as Map;
      rStr = '${rMap['name'] ?? ''} ${rMap['role_id'] ?? ''} $rStr'.toLowerCase();
    } else if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      final firstRole = (json['roles'] as List).first;
      if (firstRole is Map) {
        rStr = '${firstRole['name'] ?? ''} ${firstRole['role_id'] ?? ''} $rStr'.toLowerCase();
      }
    }
    if (rStr.contains('admin') || rStr.contains('00000000-0000-0000-0000-000000000001')) {
      role = UserRole.admin;
    } else if (rStr.contains('super') || rStr.contains('00000000-0000-0000-0000-000000000002')) {
      role = UserRole.supervisor;
    }

    // Extract credit score from joined credit_balance or direct field
    int score = 100;
    if (json['credit_score'] != null) {
      score = int.tryParse(json['credit_score'].toString()) ?? 100;
    } else if (json['credit_balance'] != null) {
      final cb = json['credit_balance'];
      if (cb is Map) {
        score = int.tryParse(cb['current_score']?.toString() ?? '100') ?? 100;
      } else if (cb is List && cb.isNotEmpty && cb.first is Map) {
        score = int.tryParse(cb.first['current_score']?.toString() ?? '100') ?? 100;
      }
    }

    // Extract assigned area from joined work_area_assignments
    String? areaId = json['assigned_area_id']?.toString();
    String? areaName = json['assigned_area_name']?.toString();
    if (json['work_area_assignments'] is List) {
      final assignments = json['work_area_assignments'] as List;
      final active = assignments.firstWhere(
        (a) => a is Map && (a['is_active'] == true || a['is_active'] == 1),
        orElse: () => assignments.isNotEmpty ? assignments.first : null,
      );
      if (active is Map) {
        areaId = active['workarea_id']?.toString();
        if (active['work_areas'] is Map) {
          areaName = active['work_areas']['name']?.toString();
        }
      }
    }

    // Parse Shift Schedule from joined schedules table (specs/schema.sql) or fallback column
    String parsedSchedule = 'Unassigned';
    if (json['schedules'] is List && (json['schedules'] as List).isNotEmpty) {
      final sList = (json['schedules'] as List).whereType<Map>().toList();
      if (sList.isNotEmpty) {
        sList.sort((a, b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
        final latest = sList.first;
        final rawDays = latest['days']?.toString() ?? 'Mon-Fri';
        var st = latest['start_time']?.toString() ?? '08:00';
        var et = latest['end_time']?.toString() ?? '17:00';
        if (st.length > 5 && st.contains(':')) st = st.substring(0, 5);
        if (et.length > 5 && et.contains(':')) et = et.substring(0, 5);
        parsedSchedule = '$rawDays $st - $et';
      }
    } else if (json['schedule'] != null && json['schedule'].toString().trim().isNotEmpty) {
      parsedSchedule = json['schedule'].toString();
    }

    return UserModel(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      qrToken: json['qr_token']?.toString(),
      role: role,
      faceEmbedding: json['face_embedding']?.toString(),
      status: json['status']?.toString() ?? 'active',
      assignedAreaId: areaId,
      assignedAreaName: areaName,
      photoUrl: json['photo_url']?.toString(),
      schedule: parsedSchedule,
      creditScore: score,
    );
  }
}

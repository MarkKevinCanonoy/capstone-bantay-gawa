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
    this.schedule = 'Mon-Fri 07:00 - 16:00',
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
    final rStr = (json['role'] ?? json['role_name'] ?? '').toString().toLowerCase();
    if (rStr.contains('admin')) {
      role = UserRole.admin;
    } else if (rStr.contains('super')) {
      role = UserRole.supervisor;
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
      assignedAreaId: json['assigned_area_id']?.toString(),
      assignedAreaName: json['assigned_area_name']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      schedule: json['schedule']?.toString() ?? 'Mon-Fri 07:00 - 16:00',
      creditScore: int.tryParse(json['credit_score']?.toString() ?? '100') ?? 100,
    );
  }
}

class PasskeyModel {
  final String passkeyId;
  final String userId;
  final String credentialId;
  final String? publicKey;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const PasskeyModel({
    required this.passkeyId,
    required this.userId,
    required this.credentialId,
    this.publicKey,
    required this.deviceName,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory PasskeyModel.fromJson(Map<String, dynamic> json) {
    return PasskeyModel(
      passkeyId: json['passkey_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      credentialId: json['credential_id'] as String? ?? '',
      publicKey: json['public_key'] as String?,
      deviceName: json['device_name'] as String? ?? 'Biometric Device',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (passkeyId.isNotEmpty) 'passkey_id': passkeyId,
      'user_id': userId,
      'credential_id': credentialId,
      if (publicKey != null) 'public_key': publicKey,
      'device_name': deviceName,
      'created_at': createdAt.toIso8601String(),
      if (lastUsedAt != null) 'last_used_at': lastUsedAt!.toIso8601String(),
    };
  }

  PasskeyModel copyWith({
    String? passkeyId,
    String? userId,
    String? credentialId,
    String? publicKey,
    String? deviceName,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return PasskeyModel(
      passkeyId: passkeyId ?? this.passkeyId,
      userId: userId ?? this.userId,
      credentialId: credentialId ?? this.credentialId,
      publicKey: publicKey ?? this.publicKey,
      deviceName: deviceName ?? this.deviceName,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

class BroadcastModel {
  final String notificationId;
  final String? senderId;
  final String? receiverId;
  final String recipients; // 'All Personnel', 'Field Supervisors', 'District 1 Crew', etc.
  final String subject;
  final String message;
  final String type; // 'announcement', 'confidential', 'alert'
  final bool isConfidential;
  final int deliveredCount;
  final DateTime sentAt;

  BroadcastModel({
    required this.notificationId,
    this.senderId,
    this.receiverId,
    required this.recipients,
    required this.subject,
    required this.message,
    this.type = 'announcement',
    this.isConfidential = false,
    this.deliveredCount = 48,
    required this.sentAt,
  });

  BroadcastModel copyWith({
    String? notificationId,
    String? senderId,
    String? receiverId,
    String? recipients,
    String? subject,
    String? message,
    String? type,
    bool? isConfidential,
    int? deliveredCount,
    DateTime? sentAt,
  }) {
    return BroadcastModel(
      notificationId: notificationId ?? this.notificationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      recipients: recipients ?? this.recipients,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      type: type ?? this.type,
      isConfidential: isConfidential ?? this.isConfidential,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

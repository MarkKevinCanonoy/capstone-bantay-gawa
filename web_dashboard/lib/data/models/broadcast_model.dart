import '../../core/utils/uuid_helper.dart';

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
    this.deliveredCount = 0,
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

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'announcement';
    var rawMsg = json['message']?.toString() ?? '';

    // Check for smart target/audience tag: [Target: ...] or [Audience: ...]
    String? audienceTag;
    if (rawMsg.startsWith('[Target: ') && rawMsg.contains(']')) {
      final endIdx = rawMsg.indexOf(']');
      audienceTag = rawMsg.substring(9, endIdx).trim();
      rawMsg = rawMsg.substring(endIdx + 1).trim();
    } else if (rawMsg.startsWith('[Audience: ') && rawMsg.contains(']')) {
      final endIdx = rawMsg.indexOf(']');
      audienceTag = rawMsg.substring(11, endIdx).trim();
      rawMsg = rawMsg.substring(endIdx + 1).trim();
    }

    String subj = json['subject']?.toString() ?? '';
    String body = rawMsg;
    if (subj.isEmpty) {
      if (rawMsg.contains(':')) {
        final split = rawMsg.split(':');
        subj = split.first.trim();
        body = split.sublist(1).join(':').trim();
      } else {
        subj = type == 'announcement' ? 'Public ENRO Announcement' : 'Official Notice';
      }
    }

    // Determine smart target recipient
    String resolvedRecipients;
    if (audienceTag != null && audienceTag.isNotEmpty) {
      resolvedRecipients = audienceTag;
    } else if (json['recipients'] != null &&
        json['recipients'].toString().isNotEmpty &&
        json['recipients'] != 'Field Worker' &&
        json['recipients'] != 'All Personnel') {
      resolvedRecipients = json['recipients'].toString();
    } else if (json['receiver'] is Map) {
      final r = json['receiver'] as Map;
      final fName = r['first_name']?.toString() ?? '';
      final lName = r['last_name']?.toString() ?? '';
      final fullName = '$fName $lName'.trim();
      final role = (r['roles'] is Map ? (r['roles'] as Map)['name']?.toString() : null) ?? r['role']?.toString() ?? '';
      final roleLabel = role.toLowerCase().contains('supervisor') ? 'Supervisor' : 'Worker';
      if (fullName.isNotEmpty) {
        resolvedRecipients = '$fullName ($roleLabel)';
      } else {
        resolvedRecipients = roleLabel;
      }
    } else if (json['receiver_id'] != null) {
      resolvedRecipients = json['recipients']?.toString() ?? 'Field Worker';
    } else {
      resolvedRecipients = json['recipients']?.toString() ?? 'All Users (City-wide Personnel)';
    }

    return BroadcastModel(
      notificationId: json['notification_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      receiverId: json['receiver_id']?.toString(),
      recipients: resolvedRecipients,
      subject: subj,
      message: body,
      type: type,
      isConfidential: type == 'confidential',
      deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    var combinedMessage = subject.isNotEmpty ? '$subject: $message' : message;
    if (!combinedMessage.startsWith('[Target: ') && recipients.isNotEmpty) {
      combinedMessage = '[Target: $recipients] $combinedMessage';
    }
    return {
      'notification_id': notificationId.isNotEmpty ? notificationId : UuidHelper.generate(),
      if (senderId != null && senderId!.isNotEmpty) 'sender_id': senderId,
      if (receiverId != null && receiverId!.isNotEmpty) 'receiver_id': receiverId,
      'message': combinedMessage,
      'type': type,
      'is_read': false,
    };
  }
}

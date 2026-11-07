class CreditHistoryModel {
  final String historyId;
  final String userId;
  final int changeAmount; // e.g., +5, +10, -15, -5
  final String reason;
  final String category; // 'attendance', 'accomplishment', 'absence', 'breach'
  final DateTime createdAt;

  CreditHistoryModel({
    required this.historyId,
    required this.userId,
    required this.changeAmount,
    required this.reason,
    this.category = 'attendance',
    required this.createdAt,
  });

  bool get isAddition => changeAmount > 0;

  factory CreditHistoryModel.fromJson(Map<String, dynamic> json) {
    return CreditHistoryModel(
      historyId: json['history_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      changeAmount: json['change_amount'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      category: json['category'] as String? ?? 'attendance',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history_id': historyId,
      'user_id': userId,
      'change_amount': changeAmount,
      'reason': reason,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

import 'user.dart';

class Contact {
  final int id;
  final User contactUser;
  final String? displayName;
  final DateTime addedAt;
  final bool isBlocked;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Contact({
    required this.id,
    required this.contactUser,
    this.displayName,
    required this.addedAt,
    this.isBlocked = false,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as int,
      contactUser: User.fromJson(json['contact_user'] as Map<String, dynamic>),
      displayName: json['display_name'] as String?,
      addedAt: DateTime.parse(json['added_at'] as String),
      isBlocked: json['is_blocked'] as bool? ?? false,
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.parse(json['last_message_at'] as String) 
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_user': contactUser.toJson(),
      'display_name': displayName,
      'added_at': addedAt.toIso8601String(),
      'is_blocked': isBlocked,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }

  Contact copyWith({
    int? id,
    User? contactUser,
    String? displayName,
    DateTime? addedAt,
    bool? isBlocked,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return Contact(
      id: id ?? this.id,
      contactUser: contactUser ?? this.contactUser,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt ?? this.addedAt,
      isBlocked: isBlocked ?? this.isBlocked,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  // 获取显示名称（优先使用备注名，否则使用用户名）
  String get displayNameOrUsername => displayName ?? contactUser.username;
} 
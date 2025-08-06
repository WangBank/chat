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
      contactUser: User.fromJson(json['contactUser'] as Map<String, dynamic>),
      displayName: json['displayName'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
      isBlocked: json['isBlocked'] as bool? ?? false,
      lastMessageAt: json['lastMessageAt'] != null 
          ? DateTime.parse(json['lastMessageAt'] as String) 
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactUser': contactUser.toJson(),
      'displayName': displayName,
      'addedAt': addedAt.toIso8601String(),
      'isBlocked': isBlocked,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCount': unreadCount,
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